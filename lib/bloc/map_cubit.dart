import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/maps.dart';

part 'map_cubit.freezed.dart';

@freezed
abstract class MapState with _$MapState {
  const MapState._();
  const factory MapState({
    required MapType map,
    required MapDifficulty difficulty,
  }) = _MapState;
}

class MapCubit extends Cubit<MapState> {
  MapCubit(): super(const MapState(
    map: MapType.theBringerOfDoom,
    difficulty: MapDifficulty.hard,
  ));

  void selectMap(MapType map) {
    emit(state.copyWith(map: map));
  }

  void selectDifficulty(MapDifficulty difficulty) {
    emit(state.copyWith(difficulty: difficulty));
  }
}
