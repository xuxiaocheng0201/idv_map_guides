import 'dart:async';

import 'package:cachemesh/cachemesh.dart';
import 'package:flutter/services.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/serde.dart';

class WorldsManager<W extends BaseWorldsEnums> {
  final WorldsProvider<W> provider;
  WorldsManager({required this.provider});

  Future<Uint8List> _loadAssets(String file) async {
    return Uint8List.sublistView(await rootBundle.load('assets/maps/${provider.type.assets}/${provider.difficulty.assets}/$file'));
  }

  final Cache cache = Cache();
  Future<T> _fetchWithCache<T>({required String key, required Future<T> Function() fetch}) async {
    final result = await cache.get(
      key: key,
      fetch: () async {
        final data = await fetch();
        return Result.success(data);
      },
    );
    switch (result) {
      case Success():
        return result.value;
      case Failure():
        throw result.error;
    }
  }

  Future<(Uint8List, Map<String, Structure>)> _getStructures() async {
    return await _fetchWithCache(
      key: 'structures',
      fetch: () async {
        final data = await _loadAssets('structures.data');
        return (data, deserializeStructures(data));
      },
    );
  }

  Future<(Uint8List, World)> _getWorld(W world) async {
    final structures = (await _getStructures()).$2;
    return await _fetchWithCache(
      key: 'world/${world.index}',
      fetch: () async {
        final data = await _loadAssets(provider.worldAssets(world));
        final worldFile = deserializeWorld(data);
        return (data, constructWorld(structures, worldFile));
      },
    );
  }

  Future<void> _getPrecomputedNavigator(W world) async {
    await _fetchWithCache(
      key: 'precomputed/navigate/${world.index}',
      fetch: () async {
        final data = await _loadAssets('${provider.precomputedNavigateAssets(world)}.precomputed');
        final (_, paths) = deserializePrecomputedNavigatePath(data);
        for (final entry in paths.entries) {
          _fetchWithCache(
            key: 'navigate/${world.index}/${entry.key.identify}',
            fetch: () async => entry.value,
          );
        }
        return ();
      },
    );
  }

  void preload() {
    for (final world in provider.allWorlds) {
      unawaited(_getWorld(world));
      unawaited(_getPrecomputedNavigator(world));
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
    await _getPrecomputedNavigator(world);
    return await _fetchWithCache(
      key: 'navigate/${world.index}/${arguments.identify}',
      fetch: () async => await navigateAsync(structuresFile, worldFile, arguments),
    );
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
