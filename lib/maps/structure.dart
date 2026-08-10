import 'dart:collection';

enum Direction {
  north, // ↑
  east, // →
  south, // ↓
  west, // ←
}

extension DirectionExt on Direction {
  int get dx {
    switch (this) {
      case Direction.north: return 0;
      case Direction.south: return 0;
      case Direction.east: return 1;
      case Direction.west: return -1;
    }
  }
  int get dy {
    switch (this) {
      case Direction.north: return -1;
      case Direction.south: return 1;
      case Direction.east: return 0;
      case Direction.west: return 0;
    }
  }
  Direction get opposite {
    switch (this) {
      case Direction.north: return Direction.south;
      case Direction.south: return Direction.north;
      case Direction.east: return Direction.west;
      case Direction.west: return Direction.east;
    }
  }
  Direction rotate90CW() {
    switch (this) {
      case Direction.north: return Direction.east;
      case Direction.east: return Direction.south;
      case Direction.south: return Direction.west;
      case Direction.west: return Direction.north;
    }
  }
}

Direction parseDirection(String s) {
  switch (s) {
    case 'north': return Direction.north;
    case 'south': return Direction.south;
    case 'east': return Direction.east;
    case 'west': return Direction.west;
    default: throw ArgumentError('Invalid direction: $s');
  }
}

class LocalPos {
  final int row, col;
  const LocalPos(this.row, this.col);

  LocalPos rotate(int timesClockwise, int boundRows, int boundCols) {
    int r = row, c = col;
    int br = boundRows, bc = boundCols;
    for (int i = 0; i < timesClockwise; i++) {
      (r, c) = (c, br - 1 - r);
      (br, bc) = (bc, br);
    }
    return LocalPos(r, c);
  }

  @override
  String toString() => '($row,$col)';
}

Set<LocalPos> createPosSet() => HashSet<LocalPos>(
  equals: (a, b) => a.row == b.row && a.col == b.col,
  hashCode: (p) => p.row.hashCode ^ p.col.hashCode,
);

class DoorDef {
  final LocalPos pos;
  final Direction facing;
  const DoorDef(this.pos, this.facing);
}

Set<DoorDef> createDoorSet() => HashSet<DoorDef>(
  equals: (a, b) => a.pos == b.pos && a.facing == b.facing,
  hashCode: (p) => p.pos.hashCode ^ p.facing.hashCode,
);

enum Layer {
  upper,
  lower,
}

abstract class StructureDef {
  String get typeName;
  int get boundRows;
  int get boundCols;
  bool get isDouble;
  bool get isCorridor => false;
  Set<LocalPos> cells(Layer layer);
  Set<DoorDef> doors(Layer layer);
}

class CorridorDef extends StructureDef {
  final Set<LocalPos> path;
  final Set<DoorDef> doorList;
  CorridorDef(this.path, this.doorList): assert(path.isNotEmpty);
  @override String get typeName => 'corridor';
  @override int get boundRows => path.map((p) => p.row).reduce((a,b) => a > b ? a : b) + 1;
  @override int get boundCols => path.map((p) => p.col).reduce((a,b) => a > b ? a : b) + 1;
  @override bool get isDouble => false;
  @override bool get isCorridor => true;
  @override Set<LocalPos> cells(Layer layer) => path;
  @override Set<DoorDef> doors(Layer layer) => doorList;
}

/// ```
/// R E
/// R R
/// ```
/// ```
/// R R
/// S R
/// ```
class Stair2x2Def extends StructureDef {
  static final Set<DoorDef> _lowerDoors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 1), Direction.east),
  ]);
  static final Set<DoorDef> _upperDoors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(1, 0), Direction.south),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0,0), LocalPos(0,1),
    LocalPos(1,0), LocalPos(1,1),
  ]);
  @override String get typeName => 'stair_2x2';
  @override int get boundRows => 2;
  @override int get boundCols => 2;
  @override bool get isDouble => true;
  @override bool get isCorridor => true;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => switch (layer) {
    Layer.upper => _upperDoors,
    Layer.lower => _lowerDoors,
  };
}

