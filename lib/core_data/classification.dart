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
abstract class MainEntranceFeature with _$MainEntranceFeature {
  const MainEntranceFeature._();
  const factory MainEntranceFeature({
    required bool hasUpDoor,
    required bool hasLeftDoor,
    required bool hasRightDoor,
  }) = _MainEntranceFeature;
}

enum SideEntranceFeature {
  north, // 北
  east,  // 右
  south, // 南
  west,  // 左
  other,
}
