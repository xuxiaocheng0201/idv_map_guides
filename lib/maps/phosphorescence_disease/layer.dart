import 'package:idv_map_guides/core/data.dart';

enum PhosphorescenceDiseaseLayer implements GroundLayer {
  level1,
  level2,
  level3,
  level4;

  @override
  int get code => index;

  @override
  GroundLayer? up() {
    return switch (this) {
      PhosphorescenceDiseaseLayer.level1 => null,
      PhosphorescenceDiseaseLayer.level2 => PhosphorescenceDiseaseLayer.level1,
      PhosphorescenceDiseaseLayer.level3 => PhosphorescenceDiseaseLayer.level2,
      PhosphorescenceDiseaseLayer.level4 => PhosphorescenceDiseaseLayer.level3,
    };
  }

  @override
  GroundLayer? down() {
    return switch (this) {
      PhosphorescenceDiseaseLayer.level1 => PhosphorescenceDiseaseLayer.level2,
      PhosphorescenceDiseaseLayer.level2 => PhosphorescenceDiseaseLayer.level3,
      PhosphorescenceDiseaseLayer.level3 => PhosphorescenceDiseaseLayer.level4,
      PhosphorescenceDiseaseLayer.level4 => null,
    };
  }
}
