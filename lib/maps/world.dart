import 'dart:collection';
import 'dart:convert';

import 'package:idv_map_guides/maps/structure.dart';

class PlacedStructure {
  final int id;
  final StructureDef def;
  final int originX, originY;
  final int rotation;
  final Layer? singleLayer;

  PlacedStructure(this.id, this.def, this.originX, this.originY,
      {this.rotation = 0, this.singleLayer});

  LocalPos toWorld(LocalPos local) {
    final rotated = local.rotate(rotation, def.boundRows, def.boundCols);
    return LocalPos(rotated.row + originY, rotated.col + originX);
  }

  Direction toWorldDirection(Direction localDirection) {
    Direction d = localDirection;
    for (int i = 0; i < rotation; i++) {
      d = d.rotate90CW();
    }
    return d;
  }

  Set<LocalPos> worldCells(Layer layer) {
    if (!def.isDouble && singleLayer != layer) return createPosSet();
    return createPosSet()..addAll(def.cells(layer).map(toWorld));
  }

  Set<DoorDef> worldDoors(Layer layer) {
    if (!def.isDouble && singleLayer != layer) return createDoorSet();
    return createDoorSet()..addAll(def.doors(layer).map((d) => DoorDef(toWorld(d.pos), toWorldDirection(d.facing))));
  }
}

class CellInfo {
  int? structureId;
  bool isCorridor = false;
  Set<Direction> doors = {};
}

class MapModel {
  final int width, height;
  final Map<Layer, List<List<CellInfo>>> grids;
  final List<PlacedStructure> structures = [];
  final List<String> errors = [];

  MapModel(this.width, this.height): grids = HashMap.fromEntries(
    Layer.values.map((l) => MapEntry(l, List.generate(height, (_) => List.generate(width, (_) => CellInfo()))))
  );

  bool placeStructure(PlacedStructure ps) {
    for (final layer in Layer.values) {
      final cells = ps.worldCells(layer);
      for (final c in cells) {
        if (c.row < 0 || c.row >= height || c.col < 0 || c.col >= width) {
          errors.add('Structure ${ps.id} out of world.');
          return false;
        }
      }
    }

    for (final layer in Layer.values) {
      final grid = grids[layer]!;
      final cells = ps.worldCells(layer);
      for (final c in cells) {
        if (grid[c.row][c.col].structureId != null) {
          errors.add('Overlap at layer $layer (${c.row},${c.col})');
          return false;
        }
      }
    }

    for (final layer in Layer.values) {
      final grid = grids[layer]!;
      for (final c in ps.worldCells(layer)) {
        grid[c.row][c.col].structureId = ps.id;
        grid[c.row][c.col].isCorridor = ps.def.isCorridor;
      }
      for (final d in ps.worldDoors(layer)) {
        grid[d.pos.row][d.pos.col].doors.add(d.facing);
      }
    }

    structures.add(ps);
    return true;
  }

  void validateDoors() {
    for (final layer in Layer.values) {
      final grid = grids[layer]!;
      for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
          final cell = grid[row][col];
          for (final dir in cell.doors) {
            final ny = row + dir.dy;
            final nx = col + dir.dx;
            if (ny < 0 || ny >= height || nx < 0 || nx >= width) continue;
            final neighbor = grid[ny][nx];
            if (neighbor.structureId == null) continue;
            if (neighbor.structureId == cell.structureId) {
              errors.add('Door inside structure at ($row,$col) facing ${dir.name}');
            }
            if (!neighbor.doors.contains(dir.opposite)) {
              errors.add('Door mismatch at ($row,$col) facing ${dir.name}');
            }
          }
        }
      }
    }
  }
}

MapModel parseJson(String source) {
  final data = json.decode(source);
  final w = data['width'] as int;
  final h = data['height'] as int;
  final map = MapModel(w, h);
  var idCounter = 1;

  for (final s in data['structures']) {
    final id = idCounter++;
    final type = s['type'] as String;
    final ox = s['originX'] ?? 0;
    final oy = s['originY'] ?? 0;
    final rot = s['rotation'] ?? 0;
    Layer? layer;
    if (s.containsKey('layer')) {
      layer = s['layer'] == 'upper' ? Layer.upper : Layer.lower;
    }

    StructureDef def;
    switch (type) {
      case 'corridor':
        final path = (s['cells'] as List).map((c) {
          final arr = c as List;
          return LocalPos(arr[0] as int, arr[1] as int);
        }).toSet();
        final doors = (s['doors'] as List).map((d) => DoorDef(
          LocalPos(d['row'], d['col']),
          parseDirection(d['facing']),
        )).toSet();
        def = CorridorDef(path, doors);
        break;
      case 'stair_2x2':
        def = Stair2x2Def();
        break;
      case 'stair_3x3_t':
        def = Stair3x3TDef();
        break;
      case 'stair_3x3_o':
        def = Stair3x3ODef();
        break;
      case 'y_corridor':
        def = YCorridorDef();
        break;
      case 'center_corridor':
        def = CenterCorridorDef();
        break;
      case 'main_entrance':
        def = MainEntranceDef();
        break;
      case 'muse_room':
        def = MuseRoomDef();
        break;
      case 'bed_room':
        def = BedRoomDef();
        break;
      case 'five_bed_room':
        def = FiveBedRoomDef();
        break;
      case 'meeting_room':
        def = MeetingRoomDef();
        break;
      case 'restaurant_room':
        def = RestaurantRoomDef();
        break;
      case 'corner_room_a':
        def = CornerRoomADef();
        break;
      case 'corner_room_b':
        def = CornerRoomBDef();
        break;
      case 'center_room':
        def = CenterRoomDef();
        break;
      case 'safe_room':
        def = SafeRoomDef();
        break;
      case 'stair_room':
        def = StairRoomDef();
        break;
      case 't_room':
        def = TRoomDef();
        break;
      case 'lantern_room':
        def = LanternRoomDef();
        break;
      default:
        throw ArgumentError('Unknown structure type: $type');
    }

    final ps = PlacedStructure(id, def, ox, oy, rotation: rot, singleLayer: layer);
    map.placeStructure(ps);
  }
  map.validateDoors();
  return map;
}
