import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/main.dart';
import 'package:idv_map_guides/painter/path_drawer.dart';

// ============================================================
// 颜色常量
// ============================================================

// 地图
const backgroundColor = Color(0xFF223344);
const corridorColor = Color(0xFF666666);
const roomColor = Color(0xFF665544);
const wallColor = Color(0xFF778899);
const doorColor = Color(0xFFFFDD33);
const holeColor = Color(0xFFFF6666);
const stairColor = Color(0xFFBCBCFF);
const stairGridColor = Color(0xFFBDBDBD);
const entranceColor = Color(0xFF00CC55);
const suspiciousColor = Color(0xFFFF0066);
const resourceColor = Color(0xFFFF9900);
const selectedBorderColor = Color(0xFFFFD700);

// 编辑器
const gridColor = Color(0x44556677);
const double vertexHandleRadius = 12.0;
const Color outlineStrokeColor = Color(0xFFFFD700);
const Color selectedVertexColor = Color(0xFFFF8800);
const Color vertexColor = Color(0xFFFFD700);
const Color vertexBorderColor = Color(0x99000000);

// ============================================================
// 类型定义
// ============================================================

typedef CellRectFn = Rect Function(int x, int y);
typedef PointOffsetFn = Offset Function(double x, double y);

// ============================================================
// 基础图元
// ============================================================

void drawBackground(Canvas canvas, int width, int height, double cellSize) {
  final rect = Rect.fromLTWH(0, 0, width * cellSize, height * cellSize);
  canvas.drawRect(rect, Paint()..color = backgroundColor);
}

void drawCellPath(Canvas canvas, Path path, bool isCorridor, double cellSize, bool isSuspicious) {
  var color = isCorridor ? corridorColor : roomColor;
  if (editorMode.value && isSuspicious) {
    color = Color.alphaBlend(suspiciousColor.withValues(alpha: 0.2), color);
  }
  canvas.drawPath(path, Paint()..color = color);
}

void drawResource(Canvas canvas, Rect rect, double cellSize) {
  final fillPaint = Paint()
    ..color = resourceColor
    ..style = PaintingStyle.fill;
  final borderPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.01;
  final radius = cellSize * 0.14;
  canvas.drawCircle(rect.center, radius, fillPaint);
  canvas.drawCircle(rect.center, radius, borderPaint);
}

void drawStair(Canvas canvas, Rect rect, StairTransport stair, double cellSize) {
  final Paint gridPaint = Paint()
    ..color = stairGridColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.01;
  const divisions = 8;
  for (int i = 1; i < divisions; i++) {
    final x = rect.left + rect.width * i / divisions;
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    final y = rect.top + rect.height * i / divisions;
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
  }
  if (stair == StairTransport.nothing) return;
  final center = rect.center;
  final arrowSize = cellSize * 0.22;
  final arrowHeight = cellSize * 0.3;
  final paint = Paint()
    ..style = PaintingStyle.fill
    ..color = stairColor;
  final path = Path();
  if (stair == StairTransport.goUp) {
    path.moveTo(center.dx, center.dy - arrowHeight);
    path.lineTo(center.dx - arrowSize, center.dy + arrowHeight * 0.6);
    path.lineTo(center.dx + arrowSize, center.dy + arrowHeight * 0.6);
    path.close();
  } else {
    path.moveTo(center.dx, center.dy + arrowHeight);
    path.lineTo(center.dx - arrowSize, center.dy - arrowHeight * 0.6);
    path.lineTo(center.dx + arrowSize, center.dy - arrowHeight * 0.6);
    path.close();
  }
  canvas.drawPath(path, paint);
}

void drawEntrance(Canvas canvas, Rect rect, double cellSize) {
  final Paint paint = Paint()
    ..color = entranceColor
    ..style = PaintingStyle.fill;
  canvas.drawCircle(rect.center, cellSize * 0.3, paint);
}

// ============================================================
// 线段绘制
// ============================================================

void drawWallSegment(Canvas canvas, Offset p1, Offset p2, double cellSize) {
  final paint = Paint()
    ..color = wallColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.04;
  canvas.drawLine(p1, p2, paint);
}

