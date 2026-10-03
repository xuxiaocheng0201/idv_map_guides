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
    @Default(<(Node, Node), int>{}) Map<(Node, Node), int> entrancesLength,
    @Default(1) int defaultWeight,
    /// 一人到达关键资源点后，另一人继续移动时每步的权重
    @Default(2) int transportWaitingWeight,
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

@freezed
abstract class _DoubleAStarKey with _$DoubleAStarKey {
  _DoubleAStarKey._();
  factory _DoubleAStarKey({
    required int current1,
    required int current2,
    required ResourceSet arrived,
    required _TransportPhase phase,
  }) = __DoubleAStarKey;
}

@freezed
sealed class _DoubleAction with _$DoubleAction {
  const factory _DoubleAction.move(int who, int target) = _MoveAction;
  const factory _DoubleAction.teleport() = _TeleportAction;
}

({List<Node> path1, List<Node> path2}) navigateDouble(World world, NavigateDoubleArguments arguments) {
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
  if (n == 0) return (path1: <Node>[], path2: <Node>[]);
  // 关键资源点和权重
  int? keyTransportNodeIndex;
  int defaultWeight = arguments.defaultWeight;
  int waitingWeight = arguments.transportWaitingWeight;
  int keyResourceWeight = defaultWeight;
  if (keyResource != null) {
    keyTransportNodeIndex = nodeToIndex[keyResource.transport]!;
    keyResourceWeight = keyResource.keyResourceWeight;
  }
  assert(keyResourceWeight >= defaultWeight);
  assert(waitingWeight >= keyResourceWeight);
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
  final start1Landmark = addLandmark(arguments.start1);
  final start2Landmark = addLandmark(arguments.start2);
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
  final distLandmarks = List<List<int?>>.generate(
      k, (i) => List<int?>.generate(k, (j) => distParentLandmarks[i].dist[getLandmarkNode(j)],
  ));
  /// 计算地标到最近出口的最短路线
  ({int? dist, int? exit}) distLandmarkToExit(int landmark) {
    if (exitNodeIndexes.isEmpty) return (dist: 0, exit: null);
    int? best;
    int? bestExit;
    for (final exit in exitNodeIndexes) {
      final dist = distParentLandmarks[landmark].dist[exit];
      if (dist == null) continue;
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
    k, (landmarkIndex) => distParentLandmarkExits[landmarkIndex].dist!, // 出口一定可达
  );

  // 4. 计算上界: 双人贪心（最近邻）

  // 约定地标 -1 表示传送

  /// 双人贪心：轮流把剩余地标分配给让 max(cost1,cost2) 增长更小的人，最后去出口，返回路线不含起点
  ({int cost, List<int> path1, List<int> path2})? greedyDouble(int current1, int cost1, int current2, int cost2, ResourceSet arrived, int weight) {
    final p1 = <int>[];
    final p2 = <int>[];
    while (arrived.length < k) {
      int? bestResource;
      bool? bestWho;
      int? bestMax;
      int? bestCost;
      for (int r = 0; r < k; r++) {
        if (arrived.contains(r)) continue;
        final d1 = distLandmarks[current1][r];
        if (d1 != null) {
          final newCost = cost1 + d1 * weight;
          final m = max(newCost, cost2);
          if (bestMax == null || m < bestMax) {
            bestMax = m;
            bestResource = r;
            bestWho = true;
            bestCost = newCost;
          }
        }
        final d2 = distLandmarks[current2][r];
        if (d2 != null) {
          final newCost = cost2 + d2 * weight;
          final m = max(cost1, newCost);
          if (bestMax == null || m < bestMax) {
            bestMax = m;
            bestResource = r;
            bestWho = false;
            bestCost = newCost;
          }
        }
      }
      if (bestResource == null) return null;
      if (bestWho!) {
        cost1 = bestCost!;
        current1 = bestResource;
        p1.add(bestResource);
      } else {
        cost2 = bestCost!;
        current2 = bestResource;
        p2.add(bestResource);
      }
      arrived = arrived.add(bestResource);
    }
    final total1 = cost1 + distLandmarkExit[current1] * weight;
    final total2 = cost2 + distLandmarkExit[current2] * weight;
    return (cost: max(total1, total2), path1: p1, path2: p2);
  }
  /// 单人贪心：在路线长不超过 limitDist 的前提下，最近领访问尽可能多的地标，返回路线不含起点
  ({int dist, List<int> path, ResourceSet newArrived}) greedyOne(int current, ResourceSet arrived, int limitDist) {
    int distTotal = 0;
    final path = <int>[];
    while (arrived.length < k) {
      int? best;
      int? bestTarget;
      for (int r = 0; r < k; r++) {
        if (arrived.contains(r)) continue;
        final dist = distLandmarks[current][r];
        if (dist == null) continue;
        if (best == null || dist < best) {
          best = dist;
          bestTarget = r;
        }
      }
      if (best == null) break;
      if (distTotal + best > limitDist) break;
      distTotal += best;
      current = bestTarget!;
      arrived = arrived.add(current);
      path.add(current);
    }
    return (dist: distTotal, path: path, newArrived: arrived);
  }
  int? greedyCost;
  List<int>? greedyPath1;
  List<int>? greedyPath2;
  if (keyResource == null) {
    // 无关键资源：直接双人贪心
    final res = greedyDouble(
      start1Landmark, 0, start2Landmark, 0,
      ResourceSet.singleton(start1Landmark).add(start2Landmark),
      defaultWeight,
    );
    if (res != null) {
      greedyCost = res.cost;
      greedyPath1 = [start1Landmark, ...res.path1];
      greedyPath2 = [start2Landmark, ...res.path2];
    }
  } else {
    // 存在关键资源点，近的人先到关键资源点，随后立即传送，再双人收集其他资源
    final keyLandmark = keyPositionLandmark!;
    // 计算两人直接到关键资源点的距离
    final d1 = start1Landmark == keyLandmark ? 0 : distLandmarks[start1Landmark][keyLandmark];
    final d2 = start2Landmark == keyLandmark ? 0 : distLandmarks[start2Landmark][keyLandmark];
    int nearWho; // 1 或 2
    int nearDist;
    if (d1 != null && (d2 == null || d1 <= d2)) {
      nearWho = 1;
      nearDist = d1;
    } else if (d2 != null) {
      nearWho = 2;
      nearDist = d2;
    } else {
      // 两人都不可达关键资源点，无法构造可行上界
      nearWho = 0;
      nearDist = 0;
    }
    if (nearWho != 0) {
      final nearStart = nearWho == 1 ? start1Landmark : start2Landmark;
      final farStart = nearWho == 1 ? start2Landmark : start1Landmark;
      final farResult = greedyOne(farStart, ResourceSet.singleton(start1Landmark).add(start2Landmark).add(keyLandmark), nearDist);
      final base = nearDist * keyResourceWeight; // = max(nearDist, farResult.dist) * keyResourceWeight
      final res = greedyDouble(keyLandmark, base, keyLandmark, base, farResult.newArrived, defaultWeight);
      if (res != null) {
        greedyCost = res.cost;
        // near: 起点 -> (若起点不是 keyLandmark) keyLandmark -> -1(传送) -> res.path
        final nearPath = nearStart == keyLandmark ? <int>[nearStart, -1] : <int>[nearStart, keyLandmark, -1];
        // far: 起点 -> farPath -> -1(传送) -> res.path
        final farPath = <int>[farStart, ...farResult.path, -1];
        if (nearWho == 1) {
          greedyPath1 = [...nearPath, ...res.path1];
          greedyPath2 = [...farPath, ...res.path2];
        } else {
          greedyPath1 = [...farPath, ...res.path1];
          greedyPath2 = [...nearPath, ...res.path2];
        }
      }
    }
  }

  // 5. 计算下界: 剩余地标 + 出口的 MST / 2

  /// 已到达关键资源点的人花费 keyCost，另一个人已花费 otherCost，另一个人再走 d 步的实际花费
  int waitingMoveCost(int dist, int keyCost, int otherCost) {
    if (otherCost >= keyCost) return dist * waitingWeight;
    final syncTime = keyCost - otherCost;
    final beforeSteps = min(dist, syncTime ~/ keyResourceWeight);
    final afterSteps = dist - beforeSteps;
    return beforeSteps * keyResourceWeight + afterSteps * waitingWeight;
  }
  final mstCache = EqualityMap<List<int>, int>(ListEquality<int>());
  /// 计算 当前点 + 所有剩余地标 + 出口 的最小生成树
  int? mst(int current1, int current2, ResourceSet arrived) {
    // 剩余地标（按地标索引升序）
    final remaining = <int>[];
    for (int r = 0; r < k; r++) {
      if (r == current1 || r == current2 || !arrived.contains(r)) {
        remaining.add(r);
      }
    }
    final size = remaining.length;
    final totalNodes = size + 1;
    final exitNode = size;
    // 缓存
    final cached = mstCache[remaining];
    if (cached != null) return cached;
    // Prim 求 MST
    final visited = BoolList(totalNodes, fill: false);
    final pq = PriorityQueue<(int, int)>(compare<(int, int)>((p) => p.$2)); // 元素为 (v, cost)
    int total = 0;
    int visitedCount = 0;
    pq.add((0, 0));
    while (pq.isNotEmpty && visitedCount < totalNodes) {
      final (u, cost) = pq.removeFirst();
      if (visited[u]) continue;
      visited[u] = true;
      visitedCount++;
      total += cost;
      if (u == exitNode) continue; // 不从出口节点扩展
      for (int v = 0; v < size; v++) {
        if (v == u || visited[v]) continue;
        final a = distLandmarks[remaining[u]][remaining[v]];
        final b = distLandmarks[remaining[v]][remaining[u]];
        final w = minOfTwo(a, b);
        if (w == null) return null; // 图不连通，这种情况极为罕见，所以不缓存
        pq.add((v, w));
      }
      if (!visited[exitNode]) {
        pq.add((exitNode, distLandmarkExit[remaining[u]]));
      }
    }
    if (visitedCount < totalNodes) return null;
    mstCache[remaining] = total;
    return total;
  }
  /// 通用下界，max(直接去出口, MST / 2, 各剩余地标的最小访问)，权重取最小的 defaultWeight
  int? heuristicBase(int current1, int current2, ResourceSet arrived, int cost1, int cost2) {
    // 下界 1：两人直接去出口
    final int lbReturn = max(
      cost1 + distLandmarkExit[current1] * defaultWeight,
      cost2 + distLandmarkExit[current2] * defaultWeight,
    );
    // 下界 2：每个剩余地标必须由某人访问，对每个地标取访问它的最小可能
    int lbCity = 0;
    for (int r = 0; r < k; r++) {
      if (arrived.contains(r)) continue;
      final int? dr1 = distLandmarks[current1][r];
      final int? dr2 = distLandmarks[current2][r];
      final int drExit = distLandmarkExit[r];
      int? c1Val;
      int? c2Val;
      if (dr1 != null) c1Val = cost1 + (dr1 + drExit) * defaultWeight;
      if (dr2 != null) c2Val = cost2 + (dr2 + drExit) * defaultWeight;
      if (c1Val == null && c2Val == null) return null;
      final int c = c1Val == null ? c2Val! : (c2Val == null ? c1Val : min(c1Val, c2Val));
      if (c > lbCity) lbCity = c;
    }
    // 下界 3：剩余地标 + 出口的 MST，两人并行的最大路线 >= 总距离 / 2
    final int? mstCost = mst(current1, current2, arrived);
    if (mstCost == null) return null;
    final int lbMst = (cost1 + cost2 + mstCost * defaultWeight + 1) ~/ 2; // ceil
    return max(max(lbReturn, lbCity), lbMst);
  }
  /// 最终启发式分派
  int? heuristicDouble(_DoubleAStarState state) {
    final int current1 = state.current1;
    final int current2 = state.current2;
    final ResourceSet arrived = state.arrived;
    final int cost1 = state.cost1;
    final int cost2 = state.cost2;
    final _TransportPhase phase = state.phase;
    final base = heuristicBase(current1, current2, arrived, cost1, cost2);
    if (base == null) return null;
    // 无关键资源，或已经传送完成，直接用通用下界
    if (keyResource == null || phase == _TransportPhase.after) {
      return base;
    }
    final int keyLandmark = keyPositionLandmark!;
    int keyLb = 0;
    switch (phase) {
      case _TransportPhase.before:
        // 传送前启发式，最近一人到达关键资源点，立即传送
        final dist1ToKey = current1 == keyLandmark ? 0 : distLandmarks[current1][keyLandmark];
        final dist2ToKey = current2 == keyLandmark ? 0 : distLandmarks[current2][keyLandmark];
        if (dist1ToKey == null && dist2ToKey == null) return null;
        final cost1ToKey = dist1ToKey == null ? null : max(cost1 + dist1ToKey * keyResourceWeight, cost2);
        final cost2ToKey = dist2ToKey == null ? null : max(cost1, cost2 + dist2ToKey * keyResourceWeight);
        final costOnlyTransport = minOfTwo(cost1ToKey, cost2ToKey)!;
        keyLb = costOnlyTransport + distLandmarkExit[keyLandmark] * defaultWeight;
        // 取任一随机普通资源点比较其在传送前/传送后收集的成本
        for (int r = 0; r < k; r++) {
          if (r == keyLandmark || arrived.contains(r)) continue;
          // r 在传送后收集
          final distKeyR = distLandmarks[keyLandmark][r];
          final distRExit = distLandmarkExit[r];
          final collectAfter = distKeyR == null ? null : costOnlyTransport + (distKeyR + distRExit) * defaultWeight;
          // r 在传送前收集
          final dist1ToR = distLandmarks[current1][r];
          final dist2ToR = distLandmarks[current2][r];
          final distRKey = distLandmarks[r][keyLandmark];
          final collectBefore1 = dist1ToR == null || distRKey == null ? null : max(cost1 + (dist1ToR + distRKey) * keyResourceWeight, cost2);
          final collectBefore2 = dist2ToR == null || distRKey == null ? null : max(cost1, cost2 + (dist2ToR + distRKey) * keyResourceWeight);
          final collectBefore = collectBefore1 == null && collectBefore2 == null ? null : minOfTwo(collectBefore1, collectBefore2)! + distLandmarkExit[keyLandmark] * defaultWeight;
          // 更新最大下界
          final costCollect = minOfTwo(collectAfter, collectBefore);
          if (costCollect == null) return null;
          keyLb = max(keyLb, costCollect);
        }
        break;
      case _TransportPhase.waiting:
        // 等待中启发式，立即同意传送
        final keyCost = current1 == keyLandmark ? cost1 : cost2;
        final otherCost = current1 == keyLandmark ? cost2 : cost1;
        final otherCurrent = current1 == keyLandmark ? current2 : current1;
        final costTransport = max(keyCost, otherCost);
        keyLb = costTransport + distLandmarkExit[keyLandmark] * defaultWeight;
        if (otherCurrent != keyLandmark) {
          // 取任一随机普通资源点比较其在传送前/传送后收集的成本
          for (int r = 0; r < k; r++) {
            if (r == keyLandmark || arrived.contains(r)) continue;
            // 传送前收集
            final distToR = distLandmarks[otherCurrent][r];
            final costToR = distToR == null ? null : waitingMoveCost(distToR, keyCost, otherCost);
            final collectBefore = costToR == null ? null : max(keyCost, otherCost + costToR) + distLandmarkExit[keyLandmark] * defaultWeight;
            // 传送后收集
            final distKeyR = distLandmarks[keyLandmark][r];
            final distRExit = distLandmarkExit[r];
            final collectAfter = distKeyR == null ? null : max(keyCost, otherCost) + (distKeyR + distRExit) * defaultWeight;
            // 更新更大下界
            final costCollect = minOfTwo(collectAfter, collectBefore);
            if (costCollect == null) return null;
            keyLb = max(keyLb, costCollect);
          }
        }
        break;
      case _TransportPhase.after:
        return base; // unreachable
    }
    return max(base, keyLb);
  }

  // 6. A* / 分支定界搜索

  final bool start1IsKey = keyResource != null && start1Landmark == keyPositionLandmark;
  final bool start2IsKey = keyResource != null && start2Landmark == keyPositionLandmark;
  final startArrived = ResourceSet.singleton(start1Landmark).add(start2Landmark);
  final _TransportPhase startPhase;
  if (keyResource == null) {
    startPhase = _TransportPhase.after;
  } else if (start1IsKey || start2IsKey) {
    startPhase = _TransportPhase.waiting;
  } else {
    startPhase = _TransportPhase.before;
  }
  final _DoubleAStarState startState = _DoubleAStarState(
    current1: start1Landmark,
    current2: start2Landmark,
    arrived: startArrived,
    phase: startPhase,
    cost1: 0,
    cost2: 0,
  );
  final startH = heuristicDouble(startState);
  if (startH == null) return (path1: <Node>[], path2: <Node>[]); // 起点状态无解
  int? bestCost = greedyCost;
  _DoubleAStarState? bestFinalState;
  final pq = HeapPriorityQueue<(int, int, _DoubleAStarState)>(
    compareSequentially([
      compare<(int, int, _DoubleAStarState)>((e) => e.$1),
      compare<(int, int, _DoubleAStarState)>((e) => e.$2),
    ]),
  ); // 元素为(f, max(cost1,cost2), state)
  final seen = <_DoubleAStarKey, List<(int, int)>>{}; // 支配剪枝 seen[key] = [(cost1, cost2), ..]
  final prev = <_DoubleAStarState, (_DoubleAStarState, _DoubleAction)>{};
  (_DoubleAStarKey, int, int) canonicalKeyCost(_DoubleAStarState s) {
    final swap = s.current1 > s.current2 || (s.current1 == s.current2 && s.cost1 > s.cost2);
    final key = _DoubleAStarKey(
      current1: swap ? s.current2 : s.current1,
      current2: swap ? s.current1 : s.current2,
      arrived: s.arrived,
      phase: s.phase,
    );
    return swap ? (key, s.cost2, s.cost1) : (key, s.cost1, s.cost2);
  }
  bool isDominated(_DoubleAStarState s) {
    final (key, cost1, cost2) = canonicalKeyCost(s);
    final list = seen[key];
    if (list == null) return false;
    for (final (c1, c2) in list) {
      if (c1 <= cost1 && c2 <= cost2) return true;
    }
    return false;
  }
  void markSeen(_DoubleAStarState s) {
    final (key, cost1, cost2) = canonicalKeyCost(s);
    final list = seen.putIfAbsent(key, () => []);
    list.removeWhere((e) => cost1 <= e.$1 && cost2 <= e.$2);
    list.add((cost1, cost2));
  }
  pq.add((startH, 0, startState));
  seen[canonicalKeyCost(startState).$1] = <(int, int)>[(0, 0)];
  void addState(_DoubleAStarState newState, _DoubleAStarState parent, _DoubleAction action) {
    if (isDominated(newState)) return; // 被已有状态支配，剪枝
    // 启发式不可达或下界已经不低于当前最优解，剪枝。
    final h = heuristicDouble(newState);
    if (h == null) return;
    if (bestCost != null && h >= bestCost) return;
    // 记录 Pareto 前沿、父状态和动作，然后入队。
    markSeen(newState);
    prev[newState] = (parent, action);
    pq.add((h, max(newState.cost1, newState.cost2), newState));
  }
  while (pq.isNotEmpty) {
    final (f, _, state) = pq.removeFirst();
    if (bestCost != null && f >= bestCost) break; // 当前下界已不优于当前上界，结束
    final current1 = state.current1;
    final current2 = state.current2;
    final arrived = state.arrived;
    final phase = state.phase;
    final cost1 = state.cost1;
    final cost2 = state.cost2;
    // 资源全收集，到出口，更新上界
    if (arrived.length == k) {
      final weight = switch (phase) {
        _TransportPhase.before => keyResourceWeight,
        _TransportPhase.waiting => waitingWeight,
        _TransportPhase.after => defaultWeight,
      };
      final total1 = cost1 + distLandmarkExit[current1] * weight;
      final total2 = cost2 + distLandmarkExit[current2] * weight;
      final cost = max(total1, total2);
      if (bestCost == null || cost < bestCost) {
        bestCost = cost;
        bestFinalState = state;
      }
      continue;
    }
    final samePersonState = current1 == current2 && cost1 == cost2;
    switch (phase) {
      case _TransportPhase.before:
        // before：还没有人到达关键资源点
        for (int r = 0; r < k; r++) {
          if (arrived.contains(r)) continue;
          final d1 = distLandmarks[current1][r];
          if (d1 != null) {
            final newArrived = arrived.add(r);
            final newPhase = r == keyPositionLandmark ? _TransportPhase.waiting : _TransportPhase.before;
            final newState = _DoubleAStarState(
              current1: r,
              current2: current2,
              arrived: newArrived,
              phase: newPhase,
              cost1: cost1 + d1 * keyResourceWeight,
              cost2: cost2,
            );
            addState(newState, state, _MoveAction(1, r));
          }
          if (samePersonState) continue;
          final d2 = distLandmarks[current2][r];
          if (d2 != null) {
            final newArrived = arrived.add(r);
            final newPhase = r == keyPositionLandmark ? _TransportPhase.waiting : _TransportPhase.before;
            final newState = _DoubleAStarState(
              current1: current1,
              current2: r,
              arrived: newArrived,
              phase: newPhase,
              cost1: cost1,
              cost2: cost2 + d2 * keyResourceWeight,
            );
            addState(newState, state, _DoubleAction.move(2, r));
          }
        }
        break;
      case _TransportPhase.waiting:
        // waiting：已经有人到达关键资源点，正在等待同意传送
        final bool firstIsKey = current1 == keyPositionLandmark;
        final int keyCost = firstIsKey ? cost1 : cost2;
        final int otherCost = firstIsKey ? cost2 : cost1;
        final int otherCurrent = firstIsKey ? current2 : current1;
        // 同意传送：两人都从 keyResource.transport 出发，成本同步为 max(cost1,cost2)
        final base = max(cost1, cost2);
        final afterState = _DoubleAStarState(
          current1: keyPositionLandmark!,
          current2: keyPositionLandmark,
          arrived: arrived,
          phase: _TransportPhase.after,
          cost1: base,
          cost2: base,
        );
        addState(afterState, state, const _DoubleAction.teleport());
        // 等待者（未在关键点的人）继续移动
        if (otherCurrent != keyPositionLandmark) {
          for (int r = 0; r < k; r++) {
            if (arrived.contains(r)) continue;
            final d = distLandmarks[otherCurrent][r];
            if (d == null) continue;
            final add = waitingMoveCost(d, keyCost, otherCost);
            final newArrived = arrived.add(r);
            final _DoubleAStarState newState;
            final _DoubleAction action;
            if (firstIsKey) {
              // 移动 2
              newState = _DoubleAStarState(
                current1: current1,
                current2: r,
                arrived: newArrived,
                phase: _TransportPhase.waiting,
                cost1: cost1,
                cost2: cost2 + add,
              );
              action = _MoveAction(2, r);
            } else {
              // 移动 1
              newState = _DoubleAStarState(
                current1: r,
                current2: current2,
                arrived: newArrived,
                phase: _TransportPhase.waiting,
                cost1: cost1 + add,
                cost2: cost2,
              );
              action = _MoveAction(1, r);
            }
            addState(newState, state, action);
          }
        }
        break;
      case _TransportPhase.after:
        // after：已经完成传送
        for (int r = 0; r < k; r++) {
          if (arrived.contains(r)) continue;
          final d1 = distLandmarks[current1][r];
          if (d1 != null) {
            final newState = _DoubleAStarState(
              current1: r,
              current2: current2,
              arrived: arrived.add(r),
              phase: _TransportPhase.after,
              cost1: cost1 + d1 * defaultWeight,
              cost2: cost2,
            );
            addState(newState, state, _MoveAction(1, r));
          }
          if (samePersonState) continue;
          final d2 = distLandmarks[current2][r];
          if (d2 != null) {
            final newState = _DoubleAStarState(
              current1: current1,
              current2: r,
              arrived: arrived.add(r),
              phase: _TransportPhase.after,
              cost1: cost1,
              cost2: cost2 + d2 * defaultWeight,
            );
            addState(newState, state, _MoveAction(2, r));
          }
        }
        break;
    }
  }

  // 7. 回溯路径

  // 回溯地标路径
  final List<int> path1;
  final List<int> path2;
  if (bestFinalState == null) {
    // 贪心解法已是最优，未找到更优解
    path1 = greedyPath1 ?? <int>[];
    path2 = greedyPath2 ?? <int>[];
  } else {
    // 回溯动作
    final rActions = <_DoubleAction>[];
    var curState = bestFinalState;
    while (curState != startState) {
      final (prevState, action) = prev[curState]!;
      rActions.add(action);
      curState = prevState;
    }
    final orderedActions = rActions.reversed.toList();
    // 展开地标路径
    path1 = <int>[start1Landmark];
    path2 = <int>[start2Landmark];
    for (final action in orderedActions) {
      switch (action) {
        case _MoveAction():
          if (action.who == 1) {
            path1.add(action.target);
          } else {
            path2.add(action.target);
          }
          break;
        case _TeleportAction():
          path1.add(-1);
          path2.add(-1);
          break;
      }
    }
  }
  /// 还原路径，在 [parents] 中，从 [target] 回溯到 [start]，不含起点start，含终点target
  Iterable<int> getSegment(List<int?> parents, int target, int start) {
    final segment = <int>[];
    var cur = target;
    while (cur != start) {
      segment.add(cur);
      cur = parents[cur]!;
    }
    return segment.reversed;
  }
  /// 展开到节点路径
  List<int> expandLandmarkPath(List<int> landmarks) {
    final result = <int>[];
    if (landmarks.isEmpty) return result;
    int prevLandmark = landmarks[0];
    int prevNode = getLandmarkNode(prevLandmark);
    result.add(prevNode);
    for (int i = 1; i < landmarks.length; i++) {
      final landmark = landmarks[i];
      if (landmark == -1) {
        // 传送，补上传送目标节点
        result.add(keyTransportNodeIndex!);
        prevLandmark = keyPositionLandmark!;
        prevNode = keyTransportNodeIndex;
        continue;
      }
      final parents = distParentLandmarks[prevLandmark].parent;
      final targetNode = getLandmarkNode(landmark);
      final startNode = prevLandmark == keyPositionLandmark ? keyTransportNodeIndex! : getLandmarkNode(prevLandmark); // 传送后移动，start 应改为 keyTransportNodeIndex
      result.addAll(getSegment(parents, targetNode, startNode));
      prevLandmark = landmark;
      prevNode = targetNode;
    }
    // 末尾，从最后一个地标走到最近的出口
    if (exitNodeIndexes.isNotEmpty) {
      final parents = distParentLandmarks[prevLandmark].parent;
      final exit = distParentLandmarkExits[prevLandmark].exit!;
      final startNode = prevLandmark == keyPositionLandmark ? keyTransportNodeIndex! : getLandmarkNode(prevLandmark); // 传送后移动
      result.addAll(getSegment(parents, exit, startNode));
    }
    return result;
  }
  // 返回原始节点路线
  final path1Indexes = expandLandmarkPath(path1);
  final path2Indexes = expandLandmarkPath(path2);
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
    try {
      final structures = deserializeStructures(structuresFile);
      final world = deserializeWorld(worldFile);
      final worldInstance = constructWorld(structures, world);
      final navigateArguments = deserializeNavigateDoubleArguments(arguments);
      final result = navigateDouble(worldInstance, navigateArguments);
      return (serializeNavigatePath(result.path1), serializeNavigatePath(result.path2));
    } catch (e, st) {
      // ignore: avoid_print
      assert(() { print(e); print(st); return true; }());
      rethrow;
    }
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
