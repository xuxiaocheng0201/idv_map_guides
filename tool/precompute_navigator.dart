import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/serde.dart';

WorldsProvider<BaseWorldsEnums>? worldProvider(WorldType type, WorldDifficulty diff) {
  return switch (type) {
    WorldType.theBringerOfDoom => switch (diff) {
      WorldDifficulty.novice => TheBringerOfDoomNoviceWorldsProvider(),
      WorldDifficulty.easy => null,
      WorldDifficulty.normal => null,
      WorldDifficulty.hard => TheBringerOfDoomHardWorldsProvider(),
      WorldDifficulty.insane => TheBringerOfDoomInsaneWorldsProvider(),
    },
  };
}

Future<Uint8List> readAsset(Directory root, WorldType type, WorldDifficulty difficulty, String name) async {
  final path = '${root.path}/assets/maps/${type.assets}/${difficulty.assets}/$name';
  final file = File(path);
  if (!await file.exists()) throw StateError('Missing: $path');
  return Uint8List.fromList(await file.readAsBytes());
}

Future<void> writeAsset(Directory root, WorldType type, WorldDifficulty difficulty, String name, Uint8List data) async {
  final path = '${root.path}/assets/maps/${type.assets}/${difficulty.assets}/$name.precomputed';
  await File(path).writeAsBytes(data);
}

String computeWorldHash(Uint8List structuresBytes, Uint8List worldBytes) {
  final structuresHash = sha256.convert(structuresBytes).toString();
  final worldHash = sha256.convert(worldBytes).toString();
  return 'v2/$structuresHash/$worldHash';
}

Future<bool> isWorldUpToDate(
  Directory root,
  WorldType type,
  WorldDifficulty difficulty,
  String name,
  String expectedHash,
) async {
  final file = File('${root.path}/assets/maps/${type.assets}/${difficulty.assets}/$name.precomputed');
  if (!await file.exists()) return false;
  try {
    final content = await file.readAsBytes();
    final (storedHash, _) = deserializePrecomputedNavigatePath(content);
    return storedHash == expectedHash;
  } catch (_) {
    return false;
  }
}

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final root = Directory.current;
  stdout.writeln('[precompute] 开始预计算导航');
  for (final type in WorldType.values) {
    for (final difficulty in WorldDifficulty.values) {
      final provider = worldProvider(type, difficulty);
      if (provider == null) {
        stdout.writeln('[precompute] 跳过 ${type.name}/${difficulty.name}（未实现）');
        continue;
      }
      final total = provider.allWorlds.length;
      int current = 0;
      stdout.writeln('[precompute] 处理 ${type.name}/${difficulty.name}，共 $total 个世界');
      final structuresBytes = await readAsset(root, type, difficulty, 'structures.data');
      final structures = deserializeStructures(structuresBytes);
      for (final world in provider.allWorlds) {
        current++;
        final worldBytes = await readAsset(root, type, difficulty, provider.worldAssets(world));
        final worldHash = computeWorldHash(structuresBytes, worldBytes);
        if (!force && await isWorldUpToDate(root, type, difficulty, provider.precomputedNavigateAssets(world), worldHash)) {
          stdout.writeln('[precompute] ($current/$total) ${type.name}/${difficulty.name}/$world 缓存有效，跳过');
          continue;
        }
        stdout.writeln('[precompute] ($current/$total) ${type.name}/${difficulty.name}/$world 开始计算');
        final worldInstance = constructWorld(structures, deserializeWorld(worldBytes));
        final navigateArgs = provider.preloadNavigateArguments(worldInstance);
        final paths = <NavigateArguments, List<Node>>{};
        for (int i = 0; i < navigateArgs.length; i++) {
          final arg = navigateArgs[i];
          stdout.writeln('[precompute] (${i + 1}/${navigateArgs.length}) 计算中...');
          paths[arg] = navigate(worldInstance, arg);
        }
        final data = serializePrecomputedNavigatePath(worldHash, paths);
        await writeAsset(root, type, difficulty, provider.precomputedNavigateAssets(world), data);
        stdout.writeln('[precompute] 已写入 ${type.name}/${difficulty.name}/$world (${paths.length} 条导航)');
      }
    }
  }
}
