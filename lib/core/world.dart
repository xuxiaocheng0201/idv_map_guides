import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/errors.dart';

part 'world.freezed.dart';
part 'world.g.dart';

enum EdgeType {
  nothing,
  door,
  innerWall,
  hole,
}

@freezed
sealed class Cell with _$Cell {
  const Cell._();
  const factory Cell.empty() = CellEmpty;
  const factory Cell.structure({
    required int id,
    required bool isCorridor,
    required StairTransport? isStair,
    required EdgeType edgeNorth,
    required EdgeType edgeEast,
    required EdgeType edgeSouth,
    required EdgeType edgeWest,
  }) = CellStructure;

  Cell setEdgeType(Direction direction, EdgeType type) {
    if (this is CellEmpty) return this;
    final s = this as CellStructure;
    return switch (direction) {
      Direction.north => s.copyWith(edgeNorth: type),
      Direction.east => s.copyWith(edgeEast: type),
      Direction.south => s.copyWith(edgeSouth: type),
      Direction.west => s.copyWith(edgeWest: type),
    };
  }

  EdgeType getEdgeType(Direction direction) {
    if (this is CellEmpty) return EdgeType.nothing;
    final s = this as CellStructure;
    return switch (direction) {
      Direction.north => s.edgeNorth,
      Direction.east => s.edgeEast,
      Direction.south => s.edgeSouth,
      Direction.west => s.edgeWest,
    };
  }

  @Deprecated('method too complex')
  Set<Direction> getDirections(EdgeType target) {
    if (this is CellEmpty) return <Direction>{};
    final s = this as CellStructure;
    return {
      if (s.edgeNorth == target) Direction.north,
      if (s.edgeEast == target) Direction.east,
      if (s.edgeSouth == target) Direction.south,
      if (s.edgeWest == target) Direction.west,
    };
  }
}

class World {
  final int minX, maxX, minY, maxY;
  Map<GroundLayer, List<List<Cell>>> map;
  Set<Entrance> entrances;
  int _nextStructureId;

  World({
    required Set<GroundLayer> layers,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  }): map = {
        for (final layer in layers)
          layer: List.generate(maxX - minX + 1, (_) => List.generate(maxY - minY + 1, (_) => const Cell.empty())),
      },
      entrances = <Entrance>{},
      _nextStructureId = 0;

  Set<GroundLayer> get layers => map.keys.toSet();
  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;

  bool _isOutOfWorld(int x, int y) => x < minX || maxX < x || y < minY || maxY < y;

  Cell? cell(GroundLayer layer, int x, int y) {
    if (_isOutOfWorld(x, y)) return null;
    return map[layer]?[x - minX][y - minY];
  }

  void _setCell(GroundLayer layer, int x, int y, Cell newCell) {
    if (_isOutOfWorld(x, y)) return;
    map[layer]?[x - minX][y - minY] = newCell;
  }


  void _addEntrance(Entrance entrance) {
    if (!map.containsKey(entrance.layer) || _isOutOfWorld(entrance.position.x, entrance.position.y)) {
      throw WorldError.entranceOutOfWorld(entrance: entrance);
    }
    entrances.add(entrance);
  }

