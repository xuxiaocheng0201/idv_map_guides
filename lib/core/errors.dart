import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';

part 'errors.freezed.dart';

@freezed
sealed class WorldError with _$WorldError {
  const factory WorldError.entranceOutOfWorld({required Entrance entrance}) = WorldError_EntranceOutOfWorld;
  const factory WorldError.cellOutOfWorld({required Position worldPosition}) = WorldError_CellOutOfWorld;
  const factory WorldError.cellOverlap({required Position worldPosition}) = WorldError_CellOverlap;
  const factory WorldError.doorNotAtBoundary({required Edge worldDoor}) = WorldError_DoorNotAtBoundary;
  const factory WorldError.innerWallAtBoundary({required Edge worldWall}) = WorldError_InnerWallAtBoundary;
  const factory WorldError.stairMoveOutOfLayer({required Position worldStair}) = WorldError_StairMoveOutOfLayer;
  const factory WorldError.holeMoveOutOfLayer({required Edge worldHole}) = WorldError_HoleMoveOutOfLayer;
  const factory WorldError.holeOutOfWorld({required Edge worldHole}) = WorldError_HoleOutOfWorld;

  const factory WorldError.entranceInEmpty({required Entrance entrance}) = WorldError_EntranceInEmpty;
  const factory WorldError.doorMismatch({required Edge worldDoor}) = WorldError_DoorMismatch;
  const factory WorldError.stairMismatch({required Position worldStair}) = WorldError_StairMismatch;
  const factory WorldError.holeMismatch({required Edge worldHole}) = WorldError_HoleMismatch;
  const factory WorldError.holeMovedMismatch({required Edge worldHole}) = WorldError_HoleMovedMismatch;

  const factory WorldError.emptyMap() = WorldError_EmptyMap;
  const factory WorldError.unknownStructureType({required String typeName}) = WorldError_UnknownStructureType;
  const factory WorldError.corridorMissingCells() = WorldError_CorridorMissingCells;
}

@Freezed(makeCollectionsUnmodifiable: false)
abstract class WorldErrors with _$WorldErrors implements Exception {
  const WorldErrors._();
  const factory WorldErrors({
    @Default(<WorldError>[]) List<WorldError> errors,
  }) = _WorldErrors;

  void push(WorldError e) => errors.add(e);

  void merge(WorldErrors other) => errors.addAll(other.errors);

  bool get isEmpty => errors.isEmpty;
}