/// ```
/// R R N
/// R R R
/// S R R
/// ```
/// ```
/// R R R
/// W R E
/// R R R
/// ```
class Stair3x3TDef extends StructureDef {
  static final Set<DoorDef> _lowerDoors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 2), Direction.north),
    DoorDef(LocalPos(2, 0), Direction.south),
  ]);
  static final Set<DoorDef> _upperDoors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(1, 0), Direction.west),
    DoorDef(LocalPos(1, 2), Direction.east),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0,0), LocalPos(0,1), LocalPos(0,2),
    LocalPos(1,0), LocalPos(1,1), LocalPos(1,2),
    LocalPos(2,0), LocalPos(2,1), LocalPos(2,2),
  ]);
  @override String get typeName => 'stair_3x3_t';
  @override int get boundRows => 3;
  @override int get boundCols => 3;
  @override bool get isDouble => true;
  @override bool get isCorridor => true;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => switch (layer) {
    Layer.upper => _upperDoors,
    Layer.lower => _lowerDoors,
  };
}

/// ```
/// R R R
/// R R R
/// R S R
/// ```
/// ```
/// W R E
/// R R R
/// R R R
/// ```
class Stair3x3ODef extends StructureDef {
  static final Set<DoorDef> _lowerDoors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(2, 1), Direction.south),
  ]);
  static final Set<DoorDef> _upperDoors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.west),
    DoorDef(LocalPos(0, 2), Direction.east),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0,0), LocalPos(0,1), LocalPos(0,2),
    LocalPos(1,0), LocalPos(1,1), LocalPos(1,2),
    LocalPos(2,0), LocalPos(2,1), LocalPos(2,2),
  ]);
  @override String get typeName => 'stair_3x3_o';
  @override int get boundRows => 3;
  @override int get boundCols => 3;
  @override bool get isDouble => true;
  @override bool get isCorridor => true;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => switch (layer) {
    Layer.upper => _upperDoors,
    Layer.lower => _lowerDoors,
  };
}

/// ```
/// N X X X N
/// R R X R R
/// X R R R X
/// X X R X X
/// X X S X X
///
class YCorridorDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.north),
    DoorDef(LocalPos(0, 4), Direction.north),
    DoorDef(LocalPos(4, 2), Direction.south),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0,0), LocalPos(0,4),
    LocalPos(1,0), LocalPos(1,1), LocalPos(1,3), LocalPos(1,4),
    LocalPos(2,1), LocalPos(2,2), LocalPos(2,3),
    LocalPos(3,2),
    LocalPos(4,2),
  ]);
  @override String get typeName => 'y_corridor';
  @override int get boundRows => 5;
  @override int get boundCols => 5;
  @override bool get isDouble => false;
  @override bool get isCorridor => true;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// R N R
/// W R E
/// R S R
/// ```
class CenterCorridorDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 1), Direction.north),
    DoorDef(LocalPos(1, 0), Direction.west),
    DoorDef(LocalPos(1, 2), Direction.east),
    DoorDef(LocalPos(2, 1), Direction.south),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2),
    LocalPos(2, 0), LocalPos(2, 1), LocalPos(2, 2),
  ]);
  @override String get typeName => 'center_corridor';
  @override int get boundRows => 3;
  @override int get boundCols => 3;
  @override bool get isDouble => false;
  @override bool get isCorridor => true;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// X N X
/// R R R
/// R R R
/// W R E
/// X R X
/// ```
class MainEntranceDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 1), Direction.north),
    DoorDef(LocalPos(3, 0), Direction.west),
    DoorDef(LocalPos(3, 2), Direction.east),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 1),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2),
    LocalPos(2, 0), LocalPos(2, 1), LocalPos(2, 2),
    LocalPos(3, 0), LocalPos(3, 1), LocalPos(3, 2),
    LocalPos(4, 1),
  ]);
  @override String get typeName => 'main_entrance';
  @override int get boundRows => 3;
  @override int get boundCols => 5;
  @override bool get isDouble => false;
  @override bool get isCorridor => true;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// X X N X X
