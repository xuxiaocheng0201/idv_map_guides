import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';

const backgroundColor = Color(0xFF223344);
const corridorColor = Color(0xFF666666);
const roomColor = Color(0xFF665544);
const wallColor = Color(0xFF778899);
const doorColor = Color(0xFFFFDD33);
const holeColor = Color(0xFFFF6F61);
const stairColor = Color(0xFFBCBCFF);
const stairGridColor = Color(0xFFBDBDBD);
const entranceColor = Color(0xFF00CC55);

void drawBackground(Canvas canvas, int width, int height, double cellSize) {
  final rect = Rect.fromLTWH(0, 0, width * cellSize, height * cellSize);
  canvas.drawRect(rect, Paint()..color = backgroundColor);
}

void drawCell(Canvas canvas, Rect rect, bool isCorridor, double cellSize) {
  canvas.drawRect(rect, Paint()..color = isCorridor ? corridorColor : roomColor);
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

void drawWall(Canvas canvas, Rect rect, Direction direction, double cellSize) {
  final Paint paint = Paint()
    ..color = wallColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.04;
  final double inset = paint.strokeWidth / 2;
  final Offset p1;
  final Offset p2;
  switch (direction) {
    case Direction.north:
      p1 = rect.topLeft + Offset(0, inset);
      p2 = rect.topRight + Offset(0, inset);
      break;
    case Direction.south:
      p1 = rect.bottomLeft - Offset(0, inset);
      p2 = rect.bottomRight - Offset(0, inset);
      break;
    case Direction.east:
      p1 = rect.topRight - Offset(inset, 0);
      p2 = rect.bottomRight - Offset(inset, 0);
      break;
    case Direction.west:
      p1 = rect.topLeft + Offset(inset, 0);
      p2 = rect.bottomLeft + Offset(inset, 0);
      break;
  }
  canvas.drawLine(p1, p2, paint);
}

void drawDoor(Canvas canvas, Rect rect, Direction direction, double cellSize) {
  final Paint paint = Paint()
    ..color = doorColor
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = cellSize * 0.02;
  final double inset = paint.strokeWidth / 2;
  final Offset p1;
  final Offset p2;
  switch (direction) {
    case Direction.north:
      p1 = Offset(rect.left + 0.2 * cellSize, rect.top + inset);
      p2 = Offset(rect.left + 0.8 * cellSize, rect.top + inset);
      break;
    case Direction.south:
      p1 = Offset(rect.left + 0.2 * cellSize, rect.bottom - inset);
      p2 = Offset(rect.left + 0.8 * cellSize, rect.bottom - inset);
      break;
    case Direction.east:
      p1 = Offset(rect.right - inset, rect.top + 0.2 * cellSize);
      p2 = Offset(rect.right - inset, rect.top + 0.8 * cellSize);
      break;
    case Direction.west:
      p1 = Offset(rect.left + inset, rect.top + 0.2 * cellSize);
      p2 = Offset(rect.left + inset, rect.top + 0.8 * cellSize);
      break;
  }
  canvas.drawLine(p1, p2, paint);
}

void drawHole(Canvas canvas, Rect rect, Direction direction, double cellSize) {
  final Paint paint = Paint()
    ..color = holeColor
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = cellSize * 0.02;
  final double inset = paint.strokeWidth / 2;
  const dashWidth = 4.0;
  const dashSpace = 3.0;
  double startX, startY, endX, endY;
  switch (direction) {
    case Direction.north:
      startX = rect.left;
      startY = rect.top + inset;
      endX = rect.right;
      endY = rect.top + inset;
      break;
    case Direction.south:
      startX = rect.left;
      startY = rect.bottom - inset;
      endX = rect.right;
      endY = rect.bottom - inset;
      break;
    case Direction.east:
      startX = rect.right - inset;
      startY = rect.top;
      endX = rect.right - inset;
      endY = rect.bottom;
      break;
    case Direction.west:
      startX = rect.left + inset;
      startY = rect.top;
      endX = rect.left + inset;
      endY = rect.bottom;
      break;
  }
  final total = (endX - startX).abs() + (endY - startY).abs();
  final steps = (total / (dashWidth + dashSpace)).floor();
  for (int i = 0; i < steps; i++) {
    final t1 = (i * (dashWidth + dashSpace)) / total;
    final t2 = ((i * (dashWidth + dashSpace)) + dashWidth) / total;
    final p1 = Offset(startX + (endX - startX) * t1, startY + (endY - startY) * t1);
    final p2 = Offset(startX + (endX - startX) * t2, startY + (endY - startY) * t2);
    canvas.drawLine(p1, p2, paint);
  }
}

void drawEntrance(Canvas canvas, Rect rect, double cellSize) {
  final Paint paint = Paint()
    ..color = entranceColor
    ..style = PaintingStyle.fill;
  final Offset center = rect.center;
  final double radius = cellSize * 0.3;
  canvas.drawCircle(center, radius, paint);
}

class WorldPainter extends CustomPainter {
  final World world;
  final GroundLayer layer;

  WorldPainter({required this.world, required this.layer});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = min(size.width / world.width, size.height / world.height);
    drawBackground(canvas, world.width, world.height, cellSize);
    final entrances = world.entrances[layer] ?? <Position>{};
    for (int x = world.minX; x <= world.maxX; x++) {
      for (int y = world.minY; y <= world.maxY; y++) {
        final cell = world.cell(layer, x, y)!;
        if (cell.id == null) continue;
        final rect = Rect.fromLTWH((x - world.minX) * cellSize, (world.maxY  - y) * cellSize, cellSize, cellSize);
        drawCell(canvas, rect, cell.isCorridor, cellSize);
        if (cell.info.isStair != null) {
          drawStair(canvas, rect, cell.info.isStair!, cellSize);
        }
        for (final direction in Direction.values) {
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
    for (final entrance in entrances) {
      final rect = Rect.fromLTWH((entrance.x - world.minX) * cellSize, (world.maxY  - entrance.y) * cellSize, cellSize, cellSize);
      drawEntrance(canvas, rect, cellSize);
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) {
    return oldDelegate.world != world || oldDelegate.layer != layer;
  }
}
