import 'package:flutter/rendering.dart' hide Layer;
import 'package:idv_map_guides/generated/rust/api/map.dart';

const outsideColor = Color(0xFF223344);
const corridorColor = Color(0xFF666666);
const roomColor = Color(0xFF665544);
const wallColor = Color(0xFF778899);
const doorColor = Color(0xFFFFDD33);
const stairGridColor = Color(0xFFBDBDBD);

class MapPainter extends CustomPainter {
  final MapModel map;
  final Layer layer;

  MapPainter(this.map, this.layer);

  static final Paint _outsidePaint = Paint()
    ..color = outsideColor;
  static final Paint _corridorPaint = Paint()
    ..color = corridorColor;
  static final Paint _roomPaint = Paint()
    ..color = roomColor;
  static final Paint _wallPaint = Paint()
    ..color = wallColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final Paint _doorPaint = Paint()
    ..color = doorColor
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3.0;
  static final Paint _stairGridPaint = Paint()
    ..color = stairGridColor
    ..strokeWidth = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final width = map.width.toInt();
    final height = map.height.toInt();
    final cellW = size.width / width;
    final cellH = size.height / height;
    final originX = map.minX;
    final originY = map.minY;

    // Background
    canvas.drawRect(Offset.zero & size, _outsidePaint);
    // Cell
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
              :final isCorridor,
              :final isStair,
          ):
            final rect = Rect.fromLTWH(dx * cellW, (height - dy - 1) * cellH, cellW, cellH);
            _drawCell(canvas, rect, isCorridor, isStair);
        }
      }
    }
    // Wall
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
              :final innerWalls,
              :final holes,
          ):
            final rect = Rect.fromLTWH(dx * cellW, (height - dy - 1) * cellH, cellW, cellH);
            for (final direction in Direction.values) {
              if (holes.contains(direction)) {
                continue;
              }
              final neighbor = map.cell(
                layer: layer,
                x: wx + direction.dx,
                y: wy + direction.dy,
              );
              final isBoundary = switch (neighbor) {
                null => true,
                CellInfo_Empty() => true,
                CellInfo_Structure(id: final neighborId) => id != neighborId,
              };
              final isInnerWall = innerWalls.contains(direction);
              if (isInnerWall || isBoundary) {
                _drawWall(canvas, rect, direction);
              }
            }
        }
      }
    }
    // Door
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
              :final doors,
          ):
            final rect = Rect.fromLTWH(dx * cellW, (height - dy - 1) * cellH, cellW, cellH);
            for (final door in doors) {
              _drawDoor(canvas, rect, door, cellW, cellH);
            }
        }
      }
    }
  }

  void _drawCell(Canvas canvas, Rect rect, bool isCorridor, bool isStair) {
    canvas.drawRect(rect, isCorridor ? _corridorPaint : _roomPaint);
    if (isStair) {
      const divisions = 4;
      for (int i = 1; i < divisions; i++) {
        final x = rect.left + rect.width * i / divisions;
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x, rect.bottom),
          _stairGridPaint,
        );
        final y = rect.top + rect.height * i / divisions;
        canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          _stairGridPaint,
        );
      }
    }
  }

  void _drawWall(Canvas canvas, Rect rect, Direction direction) {
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
    canvas.drawLine(p1, p2, _wallPaint);
  }

  void _drawDoor(Canvas canvas, Rect rect, Direction direction, double cellW, double cellH) {
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
    canvas.drawLine(p1, p2, _doorPaint);
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return oldDelegate.map != map || oldDelegate.layer != layer;
  }
}
