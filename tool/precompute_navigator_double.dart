import 'dart:io';

import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/modules.dart';
import 'package:idv_map_guides/core_navigator/navigator_double.dart';
import 'package:idv_map_guides/core_navigator/serde.dart';

import 'precompute_navigator.dart' hide isWorldUpToDate;

Future<bool> isWorldUpToDate(
  Directory root,
  WorldType type,
  WorldDifficulty difficulty,
  String name,
  String expectedHash,
  WorldCodec codec,
) async {
  final file = File('${root.path}/assets/maps/${type.assets}/${difficulty.assets}/$name.precomputed');
  if (!await file.exists()) return false;
  try {
    final content = await file.readAsBytes();
    final (storedHash, _) = deserializePrecomputedNavigateDoublePath(content, codec);
    return storedHash == expectedHash;
  } catch (_) {
    return false;
  }
}

Future<void> main(List<String> args) async {
  final force = args.contains('--force') || args.contains('-f');
  final root = Directory.current;
  stdout.writeln('[precompute/double] 开始预计算导航');
  for (final type in WorldType.values) {
    for (final difficulty in WorldDifficulty.values) {
      final provider = worldsProviderFor(type, difficulty);
      if (provider == null) {
        stdout.writeln('[precompute/double] 跳过 ${type.name}/${difficulty.name}（未实现）');
        continue;
      }
      final codec = provider.codec;
      final total = provider.allWorlds.length;
      int current = 0;
      stdout.writeln('[precompute/double] 处理 ${type.name}/${difficulty.name}，共 $total 个世界');
      final structuresBytes = await readAsset(root, type, difficulty, 'structures.data');
      final structures = deserializeStructures(structuresBytes);
      for (final world in provider.allWorlds) {
        current++;
        final worldBytes = await readAsset(root, type, difficulty, provider.worldAssets(world));
        final worldHash = computeWorldHash(structuresBytes, worldBytes);
        if (!force && await isWorldUpToDate(root, type, difficulty, provider.precomputedNavigateDoubleAssets(world), worldHash, codec)) {
          stdout.writeln('[precompute/double] ($current/$total) ${type.name}/${difficulty.name}/$world 缓存有效，跳过');
          continue;
        }
        stdout.writeln('[precompute/double] ($current/$total) ${type.name}/${difficulty.name}/$world 开始计算');
        final worldInstance = constructWorld(structures, deserializeWorld(worldBytes, codec));
        final navigateArgs = provider.preloadNavigateDoubleArguments(worldInstance);
        final paths = <NavigateDoubleArguments, ({List<Node> path1, List<Node> path2})>{};
        for (int i = 0; i < navigateArgs.length; i++) {
          final arg = navigateArgs[i];
          stdout.writeln('[precompute/double] (${i + 1}/${navigateArgs.length}) ${arg.resources.length} 个资源点，计算中...');
          paths[arg] = navigateDouble(worldInstance, arg);
        }
        final data = serializePrecomputedNavigateDoublePath(worldHash, paths, codec);
        await writeAsset(root, type, difficulty, provider.precomputedNavigateDoubleAssets(world), data);
        stdout.writeln('[precompute/double] 已写入 ${type.name}/${difficulty.name}/$world (${paths.length} 条导航)');
      }
    }
  }
}