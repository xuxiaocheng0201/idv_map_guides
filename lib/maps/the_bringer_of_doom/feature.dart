import 'package:idv_map_guides/core_data/classification.dart';

class MainEntranceFeature implements Comparable<MainEntranceFeature> {
  final bool hasUpDoor;
  final bool hasLeftDoor;
  final bool hasRightDoor;

  const MainEntranceFeature({
    required this.hasUpDoor,
    required this.hasLeftDoor,
    required this.hasRightDoor,
  });

  @override
  int compareTo(MainEntranceFeature b) {
    final a = this;
    final countA = _count(a);
    final countB = _count(b);
    if (countA != countB) return countB.compareTo(countA);
    if (a.hasUpDoor != b.hasUpDoor) return a.hasUpDoor ? -1 : 1;
    if (a.hasLeftDoor != b.hasLeftDoor) return a.hasLeftDoor ? -1 : 1;
    if (a.hasRightDoor != b.hasRightDoor) return a.hasRightDoor ? -1 : 1;
    return 0;
  }

  int _count(MainEntranceFeature f) =>
      (f.hasUpDoor ? 1 : 0) + (f.hasLeftDoor ? 1 : 0) + (f.hasRightDoor ? 1 : 0);
}

enum SideEntranceFeature { north, east, south, west, other }

sealed class TheBringerOfDoomEntranceFeature implements EntranceFeature {
  const TheBringerOfDoomEntranceFeature();

  const factory TheBringerOfDoomEntranceFeature.main(MainEntranceFeature feature) =
      MainEntranceFeatureValue;

  const factory TheBringerOfDoomEntranceFeature.side(SideEntranceFeature feature) =
      SideEntranceFeatureValue;

  @override
  int compareTo(EntranceFeature other) {
    return switch ((this, other)) {
      (MainEntranceFeatureValue a, MainEntranceFeatureValue b) => a.feature.compareTo(b.feature),
      (MainEntranceFeatureValue(), SideEntranceFeatureValue()) => 1,
      (SideEntranceFeatureValue(), MainEntranceFeatureValue()) => -1,
      (SideEntranceFeatureValue a, SideEntranceFeatureValue b) => a.feature.index.compareTo(b.feature.index),
      _ => 0,
    };
  }
}

class MainEntranceFeatureValue extends TheBringerOfDoomEntranceFeature {
  final MainEntranceFeature feature;

  const MainEntranceFeatureValue(this.feature) : super();
}

class SideEntranceFeatureValue extends TheBringerOfDoomEntranceFeature {
  final SideEntranceFeature feature;

  const SideEntranceFeatureValue(this.feature) : super();
}
