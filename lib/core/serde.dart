import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:comparators/comparators.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:messagepack/messagepack.dart';

extension _GroundLayerSerde on GroundLayer {
  static GroundLayer unpack(Unpacker unpacker) {
    return switch (unpacker.unpackInt()) {
      0 => GroundLayer.basement,
      1 => GroundLayer.ground,
      2 => GroundLayer.second,
      _ => throw FormatException(),
    };
  }
  void pack(Packer packer) {
    packer.packInt(switch (this) {
      GroundLayer.basement => 0,
      GroundLayer.ground => 1,
      GroundLayer.second => 2,
    });
  }
}

extension _RotationSerde on Rotation {
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

extension _PositionSerde on Position {
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

extension _NodeSerde on Node {
  static Node unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 3) throw FormatException();
    final layer = _GroundLayerSerde.unpack(unpacker);
    final x = unpacker.unpackInt();
    final y = unpacker.unpackInt();
    if (x == null || y == null) throw FormatException();
    return Node(layer, x, y);
  }
  void pack(Packer packer) {
    packer.packListLength(3);
    layer.pack(packer);
    packer.packInt(x);
    packer.packInt(y);
  }
}

extension _StairTransportSerde on StairTransport {
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

extension _EdgeTypeSerde on EdgeType {
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

extension _CellInfoSerde on CellInfo {
  static CellInfo unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 6) throw FormatException();
    return CellInfo(
      isStair: _StairTransportSerde.unpackNullable(unpacker),
      edgeNorth: _EdgeTypeSerde.unpack(unpacker),
      edgeEast: _EdgeTypeSerde.unpack(unpacker),
      edgeSouth: _EdgeTypeSerde.unpack(unpacker),
      edgeWest: _EdgeTypeSerde.unpack(unpacker),
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

extension _StructureSerde on Structure {
  static Structure unpack(Unpacker unpacker, String name) {
    final len = unpacker.unpackListLength();
    if (len != 3) throw FormatException();
    final isCorridor = unpacker.unpackBool();
    final isNoDirection = unpacker.unpackBool();
    if (isCorridor == null || isNoDirection == null) throw FormatException();
    final mapLen = unpacker.unpackMapLength();
    final cells = <Position, CellInfo>{};
    for (int i = 0; i < mapLen; i++) {
      final key = _PositionSerde.unpack(unpacker);
      final value = _CellInfoSerde.unpack(unpacker);
      cells[key] = value;
    }
    return Structure(
      name: name,
      isCorridor: isCorridor,
      isNoDirection: isNoDirection,
      cells: cells,
    );
  }
  void pack(Packer packer) {
    packer.packListLength(3);
    packer.packBool(isCorridor);
    packer.packBool(isNoDirection);
    final cells = this.cells.entries.sortedBy((e) => e.key);
    packer.packMapLength(cells.length);
    for (final entry in cells) {
      entry.key.pack(packer);
      entry.value.pack(packer);
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
    final value = _StructureSerde.unpack(unpacker, key);
    structures[key] = value;
  }
  return structures;
}

extension _StructureInstanceSerde on StructureInstance {
  static StructureInstance unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 7) throw FormatException();
    final typeName = unpacker.unpackString();
    final isSuspicious = unpacker.unpackBool();
    final layer = _GroundLayerSerde.unpack(unpacker);
    final originX = unpacker.unpackInt();
    final originY = unpacker.unpackInt();
    final rotation = _RotationSerde.unpack(unpacker);
    if (typeName == null || isSuspicious == null || originX == null || originY == null) throw FormatException();
    final mapLen = unpacker.unpackMapLength();
    final cells = <Position, CellInfo>{};
    for (int i = 0; i < mapLen; i++) {
      final key = _PositionSerde.unpack(unpacker);
      final value = _CellInfoSerde.unpack(unpacker);
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
  void pack(Packer packer) {
    packer.packListLength(7);
    packer.packString(typeName);
    packer.packBool(isSuspicious);
    layer.pack(packer);
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

extension _EntranceTypeSerde on EntranceType {
  static EntranceType unpack(Unpacker unpacker) {
    return switch (unpacker.unpackInt()) {
      0 => EntranceType.main,
      1 => EntranceType.sideGround,
      2 => EntranceType.sideSecond,
      3 => EntranceType.alterBasement,
      _ => throw FormatException(),
    };
  }
  void pack(Packer packer) {
    packer.packInt(switch (this) {
      EntranceType.main => 0,
      EntranceType.sideGround => 1,
      EntranceType.sideSecond => 2,
      EntranceType.alterBasement => 3,
    });
  }
}

extension _WorldFileSerde on WorldFile {
  static WorldFile unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 7) throw FormatException();
    final layersLen = unpacker.unpackListLength();
    final layers = <GroundLayer>{};
    for (int i = 0; i < layersLen; i++) {
      final layer = _GroundLayerSerde.unpack(unpacker);
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
      final instance = _StructureInstanceSerde.unpack(unpacker);
      instances.add(instance);
    }
    final entrancesLen = unpacker.unpackMapLength();
    final entrances = <EntranceType, Position>{};
    for (int i = 0; i < entrancesLen; i++) {
      final type = _EntranceTypeSerde.unpack(unpacker);
      final position = _PositionSerde.unpack(unpacker);
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
  void pack(Packer packer) {
    packer.packListLength(7);
    packer.packListLength(layers.length);
    for (final layer in layers) {
      layer.pack(packer);
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
      instance.pack(packer);
    }
    final entrances = this.entrances.entries.sortedBy((e) => e.key.index);
    packer.packMapLength(entrances.length);
    for (final entry in entrances) {
      entry.key.pack(packer);
      entry.value.pack(packer);
    }
  }
}

Uint8List serializeWorld(WorldFile world) {
  final packer = Packer();
  world.pack(packer);
  return packer.takeBytes();
}

WorldFile deserializeWorld(Uint8List content) {
  final unpacker = Unpacker(content);
  return _WorldFileSerde.unpack(unpacker);
}

extension _KeyResourceSerde on KeyResource {
  static KeyResource? unpackNullable(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len == 0) return null;
    if (len != 3) throw FormatException();
    final position = _NodeSerde.unpack(unpacker);
    final transport = _NodeSerde.unpack(unpacker);
    final urgency = unpacker.unpackDouble();
    if (urgency == null) throw FormatException();
    return KeyResource(position, transport, urgency);
  }
  void pack(Packer packer) {
    packer.packListLength(3);
    position.pack(packer);
    transport.pack(packer);
    packer.packDouble(urgency);
  }
}

extension _NavigateArgumentsSerde on NavigateArguments {
  static NavigateArguments unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 4) throw FormatException();
    final start = _NodeSerde.unpack(unpacker);
    final resourcesLen = unpacker.unpackListLength();
    final resources = <Node>{};
    for (int i = 0; i < resourcesLen; i++) {
      final resource = _NodeSerde.unpack(unpacker);
      resources.add(resource);
    }
    final exitsLen = unpacker.unpackListLength();
    final exits = <Node>{};
    for (int i = 0; i < exitsLen; i++) {
      final exit = _NodeSerde.unpack(unpacker);
      exits.add(exit);
    }
    final keyResource = _KeyResourceSerde.unpackNullable(unpacker);
    return NavigateArguments(start: start, resources: resources, exits: exits, keyResource: keyResource);
  }
  void pack(Packer packer) {
    packer.packListLength(4);
    start.pack(packer);
    final resources = this.resources.sorted();
    packer.packListLength(resources.length);
    for (final resource in resources) {
      resource.pack(packer);
    }
    final exits = this.exits.sorted();
    packer.packListLength(exits.length);
    for (final exit in exits) {
      exit.pack(packer);
    }
    if (keyResource == null) {
      packer.packListLength(0);
    } else {
      keyResource!.pack(packer);
    }
  }
}

Uint8List serializeNavigateArguments(NavigateArguments arguments) {
  final packer = Packer();
  arguments.pack(packer);
  return packer.takeBytes();
}

NavigateArguments deserializeNavigateArguments(Uint8List content) {
  final unpacker = Unpacker(content);
  return _NavigateArgumentsSerde.unpack(unpacker);
}

Uint8List serializeNavigatePath(List<Node> path) {
  final packer = Packer();
  packer.packListLength(path.length);
  for (final node in path) {
    node.pack(packer);
  }
  return packer.takeBytes();
}

List<Node> deserializeNavigatePath(Uint8List content) {
  final unpacker = Unpacker(content);
  final pathLen = unpacker.unpackListLength();
  final path = <Node>[];
  for (int i = 0; i < pathLen; i++) {
    final node = _NodeSerde.unpack(unpacker);
    path.add(node);
  }
  return path;
}
