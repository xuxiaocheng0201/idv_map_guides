import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';
import 'package:idv_map_guides/generated/l10n.dart';

enum WorldType {
  theBringerOfDoom;

  String get _assets => switch (this) {
    WorldType.theBringerOfDoom => 'the_bringer_of_doom',
  };
  String label(BuildContext context) {
    return switch (this) {
      WorldType.theBringerOfDoom => S.of(context).worldTheBringerOfDoom,
    };
  }
}

enum WorldDifficulty {
  novice,
  easy,
  normal,
  hard,
  insane;

  String get _assets => switch (this) {
    WorldDifficulty.novice => 'novice',
    WorldDifficulty.easy => 'easy',
    WorldDifficulty.normal => 'normal',
    WorldDifficulty.hard => 'hard',
    WorldDifficulty.insane => 'insane',
  };
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

abstract class WorldsProvider<M> {
  WorldType get type;
  WorldDifficulty get difficulty;
  Future<Uint8List> loadAssets(String file) async {
    return Uint8List.sublistView(await rootBundle.load('maps/${type._assets}/${difficulty._assets}/$file'));
  }
  Future<Map<String, Structure>> provideStructures();
  Future<WorldFile> provideWorld(M map);

  List<EntranceType> get validEntrances;
}

final Map<WorldType, Map<WorldDifficulty, WorldsProvider<dynamic>>> worldsProviders = <WorldType, Map<WorldDifficulty, WorldsProvider<dynamic>>>{
  WorldType.theBringerOfDoom: <WorldDifficulty, WorldsProvider<dynamic>> {
    WorldDifficulty.hard: TheBringerOfDoomHardWorldsProvider(),
  },
};
