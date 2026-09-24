import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:comparators/comparators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/serde.dart';
import 'package:squadron/squadron.dart';

import 'navigator_double.activator.g.dart';
part 'navigator_double.freezed.dart';
part 'navigator_double.worker.g.dart';

@freezed
abstract class NavigateDoubleArguments with _$NavigateDoubleArguments {
  NavigateDoubleArguments._();

  factory NavigateDoubleArguments({
    required Node start1,
    required Node start2,
    required Set<Node> resources,
    required Set<Node> exits,
    KeyResource? keyResource,
    /// 一人到达关键资源点后，另一人继续移动时每步额外增加的代价
    @Default(1.0) double transportWaitingUrgency,
  }) = _NavigateDoubleArguments;

  String get identify => '${start1.identify}/${start2.identify}'
      '/${resources.sorted(Comparable.compare).map((node) => node.identify).join(',')}'
      '/${exits.sorted(Comparable.compare).map((node) => node.identify).join(',')}'
      '${keyResource == null ? '' : '/${keyResource!.position.identify},${keyResource!.transport.identify},${keyResource!.urgency}'}'
      '/$transportWaitingUrgency';
}

@freezed
abstract class _BfsResult with _$BfsResult {
  _BfsResult._();
  factory _BfsResult({
    /// 原点到各节点的最短路径
    required List<int?> dist,
    /// 父指针
    required List<int?> parent,
  }) = __BfsResult;
}

@freezed
abstract class _DoubleAStarState with _$DoubleAStarState {
  _DoubleAStarState._();

  factory _DoubleAStarState({
    /// 第一个人当前所在地标
    required int landmark1,
    /// 第二个人当前所在地标
    required int landmark2,
    /// 已收集资源索引
    required Set<int> collectedResources,
    /// 0 未触发关键资源，1 已有一人在关键资源点等待，2 已传送
    required int transportPhase,
    /// 0 无等待者，1 表示第一个人在 keyResource.position 等待，2 表示第二个人在等待
    required int waitingAgent, // TODO: 合并字段
  }) = __DoubleAStarState;
}

class _DoubleCost {
  final double cost1;
  final double cost2;
  const _DoubleCost(this.cost1, this.cost2);
}

