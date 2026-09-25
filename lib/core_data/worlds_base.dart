import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/navigator_double.dart';

abstract interface class BaseWorldsEnums implements Enum {
}

abstract class WorldsProvider<W extends BaseWorldsEnums> {
  WorldType get type;
  WorldDifficulty get difficulty;
  List<W> get allWorlds;
  List<EntranceType> get validEntrances;
  String worldAssets(W world);
  MainEntranceFeature inferMainEntranceFeature(World world, EntranceType entrance);
  SideEntranceFeature inferSideEntranceFeature(World world, EntranceType entrance);
  NavigateArguments navigateArguments(World world, EntranceType entrance);
  NavigateDoubleArguments navigateDoubleArguments(World world, EntranceType entrance1, EntranceType entrance2) {
    final origin1 = navigateArguments(world, entrance1);
    final origin2 = navigateArguments(world, entrance2);
    return NavigateDoubleArguments(
      start1: origin1.start,
      start2: origin2.start,
      resources: origin1.resources,
      exits: origin1.exits,
      keyResource: origin1.keyResource,
    );
  }
  String precomputedNavigateAssets(W world) => '${worldAssets(world)}.navigator';
  List<NavigateArguments> preloadNavigateArguments(World world) => validEntrances.expand((e) {
    final origin = navigateArguments(world, e);
    return [origin, origin.copyWith(exits: <Node>{})];
  }).toList();
  String precomputedNavigateDoubleAssets(W world) => '${worldAssets(world)}.navigator.double';
  List<NavigateDoubleArguments> preloadNavigateDoubleArguments(World world) => validEntrances.expand((a) {
    return validEntrances.expand((b) {
      final origin = navigateDoubleArguments(world, a, b);
      return [origin, origin.copyWith(exits: <Node>{})];
    });
  }).toList();
}