/// N R R R N
/// X R R R X
/// X R R R X
/// X R R R X
/// ```
class MuseRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 2), Direction.north),
    DoorDef(LocalPos(1, 0), Direction.north),
    DoorDef(LocalPos(1, 4), Direction.north),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 2),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2), LocalPos(1, 3), LocalPos(1, 4),
    LocalPos(2, 1), LocalPos(2, 2), LocalPos(2, 3),
    LocalPos(3, 1), LocalPos(3, 2), LocalPos(3, 3),
    LocalPos(4, 1), LocalPos(4, 2), LocalPos(4, 3),
  ]);
  @override String get typeName => 'muse_room';
  @override int get boundRows => 5;
  @override int get boundCols => 5;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// N X X X X
/// R X R R R
/// R X R R R
/// R R R R X
/// S X X X X
/// ```
class BedRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.north),
    DoorDef(LocalPos(4, 0), Direction.south),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0),
    LocalPos(1, 0), LocalPos(1, 2), LocalPos(1, 3), LocalPos(1, 4),
    LocalPos(2, 0), LocalPos(2, 2), LocalPos(2, 3), LocalPos(2, 4),
    LocalPos(3, 0), LocalPos(3, 1), LocalPos(3, 2), LocalPos(3, 3),
    LocalPos(4, 0),
  ]);
  @override String get typeName => 'bed_room';
  @override int get boundRows => 5;
  @override int get boundCols => 5;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// N R R R R
/// R R R R E
/// R R R R R
/// R R R R R
/// R R R R R
/// ```
class FiveBedRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.north),
    DoorDef(LocalPos(1, 4), Direction.east),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2), LocalPos(0, 3), LocalPos(0, 4),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2), LocalPos(1, 3), LocalPos(1, 4),
    LocalPos(2, 0), LocalPos(2, 1), LocalPos(2, 2), LocalPos(2, 3), LocalPos(2, 4),
    LocalPos(3, 0), LocalPos(3, 1), LocalPos(3, 2), LocalPos(3, 3), LocalPos(3, 4),
    LocalPos(4, 0), LocalPos(4, 1), LocalPos(4, 2), LocalPos(4, 3), LocalPos(4, 4),
  ]);
  @override String get typeName => 'five_bed_room';
  @override int get boundRows => 5;
  @override int get boundCols => 5;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// N R R R E
/// R R R R R
/// R R R R R
/// R R R R R
/// W R R R S
/// ```
class MeetingRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.north),
    DoorDef(LocalPos(0, 4), Direction.east),
    DoorDef(LocalPos(4, 0), Direction.west),
    DoorDef(LocalPos(4, 4), Direction.south),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2), LocalPos(0, 3), LocalPos(0, 4),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2), LocalPos(1, 3), LocalPos(1, 4),
    LocalPos(2, 0), LocalPos(2, 1), LocalPos(2, 2), LocalPos(2, 3), LocalPos(2, 4),
    LocalPos(3, 0), LocalPos(3, 1), LocalPos(3, 2), LocalPos(3, 3), LocalPos(3, 4),
    LocalPos(4, 0), LocalPos(4, 1), LocalPos(4, 2), LocalPos(4, 3), LocalPos(4, 4),
  ]);
  @override String get typeName => 'meeting_room';
  @override int get boundRows => 5;
  @override int get boundCols => 5;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// W R R R R
/// R R R R R
/// R R R R R
/// R R R R R
/// W R R S R
/// ```
/// ```
/// W R R X X
/// R R R X X
/// R R R X X
/// R R R X X
/// W R R X X
/// ```
class RestaurantRoomDef extends StructureDef {
  static final Set<DoorDef> _lowerDoors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.west),
    DoorDef(LocalPos(4, 0), Direction.west),
    DoorDef(LocalPos(4, 3), Direction.south),
  ]);
  static final Set<DoorDef> _upperDoors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.west),
    DoorDef(LocalPos(4, 0), Direction.west),
  ]);
  static final Set<LocalPos> _lowerCells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2), LocalPos(0, 3), LocalPos(0, 4),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2), LocalPos(1, 3), LocalPos(1, 4),
    LocalPos(2, 0), LocalPos(2, 1), LocalPos(2, 2), LocalPos(2, 3), LocalPos(2, 4),
    LocalPos(3, 0), LocalPos(3, 1), LocalPos(3, 2), LocalPos(3, 3), LocalPos(3, 4),
    LocalPos(4, 0), LocalPos(4, 1), LocalPos(4, 2), LocalPos(4, 3), LocalPos(4, 4),
  ]);
  static final Set<LocalPos> _upperCells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2),
    LocalPos(2, 0), LocalPos(2, 1), LocalPos(2, 2),
    LocalPos(3, 0), LocalPos(3, 1), LocalPos(3, 2),
    LocalPos(4, 0), LocalPos(4, 1), LocalPos(4, 2),
  ]);
  @override String get typeName => 'restaurant_room';
  @override int get boundRows => 5;
  @override int get boundCols => 5;
  @override bool get isDouble => true;
  @override Set<LocalPos> cells(Layer layer) => switch (layer) {
    Layer.upper => _upperCells,
    Layer.lower => _lowerCells,
  };
  @override Set<DoorDef> doors(Layer layer) => switch (layer) {
    Layer.upper => _upperDoors,
    Layer.lower => _lowerDoors,
  };
}

