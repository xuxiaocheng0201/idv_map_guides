import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:comparators/comparators.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:messagepack/messagepack.dart';

abstract interface class WorldCodec {
  GroundLayer layerFromCode(int code);
  int layerToCode(GroundLayer layer);
  List<GroundLayer> get layers;

  EntranceType entranceFromCode(int code);
  int entranceToCode(EntranceType type);
  List<EntranceType> get entrances;
}

class SimpleWorldCodec implements WorldCodec {
  @override
  final List<GroundLayer> layers;
  @override
  final List<EntranceType> entrances;

  final Map<int, GroundLayer> _layerByCode;
  final Map<GroundLayer, int> _codeByLayer = Map.identity();
  final Map<int, EntranceType> _entranceByCode;
  final Map<EntranceType, int> _codeByEntrance = Map.identity();

  SimpleWorldCodec({
    required List<GroundLayer> layers,
    required List<EntranceType> entrances,
  })  : layers = List.unmodifiable(layers),
        entrances = List.unmodifiable(entrances),
        _layerByCode = {for (final l in layers) l.code: l},
        _entranceByCode = {for (final e in entrances) e.code: e} {
    for (final l in layers) {
      _codeByLayer[l] = l.code;
    }
    for (final e in entrances) {
      _codeByEntrance[e] = e.code;
    }
  }

  @override
  GroundLayer layerFromCode(int code) {
    final layer = _layerByCode[code];
    if (layer == null) throw FormatException('unknown layer code: $code');
    return layer;
  }

  @override
  int layerToCode(GroundLayer layer) {
    final code = _codeByLayer[layer];
    if (code == null) throw FormatException('unknown layer: $layer');
    return code;
  }

  @override
  EntranceType entranceFromCode(int code) {
    final entrance = _entranceByCode[code];
    if (entrance == null) throw FormatException('unknown entrance code: $code');
    return entrance;
  }

  @override
  int entranceToCode(EntranceType entrance) {
    final code = _codeByEntrance[entrance];
    if (code == null) throw FormatException('unknown entrance: $entrance');
    return code;
  }
}

class _RebuiltLayer implements GroundLayer {
  @override
  final int index;
  @override
  final int code;
  final int? _upCode;
  final int? _downCode;
  final Map<int, GroundLayer> _layersByCode;

  _RebuiltLayer(this.index, this.code, this._upCode, this._downCode, this._layersByCode);

  @override
  GroundLayer? up() => _upCode == null ? null : _layersByCode[_upCode];

  @override
  GroundLayer? down() => _downCode == null ? null : _layersByCode[_downCode];
}

class _RebuiltEntrance implements EntranceType {
  @override
  final int index;
  @override
  final int code;
  @override
  final bool displayable;
  @override
  final GroundLayer layer;

  _RebuiltEntrance({
    required this.index,
    required this.code,
    required this.displayable,
    required this.layer,
  });
}

void _packNullableInt(Packer packer, int? value) {
  if (value == null) {
    packer.packNull();
  } else {
    packer.packInt(value);
  }
}

Uint8List serializeWorldCodec(WorldCodec codec) {
  final packer = Packer();
  packer.packListLength(2);
  packer.packListLength(codec.layers.length);
  for (final layer in codec.layers) {
    packer.packListLength(4);
    packer.packInt(layer.code);
    packer.packInt(layer.index);
    _packNullableInt(packer, layer.up()?.code);
    _packNullableInt(packer, layer.down()?.code);
  }
  packer.packListLength(codec.entrances.length);
  for (final entrance in codec.entrances) {
    packer.packListLength(4);
    packer.packInt(entrance.code);
    packer.packInt(entrance.index);
    packer.packBool(entrance.displayable);
    packer.packInt(entrance.layer.code);
  }
  return packer.takeBytes();
}