  void _placeStructure(GroundLayer layer, Structure structure, int originX, int originY, Rotation rotation) {
    // ---- validate ----
    final errors = WorldErrors();
    for (final cell in structure.cells) {
      final worldPosition = cell.add(originX, originY).rotate(rotation);
      final existing = this.cell(layer, worldPosition.x, worldPosition.y);
      switch (existing) {
        case null:
          errors.push(WorldError.cellOutOfWorld(worldPosition: worldPosition, cell: cell));
        case CellStructure():
          errors.push(WorldError.cellOverlap(worldPosition: worldPosition, cell: cell));
        case CellEmpty():
          break;
      }
    }
    for (final door in structure.doors) {
      if (!structure.cells.contains(door.position)) {
        errors.push(WorldError.doorOutOfStructure(door: door));
        continue;
      }
      if (structure.cells.contains(door.opposite().position)) {
        errors.push(WorldError.doorNotAtBoundary(door: door));
        continue;
      }
    }
    for (final wall in structure.innerWalls) {
      if (!structure.cells.contains(wall.position)) {
        errors.push(WorldError.innerWallOutOfStructure(wall: wall));
        continue;
      }
      if (!structure.cells.contains(wall.opposite().position)) {
        errors.push(WorldError.innerWallAtBoundary(wall: wall));
        continue;
      }
    }
    final placedStairs = <Position>{};
    for (final stair in structure.stairs) {
      if (!structure.cells.contains(stair.position)) {
        errors.push(WorldError.stairOutOfStructure(stair: stair));
        continue;
      }
      if (stair.stairTransport == StairTransport.goUp && (layer.up() == null || !map.containsKey(layer.up()!))) {
        errors.push(WorldError.stairMoveOutOfLayer(stair: stair));
        continue;
      }
      if (stair.stairTransport == StairTransport.goDown && (layer.down() == null || !map.containsKey(layer.down()!))) {
        errors.push(WorldError.stairMoveOutOfLayer(stair: stair));
        continue;
      }
      if (!placedStairs.add(stair.position)) {
        errors.push(WorldError.stairOverlap(stair: stair));
        continue;
      }
    }
    for (final hole in structure.holes) {
      if (!structure.cells.contains(hole.position)) {
        errors.push(WorldError.holeOutOfStructure(hole: hole));
        continue;
      }
      final downLayer = layer.down();
      if (downLayer == null || !map.containsKey(downLayer)) {
        errors.push(WorldError.holeMoveOutOfLayer(hole: hole));
        continue;
      }
      final holeTarget = hole.target();
      final worldTarget = holeTarget.add(originX, originY).rotate(rotation);
      if (_isOutOfWorld(worldTarget.x, worldTarget.y)) {
        errors.push(WorldError.holeOutOfWorld(worldTarget: worldTarget, hole: hole));
        continue;
      }
    }
    if (!errors.isEmpty) {
      throw errors;
    }

    // ---- place ----
    final structureId = _nextStructureId++;
    for (final cell in structure.cells) {
      final worldPosition = cell.add(originX, originY).rotate(rotation);
      _setCell(
          layer,
          worldPosition.x,
          worldPosition.y,
          Cell.structure(
            id: structureId,
            isCorridor: structure.isCorridor,
            isStair: null,
            edgeNorth: EdgeType.nothing,
            edgeEast: EdgeType.nothing,
            edgeSouth: EdgeType.nothing,
            edgeWest: EdgeType.nothing,
          ),
      );
    }
    for (final door in structure.doors) {
      final worldPosition = door.position.add(originX, originY).rotate(rotation);
      final current = cell(layer, worldPosition.x, worldPosition.y)! as CellStructure;
      final updated = current.setEdgeType(door.direction.rotate(rotation), EdgeType.door);
      _setCell(layer, worldPosition.x, worldPosition.y, updated);
    }
    for (final innerWall in structure.innerWalls) {
      for (final wall in [innerWall, innerWall.opposite()]) {
        final worldPosition = wall.position.add(originX, originY).rotate(rotation);
        final current = cell(layer, worldPosition.x, worldPosition.y)! as CellStructure;
        final updated = current.setEdgeType(wall.direction.rotate(rotation), EdgeType.innerWall);
        _setCell(layer, worldPosition.x, worldPosition.y, updated);
      }
    }
    for (final stair in structure.stairs) {
      final worldPosition = stair.position.add(originX, originY).rotate(rotation);
      final current = cell(layer, worldPosition.x, worldPosition.y)! as CellStructure;
      final updated = current.copyWith(isStair: stair.stairTransport);
      _setCell(layer, worldPosition.x, worldPosition.y, updated);
    }
    for (final hole in structure.holes) {
      final worldPosition = hole.position.add(originX, originY).rotate(rotation);
      final current = cell(layer, worldPosition.x, worldPosition.y)! as CellStructure;
      final updated = current.setEdgeType(hole.direction.rotate(rotation), EdgeType.hole);
      _setCell(layer, worldPosition.x, worldPosition.y, updated);
    }
  }

