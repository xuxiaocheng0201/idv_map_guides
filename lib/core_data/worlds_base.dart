import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';

abstract class WorldsProvider<W> {
  WorldType get type;
  WorldDifficulty get difficulty;
  List<W> get allWorlds;
  List<EntranceType> get validEntrances;
  String worldAssets(W world);
  MainEntranceFeature inferMainEntranceFeature(World world, EntranceType entrance);
  SideEntranceFeature inferSideEntranceFeature(World world, EntranceType entrance);
  NavigateArguments navigateArguments(World world, EntranceType entrance);
  List<NavigateArguments> preloadNavigateArguments(World world) => validEntrances.expand((e) {
    final origin = navigateArguments(world, e);
    return [origin, origin.copyWith(exits: <Node>{})];
  }).toList();
}
