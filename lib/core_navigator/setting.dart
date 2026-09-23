import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/navigator_double.dart';

part 'setting.freezed.dart';

@freezed
abstract class DefaultNavigateSettings with _$DefaultNavigateSettings {
  DefaultNavigateSettings._();
  factory DefaultNavigateSettings({
    EntranceType? startEntrance,
    @Default(true) bool useResources,
    @Default(true) bool useKeyResource,
    @Default(true) bool useExits,
    // 双人模式
    @Default(false) bool useDouble,
    EntranceType? startEntrance2,
  }) = _DefaultNavigateSettings;
}

@freezed
abstract class UnionNavigateArguments with _$UnionNavigateArguments {
  UnionNavigateArguments._();
  factory UnionNavigateArguments({
    required Node start,
    required Set<Node> resources,
    required Set<Node> exits,
    KeyResource? keyResource,
    required Node start2,
  }) = _UnionNavigateArguments;

  static UnionNavigateArguments fromProvider({
    required WorldsProvider<dynamic> provider,
    required World world,
    required DefaultNavigateSettings setting,
    required EntranceType defaultEntrance,
  }) {
    final baseEntrance1 = setting.startEntrance ?? defaultEntrance;
    final baseEntrance2 = setting.startEntrance2 ?? setting.startEntrance ?? defaultEntrance;
    final originOne = provider.navigateArguments(world, baseEntrance1);
    final originDouble = provider.navigateDoubleArguments(world, baseEntrance1, baseEntrance2);
    var resources = originOne.resources;
    KeyResource? keyResource = originOne.keyResource;
    var exits = originOne.exits;
    if (!setting.useResources) {
      resources = <Node>{};
    }
    if (!setting.useKeyResource) {
      keyResource = null;
    }
    if (!setting.useExits == true) {
      exits = <Node>{};
    }
    return UnionNavigateArguments(
      start: originOne.start,
      resources: resources,
      exits: exits,
      keyResource: keyResource,
      start2: originDouble.start2,
    );
  }

  NavigateArguments get oneArgument => NavigateArguments(
    start: start,
    resources: resources,
    exits: exits,
    keyResource: keyResource,
  );

  NavigateDoubleArguments get twoArgument => NavigateDoubleArguments(
    start1: start,
    start2: start2,
    resources: resources,
    exits: exits,
    keyResource: keyResource,
  );
}
