import 'package:freezed_annotation/freezed_annotation.dart';

part 'health.freezed.dart';
part 'health.g.dart';

@freezed
class HealthData with _$HealthData {
  factory HealthData.cumulativeQuantity({
    required DateTime startDate,
    required DateTime endDate,
    required num value,
    required String dataType,
    required String unit,
    String? deviceType,
    String? platformType,
  }) = CumulativeQuantity;

  factory HealthData.discreteQuantity({
    required DateTime startDate,
    required DateTime endDate,
    required num value,
    required String dataType,
    required String unit,
    String? deviceType,
    String? platformType,
    String? sourceName,
    String? sourceId,
    String? deviceId,
  }) = DiscreteQuantity;

  factory HealthData.fromJson(Map<String, dynamic> json) =>
      _$HealthDataFromJson(json);
}
