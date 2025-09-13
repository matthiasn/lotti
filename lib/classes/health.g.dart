// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CumulativeQuantityData _$CumulativeQuantityDataFromJson(
        Map<String, dynamic> json) =>
    CumulativeQuantityData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      value: json['value'] as num,
      dataType: json['dataType'] as String,
      unit: json['unit'] as String,
      deviceType: json['deviceType'] as String?,
      platformType: json['platformType'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$CumulativeQuantityDataToJson(
        CumulativeQuantityData instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'value': instance.value,
      'dataType': instance.dataType,
      'unit': instance.unit,
      'deviceType': instance.deviceType,
      'platformType': instance.platformType,
      'runtimeType': instance.$type,
    };

DiscreteQuantityData _$DiscreteQuantityDataFromJson(
        Map<String, dynamic> json) =>
    DiscreteQuantityData(
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      value: json['value'] as num,
      dataType: json['dataType'] as String,
      unit: json['unit'] as String,
      deviceType: json['deviceType'] as String?,
      platformType: json['platformType'] as String?,
      sourceName: json['sourceName'] as String?,
      sourceId: json['sourceId'] as String?,
      deviceId: json['deviceId'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DiscreteQuantityDataToJson(
        DiscreteQuantityData instance) =>
    <String, dynamic>{
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'value': instance.value,
      'dataType': instance.dataType,
      'unit': instance.unit,
      'deviceType': instance.deviceType,
      'platformType': instance.platformType,
      'sourceName': instance.sourceName,
      'sourceId': instance.sourceId,
      'deviceId': instance.deviceId,
      'runtimeType': instance.$type,
    };
