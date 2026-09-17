import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';

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
const pathColor = Color(0xFF00EEFF);
const pathStartColor = Color(0xFF00DD77);
const pathEndColor = Color(0xFFFF3399);
const pathMarkerColor = Color(0xFFFFFFFF);

void drawBackground(Canvas canvas, int width, int height, double cellSize) {
  final rect = Rect.fromLTWH(0, 0, width * cellSize, height * cellSize);
  canvas.drawRect(rect, Paint()..color = backgroundColor);
}

void drawCell(Canvas canvas, Rect rect, bool isCorridor, double cellSize, bool isSuspicious) {
  var color = isCorridor ? corridorColor : roomColor;
  if (kDebugMode && isSuspicious) {
    color = Color.alphaBlend(suspiciousColor.withValues(alpha: 0.2), color);
  }
  canvas.drawRect(rect, Paint()..color = color);
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

void drawWall(Canvas canvas, Rect rect, Direction direction, double cellSize) {
  final Paint paint = Paint()
    ..color = wallColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.04;
  final inset = paint.strokeWidth / 2;
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
  final inset = paint.strokeWidth / 2;
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
  const dashCount = 8;
  final inset = paint.strokeWidth / 2;
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
  final normalDashLength = cellSize / 2.0 / dashCount;
  final halfDashLength = normalDashLength / 2.0;

  final dashLengths = List<double>.filled(dashCount + 1, normalDashLength);
  dashLengths[0] = halfDashLength;
  dashLengths[dashCount + 1 - 1] = halfDashLength;

  double currentDistance = 0.0;
  for (final dashLen in dashLengths) {
    final t1 = currentDistance / cellSize;
    final t2 = (currentDistance + dashLen) / cellSize;
    final Offset p1 = Offset(startX + (endX - startX) * t1, startY + (endY - startY) * t1);
    final Offset p2 = Offset(startX + (endX - startX) * t2, startY + (endY - startY) * t2);
    canvas.drawLine(p1, p2, paint);
    currentDistance += dashLen;
    currentDistance += normalDashLength;
  }
}

void drawEntrance(Canvas canvas, Rect rect, double cellSize) {
  final Paint paint = Paint()
    ..color = entranceColor
    ..style = PaintingStyle.fill;
  final Offset center = rect.center;
  final radius = cellSize * 0.3;
  canvas.drawCircle(center, radius, paint);
}

void _drawPathStart(Canvas canvas, Offset center, double cellSize) {
  final radius = cellSize * 0.26;
  final fillPaint = Paint()
    ..color = pathStartColor
    ..style = PaintingStyle.fill;
  final borderPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.05;
  final innerPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius, fillPaint);
  canvas.drawCircle(center, radius, borderPaint);
  canvas.drawCircle(center, radius * 0.36, innerPaint);
}

void _drawPathEnd(Canvas canvas, Offset center, double cellSize) {
  final radius = cellSize * 0.26;
  final fillPaint = Paint()
    ..color = pathEndColor
    ..style = PaintingStyle.fill;
  final borderPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.05;
  final innerPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius, fillPaint);
  canvas.drawCircle(center, radius, borderPaint);
  final side = radius * 0.8;
  canvas.drawRect(Rect.fromCenter(center: center, width: side, height: side), innerPaint);
}

class WorldPainter extends CustomPainter {
  final World world;
  final GroundLayer layer;
  Set<Node> resources = const <Node>{};
  List<Node> path = [];

  final int minX;
  final int maxX;
  final int minY;
  final int maxY;

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;

  WorldPainter({
    required this.world,
    required this.layer,
    int? minX,
    int? maxX,
    int? minY,
    int? maxY,
    int padding = 1,
  }): minX = (minX ?? world.minX) - padding,
      maxX = (maxX ?? world.maxX) + padding,
      minY = (minY ?? world.minY) - padding,
      maxY = (maxY ?? world.maxY) + padding;

