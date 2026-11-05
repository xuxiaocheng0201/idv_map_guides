import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/generated/l10n.dart';

extension WorldTypeL10n on WorldType {
  String label(BuildContext context) {
    return switch (this) {
      WorldType.theBringerOfDoom => S.of(context).worldTheBringerOfDoom,
    };
  }
}

extension WorldDifficultyL10n on WorldDifficulty {
  String label(BuildContext context) {
    return switch (this) {
      WorldDifficulty.novice => S.of(context).difficultyNovice,
      WorldDifficulty.easy => S.of(context).difficultyEasy,
      WorldDifficulty.normal => S.of(context).difficultyNormal,
      WorldDifficulty.hard => S.of(context).difficultyHard,
      WorldDifficulty.nightmare => S.of(context).difficultyNightmare,
    };
  }
}

extension MainEntranceFeatureL10n on MainEntranceFeature {
  String label(BuildContext context) {
    final s = S.of(context);
    final StringBuffer sb = StringBuffer();
    if (hasUpDoor) sb.write(s.mainEntranceFeatureHasUp);
    if (hasLeftDoor) sb.write(s.mainEntranceFeatureHasLeft);
    if (hasRightDoor) sb.write(s.mainEntranceFeatureHasRight);
    return sb.toString();
  }
}

extension SideEntranceFeatureL10n on SideEntranceFeature {
  String label(BuildContext context) {
    return switch (this) {
      SideEntranceFeature.north => S.of(context).sideEntranceFeatureNorth,
      SideEntranceFeature.east => S.of(context).sideEntranceFeatureEast,
      SideEntranceFeature.south => S.of(context).sideEntranceFeatureSouth,
      SideEntranceFeature.west => S.of(context).sideEntranceFeatureWest,
      SideEntranceFeature.other => S.of(context).sideEntranceFeatureOther,
    };
  }
}

extension EntranceFeatureL10n on EntranceFeature {
  String label(BuildContext context) {
    final me = this;
    return switch (me) {
      EntranceFeature_Main() => me.feature.label(context),
      EntranceFeature_Side() => me.feature.label(context),
    };
  }
}


extension TheBringerOfDoomNoviceWorldsL10n on TheBringerOfDoomNoviceWorlds {
  String label(BuildContext context) {
    return switch (this) {
      TheBringerOfDoomNoviceWorlds.onlyOne => S.of(context).worldTheBringerOfDoomNovice,
    };
  }
}

extension TheBringerOfDoomEasyWorldsL10n on TheBringerOfDoomEasyWorlds {
  String label(BuildContext context) {
    return switch (this) {
      TheBringerOfDoomEasyWorlds.northL => S.of(context).worldTheBringerOfDoomEasyNorthL,
      TheBringerOfDoomEasyWorlds.northFiveBed => S.of(context).worldTheBringerOfDoomEasyNorthFiveBed,
      TheBringerOfDoomEasyWorlds.northConcave => S.of(context).worldTheBringerOfDoomEasyNorthConcave,
      TheBringerOfDoomEasyWorlds.northRed => S.of(context).worldTheBringerOfDoomEasyNorthRed,
      TheBringerOfDoomEasyWorlds.northRedDiagonal => S.of(context).worldTheBringerOfDoomEasyNorthRedDiagonal,
      TheBringerOfDoomEasyWorlds.eastH => S.of(context).worldTheBringerOfDoomEasyEastH,
      TheBringerOfDoomEasyWorlds.eastT => S.of(context).worldTheBringerOfDoomEasyEastT,
      TheBringerOfDoomEasyWorlds.eastTwoL => S.of(context).worldTheBringerOfDoomEasyEastTwoL,
      TheBringerOfDoomEasyWorlds.eastFlatHammer => S.of(context).worldTheBringerOfDoomEasyEastFlatHammer,
      TheBringerOfDoomEasyWorlds.eastHammer => S.of(context).worldTheBringerOfDoomEasyEastHammer,
      TheBringerOfDoomEasyWorlds.eastFork => S.of(context).worldTheBringerOfDoomEasyEastFork,
      TheBringerOfDoomEasyWorlds.westL => S.of(context).worldTheBringerOfDoomEasyWestL,
      TheBringerOfDoomEasyWorlds.westY => S.of(context).worldTheBringerOfDoomEasyWestY,
      TheBringerOfDoomEasyWorlds.westZ => S.of(context).worldTheBringerOfDoomEasyWestZ,
      TheBringerOfDoomEasyWorlds.westCross => S.of(context).worldTheBringerOfDoomEasyWestCross,
      TheBringerOfDoomEasyWorlds.westReverseC => S.of(context).worldTheBringerOfDoomEasyWestReverseC,
      TheBringerOfDoomEasyWorlds.westLong1 => S.of(context).worldTheBringerOfDoomEasyWestLong1,
      TheBringerOfDoomEasyWorlds.westFork => S.of(context).worldTheBringerOfDoomEasyWestFork,
    };
  }
}

