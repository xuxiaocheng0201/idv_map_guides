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

@freezed
abstract class Position with _$Position {
  const Position._();
  const factory Position({
    required int x,
    required int y,
  }) = _Position;
  factory Position.fromJson(Map<String, dynamic> json) => _$PositionFromJson(json);

  Position add(int dx, int dy) => Position(x: x + dx, y: y + dy);

  Position rotate(Rotation rotation) {
    var result = this;
    for (var i = 0; i < rotation.times(); i++) {
      result = Position(x: result.y, y: -result.x);
    }
    return result;
  }
}

@freezed
abstract class Door with _$Door {
  const Door._();
  const factory Door({
    required Position position,
    required Direction direction,
  }) = _Door;
  factory Door.fromJson(Map<String, dynamic> json) => _$DoorFromJson(json);

  Door opposite() {
    final (dx, dy) = direction.dxy;
    return Door(
      position: position.add(dx, dy),
      direction: direction.rotate(Rotation.cw180),
    );
  }
}

@freezed
abstract class Entrance with _$Entrance {
  const Entrance._();
  const factory Entrance({
    required GroundLayer layer,
    required Position position,
  }) = _Entrance;
  factory Entrance.fromJson(Map<String, dynamic> json) => _$EntranceFromJson(json);
}

enum StairTransport {
  nothing,
  goUp,
  goDown;

  StairTransport opposite() {
    switch (this) {
      case StairTransport.nothing:
        return StairTransport.nothing;
      case StairTransport.goUp:
        return StairTransport.goDown;
      case StairTransport.goDown:
        return StairTransport.goUp;
    }
  }
}

@freezed
abstract class Stair with _$Stair {
  const Stair._();
  const factory Stair({
    required Position position,
    required StairTransport stairTransport,
  }) = _Stair;
  factory Stair.fromJson(Map<String, dynamic> json) => _$StairFromJson(json);
}

@freezed
abstract class Hole with _$Hole {
  const Hole._();
  const factory Hole({
    required Position position,
    required Direction direction,
  }) = _Hole;
  factory Hole.fromJson(Map<String, dynamic> json) => _$HoleFromJson(json);

  Position target() {
    final (dx, dy) = direction.dxy;
    return position.add(dx, dy);
  }
}

@Freezed(addImplicitFinal: false, makeCollectionsUnmodifiable: false)
abstract class Structure with _$Structure {
  Structure._();
  factory Structure({
    required bool isCorridor,
    required Set<Position> cells,
    required Set<Door> doors,
    required Set<Door> innerWalls,
    required Set<Stair> stairs,
    required Set<Hole> holes,
  }) = _Structure;
  factory Structure.fromJson(Map<String, dynamic> json) => _$StructureFromJson(json);
}