  void _validate() {
    final errors = WorldErrors();
    for (final entrance in entrances) {
      final c = cell(entrance.layer, entrance.position.x, entrance.position.y);
      if (c == null || c is CellEmpty) {
        errors.push(WorldError.entranceInEmpty(entrance: entrance));
      }
    }
    for (final layer in map.keys) {
      for (var x = minX; x <= maxX; x++) {
        for (var y = minY; y <= maxY; y++) {
          final c = cell(layer, x, y)!;
          switch (c) {
            case CellEmpty():
              break;
            case CellStructure():
              for (final direction in Direction.values) {
                switch (c.getEdgeType(direction)) {
                  case EdgeType.nothing:
                    break;
                  case EdgeType.door:
                    final worldDoor = Door(position: Position(x: x, y: y), direction: direction);
                    final oppositeDoor = worldDoor.opposite();
                    final oppositeCell = cell(layer, oppositeDoor.position.x, oppositeDoor.position.y);
                    if (oppositeCell != null && oppositeCell is CellStructure) {
                      if (oppositeCell.getEdgeType(oppositeDoor.direction) != EdgeType.door) {
                        errors.push(WorldError.doorMismatch(worldDoor: worldDoor));
                      }
                    }
                    break;
                  case EdgeType.innerWall:
                    break;
                  case EdgeType.hole:
                    final worldHole = Hole(position: Position(x: x, y: y), direction: direction);
                    final downLayer = layer.down();
                    if (downLayer == null) {
                      errors.push(WorldError.holeMovedMismatch(worldHole: worldHole));
                    } else {
                      final target = worldHole.target();
                      final targetCell = cell(layer, target.x, target.y);
                      if (targetCell is CellStructure) {
                        errors.push(WorldError.holeMismatch(worldHole: worldHole));
                      }
                      final targetMovedCell = cell(downLayer, target.x, target.y);
                      if (targetMovedCell == null || targetMovedCell is CellEmpty) {
                        errors.push(WorldError.holeMovedMismatch(worldHole: worldHole));
                      }
                    }
                    break;
                }
              }
              final isStair = c.isStair;
              if (isStair != null && isStair != StairTransport.nothing) {
                final worldStair = Stair(position: Position(x: x, y: y), stairTransport: isStair);
                final stairIsUp = isStair == StairTransport.goUp;
                final layerMoved = stairIsUp ? layer.up() : layer.down();
                if (layerMoved == null) {
                  errors.push(WorldError.stairMismatch(worldStair: worldStair));
                } else {
                  final targetCell = cell(layerMoved, x, y);
                  if (!(targetCell is CellStructure && targetCell.isStair == isStair.opposite())) {
                    errors.push(WorldError.stairMismatch(worldStair: worldStair));
                  }
                }
              }
          }
        }
      }
    }
    if (!errors.isEmpty) {
      throw errors;
    }
  }
}

@freezed
abstract class StructureInstance with _$StructureInstance {
  const StructureInstance._();
  const factory StructureInstance({
    @JsonKey(name: 'type') required String typeName,
    required GroundLayer layer,
    required int originX,
    required int originY,
    @Default(Rotation.cw0) Rotation rotation,
    Set<Position>? cells,
    Set<Door>? doors,
    Set<Door>? innerWalls,
  }) = _StructureInstance;
  factory StructureInstance.fromJson(Map<String, dynamic> json) => _$StructureInstanceFromJson(json);
}

Structure _resolveStructure(StructureInstance instance, Map<String, Structure> structures) {
  if (instance.typeName == 'corridor') {
    final cells = instance.cells;
    if (cells == null) {
      throw WorldError.corridorMissingCells();
    }
    return Structure(
      isCorridor: true,
      cells: cells,
      doors: instance.doors ?? <Door>{},
      innerWalls: instance.innerWalls ?? <Door>{},
      stairs: <Stair>{},
      holes: <Hole>{},
    );
  }
  final structure = structures[instance.typeName];
  if (structure == null) {
    throw WorldError.unknownStructureType(typeName: instance.typeName);
  }
  return structure;
}

World constructWorld(Map<String, Structure> structures, List<StructureInstance> instances, Set<Entrance> entrances) {
  if (instances.isEmpty) {
    throw WorldErrors(errors: [WorldError.emptyMap()]);
  }
  final layers = <GroundLayer>{};
  int? minX, maxX, minY, maxY;
  final errors = WorldErrors();
  for (final instance in instances) {
    layers.add(instance.layer);
    Structure structure;
    try {
      structure = _resolveStructure(instance, structures);
    } on WorldError catch (e) {
      errors.push(e);
      continue;
    }
    for (final cell in structure.cells) {
      final worldPosition = cell.add(instance.originX, instance.originY).rotate(instance.rotation);
      if (minX == null || worldPosition.x < minX) minX = worldPosition.x;
      if (maxX == null || worldPosition.x > maxX) maxX = worldPosition.x;
      if (minY == null || worldPosition.y < minY) minY = worldPosition.y;
      if (maxY == null || worldPosition.y > maxY) maxY = worldPosition.y;
    }
  }
  if (!errors.isEmpty) {
    throw errors;
  }

  final world = World(layers: layers, minX: minX!, maxX: maxX!, minY:minY!, maxY: maxY!);
  for (final instance in instances) {
    final structure = _resolveStructure(instance, structures);
    try {
      world._placeStructure(instance.layer, structure, instance.originX, instance.originY, instance.rotation);
    } on WorldErrors catch (e) {
      errors.merge(e);
    }
  }
  for (final entrance in entrances) {
    try {
      world._addEntrance(entrance);
    } on WorldError catch (e) {
      errors.push(e);
    }
  }
  try {
    world._validate();
  } on WorldErrors catch (e) {
    errors.merge(e);
  }
  if (!errors.isEmpty) {
    throw errors;
  }

  return world;
}
