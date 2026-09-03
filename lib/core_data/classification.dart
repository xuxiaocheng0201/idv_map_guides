import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/generated/l10n.dart';

part 'classification.freezed.dart';

enum WorldType {
  theBringerOfDoom;

  String get assets => switch (this) {
    WorldType.theBringerOfDoom => 'the_bringer_of_doom',
  };
  String label(BuildContext context) {
    return switch (this) {
      WorldType.theBringerOfDoom => S.of(context).worldTheBringerOfDoom,
    };
  }
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
  String label(BuildContext context) {
    return switch (this) {
      WorldDifficulty.novice => S.of(context).difficultyNovice,
      WorldDifficulty.easy => S.of(context).difficultyEasy,
      WorldDifficulty.normal => S.of(context).difficultyNormal,
      WorldDifficulty.hard => S.of(context).difficultyHard,
      WorldDifficulty.insane => S.of(context).difficultyInsane,
    };
  }
}

@freezed
abstract class MainEntranceFeature with _$MainEntranceFeature implements Comparable<MainEntranceFeature> {
  const MainEntranceFeature._();
  const factory MainEntranceFeature({
    required bool hasUpDoor,
    required bool hasLeftDoor,
    required bool hasRightDoor,
  }) = _MainEntranceFeature;

  String label(BuildContext context) {
    final s = S.of(context);
    final StringBuffer sb = StringBuffer();
    if (hasUpDoor) sb.write(s.mainEntranceFeatureHasUp);
    if (hasLeftDoor) sb.write(s.mainEntranceFeatureHasLeft);
    if (hasRightDoor) sb.write(s.mainEntranceFeatureHasRight);
    return sb.toString();
  }

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
  other;

  String label(BuildContext context) {
    return switch (this) {
      SideEntranceFeature.north => S.of(context).sideEntranceFeatureNorth,
      SideEntranceFeature.east => S.of(context).sideEntranceFeatureEast,
      SideEntranceFeature.south => S.of(context).sideEntranceFeatureSouth,
      SideEntranceFeature.west => S.of(context).sideEntranceFeatureWest,
      SideEntranceFeature.other => S.of(context).sideEntranceFeatureOther,
    };
  }
}

@freezed
sealed class EntranceFeature with _$EntranceFeature implements Comparable<EntranceFeature> {
  const EntranceFeature._();
  const factory EntranceFeature.main({required MainEntranceFeature feature}) = EntranceFeature_Main;
  const factory EntranceFeature.side({required SideEntranceFeature feature}) = EntranceFeature_Side;

  String label(BuildContext context) {
    final me = this;
    return switch (me) {
      EntranceFeature_Main() => me.feature.label(context),
      EntranceFeature_Side() => me.feature.label(context),
    };
  }

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
