import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/layer.dart';

enum PhosphorescenceDiseaseEntranceType implements EntranceType {
  main,
  entranceLeft,
  entranceRight,
  entranceRailway,
  minecartB2A,
  minecartB2B,
  minecartB3A,
  minecartB3B,
  minecartTransported;

  @override
  int get code => index;

  @override
  bool get displayable => switch (this) {
    PhosphorescenceDiseaseEntranceType.main => true,
    PhosphorescenceDiseaseEntranceType.entranceLeft => false,
    PhosphorescenceDiseaseEntranceType.entranceRight => false,
    PhosphorescenceDiseaseEntranceType.entranceRailway => false,
    PhosphorescenceDiseaseEntranceType.minecartB2A => false,
    PhosphorescenceDiseaseEntranceType.minecartB2B => false,
    PhosphorescenceDiseaseEntranceType.minecartB3A => false,
    PhosphorescenceDiseaseEntranceType.minecartB3B => false,
    PhosphorescenceDiseaseEntranceType.minecartTransported => false,
  };

  @override
  GroundLayer get layer => switch (this) {
    PhosphorescenceDiseaseEntranceType.main => PhosphorescenceDiseaseLayer.level1,
    PhosphorescenceDiseaseEntranceType.entranceLeft => PhosphorescenceDiseaseLayer.level1,
    PhosphorescenceDiseaseEntranceType.entranceRight => PhosphorescenceDiseaseLayer.level1,
    PhosphorescenceDiseaseEntranceType.entranceRailway => PhosphorescenceDiseaseLayer.level2,
    PhosphorescenceDiseaseEntranceType.minecartB2A => PhosphorescenceDiseaseLayer.level2,
    PhosphorescenceDiseaseEntranceType.minecartB2B => PhosphorescenceDiseaseLayer.level2,
    PhosphorescenceDiseaseEntranceType.minecartB3A => PhosphorescenceDiseaseLayer.level3,
    PhosphorescenceDiseaseEntranceType.minecartB3B => PhosphorescenceDiseaseLayer.level3,
    PhosphorescenceDiseaseEntranceType.minecartTransported => PhosphorescenceDiseaseLayer.level1,
  };
}
