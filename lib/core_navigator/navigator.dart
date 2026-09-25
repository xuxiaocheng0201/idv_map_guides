import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:comparators/comparators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_navigator/serde.dart';
import 'package:squadron/squadron.dart';

import 'navigator.activator.g.dart';

part 'navigator.freezed.dart';
part 'navigator.worker.g.dart';

@freezed
abstract class KeyResource with _$KeyResource {
  KeyResource._();
  factory KeyResource({
    required Node position,
    required Node transport,
    @Default(1) int keyResourceWeight,
  }) = _KeyResource;
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
    required Set<Node> exits,
    KeyResource? keyResource,
    @Default(<(Node, Node), int>{}) Map<(Node, Node), int> entrancesLength,
    @Default(1) int defaultWeight,
  }) = _NavigateArguments;

  String get identify =>
      '${start.identify}'
      '/${resources.sorted(Comparable.compare).map((node) => node.identify).join(',')}'
      '/${exits.sorted(Comparable.compare).map((node) => node.identify).join(",")}'
      '/${keyResource == null ? 'null' : '${keyResource!.position.identify},${keyResource!.transport.identify},${keyResource!.keyResourceWeight}'}'
      '/${entrancesLength.entries.sorted(compareSequentially([
        compare<MapEntry<(Node, Node), int>>((e) => e.key.$1),
        compare<MapEntry<(Node, Node), int>>((e) => e.key.$2),
      ])).map((e) => '${e.key.$1.identify},${e.key.$2.identify},${e.value}').join('|')}'
      '/$defaultWeight';
}

@freezed
abstract class _AStarState with _$AStarState {
  _AStarState._();
  factory _AStarState({
    required int current,
    required Set<int> arrived,
    required bool transported,
  }) = __AStarState;
}