void drawDoorSegment(Canvas canvas, Offset p1, Offset p2, double cellSize) {
  final paint = Paint()
    ..color = doorColor
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = cellSize * 0.02;
  canvas.drawLine(Offset.lerp(p1, p2, 0.2)!, Offset.lerp(p1, p2, 0.8)!, paint);
}

void drawHoleSegment(Canvas canvas, Offset p1, Offset p2, double cellSize) {
  final paint = Paint()
    ..color = holeColor
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = cellSize * 0.02;
  const dashCount = 8;
  final normalDash = cellSize / 2 / dashCount;
  final dash = List<double>.filled(dashCount + 1, normalDash);
  dash[0] = normalDash / 2;
  dash[dashCount] = normalDash / 2;
  double d = 0;
  for (final dl in dash) {
    canvas.drawLine(
      Offset.lerp(p1, p2, d / cellSize)!,
      Offset.lerp(p1, p2, (d + dl).clamp(0, cellSize) / cellSize)!,
      paint,
    );
    d += dl + normalDash;
  }
}

void drawStructureSelectedBorder(Canvas canvas, Offset p1, Offset p2, double cellSize) {
  final Paint paint = Paint()
    ..color = selectedBorderColor
    ..strokeWidth = cellSize * 0.02;
  canvas.drawLine(p1, p2, paint);
}

void drawCellSelectedBorder(Canvas canvas, Path path, double cellSize) {
  final Paint paint = Paint()
    ..color = selectedBorderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.02;
  canvas.drawPath(path, paint);
}

// ============================================================
// 几何工具
// ============================================================

(Offset, Offset) edgeSegment(Rect rect, Direction direction) {
  switch (direction) {
    case Direction.north: return (rect.topLeft, rect.topRight);
    case Direction.east:  return (rect.topRight, rect.bottomRight);
    case Direction.south: return (rect.bottomRight, rect.bottomLeft);
    case Direction.west:  return (rect.bottomLeft, rect.topLeft);
  }
}

Path buildStructureFillPathTransformed(PlacedStructure structured, PointOffsetFn pointOffset, CellRectFn cellRect) {
  final outline = structured.placedOutline;
  if (outline != null) {
    final points = outline.map((p) => pointOffset(p.x, p.y)).toList();
    if (points.length < 3) return Path();
    return Path()..addPolygon(points, true);
  }
  final path = Path();
  for (final p in structured.placedCells) {
    path.addRect(cellRect(p.x, p.y));
  }
  return path;
}

// ============================================================
// 网格
// ============================================================

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

// ============================================================
// 图层流程
// ============================================================

/// 结构填充
void paintLayerFills(
  Canvas canvas,
  World world,
  GroundLayer layer,
  double cellSize,
  PointOffsetFn pointOffset,
  CellRectFn cellRect, {
  Rect? clip,
}) {
  if (clip != null) {
    canvas.save();
    canvas.clipRect(clip);
  }
  for (final entry in world.structures.entries) {
    if (entry.value.layer != layer) continue;
    final path = buildStructureFillPathTransformed(entry.value, pointOffset, cellRect);
    if (path.getBounds().isEmpty) continue;
    drawCellPath(
      canvas,
      path,
      entry.value.structure.isCorridor,
      cellSize,
      world.suspiciousStructures.contains(entry.key),
    );
  }
  if (clip != null) canvas.restore();
}

/// 结构外轮廓（多边形外墙）
void paintLayerOutlines(
  Canvas canvas,
  World world,
  GroundLayer layer,
  double cellSize,
  PointOffsetFn pointOffset, {
  Rect? clip,
}) {
  if (clip != null) {
    canvas.save();
    canvas.clipRect(clip);
  }
  for (final entry in world.structures.entries) {
    if (entry.value.layer != layer) continue;
    final outline = entry.value.placedOutline;
    if (outline == null) continue;
    final points = outline.map((p) => pointOffset(p.x, p.y)).toList();
    if (points.length < 2) continue;
    for (int i = 0; i < points.length; i++) {
      drawWallSegment(canvas, points[i], points[(i + 1) % points.length], cellSize);
    }
  }
  if (clip != null) canvas.restore();
}

