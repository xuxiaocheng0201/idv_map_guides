import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/entrance.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/feature.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/layer.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/serde.dart';

B1EntranceFeature _inferB1Feature(World world, PhosphorescenceDiseaseEntranceType entrance) {
  assert (switch (entrance) {
    PhosphorescenceDiseaseEntranceType.entranceLeft || PhosphorescenceDiseaseEntranceType.entranceRight => true,
    _ => false,
  });
  final position = world.entrances[entrance]!.position;
  final direction = switch (entrance) {
    PhosphorescenceDiseaseEntranceType.entranceLeft => Direction.east,
    PhosphorescenceDiseaseEntranceType.entranceRight => Direction.west,
    _ => throw StateError('invalid entrance type'),
  };
  var cells = 0;
  var pos = position;
  while (true) {
    final (dx, dy) = direction.dxy;
    final next = pos.add(dx, dy);
    final cell = world.cell(entrance.layer, next.x, next.y);
    if (cell == null || cell.structureId == null) break;
    if (cell.structureTypeName != corridorTypeName) break;
    cells += 1;
    pos = next;
  }
  return B1EntranceFeature(cells: cells);
}

B2EntranceFeature _inferB2Feature(World world, PhosphorescenceDiseaseEntranceType entrance) {
  assert (switch (entrance) {
    PhosphorescenceDiseaseEntranceType.entranceRailway => true,
    _ => false,
  });
  final position = world.entrances[entrance]!.position;
  final entranceId = world.cell(entrance.layer, position.x, position.y)!.structureId!;
  const corridorCurveTypeName = 'corridor_curve';
  final uponCell = world.cell(entrance.layer, position.x, position.y + 2);
  B2EntranceFeatureType leftType, downType, rightType;
  if (uponCell != null && uponCell.structureId == entranceId) {
    // common case: rotation 0cw
    final leftCell = world.cell(entrance.layer, position.x - 2, position.y);
    if (leftCell == null || leftCell.structureId == null || leftCell.info.edgeEast != EdgeType.door) {
      leftType = B2EntranceFeatureType.none;
    } else {
      switch (leftCell.structureTypeName) {
        case corridorTypeName:
          leftType = B2EntranceFeatureType.straight;
          break;
        case corridorCurveTypeName:
          final leftUpon = world.cell(entrance.layer, position.x - 3, position.y + 1);
          if (leftUpon != null && leftUpon.structureId == leftCell.structureId) {
            leftType = B2EntranceFeatureType.bentUpward;
          } else {
            leftType = B2EntranceFeatureType.bentDownward;
          }
          break;
        default:
          throw UnimplementedError();
      }
    }

    final rightCell = world.cell(entrance.layer, position.x + 2, position.y);
    if (rightCell == null || rightCell.structureId == null || rightCell.info.edgeWest != EdgeType.door) {
      rightType = B2EntranceFeatureType.none;
    } else {
      switch (rightCell.structureTypeName) {
        case corridorTypeName:
          rightType = B2EntranceFeatureType.straight;
          break;
        case corridorCurveTypeName:
          final rightUpon = world.cell(entrance.layer, position.x + 3, position.y + 1);
          if (rightUpon != null && rightUpon.structureId == rightCell.structureId) {
            rightType = B2EntranceFeatureType.bentUpward;
          } else {
            rightType = B2EntranceFeatureType.bentDownward;
          }
          break;
        default:
          throw UnimplementedError();
      }
    }

    final downCell = world.cell(entrance.layer, position.x, position.y - 2);
    if (downCell == null || downCell.structureId == null || downCell.info.edgeNorth != EdgeType.door) {
      downType = B2EntranceFeatureType.none;
    } else {
      switch (downCell.structureTypeName) {
        case corridorTypeName:
          downType = B2EntranceFeatureType.straight;
          break;
        case corridorCurveTypeName:
          final downLeft = world.cell(entrance.layer, position.x - 1, position.y - 3);
          if (downLeft != null && downLeft.structureId == downCell.structureId) {
            downType = B2EntranceFeatureType.bentLeftward;
          } else {
            downType = B2EntranceFeatureType.bentRightward;
          }
          break;
        default:
          throw UnimplementedError();
      }
    }
  } else {
    throw UnimplementedError();
  }
  return B2EntranceFeature(leftType: leftType, downType: downType, rightType: rightType);
}

