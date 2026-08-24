import 'package:flutter/rendering.dart' hide Layer;
import 'package:idv_map_guides/generated/rust/api/map.dart';

const outsideColor = Color(0xFF223344);
const corridorColor = Color(0xFF666666);
const roomColor = Color(0xFF665544);
const wallColor = Color(0xFF778899);
const doorColor = Color(0xFFFFDD33);
const holeColor = Color(0xFFFF6F61);
const stairGridColor = Color(0xFFBDBDBD);

final Paint outsidePaint = Paint()
  ..color = outsideColor;
final Paint corridorPaint = Paint()
  ..color = corridorColor;
final Paint roomPaint = Paint()
  ..color = roomColor;
final Paint wallPaint = Paint()
  ..color = wallColor
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.0;
final Paint doorPaint = Paint()
  ..color = doorColor
  ..strokeCap = StrokeCap.round
  ..strokeWidth = 3.0;
final Paint holePaint = Paint()
  ..color = holeColor
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeWidth = 2.0;
final Paint stairPaint = Paint()
  ..color = stairGridColor
  ..strokeWidth = 0.7;

void drawCell(Canvas canvas, Rect rect, bool isCorridor, bool isStair) {
  canvas.drawRect(rect, isCorridor ? corridorPaint : roomPaint);
  if (isStair) {
    const divisions = 4;
    for (int i = 1; i < divisions; i++) {
      final x = rect.left + rect.width * i / divisions;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        stairPaint,
      );
      final y = rect.top + rect.height * i / divisions;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        stairPaint,
      );
    }
  }
}

void drawWall(Canvas canvas, Rect rect, Direction direction) {
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
  canvas.drawLine(p1, p2, wallPaint);
}

void drawDoor(Canvas canvas, Rect rect, Direction direction, double cellW, double cellH) {
  final Offset p1;
  final Offset p2;
  switch (direction) {
    case Direction.north:
      p1 = Offset(rect.left + 0.2 * cellW, rect.top);
      p2 = Offset(rect.left + 0.8 * cellW, rect.top);
      break;
    case Direction.south:
      p1 = Offset(rect.left + 0.2 * cellW, rect.bottom);
      p2 = Offset(rect.left + 0.8 * cellW, rect.bottom);
      break;
    case Direction.east:
      p1 = Offset(rect.right, rect.top + 0.2 * cellH);
      p2 = Offset(rect.right, rect.top + 0.8 * cellH);
      break;
    case Direction.west:
      p1 = Offset(rect.left, rect.top + 0.2 * cellH);
      p2 = Offset(rect.left, rect.top + 0.8 * cellH);
      break;
  }
  canvas.drawLine(p1, p2, doorPaint);
}

void drawHole(Canvas canvas, Rect rect, Direction direction) {
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
    canvas.drawLine(p1, p2, holePaint);
  }
}

class MapPainter extends CustomPainter {
  final MapModel map;
  final Layer layer;

  MapPainter(this.map, this.layer);

  @override
  void paint(Canvas canvas, Size size) {
    final width = map.width.toInt();
    final height = map.height.toInt();

    final cellW = size.width / width;
    final cellH = size.height / height;
    final originX = map.minX;
    final originY = map.minY;

    canvas.drawRect(Offset.zero & size, outsidePaint);
    for (int dy = height - 1; dy >= 0; dy--) {
      for (int dx = 0; dx < width; dx++) {
        final wx = originX + dx;
        final wy = originY + dy;
        final cell = map.cell(layer: layer, x: wx, y: wy);
        switch (cell) {
          case null:
          case CellInfo_Empty():
            continue;
          case CellInfo_Structure(
              :final id,
              :final isCorridor,
              :final isStair,
          ):
            final rect = Rect.fromLTWH(dx * cellW, (height - dy - 1) * cellH, cellW, cellH);
            drawCell(canvas, rect, isCorridor, isStair);
            final doors = cell.getDirections(target: EdgeType.door);
            final holes = cell.getDirections(target: EdgeType.hole);
            final innerWalls = cell.getDirections(target: EdgeType.innerWall);
            for (final direction in Direction.values) {
              if (holes.contains(direction)) {
                continue;
              }
              final (dx, dy) = direction.dxy;
              final neighbor = map.cell(
                layer: layer,
                x: wx + dx,
                y: wy + dy,
              );
              final isBoundary = switch (neighbor) {
                null => true,
                CellInfo_Empty() => true,
                CellInfo_Structure(id: final neighborId) => id != neighborId,
              };
              final isInnerWall = innerWalls.contains(direction);
              if (isInnerWall || isBoundary) {
                drawWall(canvas, rect, direction);
              }
            }
            for (final door in doors) {
              drawDoor(canvas, rect, door, cellW, cellH);
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
