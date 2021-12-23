import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/sync/vector_clock.dart';

part 'measurables.freezed.dart';
part 'measurables.g.dart';

@freezed
class EntityDefinition with _$EntityDefinition {
  factory EntityDefinition.measurableDataType({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required String displayName,
    required String description,
    required String unitName,
    required int version,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = MeasurableDataType;

  factory EntityDefinition.fromJson(Map<String, dynamic> json) =>
      _$EntityDefinitionFromJson(json);
}

@freezed
class MeasurementData with _$MeasurementData {
  factory MeasurementData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required MeasurableDataType dataType,
  }) = _MeasurementData;

  factory MeasurementData.fromJson(Map<String, dynamic> json) =>
      _$MeasurementDataFromJson(json);
}
