import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/painter/world_painter.dart';

class EntranceThumbnailPainter extends CustomPainter {
  final World world;
  final EntranceType entrance;
  final int offsetMinX;
  final int offsetMaxX;
  final int offsetMinY;
  final int offsetMaxY;

  EntranceThumbnailPainter._({
    required this.world,
    required this.entrance,
    this.offsetMinX = -3,
    this.offsetMaxX = 3,
    this.offsetMinY = -3,
    this.offsetMaxY = 3,
  }): assert(offsetMinX < offsetMaxX),
      assert(offsetMinY < offsetMaxY);

  factory EntranceThumbnailPainter.auto({
    required World world,
    required EntranceType entrance,
    int square = 7,
  }) {
    assert(square.isOdd, 'square must be odd');
    final radius = square ~/ 2;
    var minX = -radius, maxX = radius, minY = -radius, maxY = radius;
    final adjusted = _adjustOffsets(world, entrance, minX, maxX, minY, maxY);
    return EntranceThumbnailPainter._(
      world: world,
      entrance: entrance,
      offsetMinX: adjusted.$1,
      offsetMaxX: adjusted.$2,
      offsetMinY: adjusted.$3,
      offsetMaxY: adjusted.$4,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = offsetMaxX - offsetMinX + 1;
    final height = offsetMaxY - offsetMinY + 1;
    final cellSize = min(size.width / width, size.height / height);
    drawBackground(canvas, width, height, cellSize);

    final entrancePos = world.entrances[entrance]!.position;
    final ex = entrancePos.x;
    final ey = entrancePos.y;

    for (int dx = offsetMinX; dx <= offsetMaxX; dx++) {
      for (int dy = offsetMinY; dy <= offsetMaxY; dy++) {
        final worldX = ex + dx;
        final worldY = ey + dy;
        final cell = world.cell(entrance.layer, worldX, worldY);
        if (cell == null || cell.structureId == null) continue;

        final rect = Rect.fromLTWH(
          (dx - offsetMinX) * cellSize,
          (offsetMaxY - dy) * cellSize,
          cellSize,
          cellSize,
        );

        drawCell(canvas, rect, cell.isCorridor, cellSize, false);
        if (cell.info.isStair != null) {
          drawStair(canvas, rect, cell.info.isStair!, cellSize);
        }
        for (final direction in Direction.values) {
          switch (cell.info.getEdgeType(direction)) {
            case EdgeType.nothing:
              final (dx2, dy2) = direction.dxy;
              final neighbor = world.cell(entrance.layer, worldX + dx2, worldY + dy2);
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

        if (entrancePos == Position(x: worldX, y: worldY)) {
          drawEntrance(canvas, rect, cellSize);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant EntranceThumbnailPainter oldDelegate) {
    return oldDelegate.world != world ||
        oldDelegate.entrance != entrance ||
        oldDelegate.offsetMinX != offsetMinX ||
        oldDelegate.offsetMaxX != offsetMaxX ||
        oldDelegate.offsetMinY != offsetMinY ||
        oldDelegate.offsetMaxY != offsetMaxY;
  }

  BoolList getSignature() {
    final list = BoolList.empty(growable: true);
    final entrancePos = world.entrances[entrance]!;
    final ex = entrancePos.x;
    final ey = entrancePos.y;
    for (int dx = offsetMinX; dx <= offsetMaxX; dx++) {
      for (int dy = offsetMinY; dy <= offsetMaxY; dy++) {
        final cell = world.cell(entrance.layer, ex + dx, ey + dy);
        if (cell == null || cell.structureId == null) {
          list.add(false);
        } else {
          list.add(true);
          list.add(cell.isCorridor);
          list.add(cell.info.edgeNorth == EdgeType.door);
          list.add(cell.info.edgeEast == EdgeType.door);
          list.add(cell.info.edgeSouth == EdgeType.door);
          list.add(cell.info.edgeWest == EdgeType.door);
        }
      }
    }
    return list;
  }

  static (int, int, int, int) _adjustOffsets(
      World world,
      EntranceType entrance,
      int minX,
      int maxX,
      int minY,
      int maxY,
      ) {
    final pos = world.entrances[entrance]!;
    final layer = entrance.layer;

    int leftEmptyColumns = 0;
    for (int x = pos.x + minX; x <= pos.x + maxX; x++) {
      if (_isColumnEmpty(world, layer, x, pos.y + minY, pos.y + maxY)) {
        leftEmptyColumns++;
      } else {
        break;
      }
    }
    int rightEmptyColumns = 0;
    for (int x = pos.x + maxX; x >= pos.x + minX; x--) {
      if (_isColumnEmpty(world, layer, x, pos.y + minY, pos.y + maxY)) {
        rightEmptyColumns++;
      } else {
        break;
      }
    }
    int bottomEmptyRows = 0;
    for (int y = pos.y + minY; y <= pos.y + maxY; y++) {
      if (_isRowEmpty(world, layer, y, pos.x + minX, pos.x + maxX)) {
        bottomEmptyRows++;
      } else {
        break;
      }
    }
    int topEmptyRows = 0;
    for (int y = pos.y + maxY; y >= pos.y + minY; y--) {
      if (_isRowEmpty(world, layer, y, pos.x + minX, pos.x + maxX)) {
        topEmptyRows++;
      } else {
        break;
      }
    }

    int newMinX = minX, newMaxX = maxX;
    int newMinY = minY, newMaxY = maxY;
    if (leftEmptyColumns > 0 && rightEmptyColumns > 0) {
    } else if (leftEmptyColumns > 0) {
      int shift = leftEmptyColumns - 1;
      shift = min(shift, -newMinX);
      newMinX += shift;
      newMaxX += shift;
    } else if (rightEmptyColumns > 0) {
      int shift = rightEmptyColumns - 1;
      shift = min(shift, newMaxX);
      newMinX -= shift;
      newMaxX -= shift;
    }
    if (bottomEmptyRows > 0 && topEmptyRows > 0) {
    } else if (bottomEmptyRows > 0) {
      int shift = bottomEmptyRows - 1;
      shift = min(shift, -newMinY);
      newMinY += shift;
      newMaxY += shift;
    } else if (topEmptyRows > 0) {
      int shift = topEmptyRows - 1;
      shift = min(shift, newMaxY);
      newMinY -= shift;
      newMaxY -= shift;
    }

    return (newMinX, newMaxX, newMinY, newMaxY);
  }

  static bool _isColumnEmpty(World world, GroundLayer layer, int x, int yMin, int yMax) {
    for (int y = yMin; y <= yMax; y++) {
      final cell = world.cell(layer, x, y);
      if (cell != null && cell.structureId != null) return false;
    }
    return true;
  }

  static bool _isRowEmpty(World world, GroundLayer layer, int y, int xMin, int xMax) {
    for (int x = xMin; x <= xMax; x++) {
      final cell = world.cell(layer, x, y);
      if (cell != null && cell.structureId != null) return false;
    }
    return true;
  }
}