/// ```
/// R R X
/// R R E
/// X S X
/// ```
class CornerRoomADef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(1, 2), Direction.east),
    DoorDef(LocalPos(2, 1), Direction.south),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2),
    LocalPos(2, 1),
  ]);
  @override String get typeName => 'corner_room_a';
  @override int get boundRows => 3;
  @override int get boundCols => 3;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// W R N
/// R R R
/// ```
class CornerRoomBDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.west),
    DoorDef(LocalPos(0, 2), Direction.north),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2),
  ]);
  @override String get typeName => 'corner_room_b';
  @override int get boundRows => 2;
  @override int get boundCols => 3;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// W R N R
/// R R R E
/// ```
class CenterRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.west),
    DoorDef(LocalPos(0, 2), Direction.north),
    DoorDef(LocalPos(1, 3), Direction.east),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2), LocalPos(0, 3),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2), LocalPos(1, 3),
  ]);
  @override String get typeName => 'center_room';
  @override int get boundRows => 2;
  @override int get boundCols => 4;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// R N R
/// R R X
/// X R X
/// ```
class SafeRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 1), Direction.north),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2),
    LocalPos(1, 0), LocalPos(1, 1),
    LocalPos(2, 1),
  ]);
  @override String get typeName => 'safe_room';
  @override int get boundRows => 3;
  @override int get boundCols => 3;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// X R E
/// R R R
/// W R X
/// ```
class StairRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 2), Direction.east),
    DoorDef(LocalPos(2, 0), Direction.west),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 1), LocalPos(0, 2),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2),
    LocalPos(2, 0), LocalPos(2, 1),
  ]);
  @override String get typeName => 'stair_room';
  @override int get boundRows => 3;
  @override int get boundCols => 3;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// W R E
/// X R X
/// X S X
/// ```
class TRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 0), Direction.west),
    DoorDef(LocalPos(0, 2), Direction.east),
    DoorDef(LocalPos(2, 1), Direction.south),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 0), LocalPos(0, 1), LocalPos(0, 2),
    LocalPos(1, 1),
    LocalPos(2, 1),
  ]);
  @override String get typeName => 't_room';
  @override int get boundRows => 3;
  @override int get boundCols => 3;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}

/// ```
/// X N X
/// R R R
/// R R R
/// X S X
/// ```
class LanternRoomDef extends StructureDef {
  static final Set<DoorDef> _doors = createDoorSet()..addAll(const [
    DoorDef(LocalPos(0, 1), Direction.north),
    DoorDef(LocalPos(3, 1), Direction.south),
  ]);
  static final Set<LocalPos> _cells = createPosSet()..addAll(const [
    LocalPos(0, 1),
    LocalPos(1, 0), LocalPos(1, 1), LocalPos(1, 2),
    LocalPos(2, 0), LocalPos(2, 1), LocalPos(2, 2),
    LocalPos(3, 1),
  ]);
  @override String get typeName => 'lantern_room';
  @override int get boundRows => 3;
  @override int get boundCols => 4;
  @override bool get isDouble => false;
  @override Set<LocalPos> cells(Layer layer) => _cells;
  @override Set<DoorDef> doors(Layer layer) => _doors;
}
