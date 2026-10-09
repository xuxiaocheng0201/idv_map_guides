import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/painter/painter_common.dart';

class EditorWorldPainter extends CustomPainter {
  final World world;
  final GroundLayer layer;
  final int? selectedStructure;

  EditorWorldPainter({
    required this.world,
    required this.layer,
    this.selectedStructure,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = min(size.width / world.width, size.height / world.height);
    drawBackground(canvas, world.width, world.height, cellSize);

    Offset pointOffset(double x, double y) =>
        Offset((x - world.minX) * cellSize, (world.maxY - y + 1) * cellSize);
    Rect cellRect(int x, int y) =>
        Rect.fromLTWH((x - world.minX) * cellSize, (world.maxY - y) * cellSize, cellSize, cellSize);

    paintLayerFills(canvas, world, layer, cellSize, pointOffset, cellRect);
    drawGrid(canvas, world.width, world.height, cellSize);
    paintLayerOutlines(canvas, world, layer, cellSize, pointOffset);
    paintLayerCellEdges(
      canvas, world, layer, cellSize, cellRect,
      world.minX, world.maxX, world.minY, world.maxY,
    );
    paintLayerCellDecorations(
      canvas, world, layer, cellSize, cellRect,
      world.minX, world.maxX, world.minY, world.maxY,
    );
    paintLayerEntrances(
      canvas, world, layer, cellSize, cellRect,
      world.minX, world.maxX, world.minY, world.maxY,
    );
    if (selectedStructure != null) {
      paintLayerSelectedBorders(
        canvas, world, layer, cellSize, cellRect,
        world.minX, world.maxX, world.minY, world.maxY,
        selectedStructure: selectedStructure!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EditorWorldPainter oldDelegate) {
    return oldDelegate.world != world ||
        oldDelegate.layer != layer ||
        oldDelegate.selectedStructure != selectedStructure;
  }
}
