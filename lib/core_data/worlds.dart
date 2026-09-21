import 'package:cachemesh/cachemesh.dart';
import 'package:flutter/services.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/precomputed_navigator.g.dart' deferred as precomputed_navigator;
import 'package:idv_map_guides/core_navigator/serde.dart';

class WorldsManager<W extends BaseWorldsEnums> {
  final WorldsProvider<W> provider;
  WorldsManager({required this.provider});

  Future<Uint8List> _loadAssets(String file) async {
    return Uint8List.sublistView(await rootBundle.load('assets/maps/${provider.type.assets}/${provider.difficulty.assets}/$file'));
  }

  final Cache cache = Cache();

  Future<(Uint8List, Map<String, Structure>)> _getStructures() async {
    final result = await cache.get(
      key: 'structures',
      fetch: () async {
        final data = await _loadAssets('structures.data');
        return Result.success((data, deserializeStructures(data)));
      },
    );
    switch (result) {
      case Success():
        return result.value;
      case Failure():
        throw result.error;
    }
  }

  Future<(Uint8List, World)> _getWorld(W world) async {
    final structures = (await _getStructures()).$2;
    final result = await cache.get(
      key: 'world/${world.index}',
      fetch: () async {
        final data = await _loadAssets(provider.worldAssets(world));
        final worldFile = deserializeWorld(data);
        return Result.success((data, constructWorld(structures, worldFile)));
      },
    );
    switch (result) {
      case Success():
        return result.value;
      case Failure():
        throw result.error;
    }
  }

  Future<World> getWorld(W world) async {
    return (await _getWorld(world)).$2;
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

  Future<List<Node>> getNavigateResult(W world, NavigateArguments arguments) async {
    final structuresFile = (await _getStructures()).$1;
    final worldFile = (await _getWorld(world)).$1;
    final result = await cache.get(
      key: 'navigate/${world.index}/${arguments.identify}',
      fetch: () async {
        await precomputed_navigator.loadLibrary();
        final key = '${provider.type.name}/${provider.difficulty.name}/${world.index}/${arguments.identify}';
        final precomputed = precomputed_navigator.precomputedNavigateData[key];
        if (precomputed != null) {
          final path = deserializeNavigatePath(precomputed);
          return Result.success(path);
        }
        final path = await navigateAsync(structuresFile, worldFile, arguments);
        return Result.success(path);
      },
    );
    switch (result) {
      case Success():
        return result.value;
      case Failure():
        throw result.error;
    }
  }
}

final _theBringerOfDoomNovice = WorldsManager(provider: TheBringerOfDoomNoviceWorldsProvider());
final _theBringerOfDoomHard = WorldsManager(provider: TheBringerOfDoomHardWorldsProvider());
final _theBringerOfDoomInsane = WorldsManager(provider: TheBringerOfDoomInsaneWorldsProvider());

WorldsManager<BaseWorldsEnums>? getWorldsManager(WorldType type, WorldDifficulty difficulty) {
  return switch (type) {
    WorldType.theBringerOfDoom => switch (difficulty) {
      WorldDifficulty.novice => _theBringerOfDoomNovice,
      WorldDifficulty.easy => null,
      WorldDifficulty.normal => null,
      WorldDifficulty.hard => _theBringerOfDoomHard,
      WorldDifficulty.insane => _theBringerOfDoomInsane,
    },
  };
}
