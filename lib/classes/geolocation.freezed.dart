// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geolocation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Geolocation _$GeolocationFromJson(Map<String, dynamic> json) {
  return _Geolocation.fromJson(json);
}

/// @nodoc
mixin _$Geolocation {
  DateTime get createdAt => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  String get geohashString => throw _privateConstructorUsedError;
  int? get utcOffset => throw _privateConstructorUsedError;
  String? get timezone => throw _privateConstructorUsedError;
  double? get accuracy => throw _privateConstructorUsedError;
  double? get speed => throw _privateConstructorUsedError;
  double? get speedAccuracy => throw _privateConstructorUsedError;
  double? get heading => throw _privateConstructorUsedError;
  double? get headingAccuracy => throw _privateConstructorUsedError;
  double? get altitude => throw _privateConstructorUsedError;

  /// Serializes this Geolocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Geolocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GeolocationCopyWith<Geolocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GeolocationCopyWith<$Res> {
  factory $GeolocationCopyWith(
          Geolocation value, $Res Function(Geolocation) then) =
      _$GeolocationCopyWithImpl<$Res, Geolocation>;
  @useResult
  $Res call(
      {DateTime createdAt,
      double latitude,
      double longitude,
      String geohashString,
      int? utcOffset,
      String? timezone,
      double? accuracy,
      double? speed,
      double? speedAccuracy,
      double? heading,
      double? headingAccuracy,
      double? altitude});
}

