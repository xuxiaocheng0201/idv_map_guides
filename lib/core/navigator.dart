import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:comparators/comparators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:squadron/squadron.dart';

import 'navigator.activator.g.dart';
part 'navigator.freezed.dart';
part 'navigator.worker.g.dart';

/// 关键资源
///
/// 表示一个需要优先收集的资源：它位于 [position]，可以传送到 [transport]
/// 并且在未传送前每走一步都会增加 [urgency] 的额外代价
@freezed
abstract class KeyResource with _$KeyResource {
  KeyResource._();
  factory KeyResource(Node position, Node transport, double urgency) = _KeyResource;
}

extension NodeIdentify on Node {
  String get identify => '${layer.index}.$x.$y';
}

@freezed
abstract class NavigateArguments with _$NavigateArguments {
  NavigateArguments._();
  factory NavigateArguments({
    required Node start,
    required Set<Node> resources,
    @Default(<Node>{}) Set<Node> exits,
    KeyResource? keyResource,
  }) = _NavigateArguments;

  String get identify => '${start.identify}'
      '/${resources.sorted(Comparable.compare).map((node) => node.identify).join(',')}'
      '/${exits.sorted(Comparable.compare).map((node) => node.identify).join(",")}${keyResource == null ? '' : ''
      '/${keyResource!.position.identify},${keyResource!.transport.identify},${keyResource!.urgency}'}';
}

@freezed
abstract class _AStarState with _$AStarState {
  _AStarState._();
  factory _AStarState({
    /// 已收集的资源索引
    required Set<int> collectedResourceIndexes,
    /// 当前所在节点在节点列表中的索引
    required int currentNodeIndex,
    /// 是否已经从关键资源点传送过
    required bool hasTransported,
  }) = __AStarState;
}

