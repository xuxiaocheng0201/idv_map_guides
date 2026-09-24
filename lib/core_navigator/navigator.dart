import 'dart:collection';
import 'dart:convert';
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

/// 关键资源
///
/// 表示一个需要优先收集的资源：它位于 [position]，可以传送到 [transport]
/// 并且在未传送前每走一步都会增加 [urgency] 的额外代价
@freezed
abstract class KeyResource with _$KeyResource {
  KeyResource._();
  factory KeyResource({
    required Node position,
    required Node transport,
    @Default(1.0) double urgency,
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
  }) = _NavigateArguments;

  String get identify =>
      '${start.identify}'
      '/${resources.sorted(Comparable.compare).map((node) => node.identify).join(',')}'
      '/${exits.sorted(Comparable.compare).map((node) => node.identify).join(",")}'
      '${keyResource == null ? '' : '/${keyResource!.position.identify},${keyResource!.transport.identify},${keyResource!.urgency}'}';
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
abstract class _MstCacheKey with _$MstCacheKey {
  _MstCacheKey._();
  factory _MstCacheKey({
    required int currentLandmark,
    required Set<int> collectedResources,
  }) = __MstCacheKey;
}

@freezed
abstract class _AStarState with _$AStarState {
  _AStarState._();
  factory _AStarState({
    /// 已收集的资源索引
    required Set<int> collectedResourceIndexes,
    /// 当前所在地标在地标列表中的索引
    required int currentLandmarkIndex,
    /// 是否已经从关键资源点传送过
    required bool hasTransported,
  }) = __AStarState;
}

List<Node> navigate(World world, NavigateArguments arguments, {bool debugPrint = false}) {
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
  if (n == 0) return [];
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

  // 2. 构建地标集合：起点 + 所有资源点 + 所有出口 + 关键资源点位置 + 关键资源点传送目标

  // 构建地标列表与映射
  final landmarkNodes = <Node>[];
  final landmarkToIndex = <Node, int>{};
  void addLandmark(Node node) {
    assert(nodeToIndex.containsKey(node));
    if (landmarkToIndex.containsKey(node)) return;
    landmarkToIndex[node] = landmarkNodes.length;
    landmarkNodes.add(node);
  }
  addLandmark(arguments.start);
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
  final startLandmark = landmarkToIndex[arguments.start]!;
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
  if (debugPrint) {
    String landmarkType(int i) {
      final node = landmarkNodes[i];
      if (i == startLandmark) return 'start';
      if (keyResource != null && i == keyPositionLandmark) return 'keyPosition';
      if (keyResource != null && i == keyTransportLandmark) return 'keyTransport';
      if (resourceToIndex.containsKey(node)) return 'resource';
      if (arguments.exits.contains(node)) return 'exit';
      return 'unknown';
    }
    final landmarkJson = <String, dynamic>{
      'startLandmark': startLandmark,
      'exitLandmarks': exitLandmarks,
      'keyPositionLandmark': keyPositionLandmark,
      'keyTransportLandmark': keyTransportLandmark,
      'keyResourceIndex': keyResourceIndex,
      'defaultWeight': defaultWeight,
      'keyResourceWeight': keyResourceWeight,
      'nodes': [
        for (int i = 0; i < m; i++)
          <String, dynamic>{
            'index': i,
            'id': landmarkNodes[i].identify,
            'layer': landmarkNodes[i].layer.index,
            'x': landmarkNodes[i].x,
            'y': landmarkNodes[i].y,
            'type': landmarkType(i),
            'resourceIndex': getLandmarkResource(i),
          },
      ],
      'edges': [
        for (int i = 0; i < m; i++)
          for (int j = 0; j < m; j++)
            if (i != j && landmarkDist[i][j] != null)
              <String, dynamic>{
                'from': i,
                'to': j,
                'dist': landmarkDist[i][j],
              },
      ],
    };
    print(jsonEncode(landmarkJson));
  }

  // 4. A* 启发式：剩余地标的 MST 作为下界

  /// 计算 剩余资源点 + 当前地标 + 出口 的最小生成树
  /// 时间复杂度 O(k^2)
  int? mst(int currentLandmark, Set<int> collectedResources) {
    // 尚未收集的资源点
    final remainingResources = <int>[];
    for (int r = 0; r < k; r++) {
      if (!collectedResources.contains(r)) {
        remainingResources.add(r);
      }
    }
    // 如果所有资源已收集，只需走到任意出口
    if (remainingResources.isEmpty) {
      return distLandmarkToExit(currentLandmark);
    }

    // 构造距离矩阵：节点 0 为当前地标，1..remaining 为剩余资源点，最后为出口点
    final hasExit = exitLandmarks.isNotEmpty;
    final size = 1 + remainingResources.length + (hasExit ? 1 : 0);
    final distMst = List<List<int?>>.generate(
      size,
      (_) => List<int?>.filled(size, null),
    );
    int maxDist = 0;
    // 当前地标 -> 资源点
    for (int i = 0; i < remainingResources.length; i++) {
      final r = remainingResources[i];
      final d = distLandmarkToLandmark(currentLandmark, getResourceLandmark(r));
      distMst[0][i + 1] = d;
      distMst[i + 1][0] = d;
      maxDist = max(maxDist, d ?? 0);
    }
    // 资源点 -> 资源点
    for (int i = 0; i < remainingResources.length; i++) {
      for (int j = i + 1; j < remainingResources.length; j++) {
        final ri = getResourceLandmark(remainingResources[i]);
        final rj = getResourceLandmark(remainingResources[j]);
        final dij = distLandmarkToLandmark(ri, rj);
        final dji = distLandmarkToLandmark(rj, ri);
        final int? d;
        if (dij == null) {
          d = dji;
        } else if (dji == null) {
          d = dij;
        } else {
          d = dij < dji ? dij : dji;
        }
        distMst[i + 1][j + 1] = d;
        distMst[j + 1][i + 1] = d;
        maxDist = max(maxDist, d ?? 0);
      }
    }
    if (hasExit) {
      final exitPos = size - 1;
      // 当前地标 -> 最近出口
      final de = distLandmarkToExit(currentLandmark);
      distMst[0][exitPos] = de;
      distMst[exitPos][0] = de;
      maxDist = max(maxDist, de ?? 0);
      // 资源点 -> 最近出口
      for (int i = 0; i < remainingResources.length; i++) {
        final r = remainingResources[i];
        final rLandmark = getResourceLandmark(r);
        final re = distLandmarkToExit(rLandmark);
        distMst[i + 1][exitPos] = re;
        distMst[exitPos][i + 1] = re;
        maxDist = max(maxDist, re ?? 0);
      }
    }

    // Prim 算法求 MST
    final inf = maxDist + 1; // 最大边权 + 1
    final visited = List<bool>.filled(size, false);
    final minDist = List<int>.filled(size, inf);
    minDist[0] = 0;
    int total = 0;
    for (int it = 0; it < size; it++) {
      int best = inf;
      int? u;
      for (int v = 0; v < size; v++) {
        if (!visited[v] && minDist[v] < best) {
          best = minDist[v];
          u = v;
        }
      }
      if (best == inf || u == null) return null; // 图不连通
      visited[u] = true;
      total += best;
      for (int v = 0; v < size; v++) {
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
  // 缓存 mst
  final mstCache = <_MstCacheKey, int?>{};
  int? mstWithCache(int currentLandmark, Set<int> collectedResources) {
    final key = _MstCacheKey(currentLandmark: currentLandmark, collectedResources: collectedResources);
    if (mstCache.containsKey(key)) return mstCache[key];
    final cost = mst(currentLandmark, collectedResources);
    mstCache[key] = cost;
    return cost;
  }
  /// 启发式函数：使用最小生成树来计算下界
  double heuristic(int currentLandmark, Set<int> collectedResources, bool hasTransported) {
    final distMst = mstWithCache(currentLandmark, collectedResources);
    // 没有关键资源点或已经传送过，直接使用普通 MST 作为下界
    if (keyResourceIndex == null || hasTransported) {
      return distMst == null ? double.infinity : defaultWeight * distMst.toDouble();
    }
    final weight = defaultWeight + keyResourceWeight; // 未传送时的每步代价
    // 不传送，即以未传送代价走完全程
    final noTransport = distMst == null ? double.infinity : weight * distMst.toDouble();
    // 传送，先走到关键资源点，再直接到出口
    final beforeTransport = distLandmarkToLandmark(currentLandmark, keyPositionLandmark!);
    if (beforeTransport == null) return noTransport;
    final afterTransport = distLandmarkToExit(keyTransportLandmark!);
    if (afterTransport == null) return noTransport;
    final doTransport = weight * beforeTransport.toDouble() + defaultWeight * afterTransport.toDouble();
    // 取 传送/不传送 最小作为下界
    return min(noTransport, doTransport);
  }

  // 5. 贪心初始可行解，作为分支定界的初始上界

  /// 计算从当前点开始，最近邻收集剩余所有资源
  int? greedy(int currentLandmark, Set<int> collectedResources) {
    int cost = 0;
    final collected = <int>{
      ...collectedResources,
      ?getLandmarkResource(currentLandmark),
    };
    while (collected.length < k) {
      int? bestResourceIndex;
      int? bestDist;
      for (int r = 0; r < k; r++) {
        if (collected.contains(r)) continue;
        final d = distLandmarkToLandmark(
          currentLandmark,
          getResourceLandmark(r),
        );
        if (d != null && (bestDist == null || d < bestDist)) {
          bestDist = d;
          bestResourceIndex = r;
        }
      }
      if (bestResourceIndex == null) {
        return null;
      }
      cost += bestDist!;
      currentLandmark = getResourceLandmark(bestResourceIndex);
      collected.add(bestResourceIndex);
    }
    final de = distLandmarkToExit(currentLandmark);
    if (de == null) {
      return null;
    }
    return cost + de;
  }
  // 计算上界
  double bestCost = double.infinity;
  {
    final startResources = getLandmarkResource(startLandmark);
    // 先走到关键资源点、传送，再收集剩余资源，走出口
    if (keyResourceIndex != null) {
      final dToKey = distLandmarkToLandmark(
        startLandmark,
        keyPositionLandmark!,
      );
      if (dToKey != null) {
        final weight = defaultWeight + keyResourceWeight;
        final beforeCost = dToKey * weight;
        final collected = <int>{
          ?startResources,
          ?getLandmarkResource(keyPositionLandmark),
          ?getLandmarkResource(keyTransportLandmark!),
        };
        final dRemaining = greedy(keyTransportLandmark, collected);
        if (dRemaining != null) {
          final afterCost = dRemaining * defaultWeight;
          final total = beforeCost + afterCost;
          if (total < bestCost) bestCost = total;
        }
      }
    }
    // 不传送，收集所有资源后，走出口
    {
      final collected = <int>{?startResources};
      final dRemaining = greedy(startLandmark, collected);
      if (dRemaining != null) {
        final weight = keyResourceIndex == null
            ? defaultWeight
            : defaultWeight + keyResourceWeight;
        final total = dRemaining * weight;
        if (total < bestCost) bestCost = total;
      }
    }
  }

  // 6. A* / 分支定界搜索

  int searchStep = 0;
  Map<String, dynamic> stateToJson(_AStarState s) => <String, dynamic>{
    'collected': (s.collectedResourceIndexes.toList()..sort()),
    'landmark': s.currentLandmarkIndex,
    'hasTransported': s.hasTransported,
  };
  void emitEvent(Map<String, dynamic> e) {
    e['step'] = searchStep++;
    e['bestCost'] = bestCost.isFinite ? bestCost : null;
    assert(debugPrint);
    print(jsonEncode(e));
  }
  final cost = <_AStarState, double>{};
  final prev = <_AStarState, _AStarState>{};
  final pq = HeapPriorityQueue<(double, double, _AStarState)>(
    compareSequentially([
      compare<(double, double, _AStarState)>((item) => item.$1),
      compare<(double, double, _AStarState)>((item) => item.$2),
    ]),
  ); // 优先队列，元素为 (f, g, state)，先按 f 排序，再按 g 排序
  final startResources = <int>{?getLandmarkResource(startLandmark)};
  final startKey = _AStarState(
    collectedResourceIndexes: startResources,
    currentLandmarkIndex: startLandmark,
    hasTransported: false,
  );
  cost[startKey] = 0.0;
  final startH = heuristic(startLandmark, startResources, false);
  if (startH < bestCost) {
    pq.add((startH, 0.0, startKey));
  } else {
    // 贪心解法已是最优，回溯
    throw UnimplementedError();
  }
  _AStarState? bestFinalState;
  if (debugPrint) {
    emitEvent(<String, dynamic>{
      'action': 'start',
      'to': stateToJson(startKey),
      'g': 0.0,
      'h': startH,
      'f': startH,
    });
  }
  while (pq.isNotEmpty) {
    final (f, g, state) = pq.removeFirst();
    if (debugPrint) {
      emitEvent(<String, dynamic>{
        'action': 'pop',
        'from': stateToJson(state),
        'g': g,
        'h': f - g,
        'f': f,
      });
    }
    if (g > (cost[state] ?? double.infinity)) { // 如果该状态已经有更优代价，跳过
      if (debugPrint) {
        emitEvent(<String, dynamic>{
          'action': 'stale',
          'from': stateToJson(state),
          'g': g,
          'h': f - g,
          'f': f,
        });
      }
      continue;
    }
    if (f >= bestCost) { // 当前下界已不优于当前上界，结束
      if (debugPrint) {
        emitEvent(<String, dynamic>{
          'action': 'break',
          'from': stateToJson(state),
          'g': g,
          'h': f - g,
          'f': f,
        });
      }
      break;
    }
    final hasTransported = state.hasTransported;
    final currentLandmark = state.currentLandmarkIndex;
    final collectedResources = state.collectedResourceIndexes;
    final weight = (keyResourceIndex != null && !hasTransported)
        ? defaultWeight + keyResourceWeight
        : defaultWeight;
    // 叶子：所有资源已收集 → 走向出口（或出口集合为空时直接完成），更新上界
    if (collectedResources.length == k) {
      final dExit = distLandmarkToExit(currentLandmark);
      if (dExit != null) {
        final total = g + dExit * weight;
        if (total < bestCost) {
          final oldBest = bestCost;
          bestCost = total;
          bestFinalState = state;
          if (debugPrint) {
            emitEvent(<String, dynamic>{
              'action': 'updateBest',
              'from': stateToJson(state),
              'prevBestCost': oldBest.isFinite ? oldBest : null,
              'newBestCost': bestCost,
              'label': 'exit',
            });
          }
        }
      }
      continue;
    }
    // 动作 1：传送
    if (keyResourceIndex != null && !hasTransported && currentLandmark == keyPositionLandmark && collectedResources.contains(keyResourceIndex)) {
      final newResources = {
        ...collectedResources,
        ?getLandmarkResource(keyTransportLandmark!),
      };
      final newState = _AStarState(
        collectedResourceIndexes: newResources,
        currentLandmarkIndex: keyTransportLandmark,
        hasTransported: true,
      );
      final newG = g; // 传送本身不消耗步数
      if (newG < (cost[newState] ?? double.infinity)) {
        final newH = heuristic(keyTransportLandmark, newResources, true);
        final newF = newG + newH;
        if (newF < bestCost) {
          cost[newState] = newG;
          prev[newState] = state;
          pq.add((newF, newG, newState));
          if (debugPrint) {
            emitEvent(<String, dynamic>{
              'action': 'expand',
              'from': stateToJson(state),
              'to': stateToJson(newState),
              'g': newG,
              'h': newH,
              'f': newF,
              'label': 'transport',
            });
          }
        } else {
          if (debugPrint) {
            emitEvent(<String, dynamic>{
              'action': 'prune',
              'from': stateToJson(state),
              'to': stateToJson(newState),
              'g': newG,
              'h': newH,
              'f': newF,
              'label': 'transport',
            });
          }
        }
      }
    }
    // 动作 2：移动到尚未收集的资源点
    for (int r = 0; r < k; r++) {
      if (collectedResources.contains(r)) continue;
      final nextLandmark = getResourceLandmark(r);
      final d = distLandmarkToLandmark(currentLandmark, nextLandmark);
      if (d == null) continue;
      final newResources = {...collectedResources, r};
      final newState = _AStarState(
        collectedResourceIndexes: newResources,
        currentLandmarkIndex: nextLandmark,
        hasTransported: hasTransported,
      );
      final newG = g + d * weight;
      if (newG < (cost[newState] ?? double.infinity)) {
        final newH = heuristic(nextLandmark, newResources, hasTransported);
        final newF = newG + newH;
        if (newF < bestCost) {
          cost[newState] = newG;
          prev[newState] = state;
          pq.add((newF, newG, newState));
          if (debugPrint) {
            emitEvent(<String, dynamic>{
              'action': 'expand',
              'from': stateToJson(state),
              'to': stateToJson(newState),
              'g': newG,
              'h': newH,
              'f': newF,
              'label': 'move:$r',
            });
          }
        } else {
          if (debugPrint) {
            emitEvent(<String, dynamic>{
              'action': 'prune',
              'from': stateToJson(state),
              'to': stateToJson(newState),
              'g': newG,
              'h': newH,
              'f': newF,
              'label': 'move:$r',
            });
          }
        }
      }
    }
  }
  if (debugPrint) {
    emitEvent(<String, dynamic>{
      'action': 'done',
      'label': bestFinalState == null ? 'no-solution' : 'solution-found',
    });
  }
  if (bestFinalState == null) return []; // 未找到可行路径

  // 7. 回溯路径

  // 回溯地标状态序列
  final states = <_AStarState>[];
  var curState = bestFinalState;
  while (true) {
    states.add(curState);
    if (curState == startKey) break;
    curState = prev[curState]!;
  }
  final forwardStates = states.reversed.toList();
  // 将地标状态序列展开为原始节点路径
  final pathIndexes = <int>[];
  for (int i = 0; i < forwardStates.length; i++) {
    final state = forwardStates[i];
    final landmark = state.currentLandmarkIndex;
    final landmarkNode = getLandmarkNode(landmark);
    if (i == 0) {
      pathIndexes.add(landmarkNode);
      continue;
    }
    final prevState = forwardStates[i - 1];
    final prevLandmark = prevState.currentLandmarkIndex;
    if (prevLandmark == landmark) continue; // 原地传送
    final isTransport = prevState.hasTransported != state.hasTransported &&
        prevLandmark == keyPositionLandmark &&
        landmark == keyTransportLandmark;
    if (isTransport) {
      // 传送：直接补上传送目标节点
      pathIndexes.add(landmarkNode);
    } else {
      // 正常移动：使用 prevLandmark 的 BFS 父指针还原路径（不含起点，含终点）
      final parents = bfsFromLandmark[prevLandmark].parent;
      final segment = <int>[];
      var cur = landmarkNode;
      final targetNode = getLandmarkNode(prevLandmark);
      while (cur != targetNode) {
        segment.add(cur);
        cur = parents[cur]!;
      }
      pathIndexes.addAll(segment.reversed);
    }
  }
  // 末尾补上走向出口的最短路径
  final lastState = forwardStates.last;
  final lastLandmark = lastState.currentLandmarkIndex;
  if (exitLandmarks.isNotEmpty && !exitLandmarks.contains(lastLandmark)) {
    int? bestExit;
    int? bestExitD;
    for (final e in exitLandmarks) {
      final d = distLandmarkToLandmark(lastLandmark, e);
      if (d != null && (bestExitD == null || d < bestExitD)) {
        bestExitD = d;
        bestExit = e;
      }
    }
    if (bestExit != null) {
      final parents = bfsFromLandmark[lastLandmark].parent;
      final exitNode = getLandmarkNode(bestExit);
      final segment = <int>[];
      var cur = exitNode;
      final targetNode = getLandmarkNode(lastLandmark);
      while (cur != targetNode) {
        segment.add(cur);
        cur = parents[cur]!;
      }
      pathIndexes.addAll(segment.reversed);
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
    final structures = deserializeStructures(structuresFile);
    final world = deserializeWorld(worldFile);
    final worldInstance = constructWorld(structures, world);
    final navigateArguments = deserializeNavigateArguments(arguments);
    final path = navigate(worldInstance, navigateArguments);
    return serializeNavigatePath(path);
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
