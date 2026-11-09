import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/layer.dart';

enum TheBringerOfDoomEntranceType implements EntranceType {
  main,
  sideGround,
  sideSecond,
  alterBasement;

  @override
  int get code => index;

  @override
  bool get displayable => switch (this) {
    TheBringerOfDoomEntranceType.main => true,
    TheBringerOfDoomEntranceType.sideGround => true,
    TheBringerOfDoomEntranceType.sideSecond => true,
    TheBringerOfDoomEntranceType.alterBasement => false,
  };

  @override
  GroundLayer get layer => switch (this) {
    TheBringerOfDoomEntranceType.main => TheBringerOfDoomLayer.ground,
    TheBringerOfDoomEntranceType.sideGround => TheBringerOfDoomLayer.ground,
    TheBringerOfDoomEntranceType.sideSecond => TheBringerOfDoomLayer.second,
    TheBringerOfDoomEntranceType.alterBasement => TheBringerOfDoomLayer.basement,
  };
}
