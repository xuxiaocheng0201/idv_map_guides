import 'package:idv_map_guides/core/data.dart';

enum TheBringerOfDoomLayer implements GroundLayer {
  basement,
  ground,
  second;

  @override
  int get code => index;

  @override
  GroundLayer? up() {
    return switch (this) {
      TheBringerOfDoomLayer.basement => TheBringerOfDoomLayer.ground,
      TheBringerOfDoomLayer.ground => TheBringerOfDoomLayer.second,
      TheBringerOfDoomLayer.second => null,
    };
  }

  @override
  GroundLayer? down() {
    return switch (this) {
      TheBringerOfDoomLayer.basement => null,
      TheBringerOfDoomLayer.ground => TheBringerOfDoomLayer.basement,
      TheBringerOfDoomLayer.second => TheBringerOfDoomLayer.ground,
    };
  }
}
