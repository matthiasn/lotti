// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wake_run_time_series.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WakeRunTimeSeries {
  List<DailyWakeBucket> get dailyBuckets;
  List<VersionPerformanceBucket> get versionBuckets;

  /// Create a copy of WakeRunTimeSeries
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WakeRunTimeSeriesCopyWith<WakeRunTimeSeries> get copyWith =>
      _$WakeRunTimeSeriesCopyWithImpl<WakeRunTimeSeries>(
          this as WakeRunTimeSeries, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WakeRunTimeSeries &&
            const DeepCollectionEquality()
                .equals(other.dailyBuckets, dailyBuckets) &&
            const DeepCollectionEquality()
                .equals(other.versionBuckets, versionBuckets));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(dailyBuckets),
      const DeepCollectionEquality().hash(versionBuckets));

  @override
  String toString() {
    return 'WakeRunTimeSeries(dailyBuckets: $dailyBuckets, versionBuckets: $versionBuckets)';
  }
}

/// @nodoc
abstract mixin class $WakeRunTimeSeriesCopyWith<$Res> {
  factory $WakeRunTimeSeriesCopyWith(
          WakeRunTimeSeries value, $Res Function(WakeRunTimeSeries) _then) =
      _$WakeRunTimeSeriesCopyWithImpl;
  @useResult
  $Res call(
      {List<DailyWakeBucket> dailyBuckets,
      List<VersionPerformanceBucket> versionBuckets});
}

/// @nodoc
class _$WakeRunTimeSeriesCopyWithImpl<$Res>
    implements $WakeRunTimeSeriesCopyWith<$Res> {
  _$WakeRunTimeSeriesCopyWithImpl(this._self, this._then);

  final WakeRunTimeSeries _self;
  final $Res Function(WakeRunTimeSeries) _then;

  /// Create a copy of WakeRunTimeSeries
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dailyBuckets = null,
    Object? versionBuckets = null,
  }) {
    return _then(_self.copyWith(
      dailyBuckets: null == dailyBuckets
          ? _self.dailyBuckets
          : dailyBuckets // ignore: cast_nullable_to_non_nullable
              as List<DailyWakeBucket>,
      versionBuckets: null == versionBuckets
          ? _self.versionBuckets
          : versionBuckets // ignore: cast_nullable_to_non_nullable
              as List<VersionPerformanceBucket>,
    ));
  }
}

/// Adds pattern-matching-related methods to [WakeRunTimeSeries].
extension WakeRunTimeSeriesPatterns on WakeRunTimeSeries {
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
    TResult Function(_WakeRunTimeSeries value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WakeRunTimeSeries() when $default != null:
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
    TResult Function(_WakeRunTimeSeries value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WakeRunTimeSeries():
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
    TResult? Function(_WakeRunTimeSeries value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WakeRunTimeSeries() when $default != null:
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
    TResult Function(List<DailyWakeBucket> dailyBuckets,
            List<VersionPerformanceBucket> versionBuckets)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WakeRunTimeSeries() when $default != null:
        return $default(_that.dailyBuckets, _that.versionBuckets);
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
    TResult Function(List<DailyWakeBucket> dailyBuckets,
            List<VersionPerformanceBucket> versionBuckets)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WakeRunTimeSeries():
        return $default(_that.dailyBuckets, _that.versionBuckets);
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
    TResult? Function(List<DailyWakeBucket> dailyBuckets,
            List<VersionPerformanceBucket> versionBuckets)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WakeRunTimeSeries() when $default != null:
        return $default(_that.dailyBuckets, _that.versionBuckets);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _WakeRunTimeSeries implements WakeRunTimeSeries {
  const _WakeRunTimeSeries(
      {required final List<DailyWakeBucket> dailyBuckets,
      required final List<VersionPerformanceBucket> versionBuckets})
      : _dailyBuckets = dailyBuckets,
        _versionBuckets = versionBuckets;

  final List<DailyWakeBucket> _dailyBuckets;
  @override
  List<DailyWakeBucket> get dailyBuckets {
    if (_dailyBuckets is EqualUnmodifiableListView) return _dailyBuckets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dailyBuckets);
  }

  final List<VersionPerformanceBucket> _versionBuckets;
  @override
  List<VersionPerformanceBucket> get versionBuckets {
    if (_versionBuckets is EqualUnmodifiableListView) return _versionBuckets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_versionBuckets);
  }

  /// Create a copy of WakeRunTimeSeries
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WakeRunTimeSeriesCopyWith<_WakeRunTimeSeries> get copyWith =>
      __$WakeRunTimeSeriesCopyWithImpl<_WakeRunTimeSeries>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WakeRunTimeSeries &&
            const DeepCollectionEquality()
                .equals(other._dailyBuckets, _dailyBuckets) &&
            const DeepCollectionEquality()
                .equals(other._versionBuckets, _versionBuckets));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_dailyBuckets),
      const DeepCollectionEquality().hash(_versionBuckets));

  @override
  String toString() {
    return 'WakeRunTimeSeries(dailyBuckets: $dailyBuckets, versionBuckets: $versionBuckets)';
  }
}

