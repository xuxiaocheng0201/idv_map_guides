import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/navigator_double.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/entrance.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/feature.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/layer.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/serde.dart';

MainEntranceFeature _inferMainFeature(World world, TheBringerOfDoomEntranceType entrance) {
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

SideEntranceFeature _inferSideFeature(World world, TheBringerOfDoomEntranceType entrance) {
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

EntranceFeature _inferEntranceFeature(World world, TheBringerOfDoomEntranceType entrance) {
  return switch (entrance) {
    TheBringerOfDoomEntranceType.main => TheBringerOfDoomEntranceFeature.main(_inferMainFeature(world, entrance)),
    TheBringerOfDoomEntranceType.sideGround || TheBringerOfDoomEntranceType.sideSecond => TheBringerOfDoomEntranceFeature.side(_inferSideFeature(world, entrance)),
    TheBringerOfDoomEntranceType.alterBasement => throw UnimplementedError(),
  };
}

int _entrancesLength(TheBringerOfDoomEntranceType from, TheBringerOfDoomEntranceType to) {
  return switch (from) {
    TheBringerOfDoomEntranceType.main => switch (to) {
      TheBringerOfDoomEntranceType.main => 0,
      TheBringerOfDoomEntranceType.sideGround => 15,
      TheBringerOfDoomEntranceType.sideSecond => 15,
      TheBringerOfDoomEntranceType.alterBasement => throw UnimplementedError(),
    },
    TheBringerOfDoomEntranceType.sideGround => switch (to) {
      TheBringerOfDoomEntranceType.main => 15,
      TheBringerOfDoomEntranceType.sideGround => 0,
      TheBringerOfDoomEntranceType.sideSecond => 20,
      TheBringerOfDoomEntranceType.alterBasement => throw UnimplementedError(),
    },
    TheBringerOfDoomEntranceType.sideSecond => switch (to) {
      TheBringerOfDoomEntranceType.main => 8,
      TheBringerOfDoomEntranceType.sideGround => 20,
      TheBringerOfDoomEntranceType.sideSecond => 0,
      TheBringerOfDoomEntranceType.alterBasement => throw UnimplementedError(),
    },
    TheBringerOfDoomEntranceType.alterBasement => throw UnimplementedError(),
  };
}

NavigateArguments _navigateArguments(World world, TheBringerOfDoomEntranceType entrance) {
  final entrancePos = world.entrances[entrance]!.position;
  final startNode = Node(entrance.layer, entrancePos.x, entrancePos.y);
  final resources = Set.of(world.resources);
  final exitNodes = <TheBringerOfDoomEntranceType, Node>{};
  for (final entry in world.entrances.entries) {
    if (!entry.key.displayable) continue;
    final node = Node(entry.key.layer, entry.value.x, entry.value.y);
    exitNodes[entry.key as TheBringerOfDoomEntranceType] = node;
  }
  final entrancesLength = <(Node, Node), int>{};
  for (final from in exitNodes.entries) {
    for (final to in exitNodes.entries) {
      if (from.key == to.key) continue;
      entrancesLength[(from.value, to.value)] = _entrancesLength(from.key, to.key);
    }
  }
  return NavigateArguments(start: startNode, resources: resources, exits: exitNodes.values.toSet(), entrancesLength: entrancesLength);
}

enum TheBringerOfDoomNoviceWorlds implements BaseWorldsEnums {
  onlyOne,
}

class TheBringerOfDoomNoviceWorldsProvider extends WorldsProvider<TheBringerOfDoomNoviceWorlds> {
  @override WorldType get type => WorldType.theBringerOfDoom;
  @override WorldDifficulty get difficulty => WorldDifficulty.novice;
  @override WorldCodec get codec => theBringerOfDoomCodec;
  @override List<TheBringerOfDoomNoviceWorlds> get allWorlds => TheBringerOfDoomNoviceWorlds.values;
  @override List<GroundLayer> get allLayers => const <GroundLayer>[TheBringerOfDoomLayer.ground];
  @override List<EntranceType> get validEntrances => const <EntranceType>[TheBringerOfDoomEntranceType.main];
  @override String worldAssets(TheBringerOfDoomNoviceWorlds world) => 'world.data';
  @override EntranceFeature inferEntranceFeature(World world, EntranceType entrance) => _inferEntranceFeature(world, entrance as TheBringerOfDoomEntranceType);
  @override NavigateArguments navigateArguments(World world, EntranceType entrance) => _navigateArguments(world, entrance as TheBringerOfDoomEntranceType);
}

enum TheBringerOfDoomEasyWorlds implements BaseWorldsEnums {
  northL,
  northFiveBed,
  northConcave,
  northRed,
  northRedDiagonal,
  eastH,
  eastT,
  eastTwoL,
  eastFlatHammer,
  eastHammer,
  eastFork,
  westL,
  westY,
  westZ,
  westCross,
  westReverseC,
  westLong1,
  westFork;

  String get _assets => switch (this) {
    northL => 'north_l',
    northFiveBed => 'north_five_bed',
    northConcave => 'north_concave',
    northRed => 'north_red',
    northRedDiagonal => 'north_red_diagonal',
    eastH => 'east_h',
    eastT => 'east_t',
    eastTwoL => 'east_two_l',
    eastFlatHammer => 'east_flat_hammer',
    eastHammer => 'east_hammer',
    eastFork => 'east_fork',
    westL => 'west_l',
    westY => 'west_y',
    westZ => 'west_z',
    westCross => 'west_cross',
    westReverseC => 'west_reverse_c',
    westLong1 => 'west_long_1',
    westFork => 'west_fork',
  };
}

class TheBringerOfDoomEasyWorldsProvider extends WorldsProvider<TheBringerOfDoomEasyWorlds> {
  @override WorldType get type => WorldType.theBringerOfDoom;
  @override WorldDifficulty get difficulty => WorldDifficulty.easy;
  @override WorldCodec get codec => theBringerOfDoomCodec;
  @override List<TheBringerOfDoomEasyWorlds> get allWorlds => TheBringerOfDoomEasyWorlds.values;
  @override List<GroundLayer> get allLayers => const <GroundLayer>[TheBringerOfDoomLayer.ground];
  @override List<EntranceType> get validEntrances => const <EntranceType>[TheBringerOfDoomEntranceType.main, TheBringerOfDoomEntranceType.sideGround];
  @override String worldAssets(TheBringerOfDoomEasyWorlds world) => 'world_${world._assets}.data';
  @override EntranceFeature inferEntranceFeature(World world, EntranceType entrance) => _inferEntranceFeature(world, entrance as TheBringerOfDoomEntranceType);
  @override NavigateArguments navigateArguments(World world, EntranceType entrance) => _navigateArguments(world, entrance as TheBringerOfDoomEntranceType);
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
  @override WorldCodec get codec => theBringerOfDoomCodec;
  @override List<TheBringerOfDoomHardWorlds> get allWorlds => TheBringerOfDoomHardWorlds.values;
  @override List<GroundLayer> get allLayers => const <GroundLayer>[TheBringerOfDoomLayer.ground, TheBringerOfDoomLayer.second];
  @override List<EntranceType> get validEntrances => const <EntranceType>[TheBringerOfDoomEntranceType.main, TheBringerOfDoomEntranceType.sideGround, TheBringerOfDoomEntranceType.sideSecond];
  @override String worldAssets(TheBringerOfDoomHardWorlds world) => 'world_${world._assets}.data';
  @override EntranceFeature inferEntranceFeature(World world, EntranceType entrance) => _inferEntranceFeature(world, entrance as TheBringerOfDoomEntranceType);
  @override NavigateArguments navigateArguments(World world, EntranceType entrance) => _navigateArguments(world, entrance as TheBringerOfDoomEntranceType);
}

enum TheBringerOfDoomNightmareWorlds implements BaseWorldsEnums {
  northB,
  northZ1,
  northCactus,
  northLoop,
  northStair,
  southThreeRed,
  southH,
  southFloating,
  southWhiteRoom,
  eastC,
  east1Lightning,
  eastCactus,
  eastBreakC,
  eastShortT,
  eastLongZ,
  west11,
  westZ,
  westMeetingRoom,
  westFlipT,
  westCross,
  westVertical1BookGallery,
  westVertical1Corner,
  westVertical5Bed,
  westVerticalL,
  westVerticalCornerStair,
  westStair1;

  String get _assets => switch (this) {
    northB => 'north_b',
    northZ1 => 'north_z_1',
    northCactus => 'north_cactus',
    northLoop => 'north_loop',
    northStair => 'north_stair',
    southThreeRed => 'south_three_red',
    southH => 'south_h',
    southFloating => 'south_floating',
    southWhiteRoom => 'south_white_room',
    eastC => 'east_c',
    east1Lightning => 'east_1_lightning',
    eastCactus => 'east_cactus',
    eastBreakC => 'east_break_c',
    eastShortT => 'east_short_t',
    eastLongZ => 'east_long_z',
    west11 => 'west_11',
    westZ => 'west_z',
    westMeetingRoom => 'west_meeting_room',
    westFlipT => 'west_flip_t',
    westCross => 'west_cross',
    westVertical1BookGallery => 'west_vertical_1_book_gallery',
    westVertical1Corner => 'west_vertical_1_corner',
    westVertical5Bed => 'west_vertical_5_bed',
    westVerticalL => 'west_vertical_l',
    westVerticalCornerStair => 'west_vertical_corner_stair',
    westStair1 => 'west_stair_1',
  };
}

class TheBringerOfDoomNightmareWorldsProvider extends WorldsProvider<TheBringerOfDoomNightmareWorlds> {
  @override WorldType get type => WorldType.theBringerOfDoom;
  @override WorldDifficulty get difficulty => WorldDifficulty.nightmare;
  @override WorldCodec get codec => theBringerOfDoomCodec;
  @override List<TheBringerOfDoomNightmareWorlds> get allWorlds => TheBringerOfDoomNightmareWorlds.values;
  @override List<GroundLayer> get allLayers => const <GroundLayer>[TheBringerOfDoomLayer.ground, TheBringerOfDoomLayer.second, TheBringerOfDoomLayer.basement];
  @override List<EntranceType> get validEntrances => const <EntranceType>[TheBringerOfDoomEntranceType.main, TheBringerOfDoomEntranceType.sideSecond];
  @override String worldAssets(TheBringerOfDoomNightmareWorlds world) => 'world_${world._assets}.data';
  @override EntranceFeature inferEntranceFeature(World world, EntranceType entrance) => _inferEntranceFeature(world, entrance as TheBringerOfDoomEntranceType);
  @override
  NavigateArguments navigateArguments(World world, EntranceType entrance) {
    final origin = _navigateArguments(world, entrance as TheBringerOfDoomEntranceType);
    final museRoomId = world.rooms['muse_room']!.firstOrNull!;
    Node? museRoomNode;
    find: for (int x = world.minX; x <= world.maxX; x++) {
      for (int y = world.minY; y <= world.maxY; y++) {
        final cell = world.cell(TheBringerOfDoomLayer.ground, x, y)!;
        if (cell.structureId == museRoomId && cell.info.isResource) {
          museRoomNode = Node(TheBringerOfDoomLayer.ground, x, y);
          break find;
        }
      }
    }
    final alterNode = world.entranceNode(TheBringerOfDoomEntranceType.alterBasement)!;
    final keyResource = KeyResource(position: museRoomNode!, transport: alterNode, keyResourceWeight: 3);
    return origin.copyWith(keyResource: keyResource, defaultWeight: 2);
  }
  @override
  List<NavigateArguments> preloadNavigateArguments(World world) {
    return super.preloadNavigateArguments(world).expand((arg) => [arg, arg.copyWith(keyResource: null)]).toList();
  }
  @override
  NavigateDoubleArguments navigateDoubleArguments(World world, EntranceType entrance1, EntranceType entrance2) {
    final origin1 = navigateArguments(world, entrance1);
    final origin2 = navigateArguments(world, entrance2);
    return NavigateDoubleArguments(
      start1: origin1.start,
      start2: origin2.start,
      resources: origin1.resources,
      exits: origin1.exits,
      keyResource: origin1.keyResource,
      defaultWeight: 2,
      transportWaitingWeight: 3,
    );
  }
  @override
  List<NavigateDoubleArguments> preloadNavigateDoubleArguments(World world) {
    return super.preloadNavigateDoubleArguments(world).expand((arg) => [arg, arg.copyWith(keyResource: null)]).toList();
  }
}
