import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:squadron/squadron.dart';

import 'navigator.activator.g.dart';
part 'navigator.freezed.dart';
part 'navigator.worker.g.dart';

@freezed
abstract class KeyResource with _$KeyResource {
  KeyResource._();
  factory KeyResource(int id, double urgency, Node transport) = _KeyResource;
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
      '/${resources.sorted(Comparable.compare).join('.')}'
      '/${exits.sorted(Comparable.compare).map((node) => node.identify).join(".")}${keyResource == null ? '' : ''
      '/${keyResource!.id}.${keyResource!.urgency}.${keyResource!.transport.identify}'}';
}

@freezed
abstract class _State with _$State {
  _State._();
  factory _State(
      Set<int> collectedIds,
      int currentIndex,
      bool canTransport,
  ) = __State;
}

List<Node> navigate(World world, NavigateArguments arguments) {
  final start = arguments.start;
  final resources = arguments.resources;
  final exits = arguments.exits;
  final keyResource = arguments.keyResource;

  final effectiveResources = <Object>{...resources};
  if (keyResource != null) effectiveResources.add(keyResource.id);

  // 1. 构建节点列表与映射
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
  final startIndex = nodeToIndex[start];
  if (startIndex == null) return [];

  // 2. 构建有向邻接表
  final adj = List.generate(n, (_) => <int>[]);
  for (var i = 0; i < n; i++) {
    final u = nodes[i];
    final cell = world.cell(u.layer, u.x, u.y)!;
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

  // TODO: connect entrances
  // final exitIndicesSet = <int>{};
  // for (final entry in world.entrances.entries) {
  //   final layer = entry.key.layer();
  //   final pos = entry.value;
  //   final node = Node(layer, pos.x, pos.y);
  //   final idx = nodeToIndex[node];
  //   if (idx != null) exitIndicesSet.add(idx);
  // }
  // final exitIndices = exitIndicesSet.toList();
  // for (final i in exitIndices) {
  //   for (final j in exitIndices) {
  //     if (i == j) continue;
  //     adj[i].add(j);
  //   }
  // }

  // 3. 资源位映射：将需要收集的资源 id 映射到 0..k-1 的位
  final resourceList = effectiveResources.toList();
  final resourceToBit = <Object, int>{};
  for (var i = 0; i < resourceList.length; i++) {
    resourceToBit[resourceList[i]] = i;
  }
  final k = resourceList.length;
  final fullMask = (1 << k) - 1;

  // 4. 每个节点对应的资源位掩码
  final nodeResourceBit = List<int>.generate(n, (i) {
    final node = nodes[i];
    final cell = world.cell(node.layer, node.x, node.y)!;
    int bit = 0;
    final cellBit = resourceToBit[node];
    if (cellBit != null) bit |= 1 << cellBit;
    if (keyResource != null && cell.structureId == keyResource.id) {
      bit |= 1 << resourceToBit[keyResource.id]!;
    }
    return bit;
  });

  // 5. 出口索引集合
  final exitIndices = <int>{};
  for (final node in exits) {
    final idx = nodeToIndex[node];
    if (idx != null) exitIndices.add(idx);
  }

  // 6. 关键资源相关
  int? keyResourceBit;
  double urgency = 0.0;
  int? transportIndex;
  if (keyResource != null) {
    final bit = resourceToBit[keyResource.id];
    if (bit == null) return [];
    keyResourceBit = 1 << bit;
    urgency = keyResource.urgency;
    transportIndex = nodeToIndex[keyResource.transport];
    if (transportIndex == null) return [];
  }

  // 7. 反向邻接表，用于多源 BFS
  final radj = List.generate(n, (_) => <int>[]);
  for (var u = 0; u < n; u++) {
    for (final v in adj[u]) {
      radj[v].add(u);
    }
  }

  List<int?> bfs(List<int> sources) {
    final dist = List<int?>.filled(n, null);
    if (sources.isEmpty) return dist;
    final q = Queue<int>();
    for (final s in sources) {
      dist[s] = 0;
      q.add(s);
    }
    while (q.isNotEmpty) {
      final v = q.removeFirst();
      final dv = dist[v]!;
      for (final u in radj[v]) {
        if (dist[u] == null) {
          dist[u] = dv + 1;
          q.add(u);
        }
      }
    }
    return dist;
  }

  // 到任意出口的最短步数
  final distToExit = exitIndices.isEmpty
      ? List<int?>.filled(n, 0)
      : bfs(exitIndices.toList());

  // 每个资源位对应的节点集合
  final bitNodes = List.generate(k, (_) => <int>[]);
  for (var i = 0; i < n; i++) {
    final bits = nodeResourceBit[i];
    for (var b = 0; b < k; b++) {
      if ((bits & (1 << b)) != 0) bitNodes[b].add(i);
    }
  }

  // 从任意节点到每个资源位的最短步数
  final distToBit = List<List<int?>>.generate(k, (b) => bfs(bitNodes[b]));

  const int inf = 1 << 60;

  // 每个资源位到最近出口的步数
  final bitToExit = List<int>.filled(k, inf);
  for (var b = 0; b < k; b++) {
    var best = inf;
    for (final u in bitNodes[b]) {
      final d = distToExit[u];
      if (d != null && d < best) best = d;
    }
    bitToExit[b] = best;
  }

  // 资源位之间的最短步数矩阵
  final bitDist = List.generate(k, (_) => List<int>.filled(k, inf));
  for (var i = 0; i < k; i++) {
    bitDist[i][i] = 0;
    for (var j = 0; j < k; j++) {
      if (i == j) continue;
      var best = inf;
      for (final u in bitNodes[i]) {
        final d = distToBit[j][u];
        if (d != null && d < best) best = d;
      }
      bitDist[i][j] = best;
    }
  }

  // 到任意关键资源节点的最短步数
  List<int?>? distToKey;
  if (keyResourceBit != null) {
    final keyNodes = <int>[];
    for (var i = 0; i < n; i++) {
      if ((nodeResourceBit[i] & keyResourceBit) != 0) keyNodes.add(i);
    }
    distToKey = bfs(keyNodes);
  }

  // 启发式：剩余资源位 + 当前点 + 出口 的 MST 下界，单位是步数
  double hSteps(int index, int mask) {
    final remainingBits = <int>[];
    for (var b = 0; b < k; b++) {
      if ((mask & (1 << b)) == 0) remainingBits.add(b);
    }

    if (remainingBits.isEmpty) {
      if (exitIndices.isEmpty) return 0.0;
      final d = distToExit[index];
      return d == null ? double.infinity : d.toDouble();
    }

    final hasExit = exitIndices.isNotEmpty;
    final m = 1 + remainingBits.length + (hasExit ? 1 : 0);
    final distMst = List<List<double>>.generate(
      m,
          (_) => List<double>.filled(m, double.infinity),
    );

    // 当前点 -> 剩余资源位
    for (var i = 0; i < remainingBits.length; i++) {
      final b = remainingBits[i];
      final d = distToBit[b][index];
      if (d != null) {
        distMst[0][i + 1] = d.toDouble();
        distMst[i + 1][0] = d.toDouble();
      }
    }

    // 剩余资源位之间
    for (var i = 0; i < remainingBits.length; i++) {
      for (var j = i + 1; j < remainingBits.length; j++) {
        final bi = remainingBits[i];
        final bj = remainingBits[j];
        final dij = bitDist[bi][bj];
        final dji = bitDist[bj][bi];
        final d = dij < dji ? dij : dji;
        if (d < inf) {
          distMst[i + 1][j + 1] = d.toDouble();
          distMst[j + 1][i + 1] = d.toDouble();
        }
      }
    }

    // 出口虚拟点
    if (hasExit) {
      final exitPos = m - 1;
      final de = distToExit[index];
      if (de != null) {
        distMst[0][exitPos] = de.toDouble();
        distMst[exitPos][0] = de.toDouble();
      }
      for (var i = 0; i < remainingBits.length; i++) {
        final d = bitToExit[remainingBits[i]];
        if (d < inf) {
          distMst[i + 1][exitPos] = d.toDouble();
          distMst[exitPos][i + 1] = d.toDouble();
        }
      }
    }

    // Prim 求 MST
    final visited = List<bool>.filled(m, false);
    final minDist = List<double>.filled(m, double.infinity);
    minDist[0] = 0.0;

    var total = 0.0;
    for (var it = 0; it < m; it++) {
      var u = -1;
      var best = double.infinity;
      for (var v = 0; v < m; v++) {
        if (!visited[v] && minDist[v] < best) {
          best = minDist[v];
          u = v;
        }
      }
      if (u == -1 || best.isInfinite) return double.infinity;
      visited[u] = true;
      total += best;
      for (var v = 0; v < m; v++) {
        if (!visited[v] && distMst[u][v] < minDist[v]) {
          minDist[v] = distMst[u][v];
        }
      }
    }
    return total;
  }

  // 总启发式：处理传送前后的边权变化
  double heuristic(int index, int mask, bool canTransport) {
    if (keyResourceBit == null || canTransport) {
      return hSteps(index, mask);
    }

    final w0 = 1.0 + urgency;

    // 不传送：所有剩余移动都按 w0 计费
    final noTransport = w0 * hSteps(index, mask);

    // 传送下界：至少先走到关键资源点，然后传送到 transportIndex，再至少到出口
    if (transportIndex == null || distToKey == null) return noTransport;

    final dKey = distToKey[index];
    if (dKey == null) return noTransport;

    final afterTransport = exitIndices.isEmpty
        ? 0.0
        : (distToExit[transportIndex] ?? 0).toDouble();

    final transport = w0 * dKey + afterTransport;

    return min(noTransport, transport).toDouble();
  }

  // 8. 状态编码：stateKey = ((mask * n + currentIndex) << 1) | canTransport
  int encode(int mask, int index, bool canTransport) {
    return ((mask * n + index) << 1) | (canTransport ? 1 : 0);
  }

  // 9. A* / 分支限界搜索
  final startMask = nodeResourceBit[startIndex];
  final startKey = encode(startMask, startIndex, false);

  final dist = <int, double>{startKey: 0.0};
  final prev = <int, int>{};

  final pq = HeapPriorityQueue<(double, double, int)>((a, b) {
    final c = a.$1.compareTo(b.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });

  final startH = heuristic(startIndex, startMask, false);
  pq.add((startH, 0.0, startKey));

  var bestCost = double.infinity;
  int? finalStateKey;

  while (pq.isNotEmpty) {
    final (f, d, stateKey) = pq.removeFirst();
    if (d > (dist[stateKey] ?? double.infinity)) continue;
    if (f >= bestCost) break;

    final canTransport = (stateKey & 1) == 1;
    final temp = stateKey >> 1;
    final currentIndex = temp % n;
    final mask = temp ~/ n;

    // 完成条件
    if (mask == fullMask) {
      if (exitIndices.isEmpty || exitIndices.contains(currentIndex)) {
        bestCost = d;
        finalStateKey = stateKey;
        break;
      }
    }

    // 动作1：传送
    if (keyResourceBit != null && !canTransport && transportIndex != null) {
      if ((nodeResourceBit[currentIndex] & keyResourceBit) != 0) {
        final newMask = mask | nodeResourceBit[transportIndex];
        final newStateKey = encode(newMask, transportIndex, true);
        final nd = d;
        final cur = dist[newStateKey] ?? double.infinity;
        if (nd < cur) {
          final nh = heuristic(transportIndex, newMask, true);
          if (nd + nh < bestCost) {
            dist[newStateKey] = nd;
            prev[newStateKey] = stateKey;
            pq.add((nd + nh, nd, newStateKey));
          }
        }
      }
    }

    // 动作2：正常移动
    final stepCost =
    (keyResourceBit != null && !canTransport) ? 1.0 + urgency : 1.0;

    for (final v in adj[currentIndex]) {
      final newMask = mask | nodeResourceBit[v];
      final newStateKey = encode(newMask, v, canTransport);
      final nd = d + stepCost;
      final cur = dist[newStateKey] ?? double.infinity;
      if (nd < cur) {
        final nh = heuristic(v, newMask, canTransport);
        if (nd + nh < bestCost) {
          dist[newStateKey] = nd;
          prev[newStateKey] = stateKey;
          pq.add((nd + nh, nd, newStateKey));
        }
      }
    }
  }

  if (finalStateKey == null) return [];

  // 10. 回溯路径
  final pathIndices = <int>[];
  var curKey = finalStateKey;
  while (true) {
    final temp = curKey >> 1;
    final index = temp % n;
    pathIndices.add(index);
    if (curKey == startKey) break;
    final p = prev[curKey];
    if (p == null) break;
    curKey = p;
  }

  return pathIndices.reversed.map((i) => nodes[i]).toList();
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
