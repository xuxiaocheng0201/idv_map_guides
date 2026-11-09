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
    };
  }
}

extension PhosphorescenceDiseaseWorldsL10n on PhosphorescenceDiseaseWorlds {
  String label(BuildContext context) {
    return switch (this) {
      PhosphorescenceDiseaseWorlds.onlyOne => S.of(context).worldPhosphorescenceDisease,
    };
  }
}

extension PhosphorescenceDiseaseEntranceFeatureL10n on PhosphorescenceDiseaseEntranceFeature {
  String label(BuildContext context) => S.of(context).sideEntranceFeatureOther;
}
