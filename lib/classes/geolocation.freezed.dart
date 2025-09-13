// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geolocation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Geolocation {
  DateTime get createdAt;
  double get latitude;
  double get longitude;
  String get geohashString;
  int? get utcOffset;
  String? get timezone;
  double? get accuracy;
  double? get speed;
  double? get speedAccuracy;
  double? get heading;
  double? get headingAccuracy;
  double? get altitude;

  /// Create a copy of Geolocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<Geolocation> get copyWith =>
      _$GeolocationCopyWithImpl<Geolocation>(this as Geolocation, _$identity);

  /// Serializes this Geolocation to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Geolocation &&
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

  @override
  String toString() {
    return 'Geolocation(createdAt: $createdAt, latitude: $latitude, longitude: $longitude, geohashString: $geohashString, utcOffset: $utcOffset, timezone: $timezone, accuracy: $accuracy, speed: $speed, speedAccuracy: $speedAccuracy, heading: $heading, headingAccuracy: $headingAccuracy, altitude: $altitude)';
  }
}

/// @nodoc
abstract mixin class $GeolocationCopyWith<$Res> {
  factory $GeolocationCopyWith(
          Geolocation value, $Res Function(Geolocation) _then) =
      _$GeolocationCopyWithImpl;
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
class _$GeolocationCopyWithImpl<$Res> implements $GeolocationCopyWith<$Res> {
  _$GeolocationCopyWithImpl(this._self, this._then);

  final Geolocation _self;
  final $Res Function(Geolocation) _then;

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
    return _then(_self.copyWith(
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      geohashString: null == geohashString
          ? _self.geohashString
          : geohashString // ignore: cast_nullable_to_non_nullable
              as String,
      utcOffset: freezed == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      accuracy: freezed == accuracy
          ? _self.accuracy
          : accuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      speed: freezed == speed
          ? _self.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double?,
      speedAccuracy: freezed == speedAccuracy
          ? _self.speedAccuracy
          : speedAccuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      heading: freezed == heading
          ? _self.heading
          : heading // ignore: cast_nullable_to_non_nullable
              as double?,
      headingAccuracy: freezed == headingAccuracy
          ? _self.headingAccuracy
          : headingAccuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      altitude: freezed == altitude
          ? _self.altitude
          : altitude // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Geolocation].
extension GeolocationPatterns on Geolocation {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_Geolocation value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Geolocation() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_Geolocation value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Geolocation():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_Geolocation value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Geolocation() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            DateTime createdAt,
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
            double? altitude)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Geolocation() when $default != null:
        return $default(
            _that.createdAt,
            _that.latitude,
            _that.longitude,
            _that.geohashString,
            _that.utcOffset,
            _that.timezone,
            _that.accuracy,
            _that.speed,
            _that.speedAccuracy,
            _that.heading,
            _that.headingAccuracy,
            _that.altitude);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            DateTime createdAt,
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
            double? altitude)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Geolocation():
        return $default(
            _that.createdAt,
            _that.latitude,
            _that.longitude,
            _that.geohashString,
            _that.utcOffset,
            _that.timezone,
            _that.accuracy,
            _that.speed,
            _that.speedAccuracy,
            _that.heading,
            _that.headingAccuracy,
            _that.altitude);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            DateTime createdAt,
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
            double? altitude)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Geolocation() when $default != null:
        return $default(
            _that.createdAt,
            _that.latitude,
            _that.longitude,
            _that.geohashString,
            _that.utcOffset,
            _that.timezone,
            _that.accuracy,
            _that.speed,
            _that.speedAccuracy,
            _that.heading,
            _that.headingAccuracy,
            _that.altitude);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Geolocation implements Geolocation {
  const _Geolocation(
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
  factory _Geolocation.fromJson(Map<String, dynamic> json) =>
      _$GeolocationFromJson(json);

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

  /// Create a copy of Geolocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GeolocationCopyWith<_Geolocation> get copyWith =>
      __$GeolocationCopyWithImpl<_Geolocation>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GeolocationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Geolocation &&
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

  @override
  String toString() {
    return 'Geolocation(createdAt: $createdAt, latitude: $latitude, longitude: $longitude, geohashString: $geohashString, utcOffset: $utcOffset, timezone: $timezone, accuracy: $accuracy, speed: $speed, speedAccuracy: $speedAccuracy, heading: $heading, headingAccuracy: $headingAccuracy, altitude: $altitude)';
  }
}

/// @nodoc
abstract mixin class _$GeolocationCopyWith<$Res>
    implements $GeolocationCopyWith<$Res> {
  factory _$GeolocationCopyWith(
          _Geolocation value, $Res Function(_Geolocation) _then) =
      __$GeolocationCopyWithImpl;
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
class __$GeolocationCopyWithImpl<$Res> implements _$GeolocationCopyWith<$Res> {
  __$GeolocationCopyWithImpl(this._self, this._then);

  final _Geolocation _self;
  final $Res Function(_Geolocation) _then;

  /// Create a copy of Geolocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_Geolocation(
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      geohashString: null == geohashString
          ? _self.geohashString
          : geohashString // ignore: cast_nullable_to_non_nullable
              as String,
      utcOffset: freezed == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      accuracy: freezed == accuracy
          ? _self.accuracy
          : accuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      speed: freezed == speed
          ? _self.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double?,
      speedAccuracy: freezed == speedAccuracy
          ? _self.speedAccuracy
          : speedAccuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      heading: freezed == heading
          ? _self.heading
          : heading // ignore: cast_nullable_to_non_nullable
              as double?,
      headingAccuracy: freezed == headingAccuracy
          ? _self.headingAccuracy
          : headingAccuracy // ignore: cast_nullable_to_non_nullable
              as double?,
      altitude: freezed == altitude
          ? _self.altitude
          : altitude // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

// dart format on
