import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/classification.dart';
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
  late TabController _tabController;
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
        Navigator.pop(context);
      });
      return;
    }
    manager = argument.manager;
    final entrances = manager.provider.validEntrances;
    _tabController = TabController(length: entrances.length, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    for (final entrance in manager.provider.validEntrances) {
      final featureMap = SplayTreeMap<EntranceFeature, LinkedHashMap<BoolList, List<dynamic>>>((a, b) => a.compareTo(b));
      for (final worldType in manager.provider.allWorlds) {
        final world = await manager.getWorld(worldType);
        final painter = EntranceThumbnailPainter.auto(world: world, entrance: entrance);
        final signature = painter.getSignature();
        final feature = switch (entrance) {
          EntranceType.main => EntranceFeature.main(feature: manager.provider.inferMainEntranceFeature(world, entrance)),
          EntranceType.sideGround => EntranceFeature.side(feature: manager.provider.inferSideEntranceFeature(world, entrance)),
          EntranceType.sideSecond => EntranceFeature.side(feature: manager.provider.inferSideEntranceFeature(world, entrance)),
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrances = manager.provider.validEntrances;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).entrancesChooseMap),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            for (final entrance in entrances)
              Tab(text: entrance.label(context)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
            controller: _tabController,
            children: [
              for (final entrance in entrances)
                _buildEntranceGrid(entrance),
            ],
          ),
    );
  }

  Widget _buildEntranceGrid(EntranceType entrance) {
    final worlds = _worlds[entrance]!.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: worlds.length,
      itemBuilder: (context, featureIndex) {
        final feature = worlds[featureIndex].key;
        final entries = worlds[featureIndex].value.entries.toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(feature.label(context)),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 180 / (180 + 4 + MediaQuery.textScalerOf(context).scale(12)),
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final worlds = entry.value;
                    final firstWorld = worlds.first;
                    return FutureBuilder<World>(
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
                              arguments: WorldListPageArguments(manager: manager, worlds: worlds),
                            );
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: CustomPaint(
                                  painter: EntranceThumbnailPainter.auto(world: world, entrance: entrance),
                                  size: Size.infinite,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                worlds.map((m) => m.label(context) as String).join(' / '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
