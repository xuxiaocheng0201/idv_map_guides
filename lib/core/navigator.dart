import 'dart:collection';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';

part 'navigator.freezed.dart';

@freezed
abstract class Node with _$Node {
  Node._();
  factory Node(GroundLayer layer, int x, int y) = _Node;
}

List<Node> navigate(World world, Node start, Set<int> resources) {
  // Collect node list.
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

  // Build directed adjacency list.
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

  // Collect resources id.
  final resourceNodes = <int, Set<int>>{};
  for (var i = 0; i < n; i++) {
    final node = nodes[i];
    final cell = world.cell(node.layer, node.x, node.y)!;
    final sid = cell.structureId!;
    if (resources.contains(sid)) {
      resourceNodes.putIfAbsent(sid, () => <int>{}).add(i);
    }
  }
  // Collect exit id.
  final exitIndices = <int>{};
  for (final entry in world.entrances.entries) {
    final layer = entry.key.layer();
    final pos = entry.value;
    final node = Node(layer, pos.x, pos.y);
    final idx = nodeToIndex[node];
    if (idx != null) exitIndices.add(idx);
  }

  // BFS
  (int, List<int>)? bfsToNearest(int from, Set<int> targets) {
    if (targets.isEmpty) return null;
    if (targets.contains(from)) return (from, [from]);
    final prev = List.filled(n, -1);
    final visited = List.filled(n, false);
    final queue = Queue<int>()..add(from);
    visited[from] = true;
    while (queue.isNotEmpty) {
      final u = queue.removeFirst();
      for (final v in adj[u]) {
        if (visited[v]) continue;
        visited[v] = true;
        prev[v] = u;
        if (targets.contains(v)) {
          final path = <int>[v];
          var x = v;
          while (x != from) {
            x = prev[x];
            path.add(x);
          }
          return (v, path.reversed.toList());
        }
        queue.addLast(v);
      }
    }
    return null;
  }

  // Greedy access resource.
  final visitedResources = <int>{};
  final pathIndices = <int>[];
  var currentIndex = startIndex;
  pathIndices.add(currentIndex);
  while (true) {
    final remainingTargets = <int>{};
    for (final entry in resourceNodes.entries) {
      if (visitedResources.contains(entry.key)) continue;
      remainingTargets.addAll(entry.value);
    }
    if (remainingTargets.isEmpty) break;
    final result = bfsToNearest(currentIndex, remainingTargets);
    if (result == null) break;
    final (target, path) = result;
    pathIndices.addAll(path.skip(1));
    currentIndex = target;
    final cell = world.cell(nodes[currentIndex].layer, nodes[currentIndex].x, nodes[currentIndex].y)!;
    visitedResources.add(cell.structureId!);
  }
  // access exit.
  final exitResult = bfsToNearest(currentIndex, exitIndices);
  if (exitResult == null) return [];
  final (_, exitPath) = exitResult;
  pathIndices.addAll(exitPath.skip(1));

  // Return path.
  return pathIndices.map((i) => nodes[i]).toList();
}