  factory WorldPainter.auto({
    required World world,
    required GroundLayer layer,
    int padding = 1,
  }) {
    int? contentMinX, contentMaxX, contentMinY, contentMaxY;
    for (int x = world.minX; x <= world.maxX; x++) {
      for (int y = world.minY; y <= world.maxY; y++) {
        final cell = world.cell(layer, x, y);
        if (cell != null && cell.structureId != null) {
          contentMinX = contentMinX == null ? x : min(contentMinX, x);
          contentMaxX = contentMaxX == null ? x : max(contentMaxX, x);
          contentMinY = contentMinY == null ? y : min(contentMinY, y);
          contentMaxY = contentMaxY == null ? y : max(contentMaxY, y);
        }
      }
    }
    return WorldPainter(
      world: world,
      layer: layer,
      minX: (contentMinX ?? world.minX) - padding,
      maxX: (contentMaxX ?? world.maxX) + padding,
      minY: (contentMinY ?? world.minY) - padding,
      maxY: (contentMaxY ?? world.maxY) + padding,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = min(size.width / width, size.height / height);
    drawBackground(canvas, width, height, cellSize);

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final cell = world.cell(layer, x, y);
        if (cell == null || cell.structureId == null) continue;
        final rect = Rect.fromLTWH((x - minX) * cellSize, (maxY - y) * cellSize, cellSize, cellSize);
        drawCell(
          canvas,
          rect,
          cell.isCorridor,
          cellSize,
          world.suspiciousStructures.contains(cell.structureId),
        );
        if (cell.info.isResource) {
          drawResource(canvas, rect, cellSize);
        }
        if (cell.info.isStair != null) {
          drawStair(canvas, rect, cell.info.isStair!, cellSize);
        }
        for (final direction in Direction.values) {
          switch (cell.info.getEdgeType(direction)) {
            case EdgeType.nothing:
              final (dx, dy) = direction.dxy;
              final neighbor = world.cell(layer, x + dx, y + dy);
              if (neighbor == null || neighbor.structureId != cell.structureId) {
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
      final entranceLayer = entry.key.layer;
      if (entranceLayer != layer || !entry.key.displayable) continue;
      final entrance = entry.value;
      if (entrance.x < minX || entrance.x > maxX || entrance.y < minY || entrance.y > maxY) {
        continue;
      }
      final rect = Rect.fromLTWH(
        (entrance.x - minX) * cellSize,
        (maxY - entrance.y) * cellSize,
        cellSize,
        cellSize,
      );
      drawEntrance(canvas, rect, cellSize);
    }

    _paintPath(canvas, cellSize);
  }

  void _paintPath(Canvas canvas, double cellSize) {
    if (path.isEmpty) return;
    final laneOffset = cellSize * 0.12;
    final arrowSize = cellSize * 0.18;
    final linePaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arrowPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final polylines = <List<Offset>>[];
    List<Offset>? current;
    Node? prevNode;
    for (final node in path) {
      final bool nodeOnThisLayer = node.layer == layer;
      final bool isCrossLayerEntry = prevNode != null &&
          prevNode.layer == layer && !nodeOnThisLayer &&
          (node.x != prevNode.x || node.y != prevNode.y);
      if (!nodeOnThisLayer && !isCrossLayerEntry) {
        if (current != null && current.length > 1) {
          polylines.add(current);
        }
        current = null;
        prevNode = null;
        continue;
      }
      final center = Offset((node.x - minX + 0.5) * cellSize, (maxY - node.y + 0.5) * cellSize);
      if (current == null) {
        current = <Offset>[center];
      } else {
        current.add(center);
      }
      prevNode = node;
    }
    if (current != null && current.length > 1) polylines.add(current);
    if (polylines.isEmpty) return;

    final shiftedPolylines = <List<Offset>>[];
    for (final points in polylines) {
      Offset unitNormal(Offset a, Offset b) {
        final v = b - a;
        final len = v.distance;
        return Offset(-v.dy / len, v.dx / len);
      }
      final shifted = <Offset>[];
      for (int i = 0; i < points.length; i++) {
        final Offset normal;
        if (i == 0) {
          normal = unitNormal(points[i], points[i + 1]);
        } else if (i == points.length - 1) {
          normal = unitNormal(points[i - 1], points[i]);
        } else {
          final n1 = unitNormal(points[i - 1], points[i]);
          final n2 = unitNormal(points[i], points[i + 1]);
          final sum = n1 + n2;
          final len = sum.distance;
          normal = len < 1e-3 ? n1 : sum / len;
        }
        shifted.add(points[i] + normal * laneOffset);
      }
      shiftedPolylines.add(shifted);
    }

    for (final points in shiftedPolylines) {
      final route = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        route.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(route, linePaint);

      for (int i = 0; i < points.length - 1; i++) {
        final a = points[i];
        final b = points[i + 1];
        final v = b - a;
        final len = v.distance;

        final u = v / len;
        final n = Offset(-u.dy, u.dx);
        final mid = Offset.lerp(a, b, 0.5)!;
        final tip = mid + u * (arrowSize * 0.5);
        final back = tip - u * arrowSize;
        canvas.drawLine(tip, back + n * (arrowSize * 0.6), arrowPaint);
        canvas.drawLine(tip, back - n * (arrowSize * 0.6), arrowPaint);
      }
    }

    if (path.first.layer == layer) {
      _drawPathStart(canvas, shiftedPolylines.first.first, cellSize);
    }
    if (path.last.layer == layer) {
      _drawPathEnd(canvas, shiftedPolylines.last.last, cellSize);
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) {
    return oldDelegate.world != world ||
        oldDelegate.layer != layer ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        !setEquals(oldDelegate.resources, resources) ||
        !listEquals(oldDelegate.path, path);
  }
}
