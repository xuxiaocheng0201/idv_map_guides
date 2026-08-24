import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core/data.dart';

part 'errors.freezed.dart';

@freezed
sealed class WorldError with _$WorldError {
  const factory WorldError.entranceOutOfWorld({required Entrance entrance}) = WorldError_EntranceOutOfWorld;
  const factory WorldError.cellOutOfWorld({required Position worldPosition, required Position cell}) = WorldError_CellOutOfWorld;
  const factory WorldError.cellOverlap({required Position worldPosition, required Position cell}) = WorldError_CellOverlap;
  const factory WorldError.doorOutOfStructure({required Door door}) = WorldError_DoorOutOfStructure;
  const factory WorldError.doorNotAtBoundary({required Door door}) = WorldError_DoorNotAtBoundary;
  const factory WorldError.innerWallOutOfStructure({required Door wall}) = WorldError_InnerWallOutOfStructure;
  const factory WorldError.innerWallAtBoundary({required Door wall}) = WorldError_InnerWallAtBoundary;
  const factory WorldError.stairOutOfStructure({required Stair stair}) = WorldError_StairOutOfStructure;
  const factory WorldError.stairOverlap({required Stair stair}) = WorldError_StairOverlap;
  const factory WorldError.stairMoveOutOfLayer({required Stair stair}) = WorldError_StairMoveOutOfLayer;
  const factory WorldError.holeOutOfStructure({required Hole hole}) = WorldError_HoleOutOfStructure;
  const factory WorldError.holeMoveOutOfLayer({required Hole hole}) = WorldError_HoleMoveOutOfLayer;
  const factory WorldError.holeOutOfWorld({required Position worldTarget, required Hole hole}) = WorldError_HoleOutOfWorld;

  const factory WorldError.entranceInEmpty({required Entrance entrance}) = WorldError_EntranceInEmpty;
  const factory WorldError.doorMismatch({required Door worldDoor}) = WorldError_DoorMismatch;
  const factory WorldError.stairMismatch({required Stair worldStair}) = WorldError_StairMismatch;
  const factory WorldError.holeMismatch({required Hole worldHole}) = WorldError_HoleMismatch;
  const factory WorldError.holeMovedMismatch({required Hole worldHole}) = WorldError_HoleMovedMismatch;

  const factory WorldError.unknownStructureType({required String typeName}) = WorldError_UnknownStructureType;
  const factory WorldError.corridorMissingCells() = WorldError_CorridorMissingCells;
  const factory WorldError.emptyMap() = WorldError_EmptyMap;
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
