import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/provider.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/serde.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/provider.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/serde.dart';

WorldCodec worldCodecFor(WorldType type) => switch (type) {
  WorldType.theBringerOfDoom => theBringerOfDoomCodec,
  WorldType.phosphorescenceDisease => phosphorescenceDiseaseCodec,
};

WorldsProvider<BaseWorldsEnums>? worldsProviderFor(WorldType type, WorldDifficulty difficulty) {
  return switch (type) {
    WorldType.theBringerOfDoom => switch (difficulty) {
      WorldDifficulty.novice => TheBringerOfDoomNoviceWorldsProvider(),
      WorldDifficulty.easy => TheBringerOfDoomEasyWorldsProvider(),
      WorldDifficulty.normal => null, // TODO
      WorldDifficulty.hard => TheBringerOfDoomHardWorldsProvider(),
      WorldDifficulty.nightmare => TheBringerOfDoomNightmareWorldsProvider(),
    },
    WorldType.phosphorescenceDisease => switch (difficulty) {
      WorldDifficulty.novice => null,
      WorldDifficulty.easy => null,
      WorldDifficulty.normal => null, // TODO
      WorldDifficulty.hard => null, // TODO
      WorldDifficulty.nightmare => PhosphorescenceDiseaseWorldsNightmareProvider(),
    },
  };
}
