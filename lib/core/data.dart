import 'package:freezed_annotation/freezed_annotation.dart';

part 'data.freezed.dart';
part 'data.g.dart';

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

@Freezed(fromJson: false, toJson: false, toStringOverride: false)
abstract class Position with _$Position {
  const Position._();
  const factory Position({
    required int x,
    required int y,
  }) = _Position;
  factory Position.fromJson(List<dynamic> json) => Position(
    x: (json[0] as num).toInt(),
    y: (json[1] as num).toInt(),
  );
  List<int> toJson() => [x, y];

  @override String toString() => '$x,$y';
  factory Position.parse(String key) {
    final parts = key.split(',');
    return Position(
      x: int.parse(parts[0]),
      y: int.parse(parts[1]),
    );
  }

  Position toWorld(Rotation rotation, int dx, int dy) => _rotate(rotation).add(dx, dy);

  Position add(int dx, int dy) => Position(x: x + dx, y: y + dy);

  Position _rotate(Rotation rotation) {
    var result = this;
    for (var i = 0; i < rotation.times(); i++) {
      result = Position(x: result.y, y: -result.x);
    }
    return result;
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
  factory CellInfo.fromJson(Map<String, dynamic> json) => _$CellInfoFromJson(json);

  EdgeType getEdgeType(Direction direction) => switch (direction) {
    Direction.north => edgeNorth,
    Direction.east => edgeEast,
    Direction.south => edgeSouth,
    Direction.west => edgeWest,
  };

  CellInfo setEdgeType(Direction direction, EdgeType type) => switch (direction) {
    Direction.north => copyWith(edgeNorth: type),
    Direction.east => copyWith(edgeEast: type),
    Direction.south => copyWith(edgeSouth: type),
    Direction.west => copyWith(edgeWest: type),
  };
}

@freezed
abstract class Edge with _$Edge {
  const Edge._();
  const factory Edge({
    required Position position,
    required Direction direction,
  }) = _Edge;
  factory Edge.fromJson(Map<String, dynamic> json) => _$EdgeFromJson(json);

  Edge opposite() {
    final (dx, dy) = direction.dxy;
    return Edge(
      position: position.add(dx, dy),
      direction: direction.rotate(Rotation.cw180),
    );
  }
}

class CellsMapConverter extends JsonConverter<Map<Position, CellInfo>, Map<String, dynamic>> {
  const CellsMapConverter();

  @override
  Map<Position, CellInfo> fromJson(Map<String, dynamic> json) => json.map((key, value) {
    return MapEntry(Position.parse(key), CellInfo.fromJson(value as Map<String, dynamic>));
  });

  @override
  Map<String, dynamic> toJson(Map<Position, CellInfo> object) => object.map((key, value) {
    return MapEntry(key.toString(), value.toJson());
  });
}

@Freezed(addImplicitFinal: false, makeCollectionsUnmodifiable: false)
abstract class Structure with _$Structure {
  Structure._();
  factory Structure({
    required bool isCorridor,
    @CellsMapConverter() required Map<Position, CellInfo> cells,
  }) = _Structure;
  factory Structure.fromJson(Map<String, dynamic> json) => _$StructureFromJson(json);
}
