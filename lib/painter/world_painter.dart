import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/painter/painter_common.dart';
import 'package:idv_map_guides/painter/path_drawer.dart';

class WorldPainter extends CustomPainter {
  final World world;
  final GroundLayer layer;
  Set<Node> resources = const <Node>{};
  List<Node> path = [];
  List<Node> path2 = [];

  final int minX;
  final int maxX;
  final int minY;
  final int maxY;

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;

  WorldPainter({
    required this.world,
    required this.layer,
    int? minX,
    int? maxX,
    int? minY,
    int? maxY,
    int padding = 1,
  }): minX = (minX ?? world.minX) - padding,
      maxX = (maxX ?? world.maxX) + padding,
      minY = (minY ?? world.minY) - padding,
      maxY = (maxY ?? world.maxY) + padding;

  factory WorldPainter.auto({
    required World world,
    required GroundLayer layer,
    int padding = 1,
  }) {
    int? contentMinX, contentMaxX, contentMinY, contentMaxY;
    for (int x = world.minX; x <= world.maxX; x++) {
      for (int y = world.minY; y <= world.maxY; y++) {
        final cell = world.cell(layer, x, y);
        if (cell != null && cell.structureId != null) {
          contentMinX = contentMinX == null ? x : min(contentMinX, x);
          contentMaxX = contentMaxX == null ? x : max(contentMaxX, x);
          contentMinY = contentMinY == null ? y : min(contentMinY, y);
          contentMaxY = contentMaxY == null ? y : max(contentMaxY, y);
        }
      }
    }
    return WorldPainter(
      world: world,
      layer: layer,
      minX: (contentMinX ?? world.minX) - padding,
      maxX: (contentMaxX ?? world.maxX) + padding,
      minY: (contentMinY ?? world.minY) - padding,
      maxY: (contentMaxY ?? world.maxY) + padding,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = min(size.width / width, size.height / height);
    drawBackground(canvas, width, height, cellSize);

    Offset pointOffset(double x, double y) =>
        Offset((x - minX) * cellSize, (maxY - y + 1) * cellSize);
    Rect cellRect(int x, int y) =>
        Rect.fromLTWH((x - minX) * cellSize, (maxY - y) * cellSize, cellSize, cellSize);

    paintLayerFills(canvas, world, layer, cellSize, pointOffset, cellRect);
    paintLayerOutlines(canvas, world, layer, cellSize, pointOffset);
    paintLayerCellEdges(canvas, world, layer, cellSize, cellRect, minX, maxX, minY, maxY);
    paintLayerCellDecorations(
      canvas, world, layer, cellSize, cellRect, minX, maxX, minY, maxY,
      shouldDrawResource: (x, y) => resources.contains(Node(layer, x, y)),
    );
    paintLayerEntrances(canvas, world, layer, cellSize, cellRect, minX, maxX, minY, maxY);

    paintPath(canvas, cellSize, path2, layer, _cellCenter, path2Color);
    paintPath(canvas, cellSize, path, layer, _cellCenter, pathColor);
  }

  Offset _cellCenter(int x, int y, double cellSize) => Offset((x - minX + 0.5) * cellSize, (maxY - y + 0.5) * cellSize);

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) {
    return oldDelegate.world != world ||
        oldDelegate.layer != layer ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        !setEquals(oldDelegate.resources, resources) ||
        !listEquals(oldDelegate.path, path);
  }
}
