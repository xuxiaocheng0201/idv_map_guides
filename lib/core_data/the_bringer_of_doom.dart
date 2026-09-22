import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';

MainEntranceFeature _inferMainFeature(World world, EntranceType entrance) {
  final position = world.entrances[entrance]!.position;
  final mainEntranceId = world.cell(entrance.layer, position.x, position.y)!.structureId!;
  final upDoor = position.add(0, 4);
  final leftDoor = position.add(-1, 1);
  final rightDoor = position.add(1, 1);
  final upDoorCell = world.cell(entrance.layer, upDoor.x, upDoor.y)!;
  final leftDoorCell = world.cell(entrance.layer, leftDoor.x, leftDoor.y)!;
  final rightDoorCell = world.cell(entrance.layer, rightDoor.x, rightDoor.y)!;
  return MainEntranceFeature(
    hasUpDoor: upDoorCell.structureId == mainEntranceId && upDoorCell.info.edgeNorth == EdgeType.door,
    hasLeftDoor: leftDoorCell.structureId == mainEntranceId && leftDoorCell.info.edgeWest == EdgeType.door,
    hasRightDoor: rightDoorCell.structureId == mainEntranceId && rightDoorCell.info.edgeEast == EdgeType.door,
  );
}

SideEntranceFeature _inferSideFeature(World world, EntranceType entrance) {
  final position = world.entrances[entrance]!.position;
  final sideEntranceId = world.cell(entrance.layer, position.x, position.y)!.structureId!;
  Direction? facing;
  for (final direction in Direction.values) {
    final (dx, dy) = direction.dxy;
    final facingPosition = position.add(dx, dy);
    final facingCell = world.cell(entrance.layer, facingPosition.x, facingPosition.y);
    if (facingCell?.structureId == sideEntranceId) {
      if (facing == null) {
        facing = direction;
      } else {
        return SideEntranceFeature.other;
      }
    }
  }
  if (facing == null) {
    for (final direction in Direction.values) {
      final (dx, dy) = direction.dxy;
      final facingPosition = position.add(dx, dy);
      final facingCell = world.cell(entrance.layer, facingPosition.x, facingPosition.y);
      if (facingCell != null) {
        if (facing == null) {
          facing = direction;
        } else {
          return SideEntranceFeature.other;
        }
      }
    }
    if (facing == null) {
      return SideEntranceFeature.other;
    }
  }
  return switch (facing) {
    Direction.north => SideEntranceFeature.south,
    Direction.east => SideEntranceFeature.west,
    Direction.south => SideEntranceFeature.north,
    Direction.west => SideEntranceFeature.east,
  };
}

NavigateArguments _navigateArguments(World world, EntranceType entrance) {
  final entrancePos = world.entrances[entrance]!.position;
  final startNode = Node(entrance.layer, entrancePos.x, entrancePos.y);
  final resources = Set.of(world.resources);
  final exitNodes = <Node>{};
  for (final entry in world.entrances.entries) {
    if (!entry.key.displayable) continue;
    final node = Node(entry.key.layer, entry.value.x, entry.value.y);
    exitNodes.add(node);
  }
  return NavigateArguments(start: startNode, resources: resources, exits: exitNodes);
}

enum TheBringerOfDoomNoviceWorlds implements BaseWorldsEnums {
  onlyOne,
}

class TheBringerOfDoomNoviceWorldsProvider extends WorldsProvider<TheBringerOfDoomNoviceWorlds> {
  @override WorldType get type => WorldType.theBringerOfDoom;
  @override WorldDifficulty get difficulty => WorldDifficulty.novice;
  @override List<TheBringerOfDoomNoviceWorlds> get allWorlds => TheBringerOfDoomNoviceWorlds.values;
  @override List<EntranceType> get validEntrances => const <EntranceType>[EntranceType.main];
  @override String worldAssets(TheBringerOfDoomNoviceWorlds world) => 'world.data';
  @override MainEntranceFeature inferMainEntranceFeature(World world, EntranceType entrance) => _inferMainFeature(world, entrance);
  @override SideEntranceFeature inferSideEntranceFeature(World world, EntranceType entrance) => _inferSideFeature(world, entrance);
  @override NavigateArguments navigateArguments(World world, EntranceType entrance) => _navigateArguments(world, entrance);
}

enum TheBringerOfDoomHardWorlds implements BaseWorldsEnums {
  north1,
  north1Sofa,
  north4,
  north4Safe,
  northT,
  northConcave,
  northRed,
  northRedDiagonal,
  southL,
  southOrz,
  southThreeMissingOne,
  southCross,
  southRed,
  eastL,
  eastThreeL,
  eastTwoL,
  eastForfeit,
  eastHammer,
  eastStair,
  westY,
  westYFrog,
  westFlipT,
  westOppositeT,
  westDiagonal,
  westPots,
  westHammer1,
  westHammer2,
  westHammerLantern,
  westFork;

