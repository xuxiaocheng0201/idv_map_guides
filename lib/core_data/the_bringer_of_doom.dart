import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/generated/l10n.dart';

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
  @override List<EntranceType> get validEntrances => const <EntranceType>[EntranceType.main, EntranceType.sideGround, EntranceType.sideSecond];

  @override
  Future<Map<String, Structure>> provideStructures() async {
    final data = await loadAssets('structures.data');
    return deserializeStructures(data);
  }

  @override
  Future<WorldFile> provideWorld(TheBringerOfDoomHardWorlds map) async {
    final data = await loadAssets('world_${map._assets}.data');
    return deserializeWorld(data);
  }
}
