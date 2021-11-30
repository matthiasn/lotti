import 'package:freezed_annotation/freezed_annotation.dart';

part 'health.freezed.dart';
part 'health.g.dart';

@freezed
class QuantitativeData with _$QuantitativeData {
  factory QuantitativeData.cumulativeQuantityData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required String dataType,
    required String unit,
    String? deviceType,
    String? platformType,
  }) = CumulativeQuantityData;

  factory QuantitativeData.discreteQuantityData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required String dataType,
    required String unit,
    String? deviceType,
    String? platformType,
    String? sourceName,
    String? sourceId,
    String? deviceId,
  }) = DiscreteQuantityData;

  factory QuantitativeData.fromJson(Map<String, dynamic> json) =>
      _$QuantitativeDataFromJson(json);
}
