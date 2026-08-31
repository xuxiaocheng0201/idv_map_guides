import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/painter/entrance_thumbnail_painter.dart';

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
  final Map<EntranceType, LinkedHashMap<BoolList, List<dynamic>>> _signatureMaps = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
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
    _initialized = true;
  }

  Future<void> _loadAllData() async {
    for (final entrance in manager.provider.validEntrances) {
      final map = LinkedHashMap<BoolList, List<dynamic>>(
        equals: (a, b) => const ListEquality<bool>().equals(a, b),
        hashCode: (a) => const ListEquality<bool>().hash(a),
      );
      for (final worldType in manager.provider.allWorlds) {
        final world = await manager.getWorld(worldType);
        final painter = EntranceThumbnailPainter(world: world, entrance: entrance);
        final signature = painter.getSignature();
        map.putIfAbsent(signature, () => []).add(worldType);
      }
      _signatureMaps[entrance] = map;
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
    final entries = _signatureMaps[entrance]!.entries.toList();
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
        final maps = entry.value;
        final firstMap = maps.first;
        return FutureBuilder<World>(
          future: manager.getWorld(firstMap),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final world = snapshot.data!;
            return InkWell(
              onTap: () {}, // TODO
              child: Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      painter: EntranceThumbnailPainter(world: world, entrance: entrance),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    maps.map((m) => m.label(context) as String).join(' / '),
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
