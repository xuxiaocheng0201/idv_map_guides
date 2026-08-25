import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/errors.dart';

part 'world.freezed.dart';
part 'world.g.dart';

@Freezed(addImplicitFinal: false)
abstract class Cell with _$Cell {
  Cell._();
  factory Cell({
    int? id,
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
          layer: List.generate(maxX - minX + 1, (_) => List.generate(maxY - minY + 1, (_) => Cell())),
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


  void _addEntrance(Entrance entrance) {
    if (!map.containsKey(entrance.layer) || _isOutOfWorld(entrance.position.x, entrance.position.y)) {
      throw WorldError.entranceOutOfWorld(entrance: entrance);
    }
    entrances.add(entrance);
  }

  void _placeStructure(GroundLayer layer, Structure structure, int originX, int originY, Rotation rotation) {
    // validate
    final errors = WorldErrors();
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
        case Cell(:final id):
          if (id != null) {
            errors.push(WorldError.cellOverlap(worldPosition: worldPosition));
            break;
          }
          for (final direction in Direction.values) {
            final edge = Edge(position: position, direction: direction);
            final worldEdge = Edge(position: worldPosition, direction: direction);
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
      existing.id = structureId;
      existing.isCorridor = structure.isCorridor;
      existing.info = info;
    }
  }

  void _validate() {
    final errors = WorldErrors();
    for (final entrance in entrances) {
      final c = cell(entrance.layer, entrance.position.x, entrance.position.y);
      if (c == null || c.id == null) {
        errors.push(WorldError.entranceInEmpty(entrance: entrance));
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
                if (oppositeCell != null && oppositeCell.id != null && oppositeCell.info.getEdgeType(oppositeDoor.direction) != EdgeType.door) {
                  errors.push(WorldError.doorMismatch(worldDoor: worldEdge));
                }
                break;
              case EdgeType.innerWall:
                break;
              case EdgeType.hole:
                final downLayer = layer.down()!;
                final targetPosition = worldEdge.opposite().position;
                final targetCell = cell(layer, targetPosition.x, targetPosition.y)!;
                if (targetCell.id == null) {
                  errors.push(WorldError.holeMismatch(worldHole: worldEdge));
                }
                final targetMovedCell = cell(downLayer, targetPosition.x, targetPosition.y)!;
                if (targetMovedCell.id == null) {
                  errors.push(WorldError.holeMovedMismatch(worldHole: worldEdge));
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
              if (targetCell.id == null || targetCell.info.isStair != StairTransport.goDown) {
                errors.push(WorldError.stairMismatch(worldStair: worldPosition));
              }
              break;
            case StairTransport.goDown:
              final downLayer = layer.down()!;
              final targetCell = cell(downLayer, worldPosition.x, worldPosition.y)!;
              if (targetCell.id == null || targetCell.info.isStair != StairTransport.goUp) {
                errors.push(WorldError.stairMismatch(worldStair: worldPosition));
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

@freezed
abstract class StructureInstance with _$StructureInstance {
  const StructureInstance._();
  const factory StructureInstance({
    @JsonKey(name: 'type') required String typeName,
    required GroundLayer layer,
    required int originX,
    required int originY,
    @Default(Rotation.cw0) Rotation rotation,
    @CellsMapConverter() Map<Position, CellInfo>? cells,
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
    for (final cell in structure.cells.keys) {
      final worldPosition = cell.toWorld(instance.rotation, instance.originX, instance.originY);
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
