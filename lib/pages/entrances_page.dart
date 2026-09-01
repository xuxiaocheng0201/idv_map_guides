import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/world.dart';
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
  final Map<EntranceType, LinkedHashMap<BoolList, List<dynamic>>> _signatures = {};
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
      final map = LinkedHashMap<BoolList, List<dynamic>>(
        equals: (a, b) => const ListEquality<bool>().equals(a, b),
        hashCode: (a) => const ListEquality<bool>().hash(a),
      );
      for (final worldType in manager.provider.allWorlds) {
        final world = await manager.getWorld(worldType);
        final painter = EntranceThumbnailPainter.auto(world: world, entrance: entrance);
        final signature = painter.getSignature();
        map.putIfAbsent(signature, () => []).add(worldType);
      }
      _signatures[entrance] = map;
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
    final entries = _signatures[entrance]!.entries.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
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
    );
  }
}
