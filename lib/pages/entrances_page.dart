import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/l10n.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/pages/worlds_page.dart';
import 'package:idv_map_guides/painter/entrance_thumbnail_painter.dart';
import 'package:idv_map_guides/routes.dart';

class EntranceFeaturePageArgument {
  final WorldsManager<dynamic> manager;
  const EntranceFeaturePageArgument({required this.manager});
}

class EntranceFeaturePage extends StatefulWidget {
  const EntranceFeaturePage({super.key});

  @override
  State<EntranceFeaturePage> createState() => _EntranceFeaturePageState();
}

class _EntranceFeaturePageState extends State<EntranceFeaturePage> with SingleTickerProviderStateMixin {
  late WorldsManager<dynamic> manager;
  bool _loading = true;
  final Map<EntranceType, SplayTreeMap<EntranceFeature, LinkedHashMap<BoolList, List<dynamic>>>> _worlds = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final argument = ModalRoute.of(context)?.settings.arguments as EntranceFeaturePageArgument?;
    if (argument == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.popAndPushNamed(context, Routes.home);
        }
      });
      return;
    }
    manager = argument.manager;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    for (final entrance in manager.provider.validEntrances) {
      assert(entrance.displayable);
      final featureMap = SplayTreeMap<EntranceFeature, LinkedHashMap<BoolList, List<dynamic>>>();
      for (final worldType in manager.provider.allWorlds) {
        final world = await manager.getWorld(worldType);
        final painter = EntranceThumbnailPainter.auto(world: world, entrance: entrance);
        final signature = painter.getSignature();
        final feature = switch (entrance) {
          EntranceType.main => EntranceFeature.main(feature: manager.provider.inferMainEntranceFeature(world, entrance)),
          EntranceType.sideGround => EntranceFeature.side(feature: manager.provider.inferSideEntranceFeature(world, entrance)),
          EntranceType.sideSecond => EntranceFeature.side(feature: manager.provider.inferSideEntranceFeature(world, entrance)),
          EntranceType.alterBasement => throw UnsupportedError('alter basement is not displayable'),
        };
        featureMap.putIfAbsent(feature, () => LinkedHashMap<BoolList, List<dynamic>>(
          equals: (a, b) => const ListEquality<bool>().equals(a, b),
          hashCode: (a) => const ListEquality<bool>().hash(a),
        )).putIfAbsent(signature, () => []).add(worldType);
      }
      _worlds[entrance] = featureMap;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).entrancesChooseMap(manager.provider.type.label(context), manager.provider.difficulty.label(context))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildEntranceTabBar(context),
    );
  }

  Widget _buildEntranceTabBar(BuildContext context) {
    final entrances = manager.provider.validEntrances;
    return DefaultTabController(
      length: entrances.length,
      child: Column(
        children: [
          TabBar(
            tabs: [
              for (final entrance in entrances)
                Tab(text: entrance.label(context)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final entrance in entrances)
                  _buildFeatureTabBar(context, entrance),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTabBar(BuildContext context, EntranceType entrance) {
    final worlds = _worlds[entrance]!;
    return DefaultTabController(
      length: worlds.length,
      child: Column(
        children: [
          TabBar.secondary(
            tabs: [
              for (final feature in worlds.keys)
                Tab(text: feature.label(context)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final entry in worlds.entries)
                  _buildThumbnailGrid(context, entrance, entry.key, entry.value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGrid(BuildContext context, EntranceType entrance, EntranceFeature _, LinkedHashMap<BoolList, List<dynamic>> worlds) {
    final worldsList = worlds.values.toList();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: worldsList.length,
        itemBuilder: (context, index) {
          final worlds = worldsList[index];
          final firstWorld = worlds.first;
          return LayoutBuilder(
            builder: (context, constraints) {
              return Tooltip(
                message: worlds.map((m) => worldLabel(m, context)).join(' / '),
                verticalOffset: constraints.maxWidth / 2 + 4,
                showDuration: const Duration(seconds: 3),
                child: FutureBuilder<World>(
                  future: manager.getWorld(firstWorld),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final world = snapshot.data!;
                    return InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          Routes.worlds,
                          arguments: WorldListPageArguments(manager: manager, worlds: worlds, entrance: entrance),
                        );
                      },
                      child: CustomPaint(
                        painter: EntranceThumbnailPainter.auto(world: world, entrance: entrance),
                      ),
                    );
                  },
                ),
              );
            }
          );
        },
      ),
    );
  }
}
