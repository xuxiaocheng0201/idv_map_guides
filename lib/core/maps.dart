import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/generated/l10n.dart';

enum MapType {
  theBringerOfDoom;

  String label(BuildContext context) {
    switch (this) {
      case MapType.theBringerOfDoom:
        return S.of(context).mapTheBringerOfDoom;
    }
  }
}

enum MapDifficulty {
  novice,
  easy,
  normal,
  hard,
  insane;

  String label(BuildContext context) {
    switch (this) {
      case MapDifficulty.novice:
        return S.of(context).difficultyNovice;
      case MapDifficulty.easy:
        return S.of(context).difficultyEasy;
      case MapDifficulty.normal:
        return S.of(context).difficultyNormal;
      case MapDifficulty.hard:
        return S.of(context).difficultyHard;
      case MapDifficulty.insane:
        return S.of(context).difficultyInsane;
    }
  }
}
