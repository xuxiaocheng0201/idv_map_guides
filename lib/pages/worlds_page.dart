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
  dynamic _currentWorld;

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
    _currentWorld = worlds.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).worldsShowMap(_currentWorld.label(context) as String)),
        actions: [
          if (worlds.length > 1)
            DropdownButton<dynamic>(
              value: _currentWorld,
              items: worlds
                  .map((world) => DropdownMenuItem(value: world, child: Text(world.label(context) as String)))
                  .toList(),
              onChanged: (value) {
                if (value != null && value != _currentWorld) {
                  setState(() => _currentWorld = value);
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<World>(
        future: manager.getWorld(_currentWorld),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final world = snapshot.data!;
          final layers = world.layers.toList()..sort((a, b) => a.index.compareTo(b.index));
          return OrientationBuilder(
            builder: (context, orientation) {
              if (orientation == Orientation.portrait) {
                return Column(
                  children: [
                    for (final layer in layers)
                      Expanded(
                        child: _LayerMapItem(world: world, layer: layer),
                      ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    for (final layer in layers)
                      Expanded(
                        child: _LayerMapItem(world: world, layer: layer),
                      ),
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _LayerMapItem extends StatelessWidget {
  final World world;
  final GroundLayer layer;

  const _LayerMapItem({required this.world, required this.layer});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellSize = min(constraints.maxWidth / world.width, constraints.maxHeight / world.height);
                final paintSize = Size(world.width * cellSize, world.height * cellSize);
                return Center(
                  child: InteractiveViewer(
                    constrained: true,
                    child: CustomPaint(
                      size: paintSize,
                      painter: WorldPainter(world: world, layer: layer),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