/// @nodoc
class _$GeolocationCopyWithImpl<$Res, $Val extends Geolocation>
    implements $GeolocationCopyWith<$Res> {
  _$GeolocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Geolocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdAt = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? geohashString = null,
    Object? utcOffset = freezed,
    Object? timezone = freezed,
    Object? accuracy = freezed,
    Object? speed = freezed,
    Object? speedAccuracy = freezed,
    Object? heading = freezed,
    Object? headingAccuracy = freezed,
    Object? altitude = freezed,
  }) {
    return _then(_value.copyWith(
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      geohashString: null == geohashString
          ? _value.geohashString
          : geohashString // ignore: cast_nullable_to_non_nullable
              as String,
      utcOffset: freezed == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      accuracy: freezed == accuracy
          ? _value.accuracy
          : accuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      speed: freezed == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double?,
      speedAccuracy: freezed == speedAccuracy
          ? _value.speedAccuracy
          : speedAccuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      heading: freezed == heading
          ? _value.heading
          : heading // ignore: cast_nullable_to_non_nullable
              as double?,
      headingAccuracy: freezed == headingAccuracy
          ? _value.headingAccuracy
          : headingAccuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      altitude: freezed == altitude
          ? _value.altitude
          : altitude // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GeolocationImplCopyWith<$Res>
    implements $GeolocationCopyWith<$Res> {
  factory _$$GeolocationImplCopyWith(
          _$GeolocationImpl value, $Res Function(_$GeolocationImpl) then) =
      __$$GeolocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime createdAt,
      double latitude,
      double longitude,
      String geohashString,
      int? utcOffset,
      String? timezone,
      double? accuracy,
      double? speed,
      double? speedAccuracy,
      double? heading,
      double? headingAccuracy,
      double? altitude});
}

/// @nodoc
class __$$GeolocationImplCopyWithImpl<$Res>
    extends _$GeolocationCopyWithImpl<$Res, _$GeolocationImpl>
    implements _$$GeolocationImplCopyWith<$Res> {
  __$$GeolocationImplCopyWithImpl(
      _$GeolocationImpl _value, $Res Function(_$GeolocationImpl) _then)
      : super(_value, _then);

  /// Create a copy of Geolocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdAt = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? geohashString = null,
    Object? utcOffset = freezed,
    Object? timezone = freezed,
    Object? accuracy = freezed,
    Object? speed = freezed,
    Object? speedAccuracy = freezed,
    Object? heading = freezed,
    Object? headingAccuracy = freezed,
    Object? altitude = freezed,
  }) {
    return _then(_$GeolocationImpl(
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      geohashString: null == geohashString
          ? _value.geohashString
          : geohashString // ignore: cast_nullable_to_non_nullable
              as String,
      utcOffset: freezed == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      accuracy: freezed == accuracy
          ? _value.accuracy
          : accuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      speed: freezed == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double?,
      speedAccuracy: freezed == speedAccuracy
          ? _value.speedAccuracy
          : speedAccuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      heading: freezed == heading
          ? _value.heading
          : heading // ignore: cast_nullable_to_non_nullable
              as double?,
      headingAccuracy: freezed == headingAccuracy
          ? _value.headingAccuracy
          : headingAccuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      altitude: freezed == altitude
          ? _value.altitude
          : altitude // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GeolocationImpl implements _Geolocation {
  const _$GeolocationImpl(
      {required this.createdAt,
      required this.latitude,
      required this.longitude,
      required this.geohashString,
      this.utcOffset,
      this.timezone,
      this.accuracy,
      this.speed,
      this.speedAccuracy,
      this.heading,
      this.headingAccuracy,
      this.altitude});

  factory _$GeolocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$GeolocationImplFromJson(json);

  @override
  final DateTime createdAt;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final String geohashString;
  @override
  final int? utcOffset;
  @override
  final String? timezone;
  @override
  final double? accuracy;
  @override
  final double? speed;
  @override
  final double? speedAccuracy;
  @override
  final double? heading;
  @override
  final double? headingAccuracy;
  @override
  final double? altitude;

  @override
  String toString() {
    return 'Geolocation(createdAt: $createdAt, latitude: $latitude, longitude: $longitude, geohashString: $geohashString, utcOffset: $utcOffset, timezone: $timezone, accuracy: $accuracy, speed: $speed, speedAccuracy: $speedAccuracy, heading: $heading, headingAccuracy: $headingAccuracy, altitude: $altitude)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GeolocationImpl &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.geohashString, geohashString) ||
                other.geohashString == geohashString) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.accuracy, accuracy) ||
                other.accuracy == accuracy) &&
            (identical(other.speed, speed) || other.speed == speed) &&
            (identical(other.speedAccuracy, speedAccuracy) ||
                other.speedAccuracy == speedAccuracy) &&
            (identical(other.heading, heading) || other.heading == heading) &&
            (identical(other.headingAccuracy, headingAccuracy) ||
                other.headingAccuracy == headingAccuracy) &&
            (identical(other.altitude, altitude) ||
                other.altitude == altitude));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      createdAt,
      latitude,
      longitude,
      geohashString,
      utcOffset,
      timezone,
      accuracy,
      speed,
      speedAccuracy,
      heading,
      headingAccuracy,
      altitude);

  /// Create a copy of Geolocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GeolocationImplCopyWith<_$GeolocationImpl> get copyWith =>
      __$$GeolocationImplCopyWithImpl<_$GeolocationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GeolocationImplToJson(
      this,
    );
  }
}

abstract class _Geolocation implements Geolocation {
  const factory _Geolocation(
      {required final DateTime createdAt,
      required final double latitude,
      required final double longitude,
      required final String geohashString,
      final int? utcOffset,
      final String? timezone,
      final double? accuracy,
      final double? speed,
      final double? speedAccuracy,
      final double? heading,
      final double? headingAccuracy,
      final double? altitude}) = _$GeolocationImpl;

  factory _Geolocation.fromJson(Map<String, dynamic> json) =
      _$GeolocationImpl.fromJson;

  @override
  DateTime get createdAt;
  @override
  double get latitude;
  @override
  double get longitude;
  @override
  String get geohashString;
  @override
  int? get utcOffset;
  @override
  String? get timezone;
  @override
  double? get accuracy;
  @override
  double? get speed;
  @override
  double? get speedAccuracy;
  @override
  double? get heading;
  @override
  double? get headingAccuracy;
  @override
  double? get altitude;

  /// Create a copy of Geolocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GeolocationImplCopyWith<_$GeolocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
