import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/layer.dart';

enum PhosphorescenceDiseaseEntranceType implements EntranceType {
  main;

  @override
  int get code => index;

  @override
  bool get displayable => true;

  @override
  GroundLayer get layer => PhosphorescenceDiseaseLayer.level1;
}
