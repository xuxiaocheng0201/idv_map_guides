import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/worlds.dart';

enum TheBringerOfDoomHardWorlds {
  north,
  ;
  String get _assets => switch (this) {
    north => 'north',
  };
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
