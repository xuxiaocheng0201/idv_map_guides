import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/entrance.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/feature.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/layer.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/provider.dart';

extension TheBringerOfDoomLayerL10n on TheBringerOfDoomLayer {
  String label(BuildContext context) => switch (this) {
    TheBringerOfDoomLayer.basement => S.of(context).layerTheBringerOfDoomBasement,
    TheBringerOfDoomLayer.ground => S.of(context).layerTheBringerOfDoomGround,
    TheBringerOfDoomLayer.second => S.of(context).layerTheBringerOfDoomSecond,
  };
}

extension TheBringerOfDoomEntranceTypeL10n on TheBringerOfDoomEntranceType {
  String label(BuildContext context) => switch (this) {
    TheBringerOfDoomEntranceType.main => S.of(context).entranceTypeTheBringerOfDoomMain,
    TheBringerOfDoomEntranceType.sideGround => S.of(context).entranceTypeTheBringerOfDoomSideGround,
    TheBringerOfDoomEntranceType.sideSecond => S.of(context).entranceTypeTheBringerOfDoomSideSecond,
    TheBringerOfDoomEntranceType.alterBasement => '地下室祭坛',
  };
}

extension MainEntranceFeatureL10n on MainEntranceFeature {
  String label(BuildContext context) {
    final s = S.of(context);
    final StringBuffer sb = StringBuffer();
    if (hasUpDoor) sb.write(s.entranceFeatureTheBringerOfDoomMainHasUp);
    if (hasLeftDoor) sb.write(s.entranceFeatureTheBringerOfDoomMainHasLeft);
    if (hasRightDoor) sb.write(s.entranceFeatureTheBringerOfDoomMainHasRight);
    return sb.toString();
  }
}

extension SideEntranceFeatureL10n on SideEntranceFeature {
  String label(BuildContext context) => switch (this) {
    SideEntranceFeature.north => S.of(context).entranceFeatureTheBringerOfDoomSideNorth,
    SideEntranceFeature.east => S.of(context).entranceFeatureTheBringerOfDoomSideEast,
    SideEntranceFeature.south => S.of(context).entranceFeatureTheBringerOfDoomSideSouth,
    SideEntranceFeature.west => S.of(context).entranceFeatureTheBringerOfDoomSideWest,
    SideEntranceFeature.other => S.of(context).entranceFeatureTheBringerOfDoomSideOther,
  };
}

extension TheBringerOfDoomEntranceFeatureL10n on TheBringerOfDoomEntranceFeature {
  String label(BuildContext context) => switch (this) {
    final MainEntranceFeatureValue v => v.feature.label(context),
    final SideEntranceFeatureValue v => v.feature.label(context),
  };
}

extension TheBringerOfDoomNoviceWorldsL10n on TheBringerOfDoomNoviceWorlds {
  String label(BuildContext context) => switch (this) {
    TheBringerOfDoomNoviceWorlds.onlyOne => S.of(context).worldTheBringerOfDoomNovice,
  };
}

extension TheBringerOfDoomEasyWorldsL10n on TheBringerOfDoomEasyWorlds {
  String label(BuildContext context) => switch (this) {
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

extension TheBringerOfDoomHardWorldsL10n on TheBringerOfDoomHardWorlds {
  String label(BuildContext context) => switch (this) {
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

extension TheBringerOfDoomNightmareWorldsL10n on TheBringerOfDoomNightmareWorlds {
  String label(BuildContext context) => switch (this) {
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