List<Node> navigate(World world, NavigateArguments arguments) {
  var keyResource = arguments.keyResource;
  if (keyResource != null && !arguments.resources.contains(keyResource.position)) {
    keyResource = null;
  }

  // 1. 构建所有可通行节点的列表和索引映射

  // 节点列表与映射
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
  if (n == 0) return [];
  // 关键资源点和权重
  int? keyTransportNodeIndex;
  int defaultWeight = arguments.defaultWeight;
  int keyResourceWeight = defaultWeight;
  if (keyResource != null) {
    keyTransportNodeIndex = nodeToIndex[keyResource.transport]!;
    keyResourceWeight = keyResource.keyResourceWeight;
  }
  // 出口
  final exitNodeIndexes = <int>{};
  for (final e in arguments.exits) {
    exitNodeIndexes.add(nodeToIndex[e]!);
  }

  // 2. 构建地标图，简化原地图（入口+资源点）

  // 地标列表与映射
  final landmarkNodes = <Node>[];
  final landmarkToIndex = <Node, int>{};
  int addLandmark(Node node) {
    assert(nodeToIndex.containsKey(node));
    if (!landmarkToIndex.containsKey(node)) {
      landmarkToIndex[node] = landmarkNodes.length;
      landmarkNodes.add(node);
    }
    return landmarkToIndex[node]!;
  }
  // 起点
  final startLandmark = addLandmark(arguments.start);
  // 资源点
  for (final r in arguments.resources) {
    addLandmark(r);
  }
  final k = landmarkNodes.length;
  /// 获取地标索引对应的节点索引
  int getLandmarkNode(int landmarkIndex) => nodeToIndex[landmarkNodes[landmarkIndex]]!;
  // 关键资源点
  int? keyPositionLandmark;
  if (keyResource != null) {
    keyPositionLandmark = landmarkToIndex[keyResource.position]!;
  }

  // 3. 计算地标图的邻接矩阵

  // 有向邻接表
  final adj = List.generate(n, (_) => <(int, int)>[]); // adj[u]=(v,cost)
  for (int i = 0; i < n; i++) {
    final u = nodes[i];
    void add(Node v) {
      final vi = nodeToIndex[v]!;
      adj[i].add((vi, 1));
    }
    final cell = world.cell(u.layer, u.x, u.y)!;
    // 楼梯
    switch (cell.info.isStair) {
      case null:
      case StairTransport.nothing:
        break;
      case StairTransport.goUp:
        add(Node(u.layer.up()!, u.x, u.y));
        break;
      case StairTransport.goDown:
        add(Node(u.layer.down()!, u.x, u.y));
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
            add(Node(u.layer, nx, ny));
          }
          break;
        case EdgeType.door:
          add(Node(u.layer, nx, ny));
          break;
        case EdgeType.innerWall:
          break;
        case EdgeType.hole:
          add(Node(u.layer.down()!, nx, ny));
          break;
      }
    }
  }
  for (final entry in arguments.entrancesLength.entries) {
    // 出入口间的移动
    final u = entry.key.$1;
    final v = entry.key.$2;
    final w = entry.value;
    adj[nodeToIndex[u]!].add((nodeToIndex[v]!, w));
  }
  // 地标图有向邻接矩阵
  /// 计算从 [start] 这一 Node 出发，到其他所有 node 的最短路线
  ({List<int?> dist, List<int?> parent}) dijkstraNodeToNodes(int start) {
    final List<int?> dist = List<int?>.filled(n, null);
    final List<int?> parent = List<int?>.filled(n, null);
    final pq = PriorityQueue<(int, int)>(compare<(int, int)>((p) => p.$2)); // 元素为 (v, cost)
    dist[start] = 0;
    pq.add((start, 0));
    while (pq.isNotEmpty) {
      final (u, du) = pq.removeFirst();
      if (dist[u] != null && du > dist[u]!) continue;
      for (final (v, w) in adj[u]) {
        final nd = du + w;
        if (dist[v] == null || nd < dist[v]!) {
          dist[v] = nd;
          parent[v] = u;
          pq.add((v, nd));
        }
      }
    }
    return (dist: dist, parent: parent);
  }
  final distParentLandmarks = List<({List<int?> dist, List<int?> parent})>.generate(
    k, (landmarkIndex) => dijkstraNodeToNodes(landmarkIndex == keyPositionLandmark ? keyTransportNodeIndex! : getLandmarkNode(landmarkIndex)), // (从关键资源点出发即从传送后资源点出发)
  );
  // 地标 i 到地标 j 的最短距离
  final distLandmarks = List<List<int>>.generate(
    k, (i) => List<int>.generate(k, (j) => distParentLandmarks[i].dist[getLandmarkNode(j)]!,
  ));
  /// 计算地标到最近出口的最短路线
  ({int? dist, int? exit}) distLandmarkToExit(int landmark) {
    if (exitNodeIndexes.isEmpty) return (dist: 0, exit: null);
    int? best;
    int? bestExit;
    for (final exit in exitNodeIndexes) {
      final dist = distParentLandmarks[landmark].dist[exit]!;
      if (best == null || dist < best) {
        best = dist;
        bestExit = exit;
      }
    }
    return (dist: best, exit: bestExit);
  }
  final distParentLandmarkExits = List<({int? dist, int? exit})>.generate(
    k, (landmarkIndex) => distLandmarkToExit(landmarkIndex),
  );
  // 地标 i 到出口的最短距离
  final distLandmarkExit = List<int>.generate(
    k, (landmarkIndex) => distParentLandmarkExits[landmarkIndex].dist!,
  );

  // 4. 计算上界: 贪心（最近邻）

  /// 计算从当前点开始，贪心到达所有剩余地标，再到出口，所需的路程长度，返回路径含起点[current]
  ({int dist, List<int> path}) greedy(int current, Set<int> arrived) {
    int distTotal = 0;
    final newArrived = Set<int>.of(arrived);
    final path = <int>[current];
    while (newArrived.length < k) {
      int? best;
      int? bestTarget;
      for (int r = 0; r < k; r++) {
        if (newArrived.contains(r)) continue;
        final dist = distLandmarks[current][r];
        if (best == null || dist < best) {
          best = dist;
          bestTarget = r;
        }
      }
      distTotal += best!;
      current = bestTarget!;
      newArrived.add(current);
      path.add(current);
    }
    final distExit = distLandmarkExit[current];
    return (dist: distTotal + distExit, path: path);
  }
  // 计算上界
  int greedyCost;
  List<int> greedyPath;
  if (keyResource != null && startLandmark != keyPositionLandmark!) {
    // 存在关键资源点，先获取并传送，再收集其他资源
    final distKey = distLandmarks[startLandmark][keyPositionLandmark];
    final result = greedy(keyPositionLandmark, <int>{startLandmark, keyPositionLandmark});
    greedyCost = distKey * keyResourceWeight + result.dist * defaultWeight;
    greedyPath = <int>[startLandmark, ...result.path];
  } else {
    // 不存在关键资源点/起点就是关键资源点(直接传送)，直接收集所有资源
    final result = greedy(startLandmark, <int>{startLandmark});
    greedyCost = result.dist * defaultWeight;
    greedyPath = result.path;
  }

  // 5. 计算下界: 剩余地标的 MST

  /// 计算 当前点 + 所有剩余地标 的最小生成树 + 出口
  int mst(int current, Set<int> arrived) {
    // 剩余地标
    final remaining = <int>[current];
    for (int r = 0; r < k; r++) {
      if (arrived.contains(r)) continue;
      remaining.add(r);
    }
    if (remaining.isEmpty) {
      return distLandmarkExit[current];
    }
    final size = remaining.length;
    // Prim 求 MST
    final visited = BoolList(size, fill: false);
    final pq = PriorityQueue<(int, int)>(compare<(int, int)>((p) => p.$2)); // 元素为 (v, cost)
    int total = 0;
    int visitedCount = 0;
    pq.add((0, 0));
    while (pq.isNotEmpty && visitedCount < size) {
      final (u, cost) = pq.removeFirst();
      if (visited[u]) continue;
      visited[u] = true;
      visitedCount++;
      total += cost;
      for (int v = 0; v < size; v++) {
        if (visited[v]) continue;
        final w = min(
          distLandmarks[remaining[u]][remaining[v]],
          distLandmarks[remaining[v]][remaining[u]],
        );
        pq.add((v, w));
      }
    }
    assert (visitedCount == size);
    // 添加出口
    int? minExit;
    if (exitNodeIndexes.isEmpty) {
      minExit = 0;
    } else {
      for (final u in remaining) {
        final dist = distLandmarkExit[u];
        if (minExit == null || dist < minExit) {
          minExit = dist;
        }
      }
    }
    return total + minExit!;
  }
  // // 缓存 mst
  // @freezed
  // abstract class _MstCacheKey with _$MstCacheKey {
  //   _MstCacheKey._();
  //   factory _MstCacheKey({
  //     required int currentLandmark,
  //     required Set<int> collectedResources,
  //   }) = __MstCacheKey;
  // }
  // final mstCache = <_MstCacheKey, int?>{};
  // int? mstWithCache(int currentLandmark, Set<int> collectedResources) {
  //   final key = _MstCacheKey(currentLandmark: currentLandmark, collectedResources: collectedResources);
  //   if (mstCache.containsKey(key)) return mstCache[key];
  //   final cost = mst(currentLandmark, collectedResources);
  //   mstCache[key] = cost;
  //   return cost;
  // }
  /// 启发式函数
  int heuristic(_AStarState state) {
    final current = state.current;
    final arrived = state.arrived;
    final transported = state.transported;
    // 没有关键资源点或已经传送过，直接使用普通 MST 作为下界
    if (keyResource == null || transported) {
      final distMst = mst(current, arrived);
      return distMst * defaultWeight;
    }
    final keyLandmark = keyPositionLandmark!;
    assert(!arrived.contains(keyLandmark));
    assert(current != keyLandmark);
    // 需要考虑传送
    if (arrived.length >= k - 1) { // 只剩关键资源点未到达
      // 直接走到关键资源点，再直接到出口
      final beforeTransport = distLandmarks[current][keyLandmark] * keyResourceWeight;
      final afterTransport = distLandmarkExit[keyLandmark] * defaultWeight;
      return beforeTransport + afterTransport;
    }
    // 选择一个剩余资源，取在传送前收集和在传送后收集得最小代价
    // 即 min(起点+随机资源点+关键资源点(传送)+出口, 起点+关键资源点(传送)+随机资源点+出口)
    int? random;
    for (int r = 0; r < k; r++) {
      if (arrived.contains(r)) continue;
      if (r == keyLandmark) continue;
      random = r;
      break;
    }
    final landmark = random!;
    return min(
      (distLandmarks[current][landmark] + distLandmarks[landmark][keyLandmark]) * keyResourceWeight + distLandmarkExit[keyLandmark] * defaultWeight,
      distLandmarks[current][keyLandmark] * keyResourceWeight + (distLandmarks[keyLandmark][landmark] + distLandmarkExit[landmark]) * defaultWeight,
    );
  }

  // 6. A* / 分支定界搜索

  final startState = _AStarState(
    current: startLandmark,
    arrived: <int>{startLandmark},
    transported: keyResource != null && startLandmark == keyPositionLandmark!,
  );
  final startH = heuristic(startState);
  final List<int> path;
  if (startH >= greedyCost) {
    // 贪心解法已是最优
    path = greedyPath;
  } else {
    int bestCost = greedyCost;
    final cost = <_AStarState, int>{};
    final prev = <_AStarState, _AStarState>{};
    final pq = HeapPriorityQueue<(int, int, _AStarState)>(
      compareSequentially([
        compare<(int, int, _AStarState)>((item) => item.$1),
        compare<(int, int, _AStarState)>((item) => item.$2),
      ]),
    ); // 元素为 (f, g, state)
    cost[startState] = 0;
    pq.add((startH, 0, startState));
    _AStarState? bestFinalState;
    while (pq.isNotEmpty) {
      final (f, g, state) = pq.removeFirst();
      if (cost[state] != null && g > cost[state]!) continue; // 如果该状态已经有更优代价，跳过
      if (f >= bestCost) break; // 当前下界已不优于当前上界，结束
      void addState(_AStarState newState, int newG) {
        if (cost[newState] == null || newG < cost[newState]!) {
          final newH = heuristic(newState);
          final newF = newG + newH;
          if (newF < bestCost) {
            cost[newState] = newG;
            prev[newState] = state;
            pq.add((newF, newG, newState));
          }
        }
      }
      final current = state.current;
      final arrived = state.arrived;
      final transported = state.transported;
      final weight = (keyResource == null || transported) ? defaultWeight : keyResourceWeight;
      // 资源全收集，到出口，更新上界
      if (arrived.length == k) {
        final dist = distLandmarkExit[current];
        final total = g + dist * weight;
        if (total < bestCost) {
          bestCost = total;
          bestFinalState = state;
        }
        continue;
      }
      // 移动到尚未收集的资源点/传送
      for (int r = 0; r < k; r++) {
        if (arrived.contains(r)) continue;
        final dist = distLandmarks[current][r];
        final newState = _AStarState(
          current: r,
          arrived: <int>{...arrived, r},
          transported: transported || (keyResource != null && r == keyPositionLandmark!),
        );
        final newG = g + dist * weight;
        addState(newState, newG);
      }
    }
    if (bestFinalState == null) {
      // 未找到更优解
      path = greedyPath;
    } else {
      // 回溯地标路径
      final rPath = <int>[];
      var curState = bestFinalState;
      while (true) {
        rPath.add(curState.current);
        if (curState == startState) break;
        curState = prev[curState]!;
      }
      path = rPath.reversed.toList();
    }
  }

  // 7. 回溯路径，将地标路径展开为原始节点路径

  // 展开到节点路径
  final pathIndexes = <int>[];
  /// 还原路径，在 [parents] 中，从 [target] 回溯到 [start]，不含起点start，含终点target
  void addSegment(List<int?> parents, int target, int start) {
    final segment = <int>[];
    var cur = target;
    while (cur != start) {
      segment.add(cur);
      cur = parents[cur]!;
    }
    pathIndexes.addAll(segment.reversed);
  }
  for (int i = 0; i < path.length; i++) {
    final currentLandmark = path[i];
    final currentNode = getLandmarkNode(currentLandmark);
    if (i == 0) {
      pathIndexes.add(currentNode);
      continue;
    }
    final prevLandmark = path[i - 1];
    final prevNode = getLandmarkNode(prevLandmark);
    if (keyResource != null && prevLandmark == keyPositionLandmark!) {
      // 传送后移动，补上传送目标节点，再回溯路径
      pathIndexes.add(keyTransportNodeIndex!);
      final parents = distParentLandmarks[prevLandmark].parent;
      addSegment(parents, currentNode, keyTransportNodeIndex);
    } else {
      // 移动，回溯路径
      final parents = distParentLandmarks[prevLandmark].parent;
      addSegment(parents, currentNode, prevNode);
    }
  }
  // 末尾补上到出口的路线
  if (exitNodeIndexes.isNotEmpty) {
    final lastLandmark = path.last;
    final exit = distParentLandmarkExits[lastLandmark].exit!;
    final parents = distParentLandmarks[lastLandmark].parent;
    if (keyResource != null && lastLandmark == keyPositionLandmark!) {
      // 传送后移动
      pathIndexes.add(keyTransportNodeIndex!);
      addSegment(parents, exit, keyTransportNodeIndex);
    } else {
      addSegment(parents, exit, getLandmarkNode(lastLandmark));
    }
  }
  // 返回路径
  return pathIndexes.map((i) => nodes[i]).toList();
}

@SquadronService(baseUrl: '~/workers')
base class NavigateSquadron {
  @SquadronMethod()
  Future<Uint8List> doCompute(
    Uint8List structuresFile,
    Uint8List worldFile,
    Uint8List arguments,
  ) async {
    try {
      final structures = deserializeStructures(structuresFile);
      final world = deserializeWorld(worldFile);
      final worldInstance = constructWorld(structures, world);
      final navigateArguments = deserializeNavigateArguments(arguments);
      final path = navigate(worldInstance, navigateArguments);
      return serializeNavigatePath(path);
    } catch (e, st) {
      // ignore: avoid_print
      assert(() { print(e); print(st); return true; }());
      rethrow;
    }
  }
}

Future<List<Node>> navigateAsync(
  Uint8List structuresFile,
  Uint8List worldFile,
  NavigateArguments navigateArguments,
) async {
  final worker = NavigateSquadronWorker();
  try {
    final arguments = serializeNavigateArguments(navigateArguments);
    final path = await worker.doCompute(structuresFile, worldFile, arguments);
    return deserializeNavigatePath(path);
  } finally {
    worker.stop();
  }
}