WorldCodec deserializeWorldCodec(Uint8List content) {
  final unpacker = Unpacker(content);
  final len = unpacker.unpackListLength();
  if (len != 2) throw FormatException();

  final layersLen = unpacker.unpackListLength();
  final layerCodes = <int>[];
  final layerIndices = <int>[];
  final upCodes = <int?>[];
  final downCodes = <int?>[];
  for (int i = 0; i < layersLen; i++) {
    final l = unpacker.unpackListLength();
    if (l != 4) throw FormatException();
    layerCodes.add(unpacker.unpackInt()!);
    layerIndices.add(unpacker.unpackInt()!);
    upCodes.add(unpacker.unpackInt());
    downCodes.add(unpacker.unpackInt());
  }

  final layersByCode = <int, GroundLayer>{};
  final layers = <GroundLayer>[];
  for (int i = 0; i < layersLen; i++) {
    final layer = _RebuiltLayer(
      layerIndices[i],
      layerCodes[i],
      upCodes[i],
      downCodes[i],
      layersByCode,
    );
    layersByCode[layerCodes[i]] = layer;
    layers.add(layer);
  }

  final entrancesLen = unpacker.unpackListLength();
  final entrances = <EntranceType>[];
  for (int i = 0; i < entrancesLen; i++) {
    final l = unpacker.unpackListLength();
    if (l != 4) throw FormatException();
    final code = unpacker.unpackInt()!;
    final index = unpacker.unpackInt()!;
    final displayable = unpacker.unpackBool();
    final layerCode = unpacker.unpackInt()!;
    if (displayable == null) throw FormatException();
    entrances.add(_RebuiltEntrance(
      code: code,
      index: index,
      displayable: displayable,
      layer: layersByCode[layerCode] ?? (throw FormatException('unknown layer code: $layerCode')),
    ));
  }

  return SimpleWorldCodec(layers: layers, entrances: entrances);
}

extension RotationSerde on Rotation {
  static Rotation unpack(Unpacker unpacker) {
    return switch (unpacker.unpackInt()) {
      0 => Rotation.cw0,
      1 => Rotation.cw90,
      2 => Rotation.cw180,
      3 => Rotation.cw270,
      _ => throw FormatException(),
    };
  }

  void pack(Packer packer) {
    packer.packInt(switch (this) {
      Rotation.cw0 => 0,
      Rotation.cw90 => 1,
      Rotation.cw180 => 2,
      Rotation.cw270 => 3,
    });
  }
}

extension PositionSerde on Position {
  static Position unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 2) throw FormatException();
    final x = unpacker.unpackInt();
    final y = unpacker.unpackInt();
    if (x == null || y == null) throw FormatException();
    return Position(x: x, y: y);
  }

  void pack(Packer packer) {
    packer.packListLength(2);
    packer.packInt(x);
    packer.packInt(y);
  }
}

extension NodeSerde on Node {
  static Node unpack(Unpacker unpacker, WorldCodec codec) {
    final len = unpacker.unpackListLength();
    if (len != 3) throw FormatException();
    final layerCode = unpacker.unpackInt();
    final x = unpacker.unpackInt();
    final y = unpacker.unpackInt();
    if (layerCode == null || x == null || y == null) throw FormatException();
    return Node(codec.layerFromCode(layerCode), x, y);
  }

  void pack(Packer packer, WorldCodec codec) {
    packer.packListLength(3);
    packer.packInt(codec.layerToCode(layer));
    packer.packInt(x);
    packer.packInt(y);
  }
}

extension StairTransportSerde on StairTransport {
  static StairTransport? unpackNullable(Unpacker unpacker) {
    return switch (unpacker.unpackInt()) {
      null => null,
      0 => StairTransport.nothing,
      1 => StairTransport.goUp,
      2 => StairTransport.goDown,
      _ => throw FormatException(),
    };
  }

  void pack(Packer packer) {
    packer.packInt(switch (this) {
      StairTransport.nothing => 0,
      StairTransport.goUp => 1,
      StairTransport.goDown => 2,
    });
  }
}

extension EdgeTypeSerde on EdgeType {
  static EdgeType unpack(Unpacker unpacker) {
    return switch (unpacker.unpackInt()) {
      0 => EdgeType.nothing,
      1 => EdgeType.door,
      2 => EdgeType.innerWall,
      3 => EdgeType.hole,
      _ => throw FormatException(),
    };
  }

  void pack(Packer packer) {
    packer.packInt(switch (this) {
      EdgeType.nothing => 0,
      EdgeType.door => 1,
      EdgeType.innerWall => 2,
      EdgeType.hole => 3,
    });
  }
}

