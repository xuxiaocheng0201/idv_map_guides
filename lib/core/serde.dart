import 'dart:convert';
import 'dart:typed_data';

import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';

// TODO: pro_mpack: ^3.2.0

Uint8List serializeStructures(Map<String, Structure> structures) {
  final map = structures.map((key, value) => MapEntry(key, value.toJson()));
  final string = json.encode(map);
  return utf8.encode(string);
}

Map<String, Structure> deserializeStructures(Uint8List content) {
  final string = utf8.decode(content);
  final map = json.decode(string) as Map<String, dynamic>;
  return map.map((key, value) => MapEntry(key, Structure.fromJson(value as Map<String, dynamic>)));
}

Uint8List serializeWorld(WorldFile world) {
  final map = world.toJson();
  final string = json.encode(map);
  return utf8.encode(string);
}

WorldFile deserializeWorld(Uint8List content) {
  final string = utf8.decode(content);
  final map = json.decode(string) as Map<String, dynamic>;
  return WorldFile.fromJson(map);
}
