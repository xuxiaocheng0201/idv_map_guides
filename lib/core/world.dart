import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/errors.dart';

part 'world.freezed.dart';

@Freezed(addImplicitFinal: false)
abstract class Cell with _$Cell {
  Cell._();
  factory Cell({
    int? structureId,
    String? structureTypeName,
    @Default(false) bool isCorridor,
    @Default(CellInfo(
      isStair: null,
      edgeNorth: EdgeType.nothing,
      edgeEast: EdgeType.nothing,
      edgeSouth: EdgeType.nothing,
      edgeWest: EdgeType.nothing,
    )) CellInfo info,
  }) = _Cell;
}

enum EntranceType {
  main,
  sideGround,
  sideSecond,
  alterBasement;

  bool get displayable => switch (this) {
    EntranceType.main => true,
    EntranceType.sideGround => true,
    EntranceType.sideSecond => true,
    EntranceType.alterBasement => false,
  };
  GroundLayer layer() => switch (this) {
    EntranceType.main => GroundLayer.ground,
    EntranceType.sideGround => GroundLayer.ground,
    EntranceType.sideSecond => GroundLayer.second,
    EntranceType.alterBasement => GroundLayer.basement,
  };
}

class World {
  final int minX, maxX, minY, maxY;
  Map<GroundLayer, List<List<Cell>>> map;
  Map<EntranceType, Position> entrances;
  int _nextStructureId;
  Set<int> suspiciousStructures = <int>{};
  Set<int> resources = <int>{};
  Map<String, Set<int>> rooms = <String, Set<int>>{};

  World({
    required Set<GroundLayer> layers,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  }): map = {
        for (final layer in layers)
          layer: List.generate(maxX - minX + 1, (_) => List.generate(maxY - minY + 1, (_) => Cell())),
      },
      entrances = <EntranceType, Position>{},
      _nextStructureId = 0;

  Set<GroundLayer> get layers => map.keys.toSet();
  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;

  bool _isOutOfWorld(int x, int y) => x < minX || maxX < x || y < minY || maxY < y;

  Cell? cell(GroundLayer layer, int x, int y) {
    if (_isOutOfWorld(x, y)) return null;
    return map[layer]?[x - minX][y - minY];
  }


  int placeStructure(GroundLayer layer, Structure structure, int originX, int originY, Rotation rotation) {
    // validate
    final errors = WorldErrors(errors: <WorldError>[]);
    if (structure.isNoDirection && !{Rotation.cw0, Rotation.cw90}.contains(rotation)) {
      errors.push(WorldError.directionNotAllowed());
    }
    final downLayer = switch (layer.down()) { final k? => map.containsKey(k) ? k : null, _ => null };
    final upLayer = switch (layer.up()) { final k? => map.containsKey(k) ? k : null, _ => null };
    for (final entry in structure.cells.entries) {
      final (position, info) = (entry.key, entry.value);
      final worldPosition = position.toWorld(rotation, originX, originY);
      final existing = cell(layer, worldPosition.x, worldPosition.y);
      switch (existing) {
        case null:
          errors.push(WorldError.cellOutOfWorld(worldPosition: worldPosition));
          break;
        case Cell(:final structureId):
          if (structureId != null) {
            errors.push(WorldError.cellOverlap(worldPosition: worldPosition));
            break;
          }
          for (final direction in Direction.values) {
            final edge = Edge(position: position, direction: direction);
            final worldEdge = Edge(position: worldPosition, direction: direction.rotate(rotation));
            switch (info.getEdgeType(direction)) {
              case EdgeType.nothing:
                break;
              case EdgeType.door:
                if (structure.cells.containsKey(edge.opposite().position)) {
                  errors.push(WorldError.doorNotAtBoundary(worldDoor: worldEdge));
                }
                break;
              case EdgeType.innerWall:
                if (!structure.cells.containsKey(edge.opposite().position)) {
                  errors.push(WorldError.innerWallAtBoundary(worldWall: worldEdge));
                }
                break;
              case EdgeType.hole:
                if (downLayer == null) {
                  errors.push(WorldError.holeMoveOutOfLayer(worldHole: worldEdge));
                }
                final worldTarget = worldEdge.opposite().position;
                if (_isOutOfWorld(worldTarget.x, worldTarget.y)) {
                  errors.push(WorldError.holeOutOfWorld(worldHole: worldEdge));
                }
                break;
            }
          }
          switch (info.isStair) {
            case null:
              break;
            case StairTransport.nothing:
              break;
            case StairTransport.goUp:
              if (upLayer == null) {
                errors.push(WorldError.stairMoveOutOfLayer(worldStair: worldPosition));
              }
              break;
            case StairTransport.goDown:
              if (downLayer == null) {
                errors.push(WorldError.stairMoveOutOfLayer(worldStair: worldPosition));
              }
              break;
          }
          break;
      }
    }
    if (!errors.isEmpty) {
      throw errors;
    }
    // place
    final structureId = _nextStructureId++;
    for (final entry in structure.cells.entries) {
      final (position, info) = (entry.key, entry.value);
      final worldPosition = position.toWorld(rotation, originX, originY);
      final existing = cell(layer, worldPosition.x, worldPosition.y)!;
      existing.structureId = structureId;
      existing.structureTypeName = structure.name;
      existing.isCorridor = structure.isCorridor;
      existing.info = info.rotation(rotation);
    }
    if (structure.isResource) resources.add(structureId);
    if (!structure.isCorridor) rooms.putIfAbsent(structure.name, () => <int>{}).add(structureId);
    return structureId;
  }

