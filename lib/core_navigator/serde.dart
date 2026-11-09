import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:comparators/comparators.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/navigator_double.dart';
import 'package:messagepack/messagepack.dart';

extension KeyResourceSerde on KeyResource {
  static KeyResource? unpackNullable(Unpacker unpacker, WorldCodec codec) {
    final len = unpacker.unpackListLength();
    if (len == 0) return null;
    if (len != 3) throw FormatException();
    final position = NodeSerde.unpack(unpacker, codec);
    final transport = NodeSerde.unpack(unpacker, codec);
    final keyResourceWeight = unpacker.unpackInt();
    if (keyResourceWeight == null) throw FormatException();
    return KeyResource(position: position, transport: transport, keyResourceWeight: keyResourceWeight);
  }

  void pack(Packer packer, WorldCodec codec) {
    packer.packListLength(3);
    position.pack(packer, codec);
    transport.pack(packer, codec);
    packer.packInt(keyResourceWeight);
  }
}

extension NavigateArgumentsSerde on NavigateArguments {
  static NavigateArguments unpack(Unpacker unpacker, WorldCodec codec) {
    final len = unpacker.unpackListLength();
    if (len != 6) throw FormatException();
    final start = NodeSerde.unpack(unpacker, codec);
    final resourcesLen = unpacker.unpackListLength();
    final resources = <Node>{};
    for (int i = 0; i < resourcesLen; i++) {
      final resource = NodeSerde.unpack(unpacker, codec);
      resources.add(resource);
    }
    final exitsLen = unpacker.unpackListLength();
    final exits = <Node>{};
    for (int i = 0; i < exitsLen; i++) {
      final exit = NodeSerde.unpack(unpacker, codec);
      exits.add(exit);
    }
    final keyResource = KeyResourceSerde.unpackNullable(unpacker, codec);
    final entrancesLength = unpacker.unpackMapLength();
    final entrances = <(Node, Node), int>{};
    for (int i = 0; i < entrancesLength; i++) {
      final len = unpacker.unpackListLength();
      if (len != 2) throw FormatException();
      final u = NodeSerde.unpack(unpacker, codec);
      final v = NodeSerde.unpack(unpacker, codec);
      final w = unpacker.unpackInt();
      if (w == null) throw FormatException();
      entrances[(u, v)] = w;
    }
    final defaultWeight = unpacker.unpackInt();
    if (defaultWeight == null) throw FormatException();
    return NavigateArguments(
      start: start,
      resources: resources,
      exits: exits,
      keyResource: keyResource,
      entrancesLength: entrances,
      defaultWeight: defaultWeight,
    );
  }

  void pack(Packer packer, WorldCodec codec) {
    packer.packListLength(6);
    start.pack(packer, codec);
    final resources = this.resources.sorted();
    packer.packListLength(resources.length);
    for (final resource in resources) {
      resource.pack(packer, codec);
    }
    final exits = this.exits.sorted();
    packer.packListLength(exits.length);
    for (final exit in exits) {
      exit.pack(packer, codec);
    }
    if (keyResource == null) {
      packer.packListLength(0);
    } else {
      keyResource!.pack(packer, codec);
    }
    final entrances = entrancesLength.entries.sorted(compareSequentially([
      compare<MapEntry<(Node, Node), int>>((e) => e.key.$1),
      compare<MapEntry<(Node, Node), int>>((e) => e.key.$2),
    ]));
    packer.packMapLength(entrances.length);
    for (final entry in entrances) {
      packer.packListLength(2);
      entry.key.$1.pack(packer, codec);
      entry.key.$2.pack(packer, codec);
      packer.packInt(entry.value);
    }
    packer.packInt(defaultWeight);
  }
}

Uint8List serializeNavigateArguments(NavigateArguments arguments, WorldCodec codec) {
  final packer = Packer();
  arguments.pack(packer, codec);
  return packer.takeBytes();
}

