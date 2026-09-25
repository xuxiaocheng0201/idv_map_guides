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

class _CostNode {
  final double cost1;
  final double cost2;
  final _DoubleAStarState? prevState;
  final _CostNode? prevNode;
  _CostNode(this.cost1, this.cost2, {this.prevState, this.prevNode});
}

({List<Node> path1, List<Node> path2}) navigateDouble(World world, NavigateDoubleArguments arguments) {
  var keyResource = arguments.keyResource;
  if (keyResource != null && !arguments.resources.contains(keyResource.position)) {
    keyResource = null;
  }

  // 1. 构建所有可通行节点的列表和索引映射
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
  const double defaultWeight = 1.0;
  double keyResourceWeight = 0.0;
  if (keyResource != null) {
    keyResourceWeight = keyResource.urgency;
  }

  // 2. 构建地标集合：两个起点 + 所有资源点 + 关键资源点位置 + 关键资源点传送目标
  //    *** 出口不再加入地标 ***
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
  if (keyResource != null) {
    addLandmark(keyResource.position);
    addLandmark(keyResource.transport);
  }
  final m = landmarkNodes.length;

  int getResourceLandmark(int resourceIndex) =>
      landmarkToIndex[resources[resourceIndex]]!;
  int getLandmarkNode(int landmarkIndex) =>
      nodeToIndex[landmarkNodes[landmarkIndex]]!;
  int? getLandmarkResource(int landmarkIndex) =>
      resourceToIndex[landmarkNodes[landmarkIndex]];

  final startLandmark1 = landmarkToIndex[arguments.start1]!;
  final startLandmark2 = landmarkToIndex[arguments.start2]!;

  // 出口节点索引（不是地标）
  final exitNodeIndexes = <int>[];
  for (final e in arguments.exits) {
    final ni = nodeToIndex[e];
    if (ni != null) exitNodeIndexes.add(ni);
  }

  // 关键资源点相关
  int? keyPositionLandmark;
  int? keyTransportLandmark;
  if (keyResource != null) {
    keyPositionLandmark = landmarkToIndex[keyResource.position]!;
    keyTransportLandmark = landmarkToIndex[keyResource.transport]!;
  }

  // 3. 邻接表与 BFS 预计算
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

  // 4. 双人 A* 搜索 —— 收集阶段

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

  /// 收集阶段完成条件：资源全收齐，且关键资源已处理（或有关键资源时已传送）
  bool isCollectionComplete(_DoubleAStarState s) {
    if (s.collectedResources.length != k) return false;
    if (keyResource != null && s.transportPhase != 2) return false;
    return true;
  }

  /// 收集阶段的可采纳启发式：每个未收集资源 + 关键资源至少需要一人去访问
  ({double h1, double h2}) heuristicCollection(
      int pos1,
      int pos2,
      Set<int> collected,
      int transportPhase,
      ) {
    double common = 0.0;

    for (int r = 0; r < k; r++) {
      if (collected.contains(r)) continue;
      final rl = getResourceLandmark(r);
      final d1 = distLandmarkToLandmark(pos1, rl);
      final d2 = distLandmarkToLandmark(pos2, rl);
      final dd = min(d1 ?? (1 << 30), d2 ?? (1 << 30));
      if (dd > common) common = dd.toDouble();
    }

    if (keyResource != null && transportPhase != 2) {
      final d1 = distLandmarkToLandmark(pos1, keyPositionLandmark!);
      final d2 = distLandmarkToLandmark(pos2, keyPositionLandmark!);
      final dd = min(d1 ?? (1 << 30), d2 ?? (1 << 30));
      if (dd > common) common = dd.toDouble();
    }

    return (h1: common * defaultWeight, h2: common * defaultWeight);
  }

  /// 收集完成后，枚举出口组合，返回最优完成时间
  ({double score, int? exit1, int? exit2}) exitsCost(
      int pos1,
      int pos2,
      double cost1,
      double cost2,
      ) {
    if (exitNodeIndexes.isEmpty) {
      return (score: max(cost1, cost2), exit1: null, exit2: null);
    }

    double bestScore = double.infinity;
    int? bestExit1;
    int? bestExit2;

    for (final e1 in exitNodeIndexes) {
      final d1 = bfsFromLandmark[pos1].dist[e1];
      if (d1 == null) continue;
      final c1 = cost1 + d1 * defaultWeight;
      if (c1 >= bestScore) continue;

      for (final e2 in exitNodeIndexes) {
        final d2 = bfsFromLandmark[pos2].dist[e2];
        if (d2 == null) continue;
        final c2 = cost2 + d2 * defaultWeight;
        final score = max(c1, c2);
        if (score < bestScore) {
          bestScore = score;
          bestExit1 = e1;
          bestExit2 = e2;
        }
      }
    }

    return (score: bestScore, exit1: bestExit1, exit2: bestExit2);
  }

  final startPos1 = startLandmark1;
  final startPos2 = startLandmark2;

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
      startPhase = 1;
      startWaiting = 1;
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

  final pareto = <_DoubleAStarState, List<_CostNode>>{};
  final startNode = _CostNode(0.0, 0.0);
  pareto[startState] = [startNode];

  final pq = HeapPriorityQueue<(double, double, _CostNode, _DoubleAStarState)>(
    compareSequentially([
      compare<(double, double, _CostNode, _DoubleAStarState)>((item) => item.$1),
      compare<(double, double, _CostNode, _DoubleAStarState)>((item) => item.$2),
    ]),
  );

  double bestScore = double.infinity;
  _CostNode? bestNode;
  _DoubleAStarState? bestFinalState;
  int? bestFinalExit1;
  int? bestFinalExit2;

  const double eps = 1e-9;

  final startH = heuristicCollection(
    startPos1,
    startPos2,
    startCollected,
    startPhase,
  );
  final startF = max(0.0 + startH.h1, 0.0 + startH.h2);
  if (startF < bestScore) {
    pq.add((startF, 0.0, startNode, startState));
  }

  void addNode(
      _DoubleAStarState newState,
      double newCost1,
      double newCost2,
      _DoubleAStarState prevState,
      _CostNode prevNode,
      ) {
    final list = pareto.putIfAbsent(newState, () => []);

    // 检查是否被支配（加入 eps 容差，避免 double 噪声导致 Pareto 膨胀）
    for (final old in list) {
      if (old.cost1 <= newCost1 + eps && old.cost2 <= newCost2 + eps) {
        return;
      }
    }

    // 移除被新节点支配的旧节点
    list.removeWhere(
          (old) => newCost1 <= old.cost1 + eps && newCost2 <= old.cost2 + eps,
    );

    final newNode = _CostNode(
      newCost1,
      newCost2,
      prevState: prevState,
      prevNode: prevNode,
    );
    list.add(newNode);

    final h = heuristicCollection(
      newState.landmark1,
      newState.landmark2,
      newState.collectedResources,
      newState.transportPhase,
    );
    final f1 = newCost1 + h.h1;
    final f2 = newCost2 + h.h2;
    final newF = max(f1, f2);

    if (newF < bestScore) {
      pq.add((newF, max(newCost1, newCost2), newNode, newState));
    }
  }

  /// 收集阶段只允许移动到：未收集资源、关键资源点位置
  List<int> candidateTargets(_DoubleAStarState state) {
    final targets = <int>{};

    for (int r = 0; r < k; r++) {
      if (!state.collectedResources.contains(r)) {
        targets.add(getResourceLandmark(r));
      }
    }

    if (keyResource != null && state.transportPhase == 0) {
      targets.add(keyPositionLandmark!);
    }

    return targets.toList();
  }

  while (pq.isNotEmpty) {
    final (f, maxCost, node, state) = pq.removeFirst();

    // 用 continue 而不是 break，因为启发式可能不一致
    if (f >= bestScore - eps) continue;

    final list = pareto[state];
    if (list == null || !list.contains(node)) continue;

    if (isCollectionComplete(state)) {
      final result = exitsCost(
        state.landmark1,
        state.landmark2,
        node.cost1,
        node.cost2,
      );
      if (result.score < bestScore) {
        bestScore = result.score;
        bestNode = node;
        bestFinalState = state;
        bestFinalExit1 = result.exit1;
        bestFinalExit2 = result.exit2;
      }
      continue;
    }

    final curCost1 = node.cost1;
    final curCost2 = node.cost2;

    // 动作 1：传送
    if (keyResource != null && state.transportPhase == 1) {
      final newResources = <int>{
        ...state.collectedResources,
        ?getLandmarkResource(keyTransportLandmark!),
        ?getLandmarkResource(keyPositionLandmark!),
      };
      final newState = _DoubleAStarState(
        landmark1: keyTransportLandmark!,
        landmark2: keyTransportLandmark,
        collectedResources: newResources,
        transportPhase: 2,
        waitingAgent: 0,
      );
      addNode(newState, curCost1, curCost2, state, node);
    }

    final targets = candidateTargets(state);

    // 动作 2：移动 agent1
    if (!(state.transportPhase == 1 && state.waitingAgent == 1)) {
      for (final next in targets) {
        if (next == state.landmark1) continue;
        final d = distLandmarkToLandmark(state.landmark1, next);
        if (d == null) continue;
        final weight = stepWeight(state, 1);
        final newCost1 = curCost1 + d * weight;
        final newCost2 = curCost2;

        var newPhase = state.transportPhase;
        var newWaiting = state.waitingAgent;

        final newResources = <int>{
          ...state.collectedResources,
          ?getLandmarkResource(next),
        };

        if (keyResource != null &&
            newPhase == 0 &&
            next == keyPositionLandmark) {
          newPhase = 1;
          newWaiting = 1;
        }

        final newState = _DoubleAStarState(
          landmark1: next,
          landmark2: state.landmark2,
          collectedResources: newResources,
          transportPhase: newPhase,
          waitingAgent: newWaiting,
        );
        addNode(newState, newCost1, newCost2, state, node);
      }
    }

    // 动作 3：移动 agent2
    if (!(state.transportPhase == 1 && state.waitingAgent == 2)) {
      for (final next in targets) {
        if (next == state.landmark2) continue;
        final d = distLandmarkToLandmark(state.landmark2, next);
        if (d == null) continue;
        final weight = stepWeight(state, 2);
        final newCost1 = curCost1;
        final newCost2 = curCost2 + d * weight;

        var newPhase = state.transportPhase;
        var newWaiting = state.waitingAgent;

        final newResources = <int>{
          ...state.collectedResources,
          ?getLandmarkResource(next),
        };

        if (keyResource != null &&
            newPhase == 0 &&
            next == keyPositionLandmark) {
          newPhase = 1;
          newWaiting = 2;
        }

        final newState = _DoubleAStarState(
          landmark1: state.landmark1,
          landmark2: next,
          collectedResources: newResources,
          transportPhase: newPhase,
          waitingAgent: newWaiting,
        );
        addNode(newState, newCost1, newCost2, state, node);
      }
    }
  }

  if (bestNode == null || bestFinalState == null) {
    return (path1: [], path2: []);
  }

  // 5. 回溯路径
  final nodeSequence = <_CostNode>[];
  final stateSequence = <_DoubleAStarState>[];
  var curNode = bestNode;
  var curState = bestFinalState;
  while (true) {
    nodeSequence.add(curNode);
    stateSequence.add(curState);
    if (curNode == startNode) break;
    final prevState = curNode.prevState!;
    final prevNode = curNode.prevNode!;
    curNode = prevNode;
    curState = prevState;
  }
  final forwardStates = stateSequence.reversed.toList();

  final path1Indexes = <int>[];
  final path2Indexes = <int>[];

  /// 从地标 [fromLandmark] 到任意节点 [toNodeIndex] 追加路径段
  void appendSegmentToNode(List<int> path, int fromLandmark, int toNodeIndex) {
    final fromNode = getLandmarkNode(fromLandmark);
    if (fromNode == toNodeIndex) return;

    final parents = bfsFromLandmark[fromLandmark].parent;
    final segment = <int>[];
    var cur = toNodeIndex;
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
    final isTransport =
        prevState.transportPhase == 1 && state.transportPhase == 2;

    if (isTransport) {
      final waitingAgent = prevState.waitingAgent;
      if (keyPositionLandmark != keyTransportLandmark) {
        if (waitingAgent == 1) {
          path1Indexes.add(getLandmarkNode(keyTransportLandmark!));
        } else {
          path2Indexes.add(getLandmarkNode(keyTransportLandmark!));
        }
      }
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

    if (state.landmark1 != prevState.landmark1) {
      appendSegmentToNode(
        path1Indexes,
        prevState.landmark1,
        getLandmarkNode(state.landmark1),
      );
    }
    if (state.landmark2 != prevState.landmark2) {
      appendSegmentToNode(
        path2Indexes,
        prevState.landmark2,
        getLandmarkNode(state.landmark2),
      );
    }
  }

  // 补上到出口的路径（使用阶段 B 枚举得到的最优出口）
  final lastState = forwardStates.last;
  if (bestFinalExit1 != null) {
    appendSegmentToNode(path1Indexes, lastState.landmark1, bestFinalExit1!);
  }
  if (bestFinalExit2 != null) {
    appendSegmentToNode(path2Indexes, lastState.landmark2, bestFinalExit2!);
  }

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
