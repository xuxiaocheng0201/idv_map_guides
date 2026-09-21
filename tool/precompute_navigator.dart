import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';

WorldsProvider<dynamic>? worldProvider(WorldType type, WorldDifficulty diff) {
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

Future<bool> _isUpToDate(Directory root) async {
  // FIXME: may save hash?
  final path = File('${root.path}/assets/navigator_time.precomputed');
  if (!await path.exists()) return false;
  final outTime = (await path.stat()).modified;
  await for (final entity in Directory('${root.path}/assets/maps').list(recursive: true)) {
    if (entity is File && !entity.path.endsWith('.precomputed')) {
      if ((await entity.stat()).modified.isAfter(outTime)) return false;
    }
  }
  return true;
}

Future<void> _setUpToDate(Directory root) async {
  final path = File('${root.path}/assets/navigator_time.precomputed');
  if (await path.exists()) await path.delete();
  await path.create();
}

Future<void> main(List<String> args) async {
  final root = Directory.current;
  if (!args.contains('--force') && await _isUpToDate(root)) {
    stdout.writeln('[precompute] 缓存有效，跳过');
    return;
  }
  stdout.writeln('[precompute] 开始预计算导航');
  final entries = <String, Uint8List>{};
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
        final worldFile = deserializeWorld(worldBytes);
        final worldInstance = constructWorld(structures, worldFile);
        final args = provider.preloadNavigateArguments(worldInstance);
        stdout.writeln('[precompute] ($current/$total) ${type.name}/${difficulty.name} world=${world.toString()} 开始，共 ${args.length} 条导航');
        for (int i = 0; i < args.length; i++) {
          final arg = args[i];
          stdout.writeln('[precompute] ($current/$total) (${i+1}/${args.length}) ${type.name}/${difficulty.name} world=${world.toString()} 计算中...');
          final nodes = navigate(worldInstance, arg);
          final key = '${type.name}/${difficulty.name}/${world.index}/${arg.identify}';
          entries[key] = serializeNavigatePath(nodes);
        }
      }
    }
  }

  // 生成 .g.dart 文件
  final outputPath = '${root.path}/lib/core_navigator/precomputed_navigator.g.dart';
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// coverage:ignore-file')
    ..writeln('// 由 tool/precompute.dart 生成')
    ..writeln()
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln('final Map<String, Uint8List> precomputedNavigateData = {');
  for (final e in entries.entries) {
    buffer.writeln("  '${e.key}': base64Decode('${base64Encode(e.value)}'),");
  }
  buffer.writeln('};');
  await File(outputPath).writeAsString(buffer.toString());
  stdout.writeln('[precompute] 已写入 $outputPath (${entries.length} 条导航)');

  await _setUpToDate(root);
}
