import 'dart:async';

import 'package:cachemesh/cachemesh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/navigator_double.dart';
import 'package:idv_map_guides/core_navigator/serde.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/provider.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class WorldsManager<W extends BaseWorldsEnums> {
  final WorldsProvider<W> provider;
  WorldsManager({required this.provider});

  Future<Uint8List> _loadAssets(String file) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'loadAssets',
      data: {
        'type': provider.type.assets,
        'difficulty': provider.difficulty.assets,
        'file': file,
      },
    ));
    return Uint8List.sublistView(await rootBundle.load('assets/maps/${provider.type.assets}/${provider.difficulty.assets}/$file'));
  }

  final Cache cache = Cache();
  Future<T> _fetchWithCache<T>({required String key, required Future<T> Function() fetch, String? debugLabel}) async {
    final result = await cache.get(
      key: key,
      fetch: () async {
        try {
          final data = await fetch();
          return Result.success(data);
        } catch (e, st) {
          return Result<T>.failure(e, st);
        }
      },
    );
    switch (result) {
      case Success():
        return result.value;
      case Failure():
        if (result.stackTrace == null) throw result.error;
        if (kDebugMode) {
          final message = debugLabel ?? key;
          print('error when get `$message`');
        }
        Error.throwWithStackTrace(result.error, result.stackTrace!);
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
        final worldFile = deserializeWorld(data, provider.codec);
        return (data, constructWorld(structures, worldFile));
      },
      debugLabel: '${world.runtimeType}/${world.name}',
    );
  }

  Future<void> _getPrecomputedNavigator(W world) async {
    try {
      await _fetchWithCache(
        key: 'precomputed/navigate/${world.index}',
        fetch: () async {
          final data = await _loadAssets('${provider.precomputedNavigateAssets(world)}.precomputed');
          if (data.isEmpty) throw FormatException();
          final (_, paths) = deserializePrecomputedNavigatePath(data, provider.codec);
          for (final entry in paths.entries) {
            _fetchWithCache(
              key: 'navigate/${world.index}/${entry.key.identify}',
              fetch: () async => entry.value,
            );
          }
          return ();
        },
      );
    } on Exception {
      // silently fallback to compute realtime
    } on Error {
      // silently fallback to compute realtime
    }
  }

  Future<void> _getPrecomputedNavigatorDouble(W world) async {
    try {
      await _fetchWithCache(
        key: 'precomputed/navigate_double/${world.index}',
        fetch: () async {
          final data = await _loadAssets('${provider.precomputedNavigateDoubleAssets(world)}.precomputed');
          if (data.isEmpty) throw FormatException();
          final (_, paths) = deserializePrecomputedNavigateDoublePath(data, provider.codec);
          for (final entry in paths.entries) {
            _fetchWithCache(
              key: 'navigate_double/${world.index}/${entry.key.identify}',
              fetch: () async => entry.value,
            );
          }
          return ();
        },
      );
    } on Exception {
      // silently fallback to compute realtime
    } on Error {
      // silently fallback to compute realtime
    }
  }

  void preload() {
    for (final world in provider.allWorlds) {
      unawaited(_getWorld(world));
      unawaited(_getPrecomputedNavigator(world));
      unawaited(_getPrecomputedNavigatorDouble(world));
    }
  }

  Future<World> getWorld(W world) async {
    return (await _getWorld(world)).$2;
  }

  Future<List<Node>> getNavigateResult(W world, NavigateArguments arguments) async {
    final structuresFile = (await _getStructures()).$1;
    final worldFile = (await _getWorld(world)).$1;
    await _getPrecomputedNavigator(world);
    return await _fetchWithCache(
      key: 'navigate/${world.index}/${arguments.identify}',
      fetch: () async => await navigateAsync(provider.codec, structuresFile, worldFile, arguments),
    );
  }

  Future<({List<Node> path1, List<Node> path2})> getNavigateDoubleResult(W world, NavigateDoubleArguments arguments) async {
    final structuresFile = (await _getStructures()).$1;
    final worldFile = (await _getWorld(world)).$1;
    await _getPrecomputedNavigatorDouble(world);
    return await _fetchWithCache(
      key: 'navigate_double/${world.index}/${arguments.identify}',
      fetch: () async => await navigateDoubleAsync(provider.codec, structuresFile, worldFile, arguments),
    );
  }
}

final _theBringerOfDoomNovice = WorldsManager(provider: TheBringerOfDoomNoviceWorldsProvider());
final _theBringerOfDoomEasy = WorldsManager(provider: TheBringerOfDoomEasyWorldsProvider());
final _theBringerOfDoomHard = WorldsManager(provider: TheBringerOfDoomHardWorldsProvider());
final _theBringerOfDoomNightmare = WorldsManager(provider: TheBringerOfDoomNightmareWorldsProvider());
final _phosphorescence = WorldsManager(provider: PhosphorescenceDiseaseWorldsProvider());

WorldsManager<BaseWorldsEnums>? getWorldsManager(WorldType type, WorldDifficulty difficulty) {
  return switch (type) {
    WorldType.theBringerOfDoom => switch (difficulty) {
      WorldDifficulty.novice => _theBringerOfDoomNovice,
      WorldDifficulty.easy => _theBringerOfDoomEasy,
      WorldDifficulty.normal => null,
      WorldDifficulty.hard => _theBringerOfDoomHard,
      WorldDifficulty.nightmare => _theBringerOfDoomNightmare,
    },
    WorldType.phosphorescenceDisease => switch (difficulty) {
      WorldDifficulty.normal => _phosphorescence,
      _ => null,
    },
  }?..preload();
}
