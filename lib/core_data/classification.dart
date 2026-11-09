enum WorldType {
  theBringerOfDoom,
  phosphorescenceDisease;

  String get assets => switch (this) {
    WorldType.theBringerOfDoom => 'the_bringer_of_doom',
    WorldType.phosphorescenceDisease => 'phosphorescence_disease',
  };
}

enum WorldDifficulty {
  novice,
  easy,
  normal,
  hard,
  nightmare;

  String get assets => switch (this) {
    WorldDifficulty.novice => 'novice',
    WorldDifficulty.easy => 'easy',
    WorldDifficulty.normal => 'normal',
    WorldDifficulty.hard => 'hard',
    WorldDifficulty.nightmare => 'nightmare',
  };
}

abstract interface class EntranceFeature implements Comparable<EntranceFeature> {}
