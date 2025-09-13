// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geolocation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Geolocation _$GeolocationFromJson(Map<String, dynamic> json) => _Geolocation(
      createdAt: DateTime.parse(json['createdAt'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      geohashString: json['geohashString'] as String,
      utcOffset: (json['utcOffset'] as num?)?.toInt(),
      timezone: json['timezone'] as String?,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      speedAccuracy: (json['speedAccuracy'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      headingAccuracy: (json['headingAccuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$GeolocationToJson(_Geolocation instance) =>
    <String, dynamic>{
      'createdAt': instance.createdAt.toIso8601String(),
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'geohashString': instance.geohashString,
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'accuracy': instance.accuracy,
      'speed': instance.speed,
      'speedAccuracy': instance.speedAccuracy,
      'heading': instance.heading,
      'headingAccuracy': instance.headingAccuracy,
      'altitude': instance.altitude,
    };
