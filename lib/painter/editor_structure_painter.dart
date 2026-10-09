import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/painter/painter_common.dart';

class EditorStructurePainter extends CustomPainter {
  final Structure structure;
  final int width;
  final int height;
  final bool editingOutline;
  final Position? selectedCell;
  final int? selectedVertexIndex;
  final bool showOriginalCells;

  EditorStructurePainter({
    required this.structure,
    required this.width,
    required this.height,
    this.editingOutline = false,
    this.selectedCell,
    this.selectedVertexIndex,
    this.showOriginalCells = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = min(size.width / width, size.height / height);
    drawBackground(canvas, width, height, cellSize);

    Offset pointOffset(double x, double y) =>
        Offset(x * cellSize, (height - y) * cellSize);
    Rect cellRect(int x, int y) =>
        Rect.fromLTWH(x * cellSize, (height - 1 - y) * cellSize, cellSize, cellSize);

    final structured = PlacedStructure(
      structure: structure,
      layer: GroundLayer.ground,
      originX: 0,
      originY: 0,
      rotation: Rotation.cw0,
      isSuspicious: false,
    );
    final outlinePoints = structure.outline?.map((p) => pointOffset(p.x, p.y)).toList() ?? <Offset>[];
    final hasOutline = outlinePoints.length >= 3;

    // 填充
    final outline = buildStructureFillPathTransformed(structured, pointOffset, cellRect);
    if (!outline.getBounds().isEmpty) {
      drawCellPath(canvas, outline, structure.isCorridor, cellSize, false);
    }
    if (showOriginalCells && hasOutline) {
      final baseColor = suspiciousColor;
      final cellFill = Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor.withValues(alpha: 0.1);
      for (final p in structured.placedCells) {
        final r = cellRect(p.x, p.y);
        canvas.drawRect(r, cellFill);
      }
    }
    // 资源 / 楼梯
    for (final entry in structure.cells.entries) {
      final rect = cellRect(entry.key.x, entry.key.y);
      if (entry.value.isResource) drawResource(canvas, rect, cellSize);
      if (entry.value.isStair != null) drawStair(canvas, rect, entry.value.isStair!, cellSize);
    }
    // 网格
    drawGrid(canvas, width, height, cellSize);
    // 选中 cell 边框
    if (selectedCell != null) {
      final rect = cellRect(selectedCell!.x, selectedCell!.y);
      drawCellSelectedBorder(canvas, Path()..addRect(rect), cellSize);
    }
    // 门 / 洞 / 内墙
    for (final entry in structure.cells.entries) {
      paintCellEdges(
        canvas, cellRect(entry.key.x, entry.key.y), entry.value, cellSize,
        hasOutline: hasOutline,
      );
    }
    // 轮廓编辑叠加层
    if (editingOutline && outlinePoints.isNotEmpty) {
      if (outlinePoints.length >= 2) {
        final stroke = Paint()
          ..color = outlineStrokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.02
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final closed = outlinePoints.length >= 3;
        final segCount = closed ? outlinePoints.length : outlinePoints.length - 1;
        for (int i = 0; i < segCount; i++) {
          canvas.drawLine(outlinePoints[i], outlinePoints[(i + 1) % outlinePoints.length], stroke);
        }
      }
      final fill = Paint()..style = PaintingStyle.fill;
      final border = Paint()
        ..color = vertexBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (int i = 0; i < outlinePoints.length; i++) {
        final selected = i == selectedVertexIndex;
        fill.color = selected ? selectedVertexColor : vertexColor;
        canvas.drawCircle(outlinePoints[i], vertexHandleRadius * 0.5, fill);
        canvas.drawCircle(outlinePoints[i], vertexHandleRadius * 0.5, border);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EditorStructurePainter oldDelegate) {
    return oldDelegate.structure != structure ||
        oldDelegate.height != height ||
        oldDelegate.width != width ||
        oldDelegate.selectedCell != selectedCell ||
        oldDelegate.selectedVertexIndex != selectedVertexIndex;
  }
}