  void validate({required bool replaceStructureMismatchedDoor}) {
    final errors = WorldErrors(errors: <WorldError>[]);
    if (entrances.isEmpty) {
      errors.push(WorldError.entranceMissing());
    }
    for (final entry in entrances.entries) {
      final (type, entrance) = (entry.key, entry.value);
      final layer = type.layer();
      final c = cell(layer, entrance.x, entrance.y);
      if (c == null || c.structureId == null) {
        errors.push(WorldError.entranceInEmpty(type: type, entrance: entrance));
      }
    }
    for (final layer in map.keys) {
      for (var x = minX; x <= maxX; x++) {
        for (var y = minY; y <= maxY; y++) {
          final worldPosition = Position(x: x, y: y);
          final c = cell(layer, x, y)!;
          for (final direction in Direction.values) {
            final worldEdge = Edge(position: worldPosition, direction: direction);
            switch (c.info.getEdgeType(direction)) {
              case EdgeType.nothing:
                break;
              case EdgeType.door:
                final oppositeDoor = worldEdge.opposite();
                final oppositeCell = cell(layer, oppositeDoor.position.x, oppositeDoor.position.y);
                if (oppositeCell == null || oppositeCell.structureId == null || oppositeCell.info.getEdgeType(oppositeDoor.direction) != EdgeType.door) {
                  if (c.structureTypeName == corridorTypeName) {
                    errors.push(WorldError.doorMismatch(layer: layer, worldDoor: worldEdge));
                  } else {
                    if (replaceStructureMismatchedDoor) {
                      c.info = c.info.setEdgeType(direction, EdgeType.nothing);
                    }
                  }
                }
                break;
              case EdgeType.innerWall:
                break;
              case EdgeType.hole:
                final downLayer = layer.down()!;
                final targetPosition = worldEdge.opposite().position;
                final targetCell = cell(layer, targetPosition.x, targetPosition.y)!;
                if (targetCell.structureId == null) {
                  errors.push(WorldError.holeMismatch(layer: layer, worldHole: worldEdge));
                }
                final targetMovedCell = cell(downLayer, targetPosition.x, targetPosition.y)!;
                if (targetMovedCell.structureId == null) {
                  errors.push(WorldError.holeMovedMismatch(layer: layer, worldHole: worldEdge));
                }
                break;
            }
          }
          switch (c.info.isStair) {
            case null:
              break;
            case StairTransport.nothing:
              break;
            case StairTransport.goUp:
              final upLayer = layer.up()!;
              final targetCell = cell(upLayer, worldPosition.x, worldPosition.y)!;
              if (targetCell.structureId == null || targetCell.info.isStair != StairTransport.goDown) {
                errors.push(WorldError.stairMismatch(layer: layer, worldStair: worldPosition));
              }
              break;
            case StairTransport.goDown:
              final downLayer = layer.down()!;
              final targetCell = cell(downLayer, worldPosition.x, worldPosition.y)!;
              if (targetCell.structureId == null || targetCell.info.isStair != StairTransport.goUp) {
                errors.push(WorldError.stairMismatch(layer: layer, worldStair: worldPosition));
              }
              break;
          }
        }
      }
    }
    if (!errors.isEmpty) {
      throw errors;
    }
  }
}

@Freezed(addImplicitFinal: false, makeCollectionsUnmodifiable: false)
abstract class StructureInstance with _$StructureInstance {
  StructureInstance._();
  factory StructureInstance({
    @JsonKey(name: 'type') required String typeName,
    @Default(false) bool isSuspicious,
    required GroundLayer layer,
    required int originX,
    required int originY,
    @Default(Rotation.cw0) Rotation rotation,
    Map<Position, CellInfo>? cells,
  }) = _StructureInstance;
}

const corridorTypeName = 'corridor';

Structure resolveStructure(StructureInstance instance, Map<String, Structure> structures) {
  if (instance.typeName == corridorTypeName) {
    final cells = instance.cells;
    if (cells == null || cells.isEmpty) {
      throw WorldError.corridorMissingCells();
    }
    return Structure(
      name: corridorTypeName,
      isCorridor: true,
      isResource: false,
      isNoDirection: true,
      cells: cells,
    );
  }
  final structure = structures[instance.typeName];
  if (structure == null) {
    throw WorldError.unknownStructureType(typeName: instance.typeName);
  }
  return structure;
}

@Freezed(addImplicitFinal: false, makeCollectionsUnmodifiable: false)
abstract class WorldFile with _$WorldFile {
  WorldFile._();
  factory WorldFile({
    required Set<GroundLayer> layers,
    required int minX,
    required int maxX,
    required int minY,
    required int maxY,
    required List<StructureInstance> instances,
    required Map<EntranceType, Position> entrances,
  }) = _WorldFile;
}

World constructWorld(Map<String, Structure> structures, WorldFile worldFile) {
  if (worldFile.instances.isEmpty) {
    throw WorldErrors(errors: [WorldError.emptyMap()]);
  }
  final errors = WorldErrors(errors: <WorldError>[]);
  final world = World(layers: worldFile.layers, minX: worldFile.minX, maxX: worldFile.maxX, minY: worldFile.minY, maxY: worldFile.maxY);
  for (final instance in worldFile.instances) {
    Structure structure;
    try {
      structure = resolveStructure(instance, structures);
    } on WorldError catch (e) {
      errors.push(e);
      continue;
    }
    try {
      final structureId = world.placeStructure(instance.layer, structure, instance.originX, instance.originY, instance.rotation);
      if (instance.isSuspicious) world.suspiciousStructures.add(structureId);
    } on WorldErrors catch (e) {
      errors.merge(e);
    }
  }
  world.entrances = worldFile.entrances;
  try {
    world.validate(replaceStructureMismatchedDoor: true);
  } on WorldErrors catch (e) {
    errors.merge(e);
  }
  if (!errors.isEmpty) {
    throw errors;
  }
  return world;
}