({List<Node> path1, List<Node> path2}) navigateDouble(World world, NavigateDoubleArguments arguments) {
  var keyResource = arguments.keyResource;
  if (keyResource != null && !arguments.resources.contains(keyResource.position)) {
    keyResource = null;
  }

  // 1. 构建所有可通行节点的列表和索引映射

  // 构建节点列表与映射
  final nodes = <Node>[];
  final nodeToIndex = <Node, int>{};
  for (final layer in world.map.keys) {
    for (int x = world.minX; x <= world.maxX; x++) {
      for (int y = world.minY; y <= world.maxY; y++) {
        final cell = world.cell(layer, x, y);
        if (cell != null && cell.structureId != null) {
          final node = Node(layer, x, y);
          nodeToIndex[node] = nodes.length;
          nodes.add(node);
        }
      }
    }
  }
  final n = nodes.length;
  if (n == 0) return (path1: [], path2: []);
  // 资源点列表与映射
  final resources = arguments.resources.toList();
  final resourceToIndex = <Node, int>{};
  for (int i = 0; i < resources.length; i++) {
    resourceToIndex[resources[i]] = i;
  }
  final k = resources.length;
  // 关键资源相关
  int? keyResourceIndex;
  const double defaultWeight = 1.0;
  double keyResourceWeight = 0.0;
  if (keyResource != null) {
    keyResourceIndex = resourceToIndex[keyResource.position]!;
    keyResourceWeight = keyResource.urgency;
  }

  // 2. 构建地标集合：两个起点 + 所有资源点 + 所有出口 + 关键资源点位置 + 关键资源点传送目标 (与单人基本一致，仅修改起点处理)

  // 构建地标列表与映射
  final landmarkNodes = <Node>[];
  final landmarkToIndex = <Node, int>{};
  void addLandmark(Node node) {
    assert(nodeToIndex.containsKey(node));
    if (landmarkToIndex.containsKey(node)) return;
    landmarkToIndex[node] = landmarkNodes.length;
    landmarkNodes.add(node);
  }
  addLandmark(arguments.start1);
  addLandmark(arguments.start2);
  for (final r in resources) {
    addLandmark(r);
  }
  for (final e in arguments.exits) {
    addLandmark(e);
  }
  if (keyResource != null) {
    addLandmark(keyResource.position);
    addLandmark(keyResource.transport);
  }
  final m = landmarkNodes.length;
  /// 获取资源点索引对应的地标索引
  int getResourceLandmark(int resourceIndex) => landmarkToIndex[resources[resourceIndex]]!;
  /// 获取地标索引对应的节点索引
  int getLandmarkNode(int landmarkIndex) => nodeToIndex[landmarkNodes[landmarkIndex]]!;
  /// 获取地标索引对应的资源点索引
  int? getLandmarkResource(int landmarkIndex) => resourceToIndex[landmarkNodes[landmarkIndex]];
  // 起点
  final startLandmark1 = landmarkToIndex[arguments.start1]!;
  final startLandmark2 = landmarkToIndex[arguments.start2]!;
  // 出口
  final exitLandmarks = <int>[];
  for (final e in arguments.exits) {
    final li = landmarkToIndex[e];
    if (li != null) exitLandmarks.add(li);
  }
  // 关键资源点相关
  int? keyPositionLandmark;
  int? keyTransportLandmark;
  if (keyResource != null) {
    keyPositionLandmark = landmarkToIndex[keyResource.position]!;
    keyTransportLandmark = landmarkToIndex[keyResource.transport]!;
  }

  // 3. 对每个地标做一次正向 BFS，得到它到所有节点的最短距离与父指针

  // 构建有向邻接表
  final adj = List.generate(n, (_) => <int>[]);
  for (int i = 0; i < n; i++) {
    final u = nodes[i];
    final cell = world.cell(u.layer, u.x, u.y)!;
    // 楼梯
    switch (cell.info.isStair) {
      case null:
      case StairTransport.nothing:
        break;
      case StairTransport.goUp:
        final upLayer = u.layer.up()!;
        final v = Node(upLayer, u.x, u.y);
        final vi = nodeToIndex[v];
        if (vi != null) adj[i].add(vi);
        break;
      case StairTransport.goDown:
        final downLayer = u.layer.down()!;
        final v = Node(downLayer, u.x, u.y);
        final vi = nodeToIndex[v];
        if (vi != null) adj[i].add(vi);
        break;
    }
    // 平面移动
    for (final direction in Direction.values) {
      final (dx, dy) = direction.dxy;
      final nx = u.x + dx;
      final ny = u.y + dy;
      final neighbor = world.cell(u.layer, nx, ny);
      if (neighbor == null) continue;
      switch (cell.info.getEdgeType(direction)) {
        case EdgeType.nothing:
          if (neighbor.structureId == cell.structureId) {
            final v = Node(u.layer, nx, ny);
            final vi = nodeToIndex[v];
            if (vi != null) adj[i].add(vi);
          }
          break;
        case EdgeType.door:
          final v = Node(u.layer, nx, ny);
          final vi = nodeToIndex[v];
          if (vi != null) adj[i].add(vi);
          break;
        case EdgeType.innerWall:
          break;
        case EdgeType.hole:
          final downLayer = u.layer.down()!;
          final v = Node(downLayer, nx, ny);
          final vi = nodeToIndex[v];
          if (vi != null) adj[i].add(vi);
          break;
      }
    }
  }
  // TODO: 各出入口间的移动
  /// 正向 BFS，从 [sourceNodeIndex] 出发，返回到任意节点的最短距离与父指针
  /// 时间复杂度 O(n)
  _BfsResult bfs(int sourceNodeIndex) {
    final dist = List<int?>.filled(n, null);
    final parent = List<int?>.filled(n, null);
    dist[sourceNodeIndex] = 0;
    final q = Queue<int>()..add(sourceNodeIndex);
    while (q.isNotEmpty) {
      final u = q.removeFirst();
      final d = dist[u]!;
      for (final v in adj[u]) {
        if (dist[v] == null) {
          dist[v] = d + 1;
          parent[v] = u;
          q.add(v);
        }
      }
    }
    return _BfsResult(dist: dist, parent: parent);
  }
  // 地标到任意节点的最短步数
  final bfsFromLandmark = List<_BfsResult>.generate(
    m,
    (landmarkIndex) => bfs(getLandmarkNode(landmarkIndex)),
  );
  /// 地标 i 地标 j 的最短距离（有向）
  final landmarkDist = List<List<int?>>.generate(
    m,
      (i) => List<int?>.generate(
       m,
        (j) => bfsFromLandmark[i].dist[getLandmarkNode(j)],
    ),
  );
  int? distLandmarkToLandmark(int i, int j) => landmarkDist[i][j];
  /// 地标到最近出口的最短距离
  int? distLandmarkToExit(int landmark) {
    if (exitLandmarks.isEmpty) return 0;
    int? best;
    for (final e in exitLandmarks) {
      final d = landmarkDist[landmark][e];
      if (d != null && (best == null || d < best)) best = d;
    }
    return best;
  }

  // 4. 双人 A* 搜索

  double stepWeight(_DoubleAStarState s, int movingAgent) {
    double w = defaultWeight;
    if (keyResource != null && s.transportPhase != 2) {
      w += keyResourceWeight;
      if (s.transportPhase == 1 && s.waitingAgent != movingAgent) {
        w += arguments.transportWaitingUrgency;
      }
    }
    return w;
  }
  bool isComplete(_DoubleAStarState s) {
    if (s.collectedResources.length != k) return false;
    if (arguments.exits.isEmpty) return true;
    return exitLandmarks.contains(s.landmark1) && exitLandmarks.contains(s.landmark2);
  }
  ({double h1, double h2}) heuristicDouble(int pos1, int pos2, Set<int> collected) {
    // 所有资源点已收集，仅需走到出口
    if (collected.length == k) {
      if (arguments.exits.isEmpty) return (h1: 0.0, h2: 0.0);
      final d1 = distLandmarkToExit(pos1);
      final d2 = distLandmarkToExit(pos2);
      if (d1 == null || d2 == null) {
        return (h1: double.infinity, h2: double.infinity);
      }
      return (h1: d1.toDouble(), h2: d2.toDouble());
    }
    // TODO: 优化下界
    return (h1: 0.0, h2: 0.0);
  }

  var startPos1 = startLandmark1;
  var startPos2 = startLandmark2;
  final startCollected = <int>{
    ?getLandmarkResource(startPos1),
    ?getLandmarkResource(startPos2),
  };
  // 处理起点就在关键资源点的情况
  int startPhase = 0;
  int startWaiting = 0;
  if (keyResource == null) {
    startPhase = 2;
  } else {
    final p1AtKey = startPos1 == keyPositionLandmark;
    final p2AtKey = startPos2 == keyPositionLandmark;
    if (p1AtKey && p2AtKey) {
      // 两人都在关键资源点：直接视为已可传送，但保留 phase=1，由传送动作统一处理
      startPhase = 1;
      startWaiting = 1; // 任意指定一人为等待者
    } else if (p1AtKey) {
      startPhase = 1;
      startWaiting = 1;
    } else if (p2AtKey) {
      startPhase = 1;
      startWaiting = 2;
    }
  }
  final startState = _DoubleAStarState(
    landmark1: startPos1,
    landmark2: startPos2,
    collectedResources: startCollected,
    transportPhase: startPhase,
    waitingAgent: startWaiting,
  );
  final cost = <_DoubleAStarState, _DoubleCost>{};
  final prev = <_DoubleAStarState, _DoubleAStarState>{};
  final pq = HeapPriorityQueue<(double, double, double, double, _DoubleAStarState)>(
    compareSequentially([
      compare<(double, double, double, double, _DoubleAStarState)>((item) => item.$1),
      compare<(double, double, double, double, _DoubleAStarState)>((item) => item.$2),
      compare<(double, double, double, double, _DoubleAStarState)>((item) => item.$3),
      compare<(double, double, double, double, _DoubleAStarState)>((item) => item.$4),
    ]),
  ); // 优先队列，元素为 (f, max(g1, g2), g1, g2, state)
  cost[startState] = const _DoubleCost(0.0, 0.0);
  pq.add((0.0, 0.0, 0.0, 0.0, startState));
  double bestScore = double.infinity;
  _DoubleAStarState? bestFinalState;
  while (pq.isNotEmpty) {
    final (f, maxCost, cost1, cost2, state) = pq.removeFirst();
    final cur = cost[state];
    if (cur == null || cur.cost1 != cost1 || cur.cost2 != cost2) continue; // 如果该状态已经有更优代价，跳过
    final score = max(cur.cost1, cur.cost2);
    if (isComplete(state)) {
      if (score < bestScore) {
        bestScore = score;
        bestFinalState = state;
      }
      continue;
    }
    if (f >= bestScore) break; // 当前下界已不优于当前上界，结束

    void tryMove(int movingAgent, int nextLandmark) {
      final pos1 = state.landmark1;
      final pos2 = state.landmark2;
      if (movingAgent == 1) {
        if (state.transportPhase == 1 && state.waitingAgent == 1) return;
        if (nextLandmark == pos1) return;
        final d = distLandmarkToLandmark(pos1, nextLandmark);
        if (d == null) return;
        final weight = stepWeight(state, 1);
        final addWeighted = d * weight;
        final newPos1 = nextLandmark;
        final newPos2 = pos2;
        var newPhase = state.transportPhase;
        var newWaiting = state.waitingAgent;
        final newResources = <int>{
          ...state.collectedResources,
          ?getLandmarkResource(nextLandmark),
        };
        if (keyResource != null && newPhase == 0 && nextLandmark == keyPositionLandmark) {
          newPhase = 1;
          newWaiting = 1;
        }
        final newCost1 = cur.cost1 + addWeighted;
        final newCost2 = cur.cost2;
        final newState = _DoubleAStarState(
          landmark1: newPos1,
          landmark2: newPos2,
          collectedResources: newResources,
          transportPhase: newPhase,
          waitingAgent: newWaiting,
        );
        final old = cost[newState];
        if (old != null && old.cost1 <= newCost1 && old.cost2 <= newCost2) {
          return;
        }
        final h = heuristicDouble(newPos1, newPos2, newResources);
        final f1 = newCost1 + h.h1;
        final f2 = newCost2 + h.h2;
        final newF = f1 > f2 ? f1 : f2;
        if (newF >= bestScore) return;
        cost[newState] = _DoubleCost(newCost1, newCost2);
        prev[newState] = state;
        pq.add((
          newF,
          newCost1 > newCost2 ? newCost1 : newCost2,
          newCost1,
          newCost2,
          newState,
        ));
      } else {
        if (state.transportPhase == 1 && state.waitingAgent == 2) return;
        if (nextLandmark == pos2) return;
        final d = distLandmarkToLandmark(pos2, nextLandmark);
        if (d == null) return;
        final weight = stepWeight(state, 2);
        final addWeighted = d * weight;
        final newPos1 = pos1;
        final newPos2 = nextLandmark;
        var newPhase = state.transportPhase;
        var newWaiting = state.waitingAgent;
        final newResources = <int>{
          ...state.collectedResources,
          ?getLandmarkResource(nextLandmark),
        };
        if (keyResource != null && newPhase == 0 && nextLandmark == keyPositionLandmark) {
          newPhase = 1;
          newWaiting = 2;
        }
        final newCost1 = cur.cost1;
        final newCost2 = cur.cost2 + addWeighted;
        final newState = _DoubleAStarState(
          landmark1: newPos1,
          landmark2: newPos2,
          collectedResources: newResources,
          transportPhase: newPhase,
          waitingAgent: newWaiting,
        );
        final old = cost[newState];
        if (old != null && old.cost1 <= newCost1 && old.cost2 <= newCost2) {
          return;
        }
        final h = heuristicDouble(newPos1, newPos2, newResources);
        final f1 = newCost1 + h.h1;
        final f2 = newCost2 + h.h2;
        final newF = f1 > f2 ? f1 : f2;
        if (newF >= bestScore) return;
        cost[newState] = _DoubleCost(newCost1, newCost2);
        prev[newState] = state;
        pq.add((
          newF,
          newCost1 > newCost2 ? newCost1 : newCost2,
          newCost1,
          newCost2,
          newState,
        ));
      }
    }
    void tryTransport() {
      if (keyResource == null) return;
      if (state.transportPhase != 1) return;
      final newPos1 = keyTransportLandmark!;
      final newPos2 = keyTransportLandmark;
      final newResources = <int>{
        ...state.collectedResources,
        ?getLandmarkResource(keyTransportLandmark),
        ?getLandmarkResource(keyPositionLandmark!),
      };
      final newState = _DoubleAStarState(
        landmark1: newPos1,
        landmark2: newPos2,
        collectedResources: newResources,
        transportPhase: 2,
        waitingAgent: 0,
      );
      final old = cost[newState];
      if (old != null && old.cost1 <= cur.cost1 && old.cost2 <= cur.cost2) {
        return;
      }
      final h = heuristicDouble(newPos1, newPos2, newResources);
      final f1 = cur.cost1 + h.h1;
      final f2 = cur.cost2 + h.h2;
      final newF = f1 > f2 ? f1 : f2;
      if (newF >= bestScore) return;
      cost[newState] = _DoubleCost(cur.cost1, cur.cost2);
      prev[newState] = state;
      pq.add((
        newF,
        cur.cost1 > cur.cost2 ? cur.cost1 : cur.cost2,
        cur.cost1,
        cur.cost2,
        newState,
      ));
    }

    tryTransport();
    for (int next = 0; next < m; next++) {
      tryMove(1, next);
      tryMove(2, next);
    }
  }
  if (bestFinalState == null) {
    return (path1: [], path2: []);
  }

  // 5. 回溯路径

  // 回溯状态序列
  final states = <_DoubleAStarState>[];
  var curState = bestFinalState;
  while (true) {
    states.add(curState);
    if (curState == startState) break;
    curState = prev[curState]!;
  }
  final forwardStates = states.reversed.toList();
  final path1Indexes = <int>[];
  final path2Indexes = <int>[];
  void appendSegment(List<int> path, int fromLandmark, int toLandmark) {
    if (fromLandmark == toLandmark) return;
    final parents = bfsFromLandmark[fromLandmark].parent;
    final fromNode = getLandmarkNode(fromLandmark);
    final toNode = getLandmarkNode(toLandmark);
    final segment = <int>[];
    var cur = toNode;
    while (cur != fromNode) {
      segment.add(cur);
      final p = parents[cur];
      if (p == null) return;
      cur = p;
    }
    path.addAll(segment.reversed);
  }
  for (int i = 0; i < forwardStates.length; i++) {
    final state = forwardStates[i];
    if (i == 0) {
      path1Indexes.add(getLandmarkNode(state.landmark1));
      path2Indexes.add(getLandmarkNode(state.landmark2));
      continue;
    }
    final prevState = forwardStates[i - 1];
    // 检测传送动作：phase 从 1 变为 2
    final isTransport = prevState.transportPhase == 1 && state.transportPhase == 2;
    if (isTransport) {
      // 传送：两人都到 keyTransport
      // 等待者原本就在 keyPosition，移动者可能在任意位置
      final waitingAgent = prevState.waitingAgent;
      // 等待者：从 keyPosition 到 keyTransport（如果不同）
      if (keyPositionLandmark != keyTransportLandmark) {
        if (waitingAgent == 1) {
          path1Indexes.add(getLandmarkNode(keyTransportLandmark!));
        } else {
          path2Indexes.add(getLandmarkNode(keyTransportLandmark!));
        }
      }
      // 移动者：从原位置直接传送到 keyTransport
      final mover = waitingAgent == 1 ? 2 : 1;
      if (mover == 1) {
        if (prevState.landmark1 != keyTransportLandmark) {
          path1Indexes.add(getLandmarkNode(keyTransportLandmark!));
        }
      } else {
        if (prevState.landmark2 != keyTransportLandmark) {
          path2Indexes.add(getLandmarkNode(keyTransportLandmark!));
        }
      }
      continue;
    }
    // 普通移动
    if (state.landmark1 != prevState.landmark1) {
      appendSegment(
        path1Indexes,
        prevState.landmark1,
        state.landmark1,
      );
    }
    if (state.landmark2 != prevState.landmark2) {
      appendSegment(
        path2Indexes,
        prevState.landmark2,
        state.landmark2,
      );
    }
  }
  // 返回路径
  return (
    path1: path1Indexes.map((i) => nodes[i]).toList(),
    path2: path2Indexes.map((i) => nodes[i]).toList(),
  );
}

@SquadronService(baseUrl: '~/workers')
base class NavigateDoubleSquadron {
  @SquadronMethod()
  Future<(Uint8List, Uint8List)> doCompute(
    Uint8List structuresFile,
    Uint8List worldFile,
    Uint8List arguments,
  ) async {
    final structures = deserializeStructures(structuresFile);
    final world = deserializeWorld(worldFile);
    final worldInstance = constructWorld(structures, world);
    final navigateArguments = deserializeNavigateDoubleArguments(arguments);
    final result = navigateDouble(worldInstance, navigateArguments);
    return (serializeNavigatePath(result.path1), serializeNavigatePath(result.path2));
  }
}

Future<({List<Node> path1, List<Node> path2})> navigateDoubleAsync(
  Uint8List structuresFile,
  Uint8List worldFile,
  NavigateDoubleArguments navigateArguments,
) async {
  final worker = NavigateDoubleSquadronWorker();
  try {
    final arguments = serializeNavigateDoubleArguments(navigateArguments);
    final (result1, result2) = await worker.doCompute(structuresFile, worldFile, arguments);
    return (path1: deserializeNavigatePath(result1), path2: deserializeNavigatePath(result2));
  } finally {
    worker.stop();
  }
}
