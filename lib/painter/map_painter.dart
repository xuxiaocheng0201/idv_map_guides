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
const stairGridColor = Color(0xFFBDBDBD);

void drawBackground(Canvas canvas, int width, int height, double cellSize) {
  final rect = Rect.fromLTWH(0, 0, width * cellSize, height * cellSize);
  canvas.drawRect(rect, Paint()..color = backgroundColor);
}

void drawCell(Canvas canvas, Rect rect, bool isCorridor, double cellSize) {
  canvas.drawRect(rect, Paint()..color = isCorridor ? corridorColor : roomColor);
}

void drawStair(Canvas canvas, Rect rect, StairTransport stair, double cellSize) {
  final Paint paint = Paint()
    ..color = stairGridColor
    ..strokeWidth = cellSize * 0.01;
  const divisions = 8;
  for (int i = 1; i < divisions; i++) {
    final x = rect.left + rect.width * i / divisions;
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    final y = rect.top + rect.height * i / divisions;
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
  }
}

void drawWall(Canvas canvas, Rect rect, Direction direction, double cellSize) {
  final Paint paint = Paint()
    ..color = wallColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.01;
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

void drawDoor(Canvas canvas, Rect rect, Direction direction, double cellSize) {
  final Paint paint = Paint()
    ..color = doorColor
    ..strokeCap = StrokeCap.round
    ..strokeWidth = cellSize * 0.02;
  final Offset p1;
  final Offset p2;
  switch (direction) {
    case Direction.north:
      p1 = Offset(rect.left + 0.2 * cellSize, rect.top);
      p2 = Offset(rect.left + 0.8 * cellSize, rect.top);
      break;
    case Direction.south:
      p1 = Offset(rect.left + 0.2 * cellSize, rect.bottom);
      p2 = Offset(rect.left + 0.8 * cellSize, rect.bottom);
      break;
    case Direction.east:
      p1 = Offset(rect.right, rect.top + 0.2 * cellSize);
      p2 = Offset(rect.right, rect.top + 0.8 * cellSize);
      break;
    case Direction.west:
      p1 = Offset(rect.left, rect.top + 0.2 * cellSize);
      p2 = Offset(rect.left, rect.top + 0.8 * cellSize);
      break;
  }
  canvas.drawLine(p1, p2, paint);
}

void drawHole(Canvas canvas, Rect rect, Direction direction, double cellSize) {
  final Paint paint = Paint()
    ..color = holeColor
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = cellSize * 0.01;
  const dashWidth = 4.0;
  const dashSpace = 3.0;
  double startX, startY, endX, endY;
  switch (direction) {
    case Direction.north:
      startX = rect.left;
      startY = rect.top;
      endX = rect.right;
      endY = rect.top;
      break;
    case Direction.south:
      startX = rect.left;
      startY = rect.bottom;
      endX = rect.right;
      endY = rect.bottom;
      break;
    case Direction.east:
      startX = rect.right;
      startY = rect.top;
      endX = rect.right;
      endY = rect.bottom;
      break;
    case Direction.west:
      startX = rect.left;
      startY = rect.top;
      endX = rect.left;
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

class MapPainter extends CustomPainter {
  final World map;
  final GroundLayer layer;

  MapPainter(this.map, this.layer);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = min(size.width / map.width, size.height / map.height);
    drawBackground(canvas, map.width, map.height, cellSize);
    for (int x = map.minX; x <= map.maxX; x++) {
      for (int y = map.minY; y <= map.maxY; y++) {
        final cell = map.cell(layer, x, y)!;
        if (cell.id == null) continue;
        final rect = Rect.fromLTWH((x - map.minX) * cellSize, (map.maxY  - y) * cellSize, cellSize, cellSize);
        drawCell(canvas, rect, cell.isCorridor, cellSize);
        if (cell.info.isStair != null) {
          drawStair(canvas, rect, cell.info.isStair!, cellSize);
        }
        for (final direction in Direction.values) {
          switch (cell.info.getEdgeType(direction)) {
            case EdgeType.nothing:
              final (dx, dy) = direction.dxy;
              final neighbor = map.cell(layer, x + dx, y + dy);
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
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return oldDelegate.map != map || oldDelegate.layer != layer;
  }
}
