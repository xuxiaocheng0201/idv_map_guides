import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/entrance.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/feature.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/layer.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/provider.dart';

extension PhosphorescenceDiseaseLayerL10n on PhosphorescenceDiseaseLayer {
  String label(BuildContext context) {
    return switch (this) {
      PhosphorescenceDiseaseLayer.level1 => S.of(context).layerPhosphorescenceDisease1,
      PhosphorescenceDiseaseLayer.level2 => S.of(context).layerPhosphorescenceDisease2,
      PhosphorescenceDiseaseLayer.level3 => S.of(context).layerPhosphorescenceDisease3,
      PhosphorescenceDiseaseLayer.level4 => S.of(context).layerPhosphorescenceDisease4,
    };
  }
}

extension PhosphorescenceDiseaseEntranceTypeL10n on PhosphorescenceDiseaseEntranceType {
  String label(BuildContext context) {
    return switch (this) {
      PhosphorescenceDiseaseEntranceType.main => '矿井',
      PhosphorescenceDiseaseEntranceType.entranceLeft => S.of(context).entranceTypePhosphorescenceDiseaseTurnLeft,
      PhosphorescenceDiseaseEntranceType.entranceRight => S.of(context).entranceTypePhosphorescenceDiseaseTurnRight,
      PhosphorescenceDiseaseEntranceType.entranceRailway => S.of(context).entranceTypePhosphorescenceDiseaseRailway,
      PhosphorescenceDiseaseEntranceType.minecartB2A => 'B2矿车1',
      PhosphorescenceDiseaseEntranceType.minecartB2B => 'B2矿车2',
      PhosphorescenceDiseaseEntranceType.minecartB3A => 'B3矿车1',
      PhosphorescenceDiseaseEntranceType.minecartB3B => 'B3矿车2',
      PhosphorescenceDiseaseEntranceType.minecartTransported => '矿车出口',
    };
  }
}

extension B1EntranceFeatureL10n on B1EntranceFeature {
  String label(BuildContext context) => S.of(context).entranceFeaturePhosphorescenceDiseaseB1(cells);
}

extension B2EntranceFeatureL10n on B2EntranceFeature {
  String label(BuildContext context) {
    final s = S.of(context);
    final sb = StringBuffer();
    switch (leftType) {
      case B2EntranceFeatureType.none:
        return s.entranceFeaturePhosphorescenceDiseaseB2LeftNo;
      case B2EntranceFeatureType.straight:
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2LeftStraight);
        break;
      case B2EntranceFeatureType.bentUpward:
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2LeftUpwardBent);
        break;
      case B2EntranceFeatureType.bentDownward:
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2LeftDownwardBent);
        break;
      case B2EntranceFeatureType.bentLeftward:
      case B2EntranceFeatureType.bentRightward:
        throw StateError('unreachable');
    }
    sb.write('-');
    switch ((downType, rightType)) {
      case (B2EntranceFeatureType.none, B2EntranceFeatureType.none):
        return s.entranceFeaturePhosphorescenceDiseaseB2LeftOnly;

      case (B2EntranceFeatureType.none, B2EntranceFeatureType.straight):
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2RightStraight);
        break;
      case (B2EntranceFeatureType.none, B2EntranceFeatureType.bentUpward):
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2RightUpwardBent);
        break;
      case (B2EntranceFeatureType.none, B2EntranceFeatureType.bentDownward):
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2RightDownwardBent);
        break;
      case (B2EntranceFeatureType.none, B2EntranceFeatureType.bentLeftward):
      case (B2EntranceFeatureType.none, B2EntranceFeatureType.bentRightward):
        throw StateError('unreachable');

      case (B2EntranceFeatureType.straight, B2EntranceFeatureType.none):
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2DownStraight);
        break;
      case (B2EntranceFeatureType.bentLeftward, B2EntranceFeatureType.none):
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2DownLeftwardBent);
        break;
      case (B2EntranceFeatureType.bentRightward, B2EntranceFeatureType.none):
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2DownRightwardBent);
        break;
      case (B2EntranceFeatureType.bentUpward, B2EntranceFeatureType.none):
      case (B2EntranceFeatureType.bentDownward, B2EntranceFeatureType.none):
        throw StateError('unreachable');

      case (_, _):
        sb.write(s.entranceFeaturePhosphorescenceDiseaseB2Both);
        break;
    }
    return sb.toString();
  }
}

extension PhosphorescenceDiseaseEntranceFeatureL10n on PhosphorescenceDiseaseEntranceFeature {
  String label(BuildContext context) => switch (this) {
    final B1EntranceFeatureValue v => v.feature.label(context),
    final B2EntranceFeatureValue v => v.feature.label(context),
  };
}

extension PhosphorescenceDiseaseNightmareWorldsL10n on PhosphorescenceDiseaseNightmareWorlds {
  String label(BuildContext context) {
    return switch (this) {
      PhosphorescenceDiseaseNightmareWorlds.map1 => S.of(context).worldPhosphorescenceDiseaseNightmare1,
      PhosphorescenceDiseaseNightmareWorlds.map2 => S.of(context).worldPhosphorescenceDiseaseNightmare2,
      PhosphorescenceDiseaseNightmareWorlds.map3 => S.of(context).worldPhosphorescenceDiseaseNightmare3,
      PhosphorescenceDiseaseNightmareWorlds.map4 => S.of(context).worldPhosphorescenceDiseaseNightmare4,
      PhosphorescenceDiseaseNightmareWorlds.map5 => S.of(context).worldPhosphorescenceDiseaseNightmare5,
      PhosphorescenceDiseaseNightmareWorlds.map6 => S.of(context).worldPhosphorescenceDiseaseNightmare6,
      PhosphorescenceDiseaseNightmareWorlds.map7 => S.of(context).worldPhosphorescenceDiseaseNightmare7,
      PhosphorescenceDiseaseNightmareWorlds.map8 => S.of(context).worldPhosphorescenceDiseaseNightmare8,
      PhosphorescenceDiseaseNightmareWorlds.map9 => S.of(context).worldPhosphorescenceDiseaseNightmare9,
      PhosphorescenceDiseaseNightmareWorlds.map10 => S.of(context).worldPhosphorescenceDiseaseNightmare10,
      PhosphorescenceDiseaseNightmareWorlds.map11 => S.of(context).worldPhosphorescenceDiseaseNightmare11,
      PhosphorescenceDiseaseNightmareWorlds.map12 => S.of(context).worldPhosphorescenceDiseaseNightmare12,
      PhosphorescenceDiseaseNightmareWorlds.map13 => S.of(context).worldPhosphorescenceDiseaseNightmare13,
      PhosphorescenceDiseaseNightmareWorlds.map14 => S.of(context).worldPhosphorescenceDiseaseNightmare14,
      PhosphorescenceDiseaseNightmareWorlds.map15 => S.of(context).worldPhosphorescenceDiseaseNightmare15,
    };
  }
}
