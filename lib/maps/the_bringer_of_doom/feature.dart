import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core_data/classification.dart';

part 'feature.freezed.dart';

@freezed
abstract class MainEntranceFeature with _$MainEntranceFeature implements Comparable<MainEntranceFeature> {
  const MainEntranceFeature._();
  const factory MainEntranceFeature({
    required bool hasUpDoor,
    required bool hasLeftDoor,
    required bool hasRightDoor,
  }) = _MainEntranceFeature;

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

  int _count(MainEntranceFeature f) =>(f.hasUpDoor ? 1 : 0) + (f.hasLeftDoor ? 1 : 0) + (f.hasRightDoor ? 1 : 0);
}

enum SideEntranceFeature implements Comparable<SideEntranceFeature> {
  north,
  east,
  south,
  west,
  other;

  @override
  int compareTo(SideEntranceFeature other) => index.compareTo(other.index);
}

@freezed
sealed class TheBringerOfDoomEntranceFeature with _$TheBringerOfDoomEntranceFeature implements EntranceFeature {
  const TheBringerOfDoomEntranceFeature._();
  const factory TheBringerOfDoomEntranceFeature.main(MainEntranceFeature feature) = MainEntranceFeatureValue;
  const factory TheBringerOfDoomEntranceFeature.side(SideEntranceFeature feature) = SideEntranceFeatureValue;

  @override
  int compareTo(EntranceFeature other) {
    return switch ((this, other)) {
      (MainEntranceFeatureValue a, MainEntranceFeatureValue b) => a.feature.compareTo(b.feature),
      (SideEntranceFeatureValue a, SideEntranceFeatureValue b) => a.feature.compareTo(b.feature),
      _ => 0,
    };
  }
}
