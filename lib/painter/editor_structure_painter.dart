import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/painter/world_painter.dart';

const gridColor = Color(0x44556677);
const selectedBorderColor = Color(0xFFFFD700);

void drawGrid(Canvas canvas, int width, int height, double cellSize) {
  final Paint paint = Paint()
    ..color = gridColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.01;
  for (int x = 0; x <= width; x++) {
    final dx = x * cellSize;
    canvas.drawLine(Offset(dx, 0), Offset(dx, height * cellSize), paint);
  }
  for (int y = 0; y <= height; y++) {
    final dy = y * cellSize;
    canvas.drawLine(Offset(0, dy), Offset(width * cellSize, dy), paint);
  }
}

void drawCellSelectedBorder(Canvas canvas, Rect rect, double cellSize) {
  final Paint paint = Paint()
    ..color = selectedBorderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.02;
  canvas.drawRect(rect, paint);
}

class EditorStructurePainter extends CustomPainter {
  final Structure structure;
  final int width;
  final int height;
  final Position? selectedCell;

  EditorStructurePainter({
    required this.structure,
    required this.width,
    required this.height,
    this.selectedCell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = min(size.width / width, size.height / height);
    drawBackground(canvas, width, height, cellSize);
    for (final entry in structure.cells.entries) {
      final (position, info) = (entry.key, entry.value);
      final rect = Rect.fromLTWH(position.x * cellSize, (height - position.y - 1) * cellSize, cellSize, cellSize);
      drawCell(canvas, rect, structure.isCorridor, cellSize, false);
      if (info.isStair != null) {
        drawStair(canvas, rect, info.isStair!, cellSize);
      }
    }
    drawGrid(canvas, width, height, cellSize);
    if (selectedCell != null) {
      final rect = Rect.fromLTWH(selectedCell!.x * cellSize, (height - selectedCell!.y - 1) * cellSize, cellSize, cellSize);
      drawCellSelectedBorder(canvas, rect, cellSize);
    }
    for (final entry in structure.cells.entries) {
      final (position, info) = (entry.key, entry.value);
      final rect = Rect.fromLTWH(position.x * cellSize, (height - position.y - 1) * cellSize, cellSize, cellSize);
      for (final direction in Direction.values) {
        switch (info.getEdgeType(direction)) {
          case EdgeType.nothing:
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

  @override
  bool shouldRepaint(covariant EditorStructurePainter oldDelegate) {
    return oldDelegate.structure != structure ||
        oldDelegate.height != height ||
        oldDelegate.width != width ||
        oldDelegate.selectedCell != selectedCell;
  }
}