  String get _assets => switch (this) {
    north1 => 'north_1',
    north1Sofa => 'north_1_sofa',
    north4 => 'north_4',
    north4Safe => 'north_4_safe',
    northT => 'north_t',
    northConcave => 'north_concave',
    northRed => 'north_red',
    northRedDiagonal => 'north_red_diagonal',
    southL => 'south_l',
    southOrz => 'south_orz',
    southThreeMissingOne => 'south_three_missing_one',
    southCross => 'south_cross',
    southRed => 'south_red',
    eastL => 'east_l',
    eastThreeL => 'east_three_l',
    eastTwoL => 'east_two_l',
    eastForfeit => 'east_forfeit',
    eastHammer => 'east_hammer',
    eastStair => 'east_stair',
    westY => 'west_y',
    westYFrog => 'west_y_frog',
    westFlipT => 'west_flip_t',
    westOppositeT => 'west_opposite_t',
    westDiagonal => 'west_diagonal',
    westPots => 'west_pots',
    westHammer1 => 'west_hammer_1',
    westHammer2 => 'west_hammer_2',
    westHammerLantern => 'west_hammer_lantern',
    westFork => 'west_fork',
  };
}

class TheBringerOfDoomHardWorldsProvider extends WorldsProvider<TheBringerOfDoomHardWorlds> {
  @override WorldType get type => WorldType.theBringerOfDoom;
  @override WorldDifficulty get difficulty => WorldDifficulty.hard;
  @override List<TheBringerOfDoomHardWorlds> get allWorlds => TheBringerOfDoomHardWorlds.values;
  @override List<EntranceType> get validEntrances => const <EntranceType>[EntranceType.main, EntranceType.sideGround, EntranceType.sideSecond];
  @override String worldAssets(TheBringerOfDoomHardWorlds world) => 'world_${world._assets}.data';
  @override MainEntranceFeature inferMainEntranceFeature(World world, EntranceType entrance) => _inferMainFeature(world, entrance);
  @override SideEntranceFeature inferSideEntranceFeature(World world, EntranceType entrance) => _inferSideFeature(world, entrance);
  @override NavigateArguments navigateArguments(World world, EntranceType entrance) => _navigateArguments(world, entrance);
}

enum TheBringerOfDoomInsaneWorlds implements BaseWorldsEnums {
  northB,
  northZ1,
  northCactus,
  northLoop,
  northStair,
  southThreeRed,
  southH,
  southFloating,
  eastC,
  east1Lightning,
  eastCactus,
  eastBreakC,
  eastShortT,
  eastLongZ,
  west11,
  westFlipT,
  west1BookGallery,
  west1Corner,
  west5Bed,
  westVerticalL,
  westStair;

  String get _assets => switch (this) {
    northB => 'north_b',
    northZ1 => 'north_z_1',
    northCactus => 'north_cactus',
    northLoop => 'north_loop',
    northStair => 'north_stair',
    southThreeRed => 'south_three_red',
    southH => 'south_h',
    southFloating => 'south_floating',
    eastC => 'east_c',
    east1Lightning => 'east_1_lightning',
    eastCactus => 'east_cactus',
    eastBreakC => 'east_break_c',
    eastShortT => 'east_short_t',
    eastLongZ => 'east_long_z',
    west11 => 'west_11',
    westFlipT => 'west_flip_t',
    west1BookGallery => 'west_1_book_gallery',
    west1Corner => 'west_1_corner',
    west5Bed => 'west_5_bed',
    westVerticalL => 'west_vertical_l',
    westStair => 'west_stair',
  };
}

class TheBringerOfDoomInsaneWorldsProvider extends WorldsProvider<TheBringerOfDoomInsaneWorlds> {
  @override WorldType get type => WorldType.theBringerOfDoom;
  @override WorldDifficulty get difficulty => WorldDifficulty.insane;
  @override List<TheBringerOfDoomInsaneWorlds> get allWorlds => TheBringerOfDoomInsaneWorlds.values;
  @override List<EntranceType> get validEntrances => const <EntranceType>[EntranceType.main, EntranceType.sideSecond];
  @override String worldAssets(TheBringerOfDoomInsaneWorlds world) => 'world_${world._assets}.data';
  @override MainEntranceFeature inferMainEntranceFeature(World world, EntranceType entrance) => _inferMainFeature(world, entrance);
  @override SideEntranceFeature inferSideEntranceFeature(World world, EntranceType entrance) => _inferSideFeature(world, entrance);
  @override
  NavigateArguments navigateArguments(World world, EntranceType entrance) {
    final origin = _navigateArguments(world, entrance);
    final museRoomId = world.rooms['muse_room']!.firstOrNull!;
    Node? museRoomNode;
    find: for (int x = world.minX; x <= world.maxX; x++) {
      for (int y = world.minY; y <= world.maxY; y++) {
        final cell = world.cell(GroundLayer.ground, x, y)!;
        if (cell.structureId == museRoomId && cell.info.isResource) {
          museRoomNode = Node(GroundLayer.ground, x, y);
          break find;
        }
      }
    }
    final alterNode = world.entranceNode(EntranceType.alterBasement)!;
    final keyResource = KeyResource(position: museRoomNode!, transport: alterNode);
    return origin.copyWith(keyResource: keyResource);
  }
  @override
  List<NavigateArguments> preloadNavigateArguments(World world) {
    return validEntrances.expand((e) {
      final origin = navigateArguments(world, e);
      return <NavigateArguments>[
        origin,
        origin.copyWith(exits: <Node>{}),
        origin.copyWith(keyResource: null),
        origin.copyWith(keyResource: null, exits: <Node>{}),
      ];
    }).toList();
  }
}
