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
    @Default(<(Node, Node), int>{}) Map<(Node, Node), int> entrancesLength,
    @Default(1) int defaultWeight,
    /// 一人到达关键资源点后，另一人继续移动时每步的权重
    @Default(1) int transportWaitingWeight,
  }) = _NavigateDoubleArguments;

  String get identify =>
      '${start1.identify}/${start2.identify}'
      '/${resources.sorted(Comparable.compare).map((node) => node.identify).join(',')}'
      '/${exits.sorted(Comparable.compare).map((node) => node.identify).join(",")}'
      '/${keyResource == null ? 'null' : '${keyResource!.position.identify},${keyResource!.transport.identify},${keyResource!.keyResourceWeight}'}'
      '/${entrancesLength.entries.sorted(compareSequentially([
        compare<MapEntry<(Node, Node), int>>((e) => e.key.$1),
        compare<MapEntry<(Node, Node), int>>((e) => e.key.$2),
      ])).map((e) => '${e.key.$1.identify},${e.key.$2.identify},${e.value}').join('|')}'
      '/$defaultWeight'
      '/$transportWaitingWeight';
}

enum _TransportPhase {
  before, // 未有人到达关键资源点，未发起传送，权重 keyResource.keyResourceWeight
  waiting, // 有人已到达关键资源点并等待同意，另一人可继续移动，权重 transportWaitingWeight
  after, // 已同意传送，两人都从 keyResource.transport 出发，权重 defaultWeight
}

@freezed
abstract class _DoubleAStarState with _$DoubleAStarState {
  _DoubleAStarState._();

  factory _DoubleAStarState({
    required int current1,
    required int current2,
    required ResourceSet arrived,
    required _TransportPhase phase,
    required int cost1,
    required int cost2,
  }) = __DoubleAStarState;
}

