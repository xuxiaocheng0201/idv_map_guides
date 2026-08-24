import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/generated/rust/api/map.dart';
import 'package:idv_map_guides/pages/editors/structures_editor.dart';
import 'package:idv_map_guides/painter/map_painter.dart';

const gridColor = Color(0x44556677);
const selectedBorderColor = Color(0xFFFFD700);

final Paint gridPaint = Paint()
  ..color = gridColor
  ..strokeWidth = 0.5;
final Paint selectedBorderPaint = Paint()
  ..color = selectedBorderColor
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.0;

class StructureEditorPainter extends CustomPainter {
  final Structure structure;
  final int cellsWidth;
  final int cellsHeight;
  final Position? selectedCell;

  StructureEditorPainter({
    required this.structure,
    required this.cellsWidth,
    required this.cellsHeight,
    this.selectedCell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cellsWidth;
    final cellH = size.height / cellsHeight;

    canvas.drawRect(Offset.zero & size, outsidePaint);

    for (int x = 0; x <= cellsWidth; x++) {
      final dx = x * cellW;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (int y = 0; y <= cellsHeight; y++) {
      final dy = y * cellH;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    for (final position in structure.cells) {
      final gx = position.x;
      final gy = position.y;
      if (gx < 0 || cellsWidth <= gx || gy < 0 || cellsHeight <= gy) continue;

      final rect = Rect.fromLTWH(gx * cellW, (cellsHeight - gy - 1) * cellH, cellW, cellH);

      final isStair = getStairInfo(structure, position);
      drawCell(canvas, rect, structure.isCorridor, isStair);

      for (final direction in Direction.values) {
        final edgeType = getEdgeType(structure, position, direction);
        switch (edgeType) {
          case EdgeType.door:
            drawDoor(canvas, rect, direction, cellW, cellH);
            break;
          case EdgeType.innerWall:
            drawWall(canvas, rect, direction);
            break;
          case EdgeType.hole:
            drawHole(canvas, rect, direction);
            break;
          case EdgeType.nothing:
            break;
        }
      }

      if (selectedCell == position) {
        canvas.drawRect(rect, selectedBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StructureEditorPainter oldDelegate) {
    return oldDelegate.structure != structure || oldDelegate.cellsHeight != cellsHeight || oldDelegate.cellsWidth != cellsWidth || oldDelegate.selectedCell != selectedCell;
  }
}
