import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:idv_map_guides/core_navigator/navigator_double.dart';
import 'package:messagepack/messagepack.dart';

extension KeyResourceSerde on KeyResource {
  static KeyResource? unpackNullable(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len == 0) return null;
    if (len != 3) throw FormatException();
    final position = NodeSerde.unpack(unpacker);
    final transport = NodeSerde.unpack(unpacker);
    final keyResourceWeight = unpacker.unpackInt();
    if (keyResourceWeight == null) throw FormatException();
    return KeyResource(position: position, transport: transport, keyResourceWeight: keyResourceWeight);
  }
  void pack(Packer packer) {
    packer.packListLength(3);
    position.pack(packer);
    transport.pack(packer);
    packer.packInt(keyResourceWeight);
  }
}

extension NavigateArgumentsSerde on NavigateArguments {
  static NavigateArguments unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 4) throw FormatException();
    final start = NodeSerde.unpack(unpacker);
    final resourcesLen = unpacker.unpackListLength();
    final resources = <Node>{};
    for (int i = 0; i < resourcesLen; i++) {
      final resource = NodeSerde.unpack(unpacker);
      resources.add(resource);
    }
    final exitsLen = unpacker.unpackListLength();
    final exits = <Node>{};
    for (int i = 0; i < exitsLen; i++) {
      final exit = NodeSerde.unpack(unpacker);
      exits.add(exit);
    }
    final keyResource = KeyResourceSerde.unpackNullable(unpacker);
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
  return NavigateArgumentsSerde.unpack(unpacker);
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
    final node = NodeSerde.unpack(unpacker);
    path.add(node);
  }
  return path;
}

Uint8List serializePrecomputedNavigatePath(String worldHash, Map<NavigateArguments, List<Node>> paths) {
  final packer = Packer();
  packer.packString(worldHash);
  final pathList = paths.entries.sortedBy((entry) => entry.key.identify);
  packer.packMapLength(pathList.length);
  for (final entry in pathList) {
    entry.key.pack(packer);
    packer.packListLength(entry.value.length);
    for (final node in entry.value) {
      node.pack(packer);
    }
  }
  return packer.takeBytes();
}

(String, Map<NavigateArguments, List<Node>>) deserializePrecomputedNavigatePath(Uint8List content) {
  final unpacker = Unpacker(content);
  final worldHash = unpacker.unpackString();
  if (worldHash == null) throw FormatException();
  final pathsLen = unpacker.unpackMapLength();
  final paths = <NavigateArguments, List<Node>>{};
  for (int i = 0; i < pathsLen; i++) {
    final key = NavigateArgumentsSerde.unpack(unpacker);
    final pathLen = unpacker.unpackListLength();
    final path = <Node>[];
    for (int i = 0; i < pathLen; i++) {
      final node = NodeSerde.unpack(unpacker);
      path.add(node);
    }
    paths[key] = path;
  }
  return (worldHash, paths);
}

extension NavigateDoubleArgumentsSerde on NavigateDoubleArguments {
  static NavigateDoubleArguments unpack(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len != 6) throw FormatException();
    final start1 = NodeSerde.unpack(unpacker);
    final start2 = NodeSerde.unpack(unpacker);
    final resourcesLen = unpacker.unpackListLength();
    final resources = <Node>{};
    for (int i = 0; i < resourcesLen; i++) {
      final resource = NodeSerde.unpack(unpacker);
      resources.add(resource);
    }
    final exitsLen = unpacker.unpackListLength();
    final exits = <Node>{};
    for (int i = 0; i < exitsLen; i++) {
      final exit = NodeSerde.unpack(unpacker);
      exits.add(exit);
    }
    final keyResource = KeyResourceSerde.unpackNullable(unpacker);
    final transportWaitingUrgency = unpacker.unpackDouble();
    if (transportWaitingUrgency == null) throw FormatException();
    return NavigateDoubleArguments(
      start1: start1,
      start2: start2,
      resources: resources,
      exits: exits,
      keyResource: keyResource,
      transportWaitingUrgency: transportWaitingUrgency,
    );
  }
  void pack(Packer packer) {
    packer.packListLength(6);
    start1.pack(packer);
    start2.pack(packer);
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
    packer.packDouble(transportWaitingUrgency);
  }
}

Uint8List serializeNavigateDoubleArguments(NavigateDoubleArguments arguments) {
  final packer = Packer();
  arguments.pack(packer);
  return packer.takeBytes();
}

NavigateDoubleArguments deserializeNavigateDoubleArguments(Uint8List content) {
  final unpacker = Unpacker(content);
  return NavigateDoubleArgumentsSerde.unpack(unpacker);
}

Uint8List serializePrecomputedNavigateDoublePath(String worldHash, Map<NavigateDoubleArguments, ({List<Node> path1, List<Node> path2})> paths) {
  final packer = Packer();
  packer.packString(worldHash);
  final pathList = paths.entries.sortedBy((entry) => entry.key.identify);
  packer.packMapLength(pathList.length);
  for (final entry in pathList) {
    entry.key.pack(packer);
    packer.packListLength(2);
    packer.packListLength(entry.value.path1.length);
    for (final node in entry.value.path1) {
      node.pack(packer);
    }
    packer.packListLength(entry.value.path2.length);
    for (final node in entry.value.path2) {
      node.pack(packer);
    }
  }
  return packer.takeBytes();
}

(String, Map<NavigateDoubleArguments, ({List<Node> path1, List<Node> path2})>) deserializePrecomputedNavigateDoublePath(Uint8List content) {
  final unpacker = Unpacker(content);
  final worldHash = unpacker.unpackString();
  if (worldHash == null) throw FormatException();
  final pathsLen = unpacker.unpackMapLength();
  final paths = <NavigateDoubleArguments, ({List<Node> path1, List<Node> path2})>{};
  for (int i = 0; i < pathsLen; i++) {
    final key = NavigateDoubleArgumentsSerde.unpack(unpacker);
    final len = unpacker.unpackListLength();
    if (len != 2) throw FormatException();
    final path1Len = unpacker.unpackListLength();
    final path1 = <Node>[];
    for (int i = 0; i < path1Len; i++) {
      final node = NodeSerde.unpack(unpacker);
      path1.add(node);
    }
    final path2Len = unpacker.unpackListLength();
    final path2 = <Node>[];
    for (int i = 0; i < path2Len; i++) {
      final node = NodeSerde.unpack(unpacker);
      path2.add(node);
    }
    paths[key] = (path1: path1, path2: path2);
  }
  return (worldHash, paths);
}
