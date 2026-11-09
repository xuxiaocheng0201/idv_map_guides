import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/entrance.dart';
import 'package:idv_map_guides/maps/the_bringer_of_doom/layer.dart';

final WorldCodec theBringerOfDoomCodec = SimpleWorldCodec(
  layers: TheBringerOfDoomLayer.values,
  entrances: TheBringerOfDoomEntranceType.values,
);
