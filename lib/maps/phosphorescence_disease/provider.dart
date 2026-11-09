import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/entrance.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/feature.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/layer.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/serde.dart';

enum PhosphorescenceDiseaseWorlds implements BaseWorldsEnums {
  onlyOne;

  String get _assets => switch (this) {
    onlyOne => 'world',
  };
}

class PhosphorescenceDiseaseWorldsProvider extends WorldsProvider<PhosphorescenceDiseaseWorlds> {
  @override WorldType get type => WorldType.phosphorescenceDisease;
  @override WorldDifficulty get difficulty => WorldDifficulty.normal;
  @override WorldCodec get codec => phosphorescenceDiseaseCodec;
  @override List<PhosphorescenceDiseaseWorlds> get allWorlds => PhosphorescenceDiseaseWorlds.values;
  @override List<GroundLayer> get allLayers => const <GroundLayer>[
    PhosphorescenceDiseaseLayer.level1,
    PhosphorescenceDiseaseLayer.level2,
    PhosphorescenceDiseaseLayer.level3,
    PhosphorescenceDiseaseLayer.level4,
  ];
  @override List<EntranceType> get validEntrances => const <EntranceType>[PhosphorescenceDiseaseEntranceType.main];
  @override String worldAssets(PhosphorescenceDiseaseWorlds world) => '${world._assets}.data';

  @override
  EntranceFeature inferEntranceFeature(World world, EntranceType entrance) {
    return const PhosphorescenceDiseaseEntranceFeature();
  }

  @override
  NavigateArguments navigateArguments(World world, EntranceType entrance) {
    final entranceNode = world.entranceNode(entrance)!;
    final exitNodes = <EntranceType, Node>{};
    for (final entry in world.entrances.entries) {
      if (!entry.key.displayable) continue;
      exitNodes[entry.key] = Node(entry.key.layer, entry.value.x, entry.value.y);
    }
    return NavigateArguments(
      start: entranceNode,
      resources: Set.of(world.resources),
      exits: exitNodes.values.toSet(),
    );
  }
}