extension TheBringerOfDoomHardWorldsL10n on TheBringerOfDoomHardWorlds {
  String label(BuildContext context) {
    return switch (this) {
      TheBringerOfDoomHardWorlds.north1 => S.of(context).worldTheBringerOfDoomHardNorth1,
      TheBringerOfDoomHardWorlds.north1Sofa => S.of(context).worldTheBringerOfDoomHardNorth1Sofa,
      TheBringerOfDoomHardWorlds.north4 => S.of(context).worldTheBringerOfDoomHardNorth4,
      TheBringerOfDoomHardWorlds.north4Safe => S.of(context).worldTheBringerOfDoomHardNorth4Safe,
      TheBringerOfDoomHardWorlds.northT => S.of(context).worldTheBringerOfDoomHardNorthT,
      TheBringerOfDoomHardWorlds.northConcave => S.of(context).worldTheBringerOfDoomHardNorthConcave,
      TheBringerOfDoomHardWorlds.northRed => S.of(context).worldTheBringerOfDoomHardNorthRed,
      TheBringerOfDoomHardWorlds.northRedDiagonal => S.of(context).worldTheBringerOfDoomHardNorthRedDiagonal,
      TheBringerOfDoomHardWorlds.southL => S.of(context).worldTheBringerOfDoomHardSouthL,
      TheBringerOfDoomHardWorlds.southOrz => S.of(context).worldTheBringerOfDoomHardSouthOrz,
      TheBringerOfDoomHardWorlds.southThreeMissingOne => S.of(context).worldTheBringerOfDoomHardSouthThreeMissingOne,
      TheBringerOfDoomHardWorlds.southCross => S.of(context).worldTheBringerOfDoomHardSouthCross,
      TheBringerOfDoomHardWorlds.southRed => S.of(context).worldTheBringerOfDoomHardSouthRed,
      TheBringerOfDoomHardWorlds.eastL => S.of(context).worldTheBringerOfDoomHardEastL,
      TheBringerOfDoomHardWorlds.eastThreeL => S.of(context).worldTheBringerOfDoomHardEastThreeL,
      TheBringerOfDoomHardWorlds.eastTwoL => S.of(context).worldTheBringerOfDoomHardEastTwoL,
      TheBringerOfDoomHardWorlds.eastForfeit => S.of(context).worldTheBringerOfDoomHardEastForfeit,
      TheBringerOfDoomHardWorlds.eastHammer => S.of(context).worldTheBringerOfDoomHardEastHammer,
      TheBringerOfDoomHardWorlds.eastStair => S.of(context).worldTheBringerOfDoomHardEastStair,
      TheBringerOfDoomHardWorlds.westY => S.of(context).worldTheBringerOfDoomHardWestY,
      TheBringerOfDoomHardWorlds.westYFrog => S.of(context).worldTheBringerOfDoomHardWestYFrog,
      TheBringerOfDoomHardWorlds.westFlipT => S.of(context).worldTheBringerOfDoomHardWestFlipT,
      TheBringerOfDoomHardWorlds.westOppositeT => S.of(context).worldTheBringerOfDoomHardWestOppositeT,
      TheBringerOfDoomHardWorlds.westDiagonal => S.of(context).worldTheBringerOfDoomHardWestDiagonal,
      TheBringerOfDoomHardWorlds.westPots => S.of(context).worldTheBringerOfDoomHardWestPots,
      TheBringerOfDoomHardWorlds.westHammer1 => S.of(context).worldTheBringerOfDoomHardWestHammer1,
      TheBringerOfDoomHardWorlds.westHammer2 => S.of(context).worldTheBringerOfDoomHardWestHammer2,
      TheBringerOfDoomHardWorlds.westHammerLantern => S.of(context).worldTheBringerOfDoomHardWestHammerLantern,
      TheBringerOfDoomHardWorlds.westFork => S.of(context).worldTheBringerOfDoomHardWestFork,
    };
  }
}