List<Node> navigate(World world, NavigateArguments arguments) {
  assert(arguments.keyResource == null || arguments.resources.contains(arguments.keyResource!.position));

  // 1. 构建所有可通行节点的列表和索引映射

  // 构建节点列表与映射
  final nodes = <Node>[];
  final nodeToIndex = <Node, int>{};
  for (final layer in world.map.keys) {
    for (var x = world.minX; x <= world.maxX; x++) {
      for (var y = world.minY; y <= world.maxY; y++) {
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
  if (n == 0) return [];
  // 起点映射
  final startIndex = nodeToIndex[arguments.start];
  if (startIndex == null) return [];
  // 资源点列表与映射
  final resources = arguments.resources.toList();
  final resourceToIndex = <Node, int>{};
  for (var i = 0; i < resources.length; i++) {
    resourceToIndex[resources[i]] = i;
  }
  final k = resources.length;
  /// 获取节点索引对应的资源点索引
  Set<int> getNodeResource(int nodeIndex) {
    final node = nodes[nodeIndex];
    final resourceIndex = resourceToIndex[node];
    return resourceIndex == null ? <int>{} : <int>{resourceIndex};
  } // 可使用 `.firstOrNull` 转为 int?
  /// 获取资源点索引对应的节点索引
  int getResourceNode(int resourceIndex) {
    final node = resources[resourceIndex];
    return nodeToIndex[node]!;
  }
  // 出口索引集合
  final exitIndexes = <int>{};
  for (final node in arguments.exits) {
    final idx = nodeToIndex[node];
    if (idx != null) exitIndexes.add(idx);
  }
  // 关键资源相关
  int? keyResourceIndex;
  int? keyResourceTransportedNodeIndex;
  double defaultWeight = 1.0;
  double keyResourceWeight = 0.0;
  if (arguments.keyResource != null) {
    final keyResource = arguments.keyResource!;
    keyResourceIndex = resourceToIndex[keyResource.position]!;
    keyResourceTransportedNodeIndex = nodeToIndex[keyResource.transport]!;
    keyResourceWeight = keyResource.urgency;
  }

  // 2. 处理楼梯、门、洞、同一结构内等的移动

  // 构建有向邻接表
  final adj = List.generate(n, (_) => <int>[]);
  for (var i = 0; i < n; i++) {
    final u = nodes[i];
    final cell = world.cell(u.layer, u.x, u.y)!;
    // 楼梯
    switch (cell.info.isStair) {
      case null:
      case StairTransport.nothing:
        break;
      case StairTransport.goUp:
        final upLayer = u.layer.up()!;
        final targetCell = world.cell(upLayer, u.x, u.y)!;
        assert(targetCell.info.isStair == StairTransport.goDown);
        final v = Node(upLayer, u.x, u.y);
        final vi = nodeToIndex[v];
        if (vi != null) adj[i].add(vi);
        break;
      case StairTransport.goDown:
        final downLayer = u.layer.down()!;
        final targetCell = world.cell(downLayer, u.x, u.y)!;
        assert(targetCell.info.isStair == StairTransport.goUp);
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
  // 反向邻接表
  final reverseAdj = List.generate(n, (_) => <int>[]);
  for (var u = 0; u < n; u++) {
    for (final v in adj[u]) {
      reverseAdj[v].add(u);
    }
  }

  // 3. 预计算各节点到出口、各资源点之间的距离

  /// 反向多源BFS，cost[i] 表示从节点 i 到最近源点的最短步数。
  /// 时间复杂度 O(n)
  List<int?> bfs(Set<int> sources) {
    final dist = List<int?>.filled(n, null);
    if (sources.isEmpty) return dist;
    final q = Queue<int>();
    for (final s in sources) {
      dist[s] = 0;
      q.add(s);
    }
    while (q.isNotEmpty) {
      final v = q.removeFirst();
      final preStep = dist[v]!;
      for (final u in reverseAdj[v]) {
        if (dist[u] == null) {
          dist[u] = preStep + 1;
          q.add(u);
        }
      }
    }
    return dist;
  }
  // 任意节点到最近出口的最短步数
  final distToExit = exitIndexes.isEmpty ? List<int?>.filled(n, 0) : bfs(exitIndexes);
  // 任意节点到各个资源点的最短步数，distToResource[b][i] 表示从节点 i 到资源点 b 的最短距离
  final distToResource = List<List<int?>>.generate(k, (b) => bfs(<int>{getResourceNode(b)}));
  /// 获取资源点到出口的最短距离
  int? distResourceToExit(int resourceIndex) {
    final nodeIndex = getResourceNode(resourceIndex);
    return distToExit[nodeIndex];
  }
  /// 获取资源点 i 到资源点 j 的最短距离（可能不对称）
  int? distResourceToResource(int resourceIndexI, int resourceIndexJ) {
    if (resourceIndexI == resourceIndexJ) return 0;
    final nodeIndexI = getResourceNode(resourceIndexI);
    return distToResource[resourceIndexJ][nodeIndexI];
  }
  // 任意节点到关键资源点的最短步数
  final distToKey = keyResourceIndex == null ? null : bfs(<int>{getResourceNode(keyResourceIndex)});

  // 4. A* / 分支限界搜索

  /// 计算 剩余资源点 + 当前点 + 出口 的最小生成树
  /// 时间复杂度 O(k^2)
  int? mst(int current, Set<int> collectedResources) {
    // 尚未收集的资源点
    final remainingResources = <int>[];
    for (var b = 0; b < k; b++) {
      if (!collectedResources.contains(b)) {
        remainingResources.add(b);
      }
    }
    // 如果所有资源已收集，只需走到任意出口
    if (remainingResources.isEmpty) {
      return distToExit[current];
    }

    // 构造距离矩阵：节点 0 为当前点，1..remaining 为剩余资源点，最后为出口点
    final hasExit = exitIndexes.isNotEmpty;
    final m = 1 + remainingResources.length + (hasExit ? 1 : 0);
    final distMst = List<List<int?>>.generate(m, (_) => List<int?>.filled(m, null));
    int maxDist = 0;
    // 当前点 -> 资源点
    for (var i = 0; i < remainingResources.length; i++) {
      final r = remainingResources[i];
      final d = distToResource[r][current];
      distMst[0][i + 1] = d;
      distMst[i + 1][0] = d;
      maxDist = max(maxDist, d ?? 0);
    }
    // 资源点 -> 资源点
    for (var i = 0; i < remainingResources.length; i++) {
      for (var j = i + 1; j < remainingResources.length; j++) {
        final ri = remainingResources[i];
        final rj = remainingResources[j];
        final dij = distResourceToResource(ri, rj);
        final dji = distResourceToResource(rj, ri);
        final int? d;
        if (dij == null) {
          d = dji;
        } else if (dji == null) {
          d = dij;
        } else {
          d = dij < dji ? dij : dji; // 取较小值，保证对称
        }
        distMst[i + 1][j + 1] = d;
        distMst[j + 1][i + 1] = d;
        maxDist = max(maxDist, d ?? 0);
      }
    }
    if (hasExit) {
      final exitPos = m - 1;
      // 当前点 -> 出口
      final de = distToExit[current];
      distMst[0][exitPos] = de;
      distMst[exitPos][0] = de;
      maxDist = max(maxDist, de ?? 0);
      // 资源点 -> 出口
      for (var i = 0; i < remainingResources.length; i++) {
        final r = remainingResources[i];
        final d = distResourceToExit(r);
        distMst[i + 1][exitPos] = d;
        distMst[exitPos][i + 1] = d;
        maxDist = max(maxDist, d ?? 0);
      }
    }

    // Prim 算法求 MST
    int inf = maxDist + 1; // 最大边权 + 1
    final visited = List<bool>.filled(m, false);
    final minDist = List<int>.filled(m, inf);
    minDist[0] = 0;
    int total = 0;
    for (var it = 0; it < m; it++) {
      int best = inf;
      int? u;
      for (var v = 0; v < m; v++) {
        if (!visited[v] && minDist[v] < best) {
          best = minDist[v];
          u = v;
        }
      }
      if (best == inf || u == null) return null; // 图不连通
      visited[u] = true;
      total += best;
      for (var v = 0; v < m; v++) {
        if (!visited[v]) {
          final d = distMst[u][v];
          if (d != null && d < minDist[v]) {
            minDist[v] = d;
          }
        }
      }
    }
    return total;
  }
  /// 启发式函数：使用最小生成树来计算下界
  double heuristic(int current, Set<int> collectedResources, bool hasTransported) {
    final distMst = mst(current, collectedResources);
    // 没有关键资源点或已经传送过，直接使用普通 MST 作为下界
    if (keyResourceIndex == null || hasTransported) {
      return distMst == null ? double.infinity : defaultWeight * distMst.toDouble();
    }
    final weight = defaultWeight + keyResourceWeight; // 未传送时的每步代价
    // 不传送，即以未传送代价走完全程
    final noTransport = distMst == null ? double.infinity : weight * distMst.toDouble();
    // 传送，先走到关键资源点，再直接到出口 TODO：也许使用更好的启发式？比如中间加一个普通资源点什么的来提升下界
    final beforeTransport = distToKey![current];
    if (beforeTransport == null) return noTransport;
    final afterTransport = distToExit[keyResourceTransportedNodeIndex!];
    if (afterTransport == null) return noTransport;
    final doTransport = weight * beforeTransport.toDouble() + defaultWeight * afterTransport.toDouble();
    // 取 传送/不传送 最小作为下界
    return min(noTransport, doTransport);
  }
  // 基本结构
  final cost = <_AStarState, double>{}; // 每个状态的最小实际代价
  final prev = <_AStarState, _AStarState>{}; // 记录前驱状态，用于回溯路径
  final pq = HeapPriorityQueue<(double, double, _AStarState)>(compareSequentially([
    compare<(double, double, _AStarState)>((item) => item.$1),
    compare<(double, double, _AStarState)>((item) => item.$2),
  ])); // 优先队列，元素为 (f, g, state)，先按 f 排序，再按 g 排序
  // 起点设置
  final startResources = getNodeResource(startIndex);
  final startKey = _AStarState(collectedResourceIndexes: startResources, currentNodeIndex: startIndex, hasTransported: false);
  cost[startKey] = 0.0;
  final startH = heuristic(startIndex, startResources, false);
  pq.add((startH, 0.0, startKey));
  // 搜索
  double bestCost = double.infinity;
  _AStarState? bestFinalState;
  while (pq.isNotEmpty) {
    final (f, g, state) = pq.removeFirst();
    if (g > (cost[state] ?? double.infinity)) continue; // 如果该状态已经有更优代价，跳过
    if (f >= bestCost) break; // 如果 f 已经不小于当前最优完成代价，剪枝
    final hasTransported = state.hasTransported;
    final current = state.currentNodeIndex;
    final collectedResources = state.collectedResourceIndexes;
    // 完成条件：所有资源已收集，且到达出口
    if (collectedResources.length == k && (exitIndexes.isEmpty || exitIndexes.contains(current))) {
      bestCost = g;
      bestFinalState = state;
      break;
    }
    // 动作1：传送
    if (keyResourceIndex != null && !hasTransported && getNodeResource(current).contains(keyResourceIndex)) {
      final newResources = {...collectedResources, ...getNodeResource(keyResourceTransportedNodeIndex!)};
      final newState = _AStarState(collectedResourceIndexes: newResources, currentNodeIndex: keyResourceTransportedNodeIndex, hasTransported: true);
      final newG = g; // 传送本身不消耗步数
      if (newG < (cost[newState] ?? double.infinity)) {
        final newH = heuristic(keyResourceTransportedNodeIndex, newResources, true);
        if (newG + newH < bestCost) {
          cost[newState] = newG;
          prev[newState] = state;
          pq.add((newG + newH, newG, newState));
        }
      }
    }
    // 动作2：正常移动
    final weight = (keyResourceIndex != null && !hasTransported) ? defaultWeight + keyResourceWeight : defaultWeight;
    for (final v in adj[current]) {
      final newResources = {...collectedResources, ...getNodeResource(v)};
      final newState = _AStarState(collectedResourceIndexes: newResources, currentNodeIndex: v, hasTransported: hasTransported);
      final newG = g + weight;
      if (newG < (cost[newState] ?? double.infinity)) {
        final newH = heuristic(v, newResources, hasTransported);
        if (newG + newH < bestCost) {
          cost[newState] = newG;
          prev[newState] = state;
          pq.add((newG + newH, newG, newState));
        }
      }
    }
  }
  if (bestFinalState == null) return []; // 未找到可行路径
  // 回溯路径
  final pathIndexes = <int>[];
  var currentState = bestFinalState;
  while (true) {
    pathIndexes.add(currentState.currentNodeIndex);
    if (currentState == startKey) break;
    currentState = prev[currentState]!;
  }
  // 反转并映射为 Node 列表返回
  return pathIndexes.reversed.map((i) => nodes[i]).toList();
}

@SquadronService(baseUrl: '~/workers')
base class NavigateSquadron {
  @SquadronMethod()
  Future<Uint8List> doCompute(Uint8List structuresFile, Uint8List worldFile, Uint8List arguments) async {
    final structures = deserializeStructures(structuresFile);
    final world = deserializeWorld(worldFile);
    final worldInstance = constructWorld(structures, world);
    final navigateArguments = deserializeNavigateArguments(arguments);
    final path = navigate(worldInstance, navigateArguments);
    return serializeNavigatePath(path);
  }
}

Future<List<Node>> navigateAsync(Uint8List structuresFile, Uint8List worldFile, NavigateArguments navigateArguments) async {
  final worker = NavigateSquadronWorker();
  try {
    final arguments = serializeNavigateArguments(navigateArguments);
    final path = await worker.doCompute(structuresFile, worldFile, arguments);
    return deserializeNavigatePath(path);
  } finally {
    worker.stop();
  }
}
