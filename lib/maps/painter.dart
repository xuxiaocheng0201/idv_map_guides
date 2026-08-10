import 'package:flutter/rendering.dart' hide Layer;
import 'package:idv_map_guides/maps/structure.dart';
import 'package:idv_map_guides/maps/world.dart';

const outside = Color(0xFF223344);
const corridor = Color(0xFF666666);
const room = Color(0xFF665544);
const wall = Color(0xFF778899);
const door = Color(0xFFFFDD33);

class MapPainter extends CustomPainter {
  final MapModel map;
  final Layer layer;
  MapPainter(this.map, this.layer);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / map.width;
    final outsidePaint = Paint()
      ..color = outside;
    final corridorPaint = Paint()
      ..color = corridor;
    final roomPaint = Paint()
      ..color = room;
    final wallPaint = Paint()
      ..color = wall
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final doorPaint = Paint()
      ..color = door
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final grid = map.grids[layer]!;

    canvas.drawRect(Offset.zero & size, outsidePaint);

    for (int row = 0; row < map.height; row++) {
      for (int col = 0; col < map.width; col++) {
        final cell = grid[row][col];
        if (cell.structureId != null) {
          final rect = Offset(col * cellSize, row * cellSize) & Size(cellSize, cellSize);
          canvas.drawRect(rect, cell.isCorridor ? corridorPaint : roomPaint);
        }
      }
    }

    for (int row = 0; row < map.height; row++) {
      for (int col = 0; col < map.width; col++) {
        final cell = grid[row][col];
        final id = cell.structureId;
        if (id == null) continue;

        for (final dir in Direction.values) {
          final ny = row + dir.dy;
          final nx = col + dir.dx;
          bool isBoundary = false;
          if (ny < 0 || ny >= map.height || nx < 0 || nx >= map.width) {
            isBoundary = true;
          } else {
            final neighbor = grid[ny][nx];
            if (neighbor.structureId != id) {
              isBoundary = true;
            }
          }
          if (!isBoundary) {
            continue;
          }
          final Offset p1, p2;
          switch (dir) {
            case Direction.north:
              p1 = Offset(col * cellSize, row * cellSize);
              p2 = Offset((col + 1) * cellSize, row * cellSize);
              break;
            case Direction.south:
              p1 = Offset(col * cellSize, (row + 1) * cellSize);
              p2 = Offset((col + 1) * cellSize, (row + 1) * cellSize);
              break;
            case Direction.east:
              p1 = Offset((col + 1) * cellSize, row * cellSize);
              p2 = Offset((col + 1) * cellSize, (row + 1) * cellSize);
              break;
            case Direction.west:
              p1 = Offset(col * cellSize, row * cellSize);
              p2 = Offset(col * cellSize, (row + 1) * cellSize);
              break;
          }
          canvas.drawLine(p1, p2, wallPaint);
        }
      }
    }

    for (int row = 0; row < map.height; row++) {
      for (int col = 0; col < map.width; col++) {
        final cell = grid[row][col];
        for (final dir in cell.doors) {
          final Offset p1, p2;switch (dir) {
            case Direction.north:
              p1 = Offset((col + 0.2) * cellSize, row * cellSize);
              p2 = Offset((col + 0.8) * cellSize, row * cellSize);
              break;
            case Direction.south:
              p1 = Offset((col + 0.2) * cellSize, (row + 1) * cellSize);
              p2 = Offset((col + 0.8) * cellSize, (row + 1) * cellSize);
              break;
            case Direction.east:
              p1 = Offset((col + 1) * cellSize, (row + 0.2) * cellSize);
              p2 = Offset((col + 1) * cellSize, (row + 0.8) * cellSize);
              break;
            case Direction.west:
              p1 = Offset(col * cellSize, (row + 0.2) * cellSize);
              p2 = Offset(col * cellSize, (row + 0.8) * cellSize);
              break;
          }
          canvas.drawLine(p1, p2, doorPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