extension TheBringerOfDoomNightmareWorldsL10n on TheBringerOfDoomNightmareWorlds {
  String label(BuildContext context) {
    return switch (this) {
      TheBringerOfDoomNightmareWorlds.northB => S.of(context).worldTheBringerOfDoomNightmareNorthB,
      TheBringerOfDoomNightmareWorlds.northZ1 => S.of(context).worldTheBringerOfDoomNightmareNorthZ1,
      TheBringerOfDoomNightmareWorlds.northCactus => S.of(context).worldTheBringerOfDoomNightmareNorthCactus,
      TheBringerOfDoomNightmareWorlds.northLoop => S.of(context).worldTheBringerOfDoomNightmareNorthLoop,
      TheBringerOfDoomNightmareWorlds.northStair => S.of(context).worldTheBringerOfDoomNightmareNorthStair,
      TheBringerOfDoomNightmareWorlds.southThreeRed => S.of(context).worldTheBringerOfDoomNightmareSouthThreeRed,
      TheBringerOfDoomNightmareWorlds.southH => S.of(context).worldTheBringerOfDoomNightmareSouthH,
      TheBringerOfDoomNightmareWorlds.southFloating => S.of(context).worldTheBringerOfDoomNightmareSouthFloating,
      TheBringerOfDoomNightmareWorlds.southWhiteRoom => S.of(context).worldTheBringerOfDoomNightmareSouthWhiteRoom,
      TheBringerOfDoomNightmareWorlds.eastC => S.of(context).worldTheBringerOfDoomNightmareEastC,
      TheBringerOfDoomNightmareWorlds.east1Lightning => S.of(context).worldTheBringerOfDoomNightmareEast1Lightning,
      TheBringerOfDoomNightmareWorlds.eastCactus => S.of(context).worldTheBringerOfDoomNightmareEastCactus,
      TheBringerOfDoomNightmareWorlds.eastBreakC => S.of(context).worldTheBringerOfDoomNightmareEastBreakC,
      TheBringerOfDoomNightmareWorlds.eastShortT => S.of(context).worldTheBringerOfDoomNightmareEastShortT,
      TheBringerOfDoomNightmareWorlds.eastLongZ => S.of(context).worldTheBringerOfDoomNightmareEastLongZ,
      TheBringerOfDoomNightmareWorlds.west11 => S.of(context).worldTheBringerOfDoomNightmareWest11,
      TheBringerOfDoomNightmareWorlds.westZ => S.of(context).worldTheBringerOfDoomNightmareWestZ,
      TheBringerOfDoomNightmareWorlds.westMeetingRoom => S.of(context).worldTheBringerOfDoomNightmareWestMeetingRoom,
      TheBringerOfDoomNightmareWorlds.westFlipT => S.of(context).worldTheBringerOfDoomNightmareWestFlipT,
      TheBringerOfDoomNightmareWorlds.westCross => S.of(context).worldTheBringerOfDoomNightmareWestCross,
      TheBringerOfDoomNightmareWorlds.westVertical1BookGallery => S.of(context).worldTheBringerOfDoomNightmareWestVertical1BookGallery,
      TheBringerOfDoomNightmareWorlds.westVertical1Corner => S.of(context).worldTheBringerOfDoomNightmareWestVertical1Corner,
      TheBringerOfDoomNightmareWorlds.westVertical5Bed => S.of(context).worldTheBringerOfDoomNightmareWestVertical5Bed,
      TheBringerOfDoomNightmareWorlds.westVerticalL => S.of(context).worldTheBringerOfDoomNightmareWestVerticalL,
      TheBringerOfDoomNightmareWorlds.westVerticalCornerStair => S.of(context).worldTheBringerOfDoomNightmareWestVerticalCornerStair,
      TheBringerOfDoomNightmareWorlds.westStair1 => S.of(context).worldTheBringerOfDoomNightmareWestStair1,
    };
  }
}

String worldLabel(BaseWorldsEnums world, BuildContext context) {
  if (world is TheBringerOfDoomNoviceWorlds) return world.label(context);
  if (world is TheBringerOfDoomEasyWorlds) return world.label(context);
  if (world is TheBringerOfDoomHardWorlds) return world.label(context);
  if (world is TheBringerOfDoomNightmareWorlds) return world.label(context);
  return (world as dynamic).label(context) as String; // unreachable
}
