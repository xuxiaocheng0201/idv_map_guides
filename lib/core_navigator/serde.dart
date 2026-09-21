import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core_navigator/navigator.dart';
import 'package:messagepack/messagepack.dart';

extension KeyResourceSerde on KeyResource {
  static KeyResource? unpackNullable(Unpacker unpacker) {
    final len = unpacker.unpackListLength();
    if (len == 0) return null;
    if (len != 3) throw FormatException();
    final position = NodeSerde.unpack(unpacker);
    final transport = NodeSerde.unpack(unpacker);
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
