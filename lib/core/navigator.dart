import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';

part 'navigator.freezed.dart';

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

  // 资源已细化到 cell 级：普通资源为 Node（单元格），关键资源 id 仍为结构 id（int）
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
  final fullMask = (1 << k) - 1; // 所有资源收集完成的掩码

  // 4. 每个节点对应的资源位掩码：
  //    - cell 级资源按节点（Node）判断；
  //    - 关键资源仍按结构 id 判断（进入该结构的任意单元格即可拾取）。
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
    if (bit == null) return []; // 理论上不会发生
    keyResourceBit = 1 << bit;
    urgency = keyResource.urgency;
    transportIndex = nodeToIndex[keyResource.transport];
    if (transportIndex == null) return [];
  }

  // 7. 状态编码：stateKey = (mask * n + currentIndex) * 2 + (canTransport ? 1 : 0)
  int encode(int mask, int index, bool canTransport) {
    return ((mask * n + index) << 1) | (canTransport ? 1 : 0);
  }

  // 8. 初始状态
  final startMask = nodeResourceBit[startIndex];
  final startKey = encode(startMask, startIndex, false);

  final dist = <int, double>{startKey: 0.0};
  final prev = <int, int>{};

  final pq = HeapPriorityQueue<(double, int)>(
        (a, b) => a.$1.compareTo(b.$1),
  );
  pq.add((0.0, startKey));

  int? finalStateKey;

  // 9. 状态压缩 Dijkstra
  while (pq.isNotEmpty) {
    final (d, stateKey) = pq.removeFirst();
    if (d > (dist[stateKey] ?? double.infinity)) continue;

    // 解码状态
    final canTransport = (stateKey & 1) == 1;
    final temp = stateKey >> 1;
    final currentIndex = temp % n;
    final mask = temp ~/ n;

    // 完成条件：收集全部资源，且满足出口要求
    if (mask == fullMask) {
      if (exitIndices.isEmpty || exitIndices.contains(currentIndex)) {
        finalStateKey = stateKey;
        break;
      }
    }

    // 动作1：传送（仅当当前在关键资源点、未使用传送、且存在传送目标）
    if (keyResourceBit != null && !canTransport && transportIndex != null) {
      if ((nodeResourceBit[currentIndex] & keyResourceBit) != 0) {
        final newMask = mask | nodeResourceBit[transportIndex];
        final newStateKey = encode(newMask, transportIndex, true);
        final cur = dist[newStateKey] ?? double.infinity;
        if (d < cur) {
          dist[newStateKey] = d;
          prev[newStateKey] = stateKey;
          pq.add((d, newStateKey));
        }
      }
    }

    // 动作2：正常移动
    final keyCollected = keyResourceBit == null || (mask & keyResourceBit) != 0;
    final stepCost = keyCollected ? 1.0 : 1.0 + urgency;

    for (final v in adj[currentIndex]) {
      final newMask = mask | nodeResourceBit[v];
      final newStateKey = encode(newMask, v, canTransport);
      final nd = d + stepCost;
      final cur = dist[newStateKey] ?? double.infinity;
      if (nd < cur) {
        dist[newStateKey] = nd;
        prev[newStateKey] = stateKey;
        pq.add((nd, newStateKey));
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
