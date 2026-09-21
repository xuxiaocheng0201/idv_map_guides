import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';
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
      WorldDifficulty.insane => S.of(context).difficultyInsane,
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

extension TheBringerOfDoomInsaneWorldsL10n on TheBringerOfDoomInsaneWorlds {
  String label(BuildContext context) {
    return switch (this) {
      TheBringerOfDoomInsaneWorlds.northB => S.of(context).worldTheBringerOfDoomInsaneNorthB,
      TheBringerOfDoomInsaneWorlds.northZ1 => S.of(context).worldTheBringerOfDoomInsaneNorthZ1,
      TheBringerOfDoomInsaneWorlds.northCactus => S.of(context).worldTheBringerOfDoomInsaneNorthCactus,
      TheBringerOfDoomInsaneWorlds.northLoop => S.of(context).worldTheBringerOfDoomInsaneNorthLoop,
      TheBringerOfDoomInsaneWorlds.northStair => S.of(context).worldTheBringerOfDoomInsaneNorthStair,
      TheBringerOfDoomInsaneWorlds.southThreeRed => S.of(context).worldTheBringerOfDoomInsaneSouthThreeRed,
      TheBringerOfDoomInsaneWorlds.southH => S.of(context).worldTheBringerOfDoomInsaneSouthH,
      TheBringerOfDoomInsaneWorlds.southFloating => S.of(context).worldTheBringerOfDoomInsaneSouthFloating,
      TheBringerOfDoomInsaneWorlds.eastC => S.of(context).worldTheBringerOfDoomInsaneEastC,
      TheBringerOfDoomInsaneWorlds.east1Lightning => S.of(context).worldTheBringerOfDoomInsaneEast1Lightning,
      TheBringerOfDoomInsaneWorlds.eastCactus => S.of(context).worldTheBringerOfDoomInsaneEastCactus,
      TheBringerOfDoomInsaneWorlds.eastBreakC => S.of(context).worldTheBringerOfDoomInsaneEastBreakC,
      TheBringerOfDoomInsaneWorlds.eastShortT => S.of(context).worldTheBringerOfDoomInsaneEastShortT,
      TheBringerOfDoomInsaneWorlds.eastLongZ => S.of(context).worldTheBringerOfDoomInsaneEastLongZ,
      TheBringerOfDoomInsaneWorlds.west11 => S.of(context).worldTheBringerOfDoomInsaneWest11,
      TheBringerOfDoomInsaneWorlds.westFlipT => S.of(context).worldTheBringerOfDoomInsaneWestFlipT,
      TheBringerOfDoomInsaneWorlds.west1BookGallery => S.of(context).worldTheBringerOfDoomInsaneWest1BookGallery,
      TheBringerOfDoomInsaneWorlds.west1Corner => S.of(context).worldTheBringerOfDoomInsaneWest1Corner,
      TheBringerOfDoomInsaneWorlds.west5Bed => S.of(context).worldTheBringerOfDoomInsaneWest5Bed,
      TheBringerOfDoomInsaneWorlds.westVerticalL => S.of(context).worldTheBringerOfDoomInsaneWestVerticalL,
      TheBringerOfDoomInsaneWorlds.westStair => S.of(context).worldTheBringerOfDoomInsaneWestStair,
    };
  }
}

String worldLabel(dynamic world, BuildContext context) {
  if (world is TheBringerOfDoomNoviceWorlds) return world.label(context);
  if (world is TheBringerOfDoomHardWorlds) return world.label(context);
  if (world is TheBringerOfDoomInsaneWorlds) return world.label(context);
  return world.label(context) as String;
}