/// @nodoc
abstract mixin class _$WakeRunTimeSeriesCopyWith<$Res>
    implements $WakeRunTimeSeriesCopyWith<$Res> {
  factory _$WakeRunTimeSeriesCopyWith(
          _WakeRunTimeSeries value, $Res Function(_WakeRunTimeSeries) _then) =
      __$WakeRunTimeSeriesCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<DailyWakeBucket> dailyBuckets,
      List<VersionPerformanceBucket> versionBuckets});
}

/// @nodoc
class __$WakeRunTimeSeriesCopyWithImpl<$Res>
    implements _$WakeRunTimeSeriesCopyWith<$Res> {
  __$WakeRunTimeSeriesCopyWithImpl(this._self, this._then);

  final _WakeRunTimeSeries _self;
  final $Res Function(_WakeRunTimeSeries) _then;

  /// Create a copy of WakeRunTimeSeries
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dailyBuckets = null,
    Object? versionBuckets = null,
  }) {
    return _then(_WakeRunTimeSeries(
      dailyBuckets: null == dailyBuckets
          ? _self._dailyBuckets
          : dailyBuckets // ignore: cast_nullable_to_non_nullable
              as List<DailyWakeBucket>,
      versionBuckets: null == versionBuckets
          ? _self._versionBuckets
          : versionBuckets // ignore: cast_nullable_to_non_nullable
              as List<VersionPerformanceBucket>,
    ));
  }
}

/// @nodoc
mixin _$DailyWakeBucket {
  DateTime get date;
  int get successCount;
  int get failureCount;
  double get successRate;
  Duration get averageDuration;

  /// Create a copy of DailyWakeBucket
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DailyWakeBucketCopyWith<DailyWakeBucket> get copyWith =>
      _$DailyWakeBucketCopyWithImpl<DailyWakeBucket>(
          this as DailyWakeBucket, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DailyWakeBucket &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.successCount, successCount) ||
                other.successCount == successCount) &&
            (identical(other.failureCount, failureCount) ||
                other.failureCount == failureCount) &&
            (identical(other.successRate, successRate) ||
                other.successRate == successRate) &&
            (identical(other.averageDuration, averageDuration) ||
                other.averageDuration == averageDuration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, date, successCount, failureCount,
      successRate, averageDuration);

  @override
  String toString() {
    return 'DailyWakeBucket(date: $date, successCount: $successCount, failureCount: $failureCount, successRate: $successRate, averageDuration: $averageDuration)';
  }
}

/// @nodoc
abstract mixin class $DailyWakeBucketCopyWith<$Res> {
  factory $DailyWakeBucketCopyWith(
          DailyWakeBucket value, $Res Function(DailyWakeBucket) _then) =
      _$DailyWakeBucketCopyWithImpl;
  @useResult
  $Res call(
      {DateTime date,
      int successCount,
      int failureCount,
      double successRate,
      Duration averageDuration});
}

