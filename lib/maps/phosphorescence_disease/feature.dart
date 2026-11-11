import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:idv_map_guides/core_data/classification.dart';

part 'feature.freezed.dart';

@freezed
abstract class B1EntranceFeature with _$B1EntranceFeature implements Comparable<B1EntranceFeature> {
  const B1EntranceFeature._();
  const factory B1EntranceFeature({
    required int cells,
  }) = _B1EntranceFeature;

  @override
  int compareTo(B1EntranceFeature other) {
    return cells.compareTo(other.cells);
  }
}

enum B2EntranceFeatureType implements Comparable<B2EntranceFeatureType> {
  none,
  straight,
  bentUpward,
  bentDownward,
  bentLeftward,
  bentRightward;

  @override
  int compareTo(B2EntranceFeatureType other) => index.compareTo(other.index);
}

@freezed
abstract class B2EntranceFeature with _$B2EntranceFeature implements Comparable<B2EntranceFeature> {
  const B2EntranceFeature._();
  const factory B2EntranceFeature({
    required B2EntranceFeatureType leftType,
    required B2EntranceFeatureType downType,
    required B2EntranceFeatureType rightType,
  }) = _B2EntranceFeatureType;

  @override
  int compareTo(B2EntranceFeature b) {
    final a = this;
    final countA = _count(a);
    final countB = _count(b);
    if (countA != countB) return countA.compareTo(countB);
    if (a.leftType != b.leftType) return a.leftType.index.compareTo(b.leftType.index);
    if (a.downType != b.downType) return a.downType.index.compareTo(b.downType.index);
    if (a.rightType != b.rightType) return a.rightType.index.compareTo(b.rightType.index);
    return 0;
  }

  int _count(B2EntranceFeature f) =>
      (f.leftType != B2EntranceFeatureType.none ? 1 : 0) +
      (f.downType != B2EntranceFeatureType.none ? 1 : 0) +
      (f.rightType != B2EntranceFeatureType.none ? 1 : 0);
}

@freezed
sealed class PhosphorescenceDiseaseEntranceFeature with _$PhosphorescenceDiseaseEntranceFeature implements EntranceFeature {
  const PhosphorescenceDiseaseEntranceFeature._();
  const factory PhosphorescenceDiseaseEntranceFeature.b1(B1EntranceFeature feature) = B1EntranceFeatureValue;
  const factory PhosphorescenceDiseaseEntranceFeature.b2(B2EntranceFeature feature) = B2EntranceFeatureValue;

  @override
  int compareTo(EntranceFeature other) {
    return switch ((this, other)) {
      (B1EntranceFeatureValue a, B1EntranceFeatureValue b) => a.feature.compareTo(b.feature),
      (B2EntranceFeatureValue a, B2EntranceFeatureValue b) => a.feature.compareTo(b.feature),
      _ => 0,
    };
  }
}
