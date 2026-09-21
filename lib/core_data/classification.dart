import 'package:freezed_annotation/freezed_annotation.dart';

part 'classification.freezed.dart';

enum WorldType {
  theBringerOfDoom;

  String get assets => switch (this) {
    WorldType.theBringerOfDoom => 'the_bringer_of_doom',
  };
}

enum WorldDifficulty {
  novice,
  easy,
  normal,
  hard,
  insane;

  String get assets => switch (this) {
    WorldDifficulty.novice => 'novice',
    WorldDifficulty.easy => 'easy',
    WorldDifficulty.normal => 'normal',
    WorldDifficulty.hard => 'hard',
    WorldDifficulty.insane => 'insane',
  };
}

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
    final countA = (a.hasUpDoor ? 1 : 0) + (a.hasLeftDoor ? 1 : 0) + (a.hasRightDoor ? 1 : 0);
    final countB = (b.hasUpDoor ? 1 : 0) + (b.hasLeftDoor ? 1 : 0) + (b.hasRightDoor ? 1 : 0);
    if (countA != countB) {
      return countB.compareTo(countA);
    }
    if (a.hasUpDoor != b.hasUpDoor) {
      return a.hasUpDoor ? -1 : 1;
    }
    if (a.hasLeftDoor != b.hasLeftDoor) {
      return a.hasLeftDoor ? -1 : 1;
    }
    if (a.hasRightDoor != b.hasRightDoor) {
      return a.hasRightDoor ? -1 : 1;
    }
    return 0;
  }
}

enum SideEntranceFeature {
  north,
  east,
  south,
  west,
  other,
}

@freezed
sealed class EntranceFeature with _$EntranceFeature implements Comparable<EntranceFeature> {
  const EntranceFeature._();
  const factory EntranceFeature.main({required MainEntranceFeature feature}) = EntranceFeature_Main;
  const factory EntranceFeature.side({required SideEntranceFeature feature}) = EntranceFeature_Side;

  @override
  int compareTo(EntranceFeature other) {
    final me = this;
    return switch (me) {
      EntranceFeature_Main() => switch (other) {
        EntranceFeature_Main() => me.feature.compareTo(other.feature),
        EntranceFeature_Side() => 1,
      },
      EntranceFeature_Side() => switch (other) {
        EntranceFeature_Main() => -1,
        EntranceFeature_Side() => me.feature.index.compareTo(other.feature.index),
      },
    };
  }
}
