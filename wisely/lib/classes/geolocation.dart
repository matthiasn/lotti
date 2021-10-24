import 'package:freezed_annotation/freezed_annotation.dart';

part 'geolocation.freezed.dart';
part 'geolocation.g.dart';

@freezed
class Geolocation with _$Geolocation {
  factory Geolocation({
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    required double latitude,
    required double longitude,
    double? altitude,
  }) = _Geolocation;

  factory Geolocation.fromJson(Map<String, dynamic> json) =>
      _$GeolocationFromJson(json);
}
