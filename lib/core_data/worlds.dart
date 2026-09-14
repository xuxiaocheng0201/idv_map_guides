import 'package:cachemesh/cachemesh.dart';
import 'package:flutter/services.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/navigator.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';

abstract class WorldsProvider<W> {
  WorldType get type;
  WorldDifficulty get difficulty;
  List<W> get allWorlds;
  List<EntranceType> get validEntrances;
  String worldAssets(W world);
  MainEntranceFeature inferMainEntranceFeature(World world, EntranceType entrance);
  SideEntranceFeature inferSideEntranceFeature(World world, EntranceType entrance);
  List<(Node, Set<int>, bool)> navigateStages(World world, EntranceType entrance);
}

class WorldsManager<W extends Enum> {
  final WorldsProvider<W> provider;
  WorldsManager({required this.provider});

  Future<Uint8List> _loadAssets(String file) async {
    return Uint8List.sublistView(await rootBundle.load('assets/maps/${provider.type.assets}/${provider.difficulty.assets}/$file'));
  }

  final Cache cache = Cache();
  Future<Map<String, Structure>> _getStructures() async {
    final result = await cache.get(
      key: 'structures',
      fetch: () async {
        final data = await _loadAssets('structures.data');
        return Result.success(deserializeStructures(data));
      },
    );
    switch (result) {
      case Success<Map<String, Structure>>():
        return result.value;
      case Failure<Map<String, Structure>>():
        throw result.error;
    }
  }
  Future<World> getWorld(W world) async {
    final structures = await _getStructures();
    final result = await cache.get(
      key: 'world/${world.index}',
      fetch: () async {
        final data = await _loadAssets(provider.worldAssets(world));
        final worldFile = deserializeWorld(data);
        return Result.success(constructWorld(structures, worldFile));
      },
    );
    switch (result) {
      case Success<World>():
        return result.value;
      case Failure<World>():
        throw result.error;
    }
  }

  Future<void> _preload() async {
    for (final world in provider.allWorlds) {
      await getWorld(world);
    }
  }

  Future<Map<MainEntranceFeature, Set<W>>> getWorldsByMainEntranceFeature(EntranceType entrance) async {
    final result = <MainEntranceFeature, Set<W>>{};
    for (final world in provider.allWorlds) {
      final map = await getWorld(world);
      final feature = provider.inferMainEntranceFeature(map, entrance);
      result.putIfAbsent(feature, () => <W>{}).add(world);
    }
    return result;
  }
  Future<Map<SideEntranceFeature, Set<W>>> getWorldsBySideEntranceFeature(EntranceType entrance) async {
    final result = <SideEntranceFeature, Set<W>>{};
    for (final world in provider.allWorlds) {
      final map = await getWorld(world);
      final feature = provider.inferSideEntranceFeature(map, entrance);
      result.putIfAbsent(feature, () => <W>{}).add(world);
    }
    return result;
  }
}

final _theBringerOfDoomHard = WorldsManager(provider: TheBringerOfDoomHardWorldsProvider());
final _theBringerOfDoomInsane = WorldsManager(provider: TheBringerOfDoomInsaneWorldsProvider());

WorldsManager<dynamic>? getWorldsManager(WorldType type, WorldDifficulty difficulty) {
  return switch (type) {
    WorldType.theBringerOfDoom => switch (difficulty) {
      WorldDifficulty.novice => null,
      WorldDifficulty.easy => null,
      WorldDifficulty.normal => null,
      WorldDifficulty.hard => _theBringerOfDoomHard,
      WorldDifficulty.insane => _theBringerOfDoomInsane,
    },
  }?.._preload();
}