NavigateArguments deserializeNavigateArguments(Uint8List content, WorldCodec codec) {
  final unpacker = Unpacker(content);
  return NavigateArgumentsSerde.unpack(unpacker, codec);
}

Uint8List serializeNavigatePath(List<Node> path, WorldCodec codec) {
  final packer = Packer();
  packer.packListLength(path.length);
  for (final node in path) {
    node.pack(packer, codec);
  }
  return packer.takeBytes();
}

List<Node> deserializeNavigatePath(Uint8List content, WorldCodec codec) {
  final unpacker = Unpacker(content);
  final pathLen = unpacker.unpackListLength();
  final path = <Node>[];
  for (int i = 0; i < pathLen; i++) {
    final node = NodeSerde.unpack(unpacker, codec);
    path.add(node);
  }
  return path;
}

Uint8List serializePrecomputedNavigatePath(String worldHash, Map<NavigateArguments, List<Node>> paths, WorldCodec codec) {
  final packer = Packer();
  packer.packString(worldHash);
  final pathList = paths.entries.sortedBy((entry) => entry.key.identify);
  packer.packMapLength(pathList.length);
  for (final entry in pathList) {
    entry.key.pack(packer, codec);
    packer.packListLength(entry.value.length);
    for (final node in entry.value) {
      node.pack(packer, codec);
    }
  }
  return packer.takeBytes();
}

(String, Map<NavigateArguments, List<Node>>) deserializePrecomputedNavigatePath(Uint8List content, WorldCodec codec) {
  final unpacker = Unpacker(content);
  final worldHash = unpacker.unpackString();
  if (worldHash == null) throw FormatException();
  final pathsLen = unpacker.unpackMapLength();
  final paths = <NavigateArguments, List<Node>>{};
  for (int i = 0; i < pathsLen; i++) {
    final key = NavigateArgumentsSerde.unpack(unpacker, codec);
    final pathLen = unpacker.unpackListLength();
    final path = <Node>[];
    for (int i = 0; i < pathLen; i++) {
      final node = NodeSerde.unpack(unpacker, codec);
      path.add(node);
    }
    paths[key] = path;
  }
  return (worldHash, paths);
}

extension NavigateDoubleArgumentsSerde on NavigateDoubleArguments {
  static NavigateDoubleArguments unpack(Unpacker unpacker, WorldCodec codec) {
    final len = unpacker.unpackListLength();
    if (len != 8) throw FormatException();
    final start1 = NodeSerde.unpack(unpacker, codec);
    final start2 = NodeSerde.unpack(unpacker, codec);
    final resourcesLen = unpacker.unpackListLength();
    final resources = <Node>{};
    for (int i = 0; i < resourcesLen; i++) {
      final resource = NodeSerde.unpack(unpacker, codec);
      resources.add(resource);
    }
    final exitsLen = unpacker.unpackListLength();
    final exits = <Node>{};
    for (int i = 0; i < exitsLen; i++) {
      final exit = NodeSerde.unpack(unpacker, codec);
      exits.add(exit);
    }
    final keyResource = KeyResourceSerde.unpackNullable(unpacker, codec);
    final entrancesLength = unpacker.unpackMapLength();
    final entrances = <(Node, Node), int>{};
    for (int i = 0; i < entrancesLength; i++) {
      final len = unpacker.unpackListLength();
      if (len != 2) throw FormatException();
      final u = NodeSerde.unpack(unpacker, codec);
      final v = NodeSerde.unpack(unpacker, codec);
      final w = unpacker.unpackInt();
      if (w == null) throw FormatException();
      entrances[(u, v)] = w;
    }
    final defaultWeight = unpacker.unpackInt();
    final transportWaitingWeight = unpacker.unpackInt();
    if (defaultWeight == null || transportWaitingWeight == null) throw FormatException();
    return NavigateDoubleArguments(
      start1: start1,
      start2: start2,
      resources: resources,
      exits: exits,
      keyResource: keyResource,
      entrancesLength: entrances,
      defaultWeight: defaultWeight,
      transportWaitingWeight: transportWaitingWeight,
    );
  }

