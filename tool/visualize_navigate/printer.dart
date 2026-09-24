import 'dart:io';

import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/the_bringer_of_doom.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';

import '../precompute_navigator.dart';

void main(List<String> args) async {
  // TODO: parse arguments.
  const worldType = WorldType.theBringerOfDoom;
  const worldDifficulty = WorldDifficulty.insane;
  const worldEnum = TheBringerOfDoomInsaneWorlds.northB;
  const worldEntrance = EntranceType.main;

  final provider = worldProvider(worldType, worldDifficulty)!;
  final root = Directory.current;
  final structuresBytes = await readAsset(root, worldType, worldDifficulty, 'structures.data');
  final structures = deserializeStructures(structuresBytes);
  final worldBytes = await readAsset(root, worldType, worldDifficulty, provider.worldAssets(worldEnum));
  final worldInstance = constructWorld(structures, deserializeWorld(worldBytes));
  final arguments = provider.navigateArguments(worldInstance, worldEntrance);
  navigate(worldInstance, arguments, debugPrint: true);
}
