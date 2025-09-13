import 'package:freezed_annotation/freezed_annotation.dart';

part 'geolocation.freezed.dart';
part 'geolocation.g.dart';

@freezed
abstract class Geolocation with _$Geolocation {
  const factory Geolocation({
    required DateTime createdAt,
    required double latitude,
    required double longitude,
    required String geohashString,
    int? utcOffset,
    String? timezone,
    double? accuracy,
    double? speed,
    double? speedAccuracy,
    double? heading,
    double? headingAccuracy,
    double? altitude,
  }) = _Geolocation;

  factory Geolocation.fromJson(Map<String, dynamic> json) =>
      _$GeolocationFromJson(json);
}
