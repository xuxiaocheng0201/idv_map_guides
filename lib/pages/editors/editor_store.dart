import 'dart:typed_data';

import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';

const int defaultCanvasWidth = 5;
const int defaultCanvasHeight = 5;
const double vertexHitRadius = 12.0;

const int defaultWorldMinX = -20;
const int defaultWorldMaxX = 20;
const int defaultWorldMinY = 0;
const int defaultWorldMaxY = 30;

WorldFile emptyWorldFile(WorldCodec codec) => WorldFile(
  layers: Set.of(codec.layers),
  minX: defaultWorldMinX,
  maxX: defaultWorldMaxX,
  minY: defaultWorldMinY,
  maxY: defaultWorldMaxY,
  instances: <StructureInstance>[],
  entrances: <EntranceType, Position>{},
);

World emptyWorld(WorldCodec codec) => World(
  layers: Set.of(codec.layers),
  minX: defaultWorldMinX,
  maxX: defaultWorldMaxX,
  minY: defaultWorldMinY,
  maxY: defaultWorldMaxY,
);

class EditorStore {
  EditorStore._(this.codec)
      : structuresData = serializeStructures(<String, Structure>{}),
        worldData = serializeWorld(emptyWorldFile(codec), codec);

  final WorldCodec codec;
  Uint8List structuresData;
  Uint8List worldData;
  String? saveDirectory;
  String? saveFilename;

  void resetWorld() {
    worldData = serializeWorld(emptyWorldFile(codec), codec);
  }
}

final Map<String, EditorStore> _stores = <String, EditorStore>{};

EditorStore editorStoreFor(String mapKey, WorldCodec codec) =>
    _stores.putIfAbsent(mapKey, () => EditorStore._(codec));

class EditorRouteArguments {
  final String mapKey;
  final EditorStore store;
  const EditorRouteArguments({required this.mapKey, required this.store});
}
