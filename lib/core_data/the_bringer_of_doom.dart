import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/generated/l10n.dart';

MainEntranceFeature _inferMainFeature(World world, EntranceType entrance) {
  final position = world.entrances[entrance]!;
  final mainEntranceId = world.cell(entrance.layer(), position.x, position.y)!.structureId!;
  final upDoor = position.add(0, 4);
  final leftDoor = position.add(-1, 1);
  final rightDoor = position.add(1, 1);
  final upDoorCell = world.cell(entrance.layer(), upDoor.x, upDoor.y)!;
  final leftDoorCell = world.cell(entrance.layer(), leftDoor.x, leftDoor.y)!;
  final rightDoorCell = world.cell(entrance.layer(), rightDoor.x, rightDoor.y)!;
  return MainEntranceFeature(
    hasUpDoor: upDoorCell.structureId == mainEntranceId && upDoorCell.info.edgeNorth == EdgeType.door,
    hasLeftDoor: leftDoorCell.structureId == mainEntranceId && leftDoorCell.info.edgeWest == EdgeType.door,
    hasRightDoor: rightDoorCell.structureId == mainEntranceId && rightDoorCell.info.edgeEast == EdgeType.door,
  );
}

SideEntranceFeature _inferSideFeature(World world, EntranceType entrance) {
  final position = world.entrances[entrance]!;
  final sideEntranceId = world.cell(entrance.layer(), position.x, position.y)!.structureId!;
  Direction? facing;
  for (final direction in Direction.values) {
    final (dx, dy) = direction.dxy;
    final facingPosition = position.add(dx, dy);
    final facingCell = world.cell(entrance.layer(), facingPosition.x, facingPosition.y);
    if (facingCell?.structureId == sideEntranceId) {
      if (facing == null) {
        facing = direction;
      } else {
        return SideEntranceFeature.other;
      }
    }
  }
  return switch (facing!) {
    Direction.north => SideEntranceFeature.north,
    Direction.east => SideEntranceFeature.east,
    Direction.south => SideEntranceFeature.south,
    Direction.west => SideEntranceFeature.west,
  };
}

enum TheBringerOfDoomHardWorlds {
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
  String label(BuildContext context) {
    return switch (this) {
      north1 => S.of(context).worldTheBringerOfDoomHardNorth1,
      north1Sofa => S.of(context).worldTheBringerOfDoomHardNorth1Sofa,
      north4 => S.of(context).worldTheBringerOfDoomHardNorth4,
      north4Safe => S.of(context).worldTheBringerOfDoomHardNorth4Safe,
      northT => S.of(context).worldTheBringerOfDoomHardNorthT,
      northConcave => S.of(context).worldTheBringerOfDoomHardNorthConcave,
      northRed => S.of(context).worldTheBringerOfDoomHardNorthRed,
      northRedDiagonal => S.of(context).worldTheBringerOfDoomHardNorthRedDiagonal,
      southL => S.of(context).worldTheBringerOfDoomHardSouthL,
      southOrz => S.of(context).worldTheBringerOfDoomHardSouthOrz,
      southThreeMissingOne => S.of(context).worldTheBringerOfDoomHardSouthThreeMissingOne,
      southCross => S.of(context).worldTheBringerOfDoomHardSouthCross,
      southRed => S.of(context).worldTheBringerOfDoomHardSouthRed,
      eastL => S.of(context).worldTheBringerOfDoomHardEastL,
      eastThreeL => S.of(context).worldTheBringerOfDoomHardEastThreeL,
      eastTwoL => S.of(context).worldTheBringerOfDoomHardEastTwoL,
      eastForfeit => S.of(context).worldTheBringerOfDoomHardEastForfeit,
      eastHammer => S.of(context).worldTheBringerOfDoomHardEastHammer,
      eastStair => S.of(context).worldTheBringerOfDoomHardEastStair,
      westY => S.of(context).worldTheBringerOfDoomHardWestY,
      westYFrog => S.of(context).worldTheBringerOfDoomHardWestYFrog,
      westFlipT => S.of(context).worldTheBringerOfDoomHardWestFlipT,
      westOppositeT => S.of(context).worldTheBringerOfDoomHardWestOppositeT,
      westDiagonal => S.of(context).worldTheBringerOfDoomHardWestDiagonal,
      westPots => S.of(context).worldTheBringerOfDoomHardWestPots,
      westHammer1 => S.of(context).worldTheBringerOfDoomHardWestHammer1,
      westHammer2 => S.of(context).worldTheBringerOfDoomHardWestHammer2,
      westHammerLantern => S.of(context).worldTheBringerOfDoomHardWestHammerLantern,
      westFork => S.of(context).worldTheBringerOfDoomHardWestFork,
    };
  }
}

class TheBringerOfDoomHardWorldsProvider extends WorldsProvider<TheBringerOfDoomHardWorlds> {
  @override WorldType get type => WorldType.theBringerOfDoom;
  @override WorldDifficulty get difficulty => WorldDifficulty.hard;
  @override List<TheBringerOfDoomHardWorlds> get allWorlds => TheBringerOfDoomHardWorlds.values;
  @override List<EntranceType> get validEntrances => const <EntranceType>[EntranceType.main, EntranceType.sideGround, EntranceType.sideSecond];
  @override String worldAssets(TheBringerOfDoomHardWorlds world) => 'world_${world._assets}.data';
  @override MainEntranceFeature inferMainEntranceFeature(World world, EntranceType entrance) => _inferMainFeature(world, entrance);
  @override SideEntranceFeature inferSideEntranceFeature(World world, EntranceType entrance) => _inferSideFeature(world, entrance);
}