extension CellInfoSerde on CellInfo {
  static CellInfo unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 6) throw FormatException();
    return CellInfo(
      isStair: StairTransportSerde.unpackNullable(unpacker),
      edgeNorth: EdgeTypeSerde.unpack(unpacker),
      edgeEast: EdgeTypeSerde.unpack(unpacker),
      edgeSouth: EdgeTypeSerde.unpack(unpacker),
      edgeWest: EdgeTypeSerde.unpack(unpacker),
      isResource: unpacker.unpackBool() ?? false,
    );
  }

  void pack(Packer packer) {
    packer.packListLength(6);
    if (isStair == null) {
      packer.packNull();
    } else {
      isStair!.pack(packer);
    }
    edgeNorth.pack(packer);
    edgeEast.pack(packer);
    edgeSouth.pack(packer);
    edgeWest.pack(packer);
    packer.packBool(isResource);
  }
}

extension ShapePointSerde on ShapePoint {
  static ShapePoint unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 2) throw FormatException();
    final x = unpacker.unpackDouble();
    final y = unpacker.unpackDouble();
    if (x == null || y == null) throw FormatException();
    return ShapePoint(x: x, y: y);
  }

  void pack(Packer packer) {
    packer.packListLength(2);
    packer.packDouble(x);
    packer.packDouble(y);
  }
}

extension StructureSerde on Structure {
  static Structure unpack(Unpacker unpacker, String name) {
    final len = unpacker.unpackListLength();
    if (len != 4) throw FormatException();
    final isCorridor = unpacker.unpackBool();
    final isNoDirection = unpacker.unpackBool();
    if (isCorridor == null || isNoDirection == null) throw FormatException();
    final mapLen = unpacker.unpackMapLength();
    final cells = <Position, CellInfo>{};
    for (int i = 0; i < mapLen; i++) {
      final key = PositionSerde.unpack(unpacker);
      final value = CellInfoSerde.unpack(unpacker);
      cells[key] = value;
    }
    final outline = <ShapePoint>[];
    final outlineLen = unpacker.unpackListLength();
    for (int i = 0; i < outlineLen; i++) {
      final point = ShapePointSerde.unpack(unpacker);
      outline.add(point);
    }
    return Structure(
      name: name,
      isCorridor: isCorridor,
      isNoDirection: isNoDirection,
      cells: cells,
      outline: outline.isEmpty ? null : outline,
    );
  }

  void pack(Packer packer) {
    packer.packListLength(4);
    packer.packBool(isCorridor);
    packer.packBool(isNoDirection);
    final cells = this.cells.entries.sortedBy((e) => e.key);
    packer.packMapLength(cells.length);
    for (final entry in cells) {
      entry.key.pack(packer);
      entry.value.pack(packer);
    }
    packer.packListLength(outline?.length ?? 0);
    for (final point in outline ?? <ShapePoint>[]) {
      point.pack(packer);
    }
  }
}

Uint8List serializeStructures(Map<String, Structure> structures) {
  final packer = Packer();
  packer.packMapLength(structures.length);
  final list = structures.entries.sortedBy((e) => e.key);
  for (final entry in list) {
    packer.packString(entry.key);
    entry.value.pack(packer);
  }
  return packer.takeBytes();
}

Map<String, Structure> deserializeStructures(Uint8List content) {
  final unpacker = Unpacker(content);
  final mapLen = unpacker.unpackMapLength();
  final structures = <String, Structure>{};
  for (int i = 0; i < mapLen; i++) {
    final key = unpacker.unpackString();
    if (key == null) throw FormatException();
    final value = StructureSerde.unpack(unpacker, key);
    structures[key] = value;
  }
  return structures;
}