EntranceFeature _inferEntranceFeature(World world, PhosphorescenceDiseaseEntranceType entrance) {
  return switch (entrance) {
    PhosphorescenceDiseaseEntranceType.entranceLeft ||
    PhosphorescenceDiseaseEntranceType.entranceRight => PhosphorescenceDiseaseEntranceFeature.b1(_inferB1Feature(world, entrance)),
    PhosphorescenceDiseaseEntranceType.entranceRailway => PhosphorescenceDiseaseEntranceFeature.b2(_inferB2Feature(world, entrance)),
    PhosphorescenceDiseaseEntranceType.main ||
    PhosphorescenceDiseaseEntranceType.minecartB2A ||
    PhosphorescenceDiseaseEntranceType.minecartB2B ||
    PhosphorescenceDiseaseEntranceType.minecartB3A ||
    PhosphorescenceDiseaseEntranceType.minecartB3B ||
    PhosphorescenceDiseaseEntranceType.minecartTransported => throw StateError('invalid entrance type'),
  };
}

enum PhosphorescenceDiseaseNightmareWorlds implements BaseWorldsEnums {
  map1,
  map2,
  map3,
  map4,
  map5,
  map6,
  map7,
  map8,
  map9,
  map10,
  map11,
  map12,
  map13,
  map14,
  map15;

  int get _assertIndex => switch (this) {
    PhosphorescenceDiseaseNightmareWorlds.map1 => 1,
    PhosphorescenceDiseaseNightmareWorlds.map2 => 2,
    PhosphorescenceDiseaseNightmareWorlds.map3 => 3,
    PhosphorescenceDiseaseNightmareWorlds.map4 => 4,
    PhosphorescenceDiseaseNightmareWorlds.map5 => 5,
    PhosphorescenceDiseaseNightmareWorlds.map6 => 6,
    PhosphorescenceDiseaseNightmareWorlds.map7 => 7,
    PhosphorescenceDiseaseNightmareWorlds.map8 => 8,
    PhosphorescenceDiseaseNightmareWorlds.map9 => 9,
    PhosphorescenceDiseaseNightmareWorlds.map10 => 10,
    PhosphorescenceDiseaseNightmareWorlds.map11 => 11,
    PhosphorescenceDiseaseNightmareWorlds.map12 => 12,
    PhosphorescenceDiseaseNightmareWorlds.map13 => 13,
    PhosphorescenceDiseaseNightmareWorlds.map14 => 14,
    PhosphorescenceDiseaseNightmareWorlds.map15 => 15,
  };
}

class PhosphorescenceDiseaseWorldsNightmareProvider extends WorldsProvider<PhosphorescenceDiseaseNightmareWorlds> {
  @override WorldType get type => WorldType.phosphorescenceDisease;
  @override WorldDifficulty get difficulty => WorldDifficulty.nightmare;
  @override WorldCodec get codec => phosphorescenceDiseaseCodec;
  @override List<PhosphorescenceDiseaseNightmareWorlds> get allWorlds => PhosphorescenceDiseaseNightmareWorlds.values;
  @override List<GroundLayer> get allLayers => const <GroundLayer>[
    PhosphorescenceDiseaseLayer.level1,
    PhosphorescenceDiseaseLayer.level2,
    PhosphorescenceDiseaseLayer.level3,
  ];
  @override List<EntranceType> get validEntrances => const <EntranceType>[
    PhosphorescenceDiseaseEntranceType.entranceLeft,
    PhosphorescenceDiseaseEntranceType.entranceRight,
    PhosphorescenceDiseaseEntranceType.entranceRailway,
  ];
  @override String worldAssets(PhosphorescenceDiseaseNightmareWorlds world) => 'world_${world._assertIndex}.data';
  @override EntranceFeature inferEntranceFeature(World world, EntranceType entrance) => _inferEntranceFeature(world, entrance as PhosphorescenceDiseaseEntranceType);

  @override
  NavigateArguments navigateArguments(World world, EntranceType entrance) {
    final entranceNode = world.entranceNode(entrance)!;
    final exitNodes = <EntranceType, Node>{};
    for (final entry in world.entrances.entries) {
      if (!entry.key.displayable) continue;
      exitNodes[entry.key] = Node(entry.key.layer, entry.value.x, entry.value.y);
    }
    return NavigateArguments(
      start: entranceNode,
      resources: Set.of(world.resources),
      exits: exitNodes.values.toSet(),
    );
  }
}
