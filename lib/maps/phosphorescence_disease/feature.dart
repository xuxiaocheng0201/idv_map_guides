import 'package:idv_map_guides/core_data/classification.dart';

class PhosphorescenceDiseaseEntranceFeature implements EntranceFeature {
  const PhosphorescenceDiseaseEntranceFeature();

  @override
  int compareTo(EntranceFeature other) {
    return other is PhosphorescenceDiseaseEntranceFeature ? 0 : 1;
  }
}
