import 'dart:math';

import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/painter/world_painter.dart';

class MapPage extends StatefulWidget {
  final World world;

  const MapPage({super.key, required this.world});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GroundLayer _activeLayer;

  @override
  void initState() {
    super.initState();
    _activeLayer = GroundLayer.ground;
  }

  @override
  Widget build(BuildContext context) {
    final layers = widget.world.layers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图展示'),
        actions: [
          PopupMenuButton<GroundLayer>(
            initialValue: _activeLayer,
            onSelected: (layer) {
              setState(() => _activeLayer = layer);
            },
            itemBuilder: (context) => [
              for (final layer in layers)
                PopupMenuItem(
                  value: layer,
                  child: Text(layer.label(context)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _activeLayer.label(context),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = min(constraints.maxWidth / widget.world.width, constraints.maxHeight / widget.world.height);
            final paintSize = Size(widget.world.width * cellSize, widget.world.height * cellSize);
            return InteractiveViewer(
              constrained: false,
              child: CustomPaint(
                size: paintSize,
                painter: WorldPainter(world: widget.world, layer: _activeLayer),
              ),
            );
          },
        ),
      ),
    );
  }
}