/// @nodoc
class _$DailyWakeBucketCopyWithImpl<$Res>
    implements $DailyWakeBucketCopyWith<$Res> {
  _$DailyWakeBucketCopyWithImpl(this._self, this._then);

  final DailyWakeBucket _self;
  final $Res Function(DailyWakeBucket) _then;

  /// Create a copy of DailyWakeBucket
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? successCount = null,
    Object? failureCount = null,
    Object? successRate = null,
    Object? averageDuration = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      successCount: null == successCount
          ? _self.successCount
          : successCount // ignore: cast_nullable_to_non_nullable
              as int,
      failureCount: null == failureCount
          ? _self.failureCount
          : failureCount // ignore: cast_nullable_to_non_nullable
              as int,
      successRate: null == successRate
          ? _self.successRate
          : successRate // ignore: cast_nullable_to_non_nullable
              as double,
      averageDuration: null == averageDuration
          ? _self.averageDuration
          : averageDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// Adds pattern-matching-related methods to [DailyWakeBucket].
extension DailyWakeBucketPatterns on DailyWakeBucket {
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
    TResult Function(_DailyWakeBucket value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DailyWakeBucket() when $default != null:
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
    TResult Function(_DailyWakeBucket value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DailyWakeBucket():
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
    TResult? Function(_DailyWakeBucket value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DailyWakeBucket() when $default != null:
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
    TResult Function(DateTime date, int successCount, int failureCount,
            double successRate, Duration averageDuration)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DailyWakeBucket() when $default != null:
        return $default(_that.date, _that.successCount, _that.failureCount,
            _that.successRate, _that.averageDuration);
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
    TResult Function(DateTime date, int successCount, int failureCount,
            double successRate, Duration averageDuration)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DailyWakeBucket():
        return $default(_that.date, _that.successCount, _that.failureCount,
            _that.successRate, _that.averageDuration);
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
    TResult? Function(DateTime date, int successCount, int failureCount,
            double successRate, Duration averageDuration)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DailyWakeBucket() when $default != null:
        return $default(_that.date, _that.successCount, _that.failureCount,
            _that.successRate, _that.averageDuration);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _DailyWakeBucket implements DailyWakeBucket {
  const _DailyWakeBucket(
      {required this.date,
      required this.successCount,
      required this.failureCount,
      required this.successRate,
      required this.averageDuration});

  @override
  final DateTime date;
  @override
  final int successCount;
  @override
  final int failureCount;
  @override
  final double successRate;
  @override
  final Duration averageDuration;

  /// Create a copy of DailyWakeBucket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DailyWakeBucketCopyWith<_DailyWakeBucket> get copyWith =>
      __$DailyWakeBucketCopyWithImpl<_DailyWakeBucket>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DailyWakeBucket &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.successCount, successCount) ||
                other.successCount == successCount) &&
            (identical(other.failureCount, failureCount) ||
                other.failureCount == failureCount) &&
            (identical(other.successRate, successRate) ||
                other.successRate == successRate) &&
            (identical(other.averageDuration, averageDuration) ||
                other.averageDuration == averageDuration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, date, successCount, failureCount,
      successRate, averageDuration);

  @override
  String toString() {
    return 'DailyWakeBucket(date: $date, successCount: $successCount, failureCount: $failureCount, successRate: $successRate, averageDuration: $averageDuration)';
  }
}

/// @nodoc
abstract mixin class _$DailyWakeBucketCopyWith<$Res>
    implements $DailyWakeBucketCopyWith<$Res> {
  factory _$DailyWakeBucketCopyWith(
          _DailyWakeBucket value, $Res Function(_DailyWakeBucket) _then) =
      __$DailyWakeBucketCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime date,
      int successCount,
      int failureCount,
      double successRate,
      Duration averageDuration});
}

/// @nodoc
class __$DailyWakeBucketCopyWithImpl<$Res>
    implements _$DailyWakeBucketCopyWith<$Res> {
  __$DailyWakeBucketCopyWithImpl(this._self, this._then);

  final _DailyWakeBucket _self;
  final $Res Function(_DailyWakeBucket) _then;

  /// Create a copy of DailyWakeBucket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? successCount = null,
    Object? failureCount = null,
    Object? successRate = null,
    Object? averageDuration = null,
  }) {
    return _then(_DailyWakeBucket(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      successCount: null == successCount
          ? _self.successCount
          : successCount // ignore: cast_nullable_to_non_nullable
              as int,
      failureCount: null == failureCount
          ? _self.failureCount
          : failureCount // ignore: cast_nullable_to_non_nullable
              as int,
      successRate: null == successRate
          ? _self.successRate
          : successRate // ignore: cast_nullable_to_non_nullable
              as double,
      averageDuration: null == averageDuration
          ? _self.averageDuration
          : averageDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc
mixin _$VersionPerformanceBucket {
  String get versionId;
  int get versionNumber;
  int get totalRuns;
  double get successRate;
  Duration get averageDuration;

  /// Create a copy of VersionPerformanceBucket
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VersionPerformanceBucketCopyWith<VersionPerformanceBucket> get copyWith =>
      _$VersionPerformanceBucketCopyWithImpl<VersionPerformanceBucket>(
          this as VersionPerformanceBucket, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VersionPerformanceBucket &&
            (identical(other.versionId, versionId) ||
                other.versionId == versionId) &&
            (identical(other.versionNumber, versionNumber) ||
                other.versionNumber == versionNumber) &&
            (identical(other.totalRuns, totalRuns) ||
                other.totalRuns == totalRuns) &&
            (identical(other.successRate, successRate) ||
                other.successRate == successRate) &&
            (identical(other.averageDuration, averageDuration) ||
                other.averageDuration == averageDuration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, versionId, versionNumber,
      totalRuns, successRate, averageDuration);

  @override
  String toString() {
    return 'VersionPerformanceBucket(versionId: $versionId, versionNumber: $versionNumber, totalRuns: $totalRuns, successRate: $successRate, averageDuration: $averageDuration)';
  }
}

/// @nodoc
abstract mixin class $VersionPerformanceBucketCopyWith<$Res> {
  factory $VersionPerformanceBucketCopyWith(VersionPerformanceBucket value,
          $Res Function(VersionPerformanceBucket) _then) =
      _$VersionPerformanceBucketCopyWithImpl;
  @useResult
  $Res call(
      {String versionId,
      int versionNumber,
      int totalRuns,
      double successRate,
      Duration averageDuration});
}

/// @nodoc
class _$VersionPerformanceBucketCopyWithImpl<$Res>
    implements $VersionPerformanceBucketCopyWith<$Res> {
  _$VersionPerformanceBucketCopyWithImpl(this._self, this._then);

  final VersionPerformanceBucket _self;
  final $Res Function(VersionPerformanceBucket) _then;

  /// Create a copy of VersionPerformanceBucket
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? versionId = null,
    Object? versionNumber = null,
    Object? totalRuns = null,
    Object? successRate = null,
    Object? averageDuration = null,
  }) {
    return _then(_self.copyWith(
      versionId: null == versionId
          ? _self.versionId
          : versionId // ignore: cast_nullable_to_non_nullable
              as String,
      versionNumber: null == versionNumber
          ? _self.versionNumber
          : versionNumber // ignore: cast_nullable_to_non_nullable
              as int,
      totalRuns: null == totalRuns
          ? _self.totalRuns
          : totalRuns // ignore: cast_nullable_to_non_nullable
              as int,
      successRate: null == successRate
          ? _self.successRate
          : successRate // ignore: cast_nullable_to_non_nullable
              as double,
      averageDuration: null == averageDuration
          ? _self.averageDuration
          : averageDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// Adds pattern-matching-related methods to [VersionPerformanceBucket].
extension VersionPerformanceBucketPatterns on VersionPerformanceBucket {
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
    TResult Function(_VersionPerformanceBucket value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VersionPerformanceBucket() when $default != null:
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
    TResult Function(_VersionPerformanceBucket value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VersionPerformanceBucket():
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
    TResult? Function(_VersionPerformanceBucket value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VersionPerformanceBucket() when $default != null:
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
    TResult Function(String versionId, int versionNumber, int totalRuns,
            double successRate, Duration averageDuration)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VersionPerformanceBucket() when $default != null:
        return $default(_that.versionId, _that.versionNumber, _that.totalRuns,
            _that.successRate, _that.averageDuration);
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
    TResult Function(String versionId, int versionNumber, int totalRuns,
            double successRate, Duration averageDuration)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VersionPerformanceBucket():
        return $default(_that.versionId, _that.versionNumber, _that.totalRuns,
            _that.successRate, _that.averageDuration);
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
    TResult? Function(String versionId, int versionNumber, int totalRuns,
            double successRate, Duration averageDuration)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VersionPerformanceBucket() when $default != null:
        return $default(_that.versionId, _that.versionNumber, _that.totalRuns,
            _that.successRate, _that.averageDuration);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _VersionPerformanceBucket implements VersionPerformanceBucket {
  const _VersionPerformanceBucket(
      {required this.versionId,
      required this.versionNumber,
      required this.totalRuns,
      required this.successRate,
      required this.averageDuration});

  @override
  final String versionId;
  @override
  final int versionNumber;
  @override
  final int totalRuns;
  @override
  final double successRate;
  @override
  final Duration averageDuration;

  /// Create a copy of VersionPerformanceBucket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VersionPerformanceBucketCopyWith<_VersionPerformanceBucket> get copyWith =>
      __$VersionPerformanceBucketCopyWithImpl<_VersionPerformanceBucket>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VersionPerformanceBucket &&
            (identical(other.versionId, versionId) ||
                other.versionId == versionId) &&
            (identical(other.versionNumber, versionNumber) ||
                other.versionNumber == versionNumber) &&
            (identical(other.totalRuns, totalRuns) ||
                other.totalRuns == totalRuns) &&
            (identical(other.successRate, successRate) ||
                other.successRate == successRate) &&
            (identical(other.averageDuration, averageDuration) ||
                other.averageDuration == averageDuration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, versionId, versionNumber,
      totalRuns, successRate, averageDuration);

  @override
  String toString() {
    return 'VersionPerformanceBucket(versionId: $versionId, versionNumber: $versionNumber, totalRuns: $totalRuns, successRate: $successRate, averageDuration: $averageDuration)';
  }
}

/// @nodoc
abstract mixin class _$VersionPerformanceBucketCopyWith<$Res>
    implements $VersionPerformanceBucketCopyWith<$Res> {
  factory _$VersionPerformanceBucketCopyWith(_VersionPerformanceBucket value,
          $Res Function(_VersionPerformanceBucket) _then) =
      __$VersionPerformanceBucketCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String versionId,
      int versionNumber,
      int totalRuns,
      double successRate,
      Duration averageDuration});
}

/// @nodoc
class __$VersionPerformanceBucketCopyWithImpl<$Res>
    implements _$VersionPerformanceBucketCopyWith<$Res> {
  __$VersionPerformanceBucketCopyWithImpl(this._self, this._then);

  final _VersionPerformanceBucket _self;
  final $Res Function(_VersionPerformanceBucket) _then;

  /// Create a copy of VersionPerformanceBucket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? versionId = null,
    Object? versionNumber = null,
    Object? totalRuns = null,
    Object? successRate = null,
    Object? averageDuration = null,
  }) {
    return _then(_VersionPerformanceBucket(
      versionId: null == versionId
          ? _self.versionId
          : versionId // ignore: cast_nullable_to_non_nullable
              as String,
      versionNumber: null == versionNumber
          ? _self.versionNumber
          : versionNumber // ignore: cast_nullable_to_non_nullable
              as int,
      totalRuns: null == totalRuns
          ? _self.totalRuns
          : totalRuns // ignore: cast_nullable_to_non_nullable
              as int,
      successRate: null == successRate
          ? _self.successRate
          : successRate // ignore: cast_nullable_to_non_nullable
              as double,
      averageDuration: null == averageDuration
          ? _self.averageDuration
          : averageDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

// dart format on