({List<Node> path1, List<Node> path2}) navigateDouble(World world, NavigateDoubleArguments arguments) {
  return (path1: <Node>[], path2: <Node>[]);
  // var keyResource = arguments.keyResource;
  // if (keyResource != null && !arguments.resources.contains(keyResource.position)) {
  //   keyResource = null;
  // }
  //
  // // 1. 构建所有可通行节点的列表和索引映射
  //
  // // 节点列表与映射
  // final nodes = <Node>[];
  // final nodeToIndex = <Node, int>{};
  // for (final layer in world.map.keys) {
  //   for (int x = world.minX; x <= world.maxX; x++) {
  //     for (int y = world.minY; y <= world.maxY; y++) {
  //       final cell = world.cell(layer, x, y);
  //       if (cell != null && cell.structureId != null) {
  //         final node = Node(layer, x, y);
  //         nodeToIndex[node] = nodes.length;
  //         nodes.add(node);
  //       }
  //     }
  //   }
  // }
  // final n = nodes.length;
  // if (n == 0) return (path1: [], path2: []);
  // // 关键资源点和权重
  // int? keyTransportNodeIndex;
  // int defaultWeight = arguments.defaultWeight;
  // int waitingWeight = arguments.transportWaitingWeight;
  // int keyResourceWeight = defaultWeight;
  // if (keyResource != null) {
  //   keyTransportNodeIndex = nodeToIndex[keyResource.transport]!;
  //   keyResourceWeight = keyResource.keyResourceWeight;
  // }
  // assert(keyResourceWeight >= defaultWeight);
  // assert(waitingWeight >= keyResourceWeight);
  // // 出口
  // final exitNodeIndexes = <int>{};
  // for (final e in arguments.exits) {
  //   exitNodeIndexes.add(nodeToIndex[e]!);
  // }
  // // 2. 构建地标图，简化原地图（入口+资源点）
  //
  // // 地标列表与映射
  // final landmarkNodes = <Node>[];
  // final landmarkToIndex = <Node, int>{};
  // int addLandmark(Node node) {
  //   assert(nodeToIndex.containsKey(node));
  //   if (!landmarkToIndex.containsKey(node)) {
  //     landmarkToIndex[node] = landmarkNodes.length;
  //     landmarkNodes.add(node);
  //   }
  //   return landmarkToIndex[node]!;
  // }
  // // 起点
  // final start1Landmark = addLandmark(arguments.start1);
  // final start2Landmark = addLandmark(arguments.start2);
  // // 资源点
  // for (final r in arguments.resources) {
  //   addLandmark(r);
  // }
  // final k = landmarkNodes.length;
  // /// 获取地标索引对应的节点索引
  // int getLandmarkNode(int landmarkIndex) => nodeToIndex[landmarkNodes[landmarkIndex]]!;
  // // int getResourceLandmark(int resourceIndex) => landmarkToIndex[resources[resourceIndex]]!;
  // // int? getLandmarkResource(int landmarkIndex) => resourceToIndex[landmarkNodes[landmarkIndex]];
  // // 关键资源点
  // int? keyPositionLandmark;
  // if (keyResource != null) {
  //   keyPositionLandmark = landmarkToIndex[keyResource.position]!;
  // }
  //
  // // 3. 计算地标图的邻接矩阵
  //
  // // 有向邻接表
  // final adj = List.generate(n, (_) => <(int, int)>[]); // adj[u]=(v,cost)
  // for (int i = 0; i < n; i++) {
  //   final u = nodes[i];
  //   void add(Node v) {
  //     final vi = nodeToIndex[v]!;
  //     adj[i].add((vi, 1));
  //   }
  //   final cell = world.cell(u.layer, u.x, u.y)!;
  //   // 楼梯
  //   switch (cell.info.isStair) {
  //     case null:
  //     case StairTransport.nothing:
  //       break;
  //     case StairTransport.goUp:
  //       add(Node(u.layer.up()!, u.x, u.y));
  //       break;
  //     case StairTransport.goDown:
  //       add(Node(u.layer.down()!, u.x, u.y));
  //       break;
  //   }
  //   // 平面移动
  //   for (final direction in Direction.values) {
  //     final (dx, dy) = direction.dxy;
  //     final nx = u.x + dx;
  //     final ny = u.y + dy;
  //     final neighbor = world.cell(u.layer, nx, ny);
  //     if (neighbor == null) continue;
  //     switch (cell.info.getEdgeType(direction)) {
  //       case EdgeType.nothing:
  //         if (neighbor.structureId == cell.structureId) {
  //           add(Node(u.layer, nx, ny));
  //         }
  //         break;
  //       case EdgeType.door:
  //         add(Node(u.layer, nx, ny));
  //         break;
  //       case EdgeType.innerWall:
  //         break;
  //       case EdgeType.hole:
  //         add(Node(u.layer.down()!, nx, ny));
  //         break;
  //     }
  //   }
  // }
  // for (final entry in arguments.entrancesLength.entries) {
  //   // 出入口间的移动
  //   final u = entry.key.$1;
  //   final v = entry.key.$2;
  //   final w = entry.value;
  //   adj[nodeToIndex[u]!].add((nodeToIndex[v]!, w));
  // }
  // // 地标图有向邻接矩阵
  // /// 计算从 [start] 这一 Node 出发，到其他所有 node 的最短路线
  // ({List<int?> dist, List<int?> parent}) dijkstraNodeToNodes(int start) {
  //   final List<int?> dist = List<int?>.filled(n, null);
  //   final List<int?> parent = List<int?>.filled(n, null);
  //   final pq = PriorityQueue<(int, int)>(compare<(int, int)>((p) => p.$2)); // 元素为 (v, cost)
  //   dist[start] = 0;
  //   pq.add((start, 0));
  //   while (pq.isNotEmpty) {
  //     final (u, du) = pq.removeFirst();
  //     if (dist[u] != null && du > dist[u]!) continue;
  //     for (final (v, w) in adj[u]) {
  //       final nd = du + w;
  //       if (dist[v] == null || nd < dist[v]!) {
  //         dist[v] = nd;
  //         parent[v] = u;
  //         pq.add((v, nd));
  //       }
  //     }
  //   }
  //   return (dist: dist, parent: parent);
  // }
  // final distParentLandmarks = List<({List<int?> dist, List<int?> parent})>.generate(
  //   k, (landmarkIndex) => dijkstraNodeToNodes(landmarkIndex == keyPositionLandmark ? keyTransportNodeIndex! : getLandmarkNode(landmarkIndex)), // (从关键资源点出发即从传送后资源点出发)
  // );
  // // 地标 i 到地标 j 的最短距离
  // final distLandmarks = List<List<int?>>.generate(
  //     k, (i) => List<int?>.generate(k, (j) => distParentLandmarks[i].dist[getLandmarkNode(j)],
  // ));
  // /// 计算地标到最近出口的最短路线
  // ({int? dist, int? exit}) distLandmarkToExit(int landmark) {
  //   if (exitNodeIndexes.isEmpty) return (dist: 0, exit: null);
  //   int? best;
  //   int? bestExit;
  //   for (final exit in exitNodeIndexes) {
  //     final dist = distParentLandmarks[landmark].dist[exit];
  //     if (dist == null) continue;
  //     if (best == null || dist < best) {
  //       best = dist;
  //       bestExit = exit;
  //     }
  //   }
  //   return (dist: best, exit: bestExit);
  // }
  // final distParentLandmarkExits = List<({int? dist, int? exit})>.generate(
  //   k, (landmarkIndex) => distLandmarkToExit(landmarkIndex),
  // );
  // // 地标 i 到出口的最短距离
  // final distLandmarkExit = List<int>.generate(
  //   k, (landmarkIndex) => distParentLandmarkExits[landmarkIndex].dist!, // 出口一定可达
  // );
  //
  // // 4. 计算上界: 双人贪心
  //
  // // 地标路径约定：
  // //   - 非负整数：地标索引
  // //   - -1：表示“传送到 keyResource.transport 后，从此处继续”
  // //        展开成原始节点路径时，遇到 -1 先补上 keyTransportNodeIndex
  //
  // /// 贪心：轮流把剩余地标分配给让 max(cost1,cost2) 增长更小的人，返回路线不含起点
  // ({int cost, List<int> path1, List<int> path2})? greedyDouble(int current1, int cost1, int current2, int cost2, ResourceSet arrived, int weight) {
  //   final p1 = <int>[];
  //   final p2 = <int>[];
  //   while (arrived.length < k) {
  //     int? bestResource;
  //     bool? bestWho; // true 为第一人，false 为第二人
  //     int? bestMax;
  //     int? bestCost;
  //     for (int r = 0; r < k; r++) {
  //       if (arrived.contains(r)) continue;
  //       final d1 = distLandmarks[current1][r];
  //       if (d1 != null) {
  //         final newCost = cost1 + d1 * weight;
  //         final m = max(newCost, cost2);
  //         if (bestMax == null || m < bestMax) {
  //           bestMax = m;
  //           bestResource = r;
  //           bestWho = true;
  //           bestCost = newCost;
  //         }
  //       }
  //       final d2 = distLandmarks[current2][r];
  //       if (d2 != null) {
  //         final newCost = cost2 + d2 * weight;
  //         final m = max(cost1, newCost);
  //         if (bestMax == null || m < bestMax) {
  //           bestMax = m;
  //           bestResource = r;
  //           bestWho = false;
  //           bestCost = newCost;
  //         }
  //       }
  //     }
  //     if (bestResource == null) return null;
  //     if (bestWho!) {
  //       cost1 = bestCost!;
  //       current1 = bestResource;
  //       p1.add(bestResource);
  //     } else {
  //       cost2 = bestCost!;
  //       current2 = bestResource;
  //       p2.add(bestResource);
  //     }
  //     arrived = arrived.add(bestResource);
  //   }
  //   final total1 = cost1 + distLandmarkExit[current1] * weight;
  //   final total2 = cost2 + distLandmarkExit[current2] * weight;
  //   return (cost: max(total1, total2), path1: p1, path2: p2);
  // }
  // /// 贪心：单人贪心，在路线长不超过 limit 的前提下，最近领访问尽可能多的地标，返回路线不含起点
  // ({int dist, List<int> path, ResourceSet newArrived}) greedyOne(int current, ResourceSet arrived, int limitDist) {
  //   int distTotal = 0;
  //   final path = <int>[];
  //   while (arrived.length < k) {
  //     int? best;
  //     int? bestTarget;
  //     for (int r = 0; r < k; r++) {
  //       if (arrived.contains(r)) continue;
  //       final dist = distLandmarks[current][r];
  //       if (dist == null) continue;
  //       if (best == null || dist < best) {
  //         best = dist;
  //         bestTarget = r;
  //       }
  //     }
  //     if (best == null) break;
  //     if (distTotal + best > limitDist) break;
  //     distTotal += best;
  //     current = bestTarget!;
  //     arrived = arrived.add(current);
  //     path.add(current);
  //   }
  //   return (dist: distTotal, path: path, newArrived: arrived);
  // }
  // int? greedyCost;
  // List<int>? greedyPath1;
  // List<int>? greedyPath2;
  // if (keyResource == null) {
  //   // 没有关键资源，直接双人贪心
  //   final res = greedyDouble(
  //     start1Landmark, 0,
  //     start2Landmark, 0,
  //     ResourceSet.singleton(start1Landmark).add(start2Landmark),
  //     defaultWeight,
  //   );
  //   if (res != null) {
  //     greedyCost = res.cost;
  //     greedyPath1 = [start1Landmark, ...res.path1];
  //     greedyPath2 = [start2Landmark, ...res.path2];
  //   }
  // } else {
  //   // 存在关键资源点，近的人先到关键资源点，随后立即传送，再双人收集其他资源
  //   final keyLandmark = keyPositionLandmark!;
  //   // 计算两人直接到关键资源点的距离
  //   final d1 = start1Landmark == keyLandmark ? 0 : distLandmarks[start1Landmark][keyLandmark];
  //   final d2 = start2Landmark == keyLandmark ? 0 : distLandmarks[start2Landmark][keyLandmark];
  //   int nearWho; // 1 或 2
  //   int nearDist;
  //   if (d1 != null && (d2 == null || d1 <= d2)) {
  //     nearWho = 1;
  //     nearDist = d1;
  //   } else if (d2 != null) {
  //     nearWho = 2;
  //     nearDist = d2;
  //   } else {
  //     // 两人都不可达关键资源点，无法构造可行上界
  //     nearWho = 0;
  //     nearDist = 0;
  //   }
  //   if (nearWho != 0) {
  //     final nearStart = nearWho == 1 ? start1Landmark : start2Landmark;
  //     final farStart = nearWho == 1 ? start2Landmark : start1Landmark;
  //     final nearCost = nearDist * keyResourceWeight;
  //     final farResult = greedyOne(farStart, ResourceSet.singleton(start1Landmark).add(start2Landmark).add(keyLandmark), nearDist);
  //     final fastCost = farResult.dist * keyResourceWeight;
  //     final res = greedyDouble(keyLandmark, nearCost, keyLandmark, fastCost, farResult.newArrived, defaultWeight);
  //     if (res != null) {
  //       // near ：起点 -> (若起点不是 keyLandmark) keyLandmark -> -1(传送) -> res.path
  //       final nearPath = nearStart == keyLandmark ? <int>[nearStart, -1] : <int>[nearStart, keyLandmark, -1];
  //       // far ：起点 -> farPath -> -1(传送) -> res.path
  //       final farPath = <int>[farStart, ...farResult.path, -1];
  //       if (nearWho == 1) {
  //         greedyPath1 = [...nearPath, ...res.path1];
  //         greedyPath2 = [...farPath, ...res.path2];
  //       } else {
  //         greedyPath1 = [...farPath, ...res.path1];
  //         greedyPath2 = [...nearPath, ...res.path2];
  //       }
  //       greedyCost = res.cost;
  //     }
  //   }
  // }
  //
  // // 5. 计算下界: 剩余地标+出口的 MST / 2
  //
  // // 缓存剩余地标图+出口的最小生成树
  // final mstCache = EqualityMap<List<int>, int>(ListEquality<int>());
  // /// 计算 当前点 + 所有剩余地标 + 出口节点 的最小生成树（不是 当前点 + 所有剩余地标 的最小生成树 + 出口）
  // int? mst(int current1, int current2, ResourceSet arrived) {
  //   // 剩余地标（按地标索引升序）
  //   final remaining = <int>[];
  //   for (int r = 0; r < k; r++) {
  //     if (r == current1 || r == current2 || !arrived.contains(r)) {
  //       remaining.add(r);
  //     }
  //   }
  //   final size = remaining.length;
  //   final totalNodes = size + 1;
  //   final exitNode = size;
  //   // 缓存
  //   final cached = mstCache[remaining];
  //   if (cached != null) return cached;
  //   // Prim 求 MST
  //   final visited = BoolList(totalNodes, fill: false);
  //   final pq = PriorityQueue<(int, int)>(compare<(int, int)>((p) => p.$2)); // 元素为 (v, cost)
  //   int total = 0;
  //   int visitedCount = 0;
  //   pq.add((0, 0));
  //   while (pq.isNotEmpty && visitedCount < totalNodes) {
  //     final (u, cost) = pq.removeFirst();
  //     if (visited[u]) continue;
  //     visited[u] = true;
  //     visitedCount++;
  //     total += cost;
  //     if (u == exitNode) continue; // 不从出口节点扩展
  //     for (int v = 0; v < size; v++) {
  //       if (v == u || visited[v]) continue;
  //       final a = distLandmarks[remaining[u]][remaining[v]];
  //       final b = distLandmarks[remaining[v]][remaining[u]];
  //       int? w = a == null ? b : (b == null ? a : min(a, b));
  //       if (w == null) return null; // 图不连通，这种情况极为罕见，所以不缓存
  //       pq.add((v, w));
  //     }
  //     if (!visited[exitNode]) {
  //       pq.add((exitNode, distLandmarkExit[remaining[u]]));
  //     }
  //   }
  //   if (visitedCount < totalNodes) return null;
  //   mstCache[remaining] = total;
  //   return total;
  // }
  // /// 启发式函数
  // int? heuristicDouble(_DoubleAStarState state) {
  //   final current1 = state.current1;
  //   final current2 = state.current2;
  //   final arrived = state.arrived;
  //   final phase = state.phase;
  //   final l1 = state.cost1;
  //   final l2 = state.cost2;
  //
  //   int weight = defaultWeight; // 使用最小权重保证可采纳
  //
  //   // ---------- 下界A：已走部分 ----------
  //   final lbAlready = max(l1, l2);
  //
  //   // ---------- 下界B：各自直接回出口 ----------
  //   final lbReturn = max(
  //     l1 + distLandmarkExit[current1] * weight,
  //     l2 + distLandmarkExit[current2] * weight,
  //   );
  //
  //   // ---------- 下界C：每个未访问资源的承担下界 ----------
  //   int lbCity = 0;
  //   for (int r = 0; r < k; r++) {
  //     if (arrived.contains(r)) continue;
  //     final dR = distLandmarkExit[r] * weight;
  //     final d1 = distLandmarks[current1][r];
  //     final d2 = distLandmarks[current2][r];
  //     int? c1, c2;
  //     if (d1 != null) c1 = l1 + d1 * weight + dR;
  //     if (d2 != null) c2 = l2 + d2 * weight + dR;
  //     if (c1 == null && c2 == null) return null;
  //     final c = c1 == null ? c2! : (c2 == null ? c1 : min(c1, c2));
  //     if (c > lbCity) lbCity = c;
  //   }
  //
  //   // ---------- 下界D：MST 均摊 ----------
  //   final mstRaw = mst(current1, current2, arrived);
  //   int lbAvg;
  //   if (mstRaw == null) {
  //     lbAvg = 0; // 图不连通时退化为 lbReturn，不影响可采纳性
  //   } else {
  //     lbAvg = ((l1 + l2 + mstRaw * weight) / 2).ceil();
  //   }
  //
  //   return max(lbAlready, max(lbReturn, max(lbCity, lbAvg)));
  // }
  //
  //
  // throw UnimplementedError();
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
