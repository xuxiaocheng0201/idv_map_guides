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
      PhosphorescenceDiseaseEntranceType.main => S.of(context).phosphorescenceDiseaseEntranceMain,
      PhosphorescenceDiseaseEntranceType.entranceLeft => '进口左转',
      PhosphorescenceDiseaseEntranceType.entranceRight => '进口右转',
      PhosphorescenceDiseaseEntranceType.entranceRailway => '轨道入口',
      PhosphorescenceDiseaseEntranceType.minecartB2A => 'B2矿车1',
      PhosphorescenceDiseaseEntranceType.minecartB2B => 'B2矿车2',
      PhosphorescenceDiseaseEntranceType.minecartB3A => 'B3矿车1',
      PhosphorescenceDiseaseEntranceType.minecartB3B => 'B3矿车2',
      PhosphorescenceDiseaseEntranceType.minecartTransported => '矿车出口',
    };
  }
}

extension PhosphorescenceDiseaseWorldsL10n on PhosphorescenceDiseaseNightmareWorlds {
  String label(BuildContext context) {
    return switch (this) {
      PhosphorescenceDiseaseNightmareWorlds.map1 => S.of(context).worldPhosphorescenceDisease,
    };
  }
}

extension PhosphorescenceDiseaseEntranceFeatureL10n on PhosphorescenceDiseaseEntranceFeature {
  String label(BuildContext context) => S.of(context).sideEntranceFeatureOther;
}
