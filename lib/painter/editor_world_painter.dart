import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/painter/editor_structure_painter.dart';
import 'package:idv_map_guides/painter/world_painter.dart';

void drawStructureSelectedBoarder(Canvas canvas, Rect rect, Direction direction, double cellSize) {
  final Paint paint = Paint()
    ..color = selectedBorderColor
    ..strokeWidth = cellSize * 0.02;
  final Offset p1;
  final Offset p2;
  switch (direction) {
    case Direction.north:
      p1 = rect.topLeft;
      p2 = rect.topRight;
      break;
    case Direction.south:
      p1 = rect.bottomLeft;
      p2 = rect.bottomRight;
      break;
    case Direction.east:
      p1 = rect.topRight;
      p2 = rect.bottomRight;
      break;
    case Direction.west:
      p1 = rect.topLeft;
      p2 = rect.bottomLeft;
      break;
  }
  canvas.drawLine(p1, p2, paint);
}

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
    for (int x = world.minX; x <= world.maxX; x++) {
      for (int y = world.minY; y <= world.maxY; y++) {
        final cell = world.cell(layer, x, y)!;
        if (cell.id == null) continue;
        final rect = Rect.fromLTWH((x - world.minX) * cellSize, (world.maxY  - y) * cellSize, cellSize, cellSize);
        drawCell(canvas, rect, cell.isCorridor, cellSize);
        if (cell.info.isStair != null) {
          drawStair(canvas, rect, cell.info.isStair!, cellSize);
        }
// == Add Start ==
      }
    }
    drawGrid(canvas, world.width, world.height, cellSize);
    for (int x = world.minX; x <= world.maxX; x++) {
      for (int y = world.minY; y <= world.maxY; y++) {
        final cell = world.cell(layer, x, y)!;
        if (cell.id == null) continue;
        final rect = Rect.fromLTWH((x - world.minX) * cellSize, (world.maxY  - y) * cellSize, cellSize, cellSize);
// == Add End ==
        for (final direction in Direction.values) {
// == Add Start ==
          if (selectedStructure != null && cell.id == selectedStructure) {
            final (dx, dy) = direction.dxy;
            final neighbor = world.cell(layer, x + dx, y + dy);
            if (neighbor == null || neighbor.id != cell.id) {
              drawStructureSelectedBoarder(canvas, rect, direction, cellSize);
            }
          }
// == Add End ==
          switch (cell.info.getEdgeType(direction)) {
            case EdgeType.nothing:
              final (dx, dy) = direction.dxy;
              final neighbor = world.cell(layer, x + dx, y + dy);
              if (neighbor != null && neighbor.id != cell.id) {
                drawWall(canvas, rect, direction, cellSize);
              }
              break;
            case EdgeType.door:
              drawDoor(canvas, rect, direction, cellSize);
              break;
            case EdgeType.innerWall:
              drawWall(canvas, rect, direction, cellSize);
              break;
            case EdgeType.hole:
              drawHole(canvas, rect, direction, cellSize);
              break;
          }
        }
      }
    }
    for (final entry in world.entrances.entries) {
      final layer = entry.key.layer();
      if (layer == this.layer) {
        final entrance = entry.value;
        final rect = Rect.fromLTWH((entrance.x - world.minX) * cellSize, (world.maxY  - entrance.y) * cellSize, cellSize, cellSize);
        drawEntrance(canvas, rect, cellSize);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EditorWorldPainter oldDelegate) {
    return oldDelegate.world != world ||
        oldDelegate.layer != layer ||
        oldDelegate.selectedStructure != selectedStructure;
  }
}
