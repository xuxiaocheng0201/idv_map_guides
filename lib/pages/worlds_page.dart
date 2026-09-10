import 'dart:math';

import 'package:collection/collection.dart';
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

  bool _isFullscreen = false;
  int _currentLayerIndex = 0;

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
        title: Text(S.of(context).worldsShowMap),
        centerTitle: true,
        actions: [
          if (worlds.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SegmentedButton(
                selected: {_currentWorld},
                segments: [
                  for (final world in worlds)
                    ButtonSegment(
                      value: world,
                      label: Text(world.label(context) as String),
                    )
                ],
                emptySelectionAllowed: false,
                multiSelectionEnabled: false,
                onSelectionChanged: (w) => setState(() {
                  _currentWorld = w.first;
                }),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
              icon: Icon(_isFullscreen ? Icons.grid_view : Icons.fullscreen),
              tooltip: _isFullscreen ? S.of(context).worldsFullscreenExit : S.of(context).worldsFullscreen,
            ),
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
          final layers = world.layers.sortedBy((e) => e.index);
          if (_currentLayerIndex >= layers.length) {
            setState(() => _currentLayerIndex = 0);
          }
          if (_isFullscreen) {
            final layer = layers[_currentLayerIndex];
            return Column(
              children: [
                SegmentedButton(
                  selected: {_currentLayerIndex},
                  segments: [
                    for (int i = 0; i < layers.length; i++)
                      ButtonSegment(
                        value: i,
                        label: Text(layers[i].label(context)),
                      )
                  ],
                  emptySelectionAllowed: false,
                  multiSelectionEnabled: false,
                  onSelectionChanged: (i) => setState(() {
                    _currentLayerIndex = i.first;
                  }),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _WorldLayerPaint(world: world, layer: layer, auto: true),
                  ),
                ),
              ],
            );
          } else {
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
          }
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
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final painter = auto ? WorldPainter.auto(world: world, layer: layer) : WorldPainter(world: world, layer: layer);
            final cellSize = min(constraints.maxWidth / painter.width, constraints.maxHeight / painter.height);
            final paintSize = Size(painter.width * cellSize, painter.height * cellSize);
            return SizedBox.fromSize(
              size: paintSize,
              child: CustomPaint(
                size: paintSize,
                painter: painter,
              ),
            );
          },
        ),
      ),
    );
  }
}
