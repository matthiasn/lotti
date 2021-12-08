import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/sync/vector_clock.dart';

part 'measurables.freezed.dart';
part 'measurables.g.dart';

@freezed
class MeasurableDataType with _$MeasurableDataType {
  factory MeasurableDataType({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    required String displayName,
    required String description,
    required String unitName,
    required int version,
    required VectorClock? vectorClock,
  }) = _MeasurableDataType;

  factory MeasurableDataType.fromJson(Map<String, dynamic> json) =>
      _$MeasurableDataTypeFromJson(json);
}
