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
    required String unitName,
    required int version,
  }) = _MeasurableDataType;

  factory MeasurableDataType.fromJson(Map<String, dynamic> json) =>
      _$MeasurableDataTypeFromJson(json);
}
