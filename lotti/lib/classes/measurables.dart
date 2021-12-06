import 'package:freezed_annotation/freezed_annotation.dart';

part 'measurables.freezed.dart';
part 'measurables.g.dart';

@freezed
class MeasurableDataType with _$MeasurableDataType {
  factory MeasurableDataType({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String uniqueName,
    required String displayName,
    required MeasurableUnit unit,
    required MeasurableType measurableType,
    required int version,
  }) = _MeasurableDataType;

  factory MeasurableDataType.fromJson(Map<String, dynamic> json) =>
      _$MeasurableDataTypeFromJson(json);
}

@freezed
class MeasurableUnit with _$MeasurableUnit {
  factory MeasurableUnit({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String unit,
    required String displayUnit,
    required int version,
  }) = _MeasurableUnit;

  factory MeasurableUnit.fromJson(Map<String, dynamic> json) =>
      _$MeasurableUnitFromJson(json);
}

@freezed
class MeasurableType with _$MeasurableType {
  factory MeasurableType({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String uniqueName,
    required String displayName,
    required int version,
  }) = _MeasurableType;

  factory MeasurableType.fromJson(Map<String, dynamic> json) =>
      _$MeasurableTypeFromJson(json);
}