  void pack(Packer packer, WorldCodec codec) {
    packer.packListLength(8);
    start1.pack(packer, codec);
    start2.pack(packer, codec);
    final resources = this.resources.sorted();
    packer.packListLength(resources.length);
    for (final resource in resources) {
      resource.pack(packer, codec);
    }
    final exits = this.exits.sorted();
    packer.packListLength(exits.length);
    for (final exit in exits) {
      exit.pack(packer, codec);
    }
    if (keyResource == null) {
      packer.packListLength(0);
    } else {
      keyResource!.pack(packer, codec);
    }
    final entrances = entrancesLength.entries.sorted(compareSequentially([
      compare<MapEntry<(Node, Node), int>>((e) => e.key.$1),
      compare<MapEntry<(Node, Node), int>>((e) => e.key.$2),
    ]));
    packer.packMapLength(entrances.length);
    for (final entry in entrances) {
      packer.packListLength(2);
      entry.key.$1.pack(packer, codec);
      entry.key.$2.pack(packer, codec);
      packer.packInt(entry.value);
    }
    packer.packInt(defaultWeight);
    packer.packInt(transportWaitingWeight);
  }
}

Uint8List serializeNavigateDoubleArguments(NavigateDoubleArguments arguments, WorldCodec codec) {
  final packer = Packer();
  arguments.pack(packer, codec);
  return packer.takeBytes();
}

NavigateDoubleArguments deserializeNavigateDoubleArguments(Uint8List content, WorldCodec codec) {
  final unpacker = Unpacker(content);
  return NavigateDoubleArgumentsSerde.unpack(unpacker, codec);
}

Uint8List serializePrecomputedNavigateDoublePath(String worldHash, Map<NavigateDoubleArguments, ({List<Node> path1, List<Node> path2})> paths, WorldCodec codec) {
  final packer = Packer();
  packer.packString(worldHash);
  final pathList = paths.entries.sortedBy((entry) => entry.key.identify);
  packer.packMapLength(pathList.length);
  for (final entry in pathList) {
    entry.key.pack(packer, codec);
    packer.packListLength(2);
    packer.packListLength(entry.value.path1.length);
    for (final node in entry.value.path1) {
      node.pack(packer, codec);
    }
    packer.packListLength(entry.value.path2.length);
    for (final node in entry.value.path2) {
      node.pack(packer, codec);
    }
  }
  return packer.takeBytes();
}

(String, Map<NavigateDoubleArguments, ({List<Node> path1, List<Node> path2})>) deserializePrecomputedNavigateDoublePath(Uint8List content, WorldCodec codec) {
  final unpacker = Unpacker(content);
  final worldHash = unpacker.unpackString();
  if (worldHash == null) throw FormatException();
  final pathsLen = unpacker.unpackMapLength();
  final paths = <NavigateDoubleArguments, ({List<Node> path1, List<Node> path2})>{};
  for (int i = 0; i < pathsLen; i++) {
    final key = NavigateDoubleArgumentsSerde.unpack(unpacker, codec);
    final len = unpacker.unpackListLength();
    if (len != 2) throw FormatException();
    final path1Len = unpacker.unpackListLength();
    final path1 = <Node>[];
    for (int i = 0; i < path1Len; i++) {
      final node = NodeSerde.unpack(unpacker, codec);
      path1.add(node);
    }
    final path2Len = unpacker.unpackListLength();
    final path2 = <Node>[];
    for (int i = 0; i < path2Len; i++) {
      final node = NodeSerde.unpack(unpacker, codec);
      path2.add(node);
    }
    paths[key] = (path1: path1, path2: path2);
  }
  return (worldHash, paths);
}