/// 单元格内的资源 / 楼梯
void paintLayerCellDecorations(
  Canvas canvas,
  World world,
  GroundLayer layer,
  double cellSize,
  CellRectFn cellRect,
  int minX,
  int maxX,
  int minY,
  int maxY, {
  bool Function(int x, int y)? shouldDrawResource,
  void Function(int x, int y, Rect rect)? onCell,
}) {
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= maxY; y++) {
      final cell = world.cell(layer, x, y);
      if (cell == null || cell.structureId == null) continue;
      final rect = cellRect(x, y);
      final drawRes = shouldDrawResource?.call(x, y) ?? cell.info.isResource;
      if (drawRes) drawResource(canvas, rect, cellSize);
      if (cell.info.isStair != null) {
        drawStair(canvas, rect, cell.info.isStair!, cellSize);
      }
      onCell?.call(x, y, rect);
    }
  }
}

/// 单个单元格四边（外墙 / 门 / 洞 / 内墙）（不处理多边形外墙）
void paintCellEdges(
  Canvas canvas,
  Rect rect,
  CellInfo info,
  double cellSize, {
  bool hasOutline = false,
  bool Function(Direction)? isBoundary,
}) {
  for (final direction in Direction.values) {
    final (p1, p2) = edgeSegment(rect, direction);
    final boundary = isBoundary?.call(direction) ?? false;
    switch (info.getEdgeType(direction)) {
      case EdgeType.nothing:
        if (!hasOutline && boundary) {
          drawWallSegment(canvas, p1, p2, cellSize);
        }
        break;
      case EdgeType.door:
        drawDoorSegment(canvas, p1, p2, cellSize);
        break;
      case EdgeType.innerWall:
        drawWallSegment(canvas, p1, p2, cellSize);
        break;
      case EdgeType.hole:
        drawHoleSegment(canvas, p1, p2, cellSize);
        break;
    }
  }
}

/// 单元格四边（外墙 / 门 / 洞 / 内墙）（不处理多边形外墙）
void paintLayerCellEdges(
  Canvas canvas,
  World world,
  GroundLayer layer,
  double cellSize,
  CellRectFn cellRect,
  int minX,
  int maxX,
  int minY,
  int maxY,
) {
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= maxY; y++) {
      final cell = world.cell(layer, x, y);
      if (cell == null || cell.structureId == null) continue;
      final rect = cellRect(x, y);
      final hasOutline = world.structures[cell.structureId!]?.structure.outline != null;
      paintCellEdges(
        canvas, rect, cell.info, cellSize,
        hasOutline: hasOutline,
        isBoundary: (d) {
          final (dx, dy) = d.dxy;
          final n = world.cell(layer, x + dx, y + dy);
          return n == null || n.structureId != cell.structureId;
        },
      );
    }
  }
}

/// 入口
void paintLayerEntrances(
  Canvas canvas,
  World world,
  GroundLayer layer,
  double cellSize,
  CellRectFn cellRect,
  int minX,
  int maxX,
  int minY,
  int maxY,
) {
  for (final entry in world.entrances.entries) {
    if (entry.key.layer != layer || !entry.key.displayable) continue;
    final entrance = entry.value;
    if (entrance.x < minX || entrance.x > maxX || entrance.y < minY || entrance.y > maxY) {
      continue;
    }
    drawEntrance(canvas, cellRect(entrance.x, entrance.y), cellSize);
  }
}

/// 选中结构边框
void paintLayerSelectedBorders(
  Canvas canvas,
  World world,
  GroundLayer layer,
  double cellSize,
  CellRectFn cellRect,
  int minX,
  int maxX,
  int minY,
  int maxY, {
  required int selectedStructure,
}) {
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= maxY; y++) {
      final cell = world.cell(layer, x, y);
      if (cell == null || cell.structureId != selectedStructure) continue;
      final rect = cellRect(x, y);
      for (final direction in Direction.values) {
        final (dx, dy) = direction.dxy;
        final n = world.cell(layer, x + dx, y + dy);
        if (n == null || n.structureId != selectedStructure) {
          final (p1, p2) = edgeSegment(rect, direction);
          drawStructureSelectedBorder(canvas, p1, p2, cellSize);
        }
      }
    }
  }
}
