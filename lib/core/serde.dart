import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:idv_map_guides/core/data.dart';

// TODO: pro_mpack: ^3.2.0

Uint8List serializeStructures(Map<String, Structure> structures) {
  final map = structures.map((key, value) => MapEntry(key, value.toJson()));
  final string = json.encode(map);
  return utf8.encode(string);
}

Map<String, Structure> deserializeStructures(Uint8List content) {
  final string = utf8.decode(content);
  final Map<String, dynamic> map = json.decode(string);
  return map.map((key, value) => MapEntry(key, Structure.fromJson(value)));
}


Future<Map<String, Structure>> loadStructures(String path) async {
  final content = await File(path).readAsBytes();
  return deserializeStructures(content);
}

Future<String> saveStructures(Map<String, Structure> structures, String path) async {
  final content = serializeStructures(structures);
  final file = File(path);
  await file.writeAsBytes(content);
  return file.absolute.path;
}