extension StructureInstanceSerde on StructureInstance {
  static StructureInstance unpack(Unpacker unpacker, WorldCodec codec) {
    final len = unpacker.unpackListLength();
    if (len != 7) throw FormatException();
    final typeName = unpacker.unpackString();
    final isSuspicious = unpacker.unpackBool();
    final layer = codec.layerFromCode(unpacker.unpackInt()!);
    final originX = unpacker.unpackInt();
    final originY = unpacker.unpackInt();
    final rotation = RotationSerde.unpack(unpacker);
    if (typeName == null || isSuspicious == null || originX == null || originY == null) throw FormatException();
    final mapLen = unpacker.unpackMapLength();
    final cells = <Position, CellInfo>{};
    for (int i = 0; i < mapLen; i++) {
      final key = PositionSerde.unpack(unpacker);
      final value = CellInfoSerde.unpack(unpacker);
      cells[key] = value;
    }
    return StructureInstance(
      typeName: typeName,
      isSuspicious: isSuspicious,
      layer: layer,
      originX: originX,
      originY: originY,
      rotation: rotation,
      cells: cells,
    );
  }

  void pack(Packer packer, WorldCodec codec) {
    packer.packListLength(7);
    packer.packString(typeName);
    packer.packBool(isSuspicious);
    packer.packInt(codec.layerToCode(layer));
    packer.packInt(originX);
    packer.packInt(originY);
    rotation.pack(packer);
    final cells = this.cells?.entries.sortedBy((e) => e.key);
    if (cells == null) {
      packer.packMapLength(null);
    } else {
      packer.packMapLength(cells.length);
      for (final entry in cells) {
        entry.key.pack(packer);
        entry.value.pack(packer);
      }
    }
  }
}

extension WorldFileSerde on WorldFile {
  static WorldFile unpack(Unpacker unpacker, WorldCodec codec) {
    final len = unpacker.unpackListLength();
    if (len != 7) throw FormatException();
    final layersLen = unpacker.unpackListLength();
    final layers = <GroundLayer>{};
    for (int i = 0; i < layersLen; i++) {
      final layer = codec.layerFromCode(unpacker.unpackInt()!);
      layers.add(layer);
    }
    final minX = unpacker.unpackInt();
    final maxX = unpacker.unpackInt();
    final minY = unpacker.unpackInt();
    final maxY = unpacker.unpackInt();
    if (minX == null || maxX == null || minY == null || maxY == null) throw FormatException();
    final instancesLen = unpacker.unpackListLength();
    final instances = <StructureInstance>[];
    for (int i = 0; i < instancesLen; i++) {
      final instance = StructureInstanceSerde.unpack(unpacker, codec);
      instances.add(instance);
    }
    final entrancesLen = unpacker.unpackMapLength();
    final entrances = <EntranceType, Position>{};
    for (int i = 0; i < entrancesLen; i++) {
      final type = codec.entranceFromCode(unpacker.unpackInt()!);
      final position = PositionSerde.unpack(unpacker);
      entrances[type] = position;
    }
    return WorldFile(
      layers: layers,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      instances: instances,
      entrances: entrances,
    );
  }

  void pack(Packer packer, WorldCodec codec) {
    packer.packListLength(7);
    packer.packListLength(layers.length);
    for (final layer in layers.sorted(compare<GroundLayer>((l) => l.index))) {
      packer.packInt(codec.layerToCode(layer));
    }
    packer.packInt(minX);
    packer.packInt(maxX);
    packer.packInt(minY);
    packer.packInt(maxY);
    final instances = this.instances.sorted(compareSequentially([
      compare<StructureInstance>((instance) => instance.layer.index),
      compare<StructureInstance>((instance) => instance.originX),
      compare<StructureInstance>((instance) => instance.originY),
      compare<StructureInstance>((instance) => instance.rotation.index),
    ]));
    packer.packListLength(instances.length);
    for (final instance in instances) {
      instance.pack(packer, codec);
    }
    final entrances = this.entrances.entries.sortedBy((e) => e.key.index);
    packer.packMapLength(entrances.length);
    for (final entry in entrances) {
      packer.packInt(codec.entranceToCode(entry.key));
      entry.value.pack(packer);
    }
  }
}

Uint8List serializeWorld(WorldFile world, WorldCodec codec) {
  final packer = Packer();
  world.pack(packer, codec);
  return packer.takeBytes();
}

WorldFile deserializeWorld(Uint8List content, WorldCodec codec) {
  final unpacker = Unpacker(content);
  return WorldFileSerde.unpack(unpacker, codec);
}
