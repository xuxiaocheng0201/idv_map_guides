import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/entrance.dart';
import 'package:idv_map_guides/maps/phosphorescence_disease/layer.dart';

final WorldCodec phosphorescenceDiseaseCodec = SimpleWorldCodec(
  layers: PhosphorescenceDiseaseLayer.values,
  entrances: PhosphorescenceDiseaseEntranceType.values,
);
