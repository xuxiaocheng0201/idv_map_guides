import 'package:comparators/comparators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'data.freezed.dart';

// ```
//     ^ y
//     |
//     |
// ----+----> x
//     |
// ```

enum GroundLayer {
  basement,
  ground,
  second;

  @useResult
  GroundLayer? up() {
    switch (this) {
      case GroundLayer.basement:
        return GroundLayer.ground;
      case GroundLayer.ground:
        return GroundLayer.second;
      case GroundLayer.second:
        return null;
    }
  }

  @useResult
  GroundLayer? down() {
    switch (this) {
      case GroundLayer.basement:
        return null;
      case GroundLayer.ground:
        return GroundLayer.basement;
      case GroundLayer.second:
        return GroundLayer.ground;
    }
  }
}

enum Rotation {
  cw0,
  cw90,
  cw180,
  cw270;

  @useResult
  int times() {
    switch (this) {
      case Rotation.cw0:
        return 0;
      case Rotation.cw90:
        return 1;
      case Rotation.cw180:
        return 2;
      case Rotation.cw270:
        return 3;
    }
  }
}

enum Direction {
  north, // ↑
  east,  // →
  south, // ↓
  west;  // ←

  @useResult
  (int, int) get dxy {
    switch (this) {
      case Direction.north:
        return (0, 1);
      case Direction.east:
        return (1, 0);
      case Direction.south:
        return (0, -1);
      case Direction.west:
        return (-1, 0);
    }
  }

  @useResult
  Direction rotate(Rotation rotation) {
    var result = this;
    for (var i = 0; i < rotation.times(); i++) {
      result = switch (result) {
        Direction.north => Direction.east,
        Direction.east => Direction.south,
        Direction.south => Direction.west,
        Direction.west => Direction.north,
      };
    }
    return result;
  }
}

@freezed
abstract class Position with _$Position implements Comparable<Position> {
  const Position._();
  const factory Position({
    required int x,
    required int y,
  }) = _Position;

  @useResult
  Position toWorld(Rotation rotation, int dx, int dy) => _rotate(rotation).add(dx, dy);

  @useResult
  Position add(int dx, int dy) => Position(x: x + dx, y: y + dy);

  @useResult
  Position _rotate(Rotation rotation) {
    var result = this;
    for (var i = 0; i < rotation.times(); i++) {
      result = Position(x: result.y, y: -result.x);
    }
    return result;
  }

  @override
  int compareTo(Position other) {
    return compareSequentially([
      compare<Position>((position) => position.x),
      compare<Position>((position) => position.y),
    ])(this, other);
  }
}

enum StairTransport {
  nothing,
  goUp,
  goDown;
}

enum EdgeType {
  nothing,
  door,
  innerWall,
  hole,
}

@freezed
abstract class CellInfo with _$CellInfo {
  const CellInfo._();
  const factory CellInfo({
    StairTransport? isStair,
    @Default(EdgeType.nothing) EdgeType edgeNorth,
    @Default(EdgeType.nothing) EdgeType edgeEast,
    @Default(EdgeType.nothing) EdgeType edgeSouth,
    @Default(EdgeType.nothing) EdgeType edgeWest,
  }) = _CellInfo;

  @useResult
  EdgeType getEdgeType(Direction direction) => switch (direction) {
    Direction.north => edgeNorth,
    Direction.east => edgeEast,
    Direction.south => edgeSouth,
    Direction.west => edgeWest,
  };

  @useResult
  CellInfo setEdgeType(Direction direction, EdgeType type) => switch (direction) {
    Direction.north => copyWith(edgeNorth: type),
    Direction.east => copyWith(edgeEast: type),
    Direction.south => copyWith(edgeSouth: type),
    Direction.west => copyWith(edgeWest: type),
  };

  @useResult
  CellInfo rotation(Rotation rotation) {
    var result = this;
    for (var i = 0; i < rotation.times(); i++) {
      result = result.copyWith(
        edgeNorth: result.edgeWest,
        edgeEast: result.edgeNorth,
        edgeSouth: result.edgeEast,
        edgeWest: result.edgeSouth,
      );
    }
    return result;
  }
}

@Freezed(addImplicitFinal: false, makeCollectionsUnmodifiable: false)
abstract class Structure with _$Structure {
  Structure._();
  factory Structure({
    required String name,
    required bool isCorridor,
    required bool isResource,
    required bool isNoDirection,
    required Map<Position, CellInfo> cells,
  }) = _Structure;
}

@freezed
abstract class Edge with _$Edge {
  const Edge._();
  const factory Edge({
    required Position position,
    required Direction direction,
  }) = _Edge;

  @useResult
  Edge opposite() {
    final (dx, dy) = direction.dxy;
    return Edge(
      position: position.add(dx, dy),
      direction: direction.rotate(Rotation.cw180),
    );
  }
}
