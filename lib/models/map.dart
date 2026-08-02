import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/generated/l10n.dart';

enum MapType {
  theBringerOfDoom,
}

enum MapDifficulty {
  novice,
  easy,
  normal,
  hard,
}

String mapLabel(BuildContext context, MapType map) {
  switch (map) {
    case MapType.theBringerOfDoom:
      return S.of(context).mapTheBringerOfDoom;
  }
}

String difficultyLabel(BuildContext context, MapDifficulty difficulty) {
  switch (difficulty) {
    case MapDifficulty.novice:
      return S.of(context).difficultyNovice;
    case MapDifficulty.easy:
      return S.of(context).difficultyEasy;
    case MapDifficulty.normal:
      return S.of(context).difficultyNormal;
    case MapDifficulty.hard:
      return S.of(context).difficultyHard;
  }
}
