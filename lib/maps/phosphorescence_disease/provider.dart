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

enum PhosphorescenceDiseaseNightmareWorlds implements BaseWorldsEnums {
  map1;

  int get _assertIndex => switch (this) {
    PhosphorescenceDiseaseNightmareWorlds.map1 => 1,
  };
}

class PhosphorescenceDiseaseWorldsNightmareProvider extends WorldsProvider<PhosphorescenceDiseaseNightmareWorlds> {
  @override WorldType get type => WorldType.phosphorescenceDisease;
  @override WorldDifficulty get difficulty => WorldDifficulty.nightmare;
  @override WorldCodec get codec => phosphorescenceDiseaseCodec;
  @override List<PhosphorescenceDiseaseNightmareWorlds> get allWorlds => PhosphorescenceDiseaseNightmareWorlds.values;
  @override List<GroundLayer> get allLayers => const <GroundLayer>[
    PhosphorescenceDiseaseLayer.level1,
    PhosphorescenceDiseaseLayer.level2,
    PhosphorescenceDiseaseLayer.level3,
  ];
  @override List<EntranceType> get validEntrances => const <EntranceType>[PhosphorescenceDiseaseEntranceType.main];
  @override String worldAssets(PhosphorescenceDiseaseNightmareWorlds world) => 'world_${world._assertIndex}.data';

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
