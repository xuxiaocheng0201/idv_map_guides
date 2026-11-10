import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/entrance.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/feature.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/l10n.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/layer.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/provider.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/entrance.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/feature.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/l10n.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/layer.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/provider.dart';

extension WorldTypeL10n on WorldType {
  String label(BuildContext context) {
    return switch (this) {
      WorldType.theBringerOfDoom => S.of(context).worldTheBringerOfDoom,
      WorldType.phosphorescenceDisease => S.of(context).worldPhosphorescenceDisease,
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

String layerLabel(BuildContext context, GroundLayer layer) {
  if (layer is TheBringerOfDoomLayer) return layer.label(context);
  if (layer is PhosphorescenceDiseaseLayer) return layer.label(context);
  return (layer as dynamic).label(context) as String;
}

String entranceLabel(BuildContext context, EntranceType entrance) {
  if (entrance is TheBringerOfDoomEntranceType) return entrance.label(context);
  if (entrance is PhosphorescenceDiseaseEntranceType) return entrance.label(context);
  return (entrance as dynamic).label(context) as String;
}

String entranceFeatureLabel(BuildContext context, EntranceFeature feature) {
  if (feature is TheBringerOfDoomEntranceFeature) return feature.label(context);
  if (feature is PhosphorescenceDiseaseEntranceFeature) return feature.label(context);
  return feature.toString();
}

String worldLabel(BaseWorldsEnums world, BuildContext context) {
  if (world is TheBringerOfDoomNoviceWorlds) return world.label(context);
  if (world is TheBringerOfDoomEasyWorlds) return world.label(context);
  if (world is TheBringerOfDoomHardWorlds) return world.label(context);
  if (world is TheBringerOfDoomNightmareWorlds) return world.label(context);
  if (world is PhosphorescenceDiseaseNightmareWorlds) return world.label(context);
  return (world as dynamic).label(context) as String;
}