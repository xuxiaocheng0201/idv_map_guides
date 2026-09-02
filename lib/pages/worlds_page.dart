import 'dart:math';

import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/painter/world_painter.dart';

class WorldListPageArguments {
  final WorldsManager<dynamic> manager;
  final List<dynamic> worlds;
  const WorldListPageArguments({required this.manager, required this.worlds});
}

class WorldListPage extends StatefulWidget {
  const WorldListPage({super.key});

  @override
  State<WorldListPage> createState() => _WorldListPageState();
}

class _WorldListPageState extends State<WorldListPage> {
  late WorldsManager<dynamic> manager;
  late List<dynamic> worlds;
  bool _initialized = false;
  int _currentWorldIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final argument = ModalRoute.of(context)?.settings.arguments as WorldListPageArguments?;
    if (argument == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }
    manager = argument.manager;
    worlds = argument.worlds;
    _currentWorldIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).worldsShowMap(worlds[_currentWorldIndex].label(context) as String)),
        actions: [
          if (worlds.length > 1)
            IconButton(
              onPressed: () => setState(() {
                _currentWorldIndex += 1;
                if (_currentWorldIndex >= worlds.length) {
                  _currentWorldIndex = 0;
                }
              }),
              icon: const Icon(Icons.swap_horiz),
              tooltip: S.of(context).worldsSwitchMap,
            ),
        ],
      ),
      body: FutureBuilder<World>(
        future: manager.getWorld(worlds[_currentWorldIndex]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final world = snapshot.data!;
          final layers = world.layers.toList()..sort((a, b) => a.index.compareTo(b.index));
          return OrientationBuilder(
            builder: (context, orientation) {
              return Flex(
                direction: switch (orientation) {
                  Orientation.portrait => Axis.vertical,
                  Orientation.landscape => Axis.horizontal,
                },
                children: [
                  for (final layer in layers)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              layer.label(context),
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: _WorldLayerPaint(world: world, layer: layer, auto: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _WorldLayerPaint extends StatelessWidget {
  final World world;
  final GroundLayer layer;
  final bool auto;

  const _WorldLayerPaint({required this.world, required this.layer, required this.auto});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = auto ? WorldPainter.auto(world: world, layer: layer) : WorldPainter(world: world, layer: layer);
          final cellSize = min(constraints.maxWidth / painter.width, constraints.maxHeight / painter.height);
          final paintSize = Size(painter.width * cellSize, painter.height * cellSize);
          return Center(
            child: InteractiveViewer(
              constrained: true,
              child: CustomPaint(
                size: paintSize,
                painter: painter,
              ),
            ),
          );
        },
      ),
    );
  }
}
