import 'dart:math';

import 'package:flutter/material.dart';
import 'package:idv_map_guides/generated/rust/api/map.dart';
import 'package:idv_map_guides/painter/map_painter.dart';

class MapScreen extends StatefulWidget {
  final MapModel map;

  const MapScreen({super.key, required this.map});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Layer _activeLayer;

  @override
  void initState() {
    super.initState();
    _activeLayer = Layer.ground;
  }

  String _layerLabel(Layer layer) {
    switch (layer) {
      case Layer.basement:
        return '地下室';
      case Layer.ground:
        return '一层';
      case Layer.second:
        return '二层';
    }
  }

  @override
  Widget build(BuildContext context) {
    final layers = widget.map.layers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('地图展示'),
        actions: [
          PopupMenuButton<Layer>(
            initialValue: _activeLayer,
            onSelected: (layer) {
              setState(() {
                _activeLayer = layer;
              });
            },
            itemBuilder: (context) => [
              for (final layer in layers)
                PopupMenuItem(
                  value: layer,
                  child: Text(_layerLabel(layer)),
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
                    _layerLabel(_activeLayer),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          final cellSize = min(
            availableWidth / widget.map.width.toDouble(),
            availableHeight / widget.map.height.toDouble(),
          );

          final mapWidth = widget.map.width.toDouble() * cellSize;
          final mapHeight = widget.map.height.toDouble() * cellSize;

          return InteractiveViewer(
            constrained: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                size: Size(mapWidth, mapHeight),
                painter: MapPainter(widget.map, _activeLayer),
              ),
            ),
          );
        },
      ),
    );
  }
}
