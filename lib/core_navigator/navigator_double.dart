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

class _DoubleStateKey {
  final int current1;
  final int current2;
  final ResourceSet arrived;
  final _TransportPhase phase;

  _DoubleStateKey(this.current1, this.current2, this.arrived, this.phase);

  @override
  bool operator ==(Object other) {
    return other is _DoubleStateKey &&
        current1 == other.current1 &&
        current2 == other.current2 &&
        phase == other.phase &&
        arrived == other.arrived;
  }

  @override
  int get hashCode => Object.hash(current1, current2, phase, arrived);
}

sealed class _DoubleAction {
  const _DoubleAction();
}

class _MoveAction extends _DoubleAction {
  final int who; // 1 或 2
  final int target;

  const _MoveAction(this.who, this.target);
}

class _TeleportAction extends _DoubleAction {
  const _TeleportAction();
}

({List<Node> path1, List<Node> path2}) navigateDouble(
    World world,
    NavigateDoubleArguments arguments,
    ) {
  var keyResource = arguments.keyResource;
  if (keyResource != null &&
      !arguments.resources.contains(keyResource.position)) {
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
  if (n == 0) return (path1: <Node>[], path2: <Node>[]);

  int defaultWeight = arguments.defaultWeight;
  int waitingWeight = arguments.transportWaitingWeight;
  int keyResourceWeight = defaultWeight;
  int? keyTransportNodeIndex;
  if (keyResource != null) {
    keyTransportNodeIndex = nodeToIndex[keyResource.transport]!;
    keyResourceWeight = keyResource.keyResourceWeight;
  }
  assert(keyResourceWeight >= defaultWeight);
  assert(waitingWeight >= keyResourceWeight);

  final exitNodeIndexes = <int>{};
  for (final e in arguments.exits) {
    exitNodeIndexes.add(nodeToIndex[e]!);
  }

  // 2. 构建地标图：起点 1、起点 2、资源点
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

  final start1Landmark = addLandmark(arguments.start1);
  final start2Landmark = addLandmark(arguments.start2);
  for (final r in arguments.resources) {
    addLandmark(r);
  }

  final k = landmarkNodes.length;
  int getLandmarkNode(int landmarkIndex) =>
      nodeToIndex[landmarkNodes[landmarkIndex]]!;

  int? keyPositionLandmark;
  if (keyResource != null) {
    keyPositionLandmark = landmarkToIndex[keyResource.position]!;
  }

  // 3. 地标图邻接矩阵
  final adj = List.generate(n, (_) => <(int, int)>[]);
  for (int i = 0; i < n; i++) {
    final u = nodes[i];

    void add(Node v) {
      final vi = nodeToIndex[v]!;
      adj[i].add((vi, 1));
    }

    final cell = world.cell(u.layer, u.x, u.y)!;

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
    final u = entry.key.$1;
    final v = entry.key.$2;
    final w = entry.value;
    adj[nodeToIndex[u]!].add((nodeToIndex[v]!, w));
  }

  ({List<int?> dist, List<int?> parent}) dijkstraNodeToNodes(int start) {
    final List<int?> dist = List<int?>.filled(n, null);
    final List<int?> parent = List<int?>.filled(n, null);
    final pq = PriorityQueue<(int, int)>(
      compare<(int, int)>((p) => p.$2),
    );

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

  final distParentLandmarks =
  List<({List<int?> dist, List<int?> parent})>.generate(
    k,
        (landmarkIndex) => dijkstraNodeToNodes(
      landmarkIndex == keyPositionLandmark
          ? keyTransportNodeIndex!
          : getLandmarkNode(landmarkIndex),
    ),
  );

  final distLandmarks = List<List<int?>>.generate(
    k,
        (i) => List<int?>.generate(
      k,
          (j) => distParentLandmarks[i].dist[getLandmarkNode(j)],
    ),
  );

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
    k,
        (landmarkIndex) => distLandmarkToExit(landmarkIndex),
  );

  final distLandmarkExit = List<int>.generate(
    k,
        (landmarkIndex) => distParentLandmarkExits[landmarkIndex].dist!,
  );

  // 4. 双人贪心可行上界
  ({int cost, List<int> path1, List<int> path2})? greedyDouble(
      int current1,
      int cost1,
      int current2,
      int cost2,
      ResourceSet arrived,
      int weight,
      ) {
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
  int? greedyCost;
  List<int>? greedyLandmarkPath1;
  List<int>? greedyLandmarkPath2;
  if (keyResource == null) {
    final res = greedyDouble(
      start1Landmark, 0,
      start2Landmark, 0,
      ResourceSet.singleton(start1Landmark).add(start2Landmark),
      defaultWeight,
    );
    if (res != null) {
      greedyCost = res.cost;
      greedyLandmarkPath1 = [start1Landmark, ...res.path1];
      greedyLandmarkPath2 = [start2Landmark, ...res.path2];
    }
  } else {
    final keyLandmark = keyPositionLandmark!;

    final d1 = start1Landmark == keyLandmark
        ? 0
        : distLandmarks[start1Landmark][keyLandmark];
    final d2 = start2Landmark == keyLandmark
        ? 0
        : distLandmarks[start2Landmark][keyLandmark];

    int? nearDist;
    if (d1 != null && (d2 == null || d1 <= d2)) {
      nearDist = d1;
    } else if (d2 != null) {
      nearDist = d2;
    }

    if (nearDist != null) {
      final base = nearDist * keyResourceWeight;
      final arrivedAfter = ResourceSet.singleton(start1Landmark)
          .add(start2Landmark)
          .add(keyLandmark);

      final res = greedyDouble(
        keyLandmark,
        base,
        keyLandmark,
        base,
        arrivedAfter,
        defaultWeight,
      );
      greedyCost = res?.cost;
    }
  }

  // 5. 下界：剩余地标 + 出口的 MST
  final mstCache = EqualityMap<List<int>, int>(ListEquality<int>());

  int? mst(int current1, int current2, ResourceSet arrived) {
    final remaining = <int>[];
    for (int r = 0; r < k; r++) {
      if (r == current1 || r == current2 || !arrived.contains(r)) {
        remaining.add(r);
      }
    }

    final size = remaining.length;
    final totalNodes = size + 1;
    final exitNode = size;

    final cached = mstCache[remaining];
    if (cached != null) return cached;

    final visited = BoolList(totalNodes, fill: false);
    final pq = PriorityQueue<(int, int)>(
      compare<(int, int)>((p) => p.$2),
    );

    int total = 0;
    int visitedCount = 0;
    pq.add((0, 0));

    while (pq.isNotEmpty && visitedCount < totalNodes) {
      final (u, cost) = pq.removeFirst();
      if (visited[u]) continue;

      visited[u] = true;
      visitedCount++;
      total += cost;

      if (u == exitNode) continue;

      for (int v = 0; v < size; v++) {
        if (v == u || visited[v]) continue;

        final a = distLandmarks[remaining[u]][remaining[v]];
        final b = distLandmarks[remaining[v]][remaining[u]];
        final int? w = a == null ? b : (b == null ? a : min(a, b));
        if (w == null) return null;

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

  int? heuristicDouble(_DoubleAStarState state) {
    // 使用最小权重保证可采纳性
    int weight = defaultWeight;

    final lbAlready = max(state.cost1, state.cost2);

    final lbReturn = max(
      state.cost1 + distLandmarkExit[state.current1] * weight,
      state.cost2 + distLandmarkExit[state.current2] * weight,
    );

    int lbCity = 0;
    for (int r = 0; r < k; r++) {
      if (state.arrived.contains(r)) continue;

      final dR = distLandmarkExit[r] * weight;
      final d1 = distLandmarks[state.current1][r];
      final d2 = distLandmarks[state.current2][r];

      int? c1;
      int? c2;
      if (d1 != null) c1 = state.cost1 + d1 * weight + dR;
      if (d2 != null) c2 = state.cost2 + d2 * weight + dR;

      if (c1 == null && c2 == null) return null;

      final c = c1 == null
          ? c2!
          : (c2 == null ? c1 : min(c1, c2));
      if (c > lbCity) lbCity = c;
    }

    final mstRaw = mst(state.current1, state.current2, state.arrived);
    int lbAvg;
    if (mstRaw == null) {
      lbAvg = 0;
    } else {
      lbAvg = ((state.cost1 + state.cost2 + mstRaw * weight) / 2).ceil();
    }

    return max(lbAlready, max(lbReturn, max(lbCity, lbAvg)));
  }

  // 6. 分支定界搜索
  final bool start1IsKey =
      keyResource != null && start1Landmark == keyPositionLandmark;
  final bool start2IsKey =
      keyResource != null && start2Landmark == keyPositionLandmark;

  final startArrived =
  ResourceSet.singleton(start1Landmark).add(start2Landmark);

  final _DoubleAStarState startState;
  if (keyResource == null) {
    startState = _DoubleAStarState(
      current1: start1Landmark,
      current2: start2Landmark,
      arrived: startArrived,
      phase: _TransportPhase.after,
      cost1: 0,
      cost2: 0,
    );
  } else if (start1IsKey || start2IsKey) {
    startState = _DoubleAStarState(
      current1: start1Landmark,
      current2: start2Landmark,
      arrived: startArrived,
      phase: _TransportPhase.waiting,
      cost1: 0,
      cost2: 0,
    );
  } else {
    startState = _DoubleAStarState(
      current1: start1Landmark,
      current2: start2Landmark,
      arrived: startArrived,
      phase: _TransportPhase.before,
      cost1: 0,
      cost2: 0,
    );
  }

  final startH = heuristicDouble(startState);
  if (startH == null) {
    return (path1: <Node>[], path2: <Node>[]);
  }

  int? bestCost = greedyCost;
  _DoubleAStarState? bestFinalState;

  final pq = HeapPriorityQueue<(int, int, _DoubleAStarState)>(
    compareSequentially([
      compare<(int, int, _DoubleAStarState)>((e) => e.$1),
      compare<(int, int, _DoubleAStarState)>((e) => e.$2),
    ]),
  );

  final prev = <_DoubleAStarState, _DoubleAStarState>{};
  final actions = <_DoubleAStarState, _DoubleAction>{};
  final seen = <_DoubleStateKey, List<(int, int)>>{};

  bool isDominated(_DoubleAStarState s) {
    final key = _DoubleStateKey(s.current1, s.current2, s.arrived, s.phase);
    final list = seen[key];
    if (list == null) return false;
    for (final (c1, c2) in list) {
      if (c1 <= s.cost1 && c2 <= s.cost2) return true;
    }
    return false;
  }

  void markSeen(_DoubleAStarState s) {
    final key = _DoubleStateKey(s.current1, s.current2, s.arrived, s.phase);
    final list = seen.putIfAbsent(key, () => []);
    list.removeWhere((e) => s.cost1 <= e.$1 && s.cost2 <= e.$2);
    list.add((s.cost1, s.cost2));
  }

  void addState(
      _DoubleAStarState newState,
      _DoubleAStarState parent,
      _DoubleAction action,
      ) {
    if (isDominated(newState)) return;

    final h = heuristicDouble(newState);
    if (h == null) return;
    if (bestCost != null && h >= bestCost) return;

    markSeen(newState);
    prev[newState] = parent;
    actions[newState] = action;

    pq.add((h, max(newState.cost1, newState.cost2), newState));
  }

  pq.add((startH, 0, startState));

  while (pq.isNotEmpty) {
    final (f, _, state) = pq.removeFirst();

    if (bestCost != null && f >= bestCost) break;

    // 目标：所有地标都已访问，且已经完成传送，或本来就没有关键资源
    if (state.arrived.length == k &&
        (keyResource == null || state.phase == _TransportPhase.after)) {
      final total1 =
          state.cost1 + distLandmarkExit[state.current1] * defaultWeight;
      final total2 =
          state.cost2 + distLandmarkExit[state.current2] * defaultWeight;
      final cost = max(total1, total2);

      if (bestCost == null || cost < bestCost) {
        bestCost = cost;
        bestFinalState = state;
      }
      continue;
    }

    switch (state.phase) {
      case _TransportPhase.before:
        {
          final weight = keyResourceWeight;

          for (int r = 0; r < k; r++) {
            if (state.arrived.contains(r)) continue;

            // 1 移动
            final d1 = distLandmarks[state.current1][r];
            if (d1 != null) {
              final newArrived = state.arrived.add(r);
              final newPhase = r == keyPositionLandmark
                  ? _TransportPhase.waiting
                  : _TransportPhase.before;

              final newState = _DoubleAStarState(
                current1: r,
                current2: state.current2,
                arrived: newArrived,
                phase: newPhase,
                cost1: state.cost1 + d1 * weight,
                cost2: state.cost2,
              );

              addState(newState, state, _MoveAction(1, r));
            }

            // 2 移动
            final d2 = distLandmarks[state.current2][r];
            if (d2 != null) {
              final newArrived = state.arrived.add(r);
              final newPhase = r == keyPositionLandmark
                  ? _TransportPhase.waiting
                  : _TransportPhase.before;

              final newState = _DoubleAStarState(
                current1: state.current1,
                current2: r,
                arrived: newArrived,
                phase: newPhase,
                cost1: state.cost1,
                cost2: state.cost2 + d2 * weight,
              );

              addState(newState, state, _MoveAction(2, r));
            }
          }
        }
        break;

      case _TransportPhase.waiting:
        {
          final bool firstIsKey = state.current1 == keyPositionLandmark;
          final bool secondIsKey = state.current2 == keyPositionLandmark;

          final int waiterCurrent =
          firstIsKey ? state.current2 : state.current1;

          // 同意传送
          final base = max(state.cost1, state.cost2);
          final afterState = _DoubleAStarState(
            current1: keyPositionLandmark!,
            current2: keyPositionLandmark,
            arrived: state.arrived,
            phase: _TransportPhase.after,
            cost1: base,
            cost2: base,
          );
          addState(afterState, state, const _TeleportAction());

          // 等待者继续移动。若等待者也在关键资源点，则只允许传送。
          if (waiterCurrent != keyPositionLandmark) {
            for (int r = 0; r < k; r++) {
              if (state.arrived.contains(r)) continue;

              final d = distLandmarks[waiterCurrent][r];
              if (d == null) continue;

              final newArrived = state.arrived.add(r);

              final _DoubleAStarState newState;
              final _DoubleAction action;

              if (firstIsKey) {
                // 等待者是 2
                newState = _DoubleAStarState(
                  current1: state.current1,
                  current2: r,
                  arrived: newArrived,
                  phase: _TransportPhase.waiting,
                  cost1: state.cost1,
                  cost2: state.cost2 + d * waitingWeight,
                );
                action = _MoveAction(2, r);
              } else {
                // 等待者是 1
                newState = _DoubleAStarState(
                  current1: r,
                  current2: state.current2,
                  arrived: newArrived,
                  phase: _TransportPhase.waiting,
                  cost1: state.cost1 + d * waitingWeight,
                  cost2: state.cost2,
                );
                action = _MoveAction(1, r);
              }

              addState(newState, state, action);
            }
          }
        }
        break;

      case _TransportPhase.after:
        {
          final weight = defaultWeight;

          for (int r = 0; r < k; r++) {
            if (state.arrived.contains(r)) continue;

            // 1 移动
            final d1 = distLandmarks[state.current1][r];
            if (d1 != null) {
              final newState = _DoubleAStarState(
                current1: r,
                current2: state.current2,
                arrived: state.arrived.add(r),
                phase: _TransportPhase.after,
                cost1: state.cost1 + d1 * weight,
                cost2: state.cost2,
              );
              addState(newState, state, _MoveAction(1, r));
            }

            // 2 移动
            final d2 = distLandmarks[state.current2][r];
            if (d2 != null) {
              final newState = _DoubleAStarState(
                current1: state.current1,
                current2: r,
                arrived: state.arrived.add(r),
                phase: _TransportPhase.after,
                cost1: state.cost1,
                cost2: state.cost2 + d2 * weight,
              );
              addState(newState, state, _MoveAction(2, r));
            }
          }
        }
        break;
    }
  }

  List<int> expandLandmarkPath(List<int> landmarks) {
    final result = <int>[];
    if (landmarks.isEmpty) return result;

    int prevLandmark = landmarks[0];
    int prevNode = getLandmarkNode(prevLandmark);
    result.add(prevNode);

    for (int i = 1; i < landmarks.length; i++) {
      final lm = landmarks[i];

      if (lm == -1) {
        if (keyTransportNodeIndex == null) continue;
        result.add(keyTransportNodeIndex);
        prevLandmark = keyPositionLandmark!;
        prevNode = keyTransportNodeIndex;
        continue;
      }

      final targetNode = getLandmarkNode(lm);

      if (prevLandmark == keyPositionLandmark) {
        final parents = distParentLandmarks[keyPositionLandmark!].parent;
        final segment = <int>[];
        var node = targetNode;
        while (node != keyTransportNodeIndex) {
          segment.add(node);
          node = parents[node]!;
        }
        result.addAll(segment.reversed);
      } else {
        final parents = distParentLandmarks[prevLandmark].parent;
        final segment = <int>[];
        final startNode = getLandmarkNode(prevLandmark);
        var node = targetNode;
        while (node != startNode) {
          segment.add(node);
          node = parents[node]!;
        }
        result.addAll(segment.reversed);
      }

      prevLandmark = lm;
      prevNode = targetNode;
    }

    // 末尾到出口
    if (exitNodeIndexes.isNotEmpty) {
      final exitInfo = distParentLandmarkExits[prevLandmark];
      final exit = exitInfo.exit;
      if (exit != null) {
        final parents = distParentLandmarks[prevLandmark].parent;
        final startNode = prevLandmark == keyPositionLandmark
            ? keyTransportNodeIndex!
            : getLandmarkNode(prevLandmark);

        final segment = <int>[];
        var node = exit;
        while (node != startNode) {
          segment.add(node);
          node = parents[node]!;
        }
        result.addAll(segment.reversed);
      }
    }

    return result;
  }

  if (bestFinalState == null) {
    if (greedyLandmarkPath1 != null && greedyLandmarkPath2 != null) {
      final path1Indexes = expandLandmarkPath(greedyLandmarkPath1);
      final path2Indexes = expandLandmarkPath(greedyLandmarkPath2);
      return (
      path1: path1Indexes.map((i) => nodes[i]).toList(),
      path2: path2Indexes.map((i) => nodes[i]).toList(),
      );
    }
    return (path1: <Node>[], path2: <Node>[]);
  }

  // 7. 回溯动作，构造地标路径
  final reversedActions = <_DoubleAction>[];
  var cur = bestFinalState;
  while (cur != startState) {
    final act = actions[cur];
    if (act == null) break;
    reversedActions.add(act);
    final p = prev[cur];
    if (p == null) break;
    cur = p;
  }
  final orderedActions = reversedActions.reversed.toList();

  final landmarkPath1 = <int>[start1Landmark];
  final landmarkPath2 = <int>[start2Landmark];

  for (final act in orderedActions) {
    if (act is _MoveAction) {
      if (act.who == 1) {
        landmarkPath1.add(act.target);
      } else {
        landmarkPath2.add(act.target);
      }
    } else if (act is _TeleportAction) {
      landmarkPath1.add(-1);
      landmarkPath2.add(-1);
    }
  }

  final path1Indexes = expandLandmarkPath(landmarkPath1);
  final path2Indexes = expandLandmarkPath(landmarkPath2);

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
