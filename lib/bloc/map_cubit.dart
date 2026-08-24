import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idv_map_guides/core/maps.dart';

class MapState {
  final MapType selectedMap;
  final MapDifficulty selectedDifficulty;

  const MapState({
    required this.selectedMap,
    required this.selectedDifficulty,
  });
}

class MapCubit extends Cubit<MapState> {
  MapCubit(): super(const MapState(
    selectedMap: MapType.theBringerOfDoom,
    selectedDifficulty: MapDifficulty.hard,
  ));

  void selectMap(MapType map) {
    emit(MapState(
      selectedMap: map,
      selectedDifficulty: state.selectedDifficulty,
    ));
  }

  void selectDifficulty(MapDifficulty difficulty) {
    emit(MapState(
      selectedMap: state.selectedMap,
      selectedDifficulty: difficulty,
    ));
  }
}
