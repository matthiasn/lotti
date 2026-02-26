// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_resolution_time_series.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskResolutionTimeSeries {
  List<DailyResolutionBucket> get dailyBuckets;

  /// Create a copy of TaskResolutionTimeSeries
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskResolutionTimeSeriesCopyWith<TaskResolutionTimeSeries> get copyWith =>
      _$TaskResolutionTimeSeriesCopyWithImpl<TaskResolutionTimeSeries>(
          this as TaskResolutionTimeSeries, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskResolutionTimeSeries &&
            const DeepCollectionEquality()
                .equals(other.dailyBuckets, dailyBuckets));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(dailyBuckets));

  @override
  String toString() {
    return 'TaskResolutionTimeSeries(dailyBuckets: $dailyBuckets)';
  }
}

/// @nodoc
abstract mixin class $TaskResolutionTimeSeriesCopyWith<$Res> {
  factory $TaskResolutionTimeSeriesCopyWith(TaskResolutionTimeSeries value,
          $Res Function(TaskResolutionTimeSeries) _then) =
      _$TaskResolutionTimeSeriesCopyWithImpl;
  @useResult
  $Res call({List<DailyResolutionBucket> dailyBuckets});
}

/// @nodoc
class _$TaskResolutionTimeSeriesCopyWithImpl<$Res>
    implements $TaskResolutionTimeSeriesCopyWith<$Res> {
  _$TaskResolutionTimeSeriesCopyWithImpl(this._self, this._then);

  final TaskResolutionTimeSeries _self;
  final $Res Function(TaskResolutionTimeSeries) _then;

  /// Create a copy of TaskResolutionTimeSeries
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dailyBuckets = null,
  }) {
    return _then(_self.copyWith(
      dailyBuckets: null == dailyBuckets
          ? _self.dailyBuckets
          : dailyBuckets // ignore: cast_nullable_to_non_nullable
              as List<DailyResolutionBucket>,
    ));
  }
}

/// Adds pattern-matching-related methods to [TaskResolutionTimeSeries].
extension TaskResolutionTimeSeriesPatterns on TaskResolutionTimeSeries {
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
    TResult Function(_TaskResolutionTimeSeries value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionTimeSeries() when $default != null:
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
    TResult Function(_TaskResolutionTimeSeries value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionTimeSeries():
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
    TResult? Function(_TaskResolutionTimeSeries value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionTimeSeries() when $default != null:
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
    TResult Function(List<DailyResolutionBucket> dailyBuckets)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionTimeSeries() when $default != null:
        return $default(_that.dailyBuckets);
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
    TResult Function(List<DailyResolutionBucket> dailyBuckets) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionTimeSeries():
        return $default(_that.dailyBuckets);
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
    TResult? Function(List<DailyResolutionBucket> dailyBuckets)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionTimeSeries() when $default != null:
        return $default(_that.dailyBuckets);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TaskResolutionTimeSeries implements TaskResolutionTimeSeries {
  const _TaskResolutionTimeSeries(
      {required final List<DailyResolutionBucket> dailyBuckets})
      : _dailyBuckets = dailyBuckets;

  final List<DailyResolutionBucket> _dailyBuckets;
  @override
  List<DailyResolutionBucket> get dailyBuckets {
    if (_dailyBuckets is EqualUnmodifiableListView) return _dailyBuckets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dailyBuckets);
  }

  /// Create a copy of TaskResolutionTimeSeries
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TaskResolutionTimeSeriesCopyWith<_TaskResolutionTimeSeries> get copyWith =>
      __$TaskResolutionTimeSeriesCopyWithImpl<_TaskResolutionTimeSeries>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TaskResolutionTimeSeries &&
            const DeepCollectionEquality()
                .equals(other._dailyBuckets, _dailyBuckets));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_dailyBuckets));

  @override
  String toString() {
    return 'TaskResolutionTimeSeries(dailyBuckets: $dailyBuckets)';
  }
}

/// @nodoc
abstract mixin class _$TaskResolutionTimeSeriesCopyWith<$Res>
    implements $TaskResolutionTimeSeriesCopyWith<$Res> {
  factory _$TaskResolutionTimeSeriesCopyWith(_TaskResolutionTimeSeries value,
          $Res Function(_TaskResolutionTimeSeries) _then) =
      __$TaskResolutionTimeSeriesCopyWithImpl;
  @override
  @useResult
  $Res call({List<DailyResolutionBucket> dailyBuckets});
}

/// @nodoc
class __$TaskResolutionTimeSeriesCopyWithImpl<$Res>
    implements _$TaskResolutionTimeSeriesCopyWith<$Res> {
  __$TaskResolutionTimeSeriesCopyWithImpl(this._self, this._then);

  final _TaskResolutionTimeSeries _self;
  final $Res Function(_TaskResolutionTimeSeries) _then;

  /// Create a copy of TaskResolutionTimeSeries
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dailyBuckets = null,
  }) {
    return _then(_TaskResolutionTimeSeries(
      dailyBuckets: null == dailyBuckets
          ? _self._dailyBuckets
          : dailyBuckets // ignore: cast_nullable_to_non_nullable
              as List<DailyResolutionBucket>,
    ));
  }
}

/// @nodoc
mixin _$DailyResolutionBucket {
  DateTime get date;
  int get resolvedCount;
  Duration get averageMttr;

  /// Create a copy of DailyResolutionBucket
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DailyResolutionBucketCopyWith<DailyResolutionBucket> get copyWith =>
      _$DailyResolutionBucketCopyWithImpl<DailyResolutionBucket>(
          this as DailyResolutionBucket, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DailyResolutionBucket &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.resolvedCount, resolvedCount) ||
                other.resolvedCount == resolvedCount) &&
            (identical(other.averageMttr, averageMttr) ||
                other.averageMttr == averageMttr));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, date, resolvedCount, averageMttr);

  @override
  String toString() {
    return 'DailyResolutionBucket(date: $date, resolvedCount: $resolvedCount, averageMttr: $averageMttr)';
  }
}

/// @nodoc
abstract mixin class $DailyResolutionBucketCopyWith<$Res> {
  factory $DailyResolutionBucketCopyWith(DailyResolutionBucket value,
          $Res Function(DailyResolutionBucket) _then) =
      _$DailyResolutionBucketCopyWithImpl;
  @useResult
  $Res call({DateTime date, int resolvedCount, Duration averageMttr});
}

/// @nodoc
class _$DailyResolutionBucketCopyWithImpl<$Res>
    implements $DailyResolutionBucketCopyWith<$Res> {
  _$DailyResolutionBucketCopyWithImpl(this._self, this._then);

  final DailyResolutionBucket _self;
  final $Res Function(DailyResolutionBucket) _then;

  /// Create a copy of DailyResolutionBucket
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? resolvedCount = null,
    Object? averageMttr = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedCount: null == resolvedCount
          ? _self.resolvedCount
          : resolvedCount // ignore: cast_nullable_to_non_nullable
              as int,
      averageMttr: null == averageMttr
          ? _self.averageMttr
          : averageMttr // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// Adds pattern-matching-related methods to [DailyResolutionBucket].
extension DailyResolutionBucketPatterns on DailyResolutionBucket {
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
    TResult Function(_DailyResolutionBucket value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DailyResolutionBucket() when $default != null:
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
    TResult Function(_DailyResolutionBucket value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DailyResolutionBucket():
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
    TResult? Function(_DailyResolutionBucket value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DailyResolutionBucket() when $default != null:
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
    TResult Function(DateTime date, int resolvedCount, Duration averageMttr)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DailyResolutionBucket() when $default != null:
        return $default(_that.date, _that.resolvedCount, _that.averageMttr);
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
    TResult Function(DateTime date, int resolvedCount, Duration averageMttr)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DailyResolutionBucket():
        return $default(_that.date, _that.resolvedCount, _that.averageMttr);
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
    TResult? Function(DateTime date, int resolvedCount, Duration averageMttr)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DailyResolutionBucket() when $default != null:
        return $default(_that.date, _that.resolvedCount, _that.averageMttr);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _DailyResolutionBucket implements DailyResolutionBucket {
  const _DailyResolutionBucket(
      {required this.date,
      required this.resolvedCount,
      required this.averageMttr});

  @override
  final DateTime date;
  @override
  final int resolvedCount;
  @override
  final Duration averageMttr;

  /// Create a copy of DailyResolutionBucket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DailyResolutionBucketCopyWith<_DailyResolutionBucket> get copyWith =>
      __$DailyResolutionBucketCopyWithImpl<_DailyResolutionBucket>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DailyResolutionBucket &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.resolvedCount, resolvedCount) ||
                other.resolvedCount == resolvedCount) &&
            (identical(other.averageMttr, averageMttr) ||
                other.averageMttr == averageMttr));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, date, resolvedCount, averageMttr);

  @override
  String toString() {
    return 'DailyResolutionBucket(date: $date, resolvedCount: $resolvedCount, averageMttr: $averageMttr)';
  }
}

/// @nodoc
abstract mixin class _$DailyResolutionBucketCopyWith<$Res>
    implements $DailyResolutionBucketCopyWith<$Res> {
  factory _$DailyResolutionBucketCopyWith(_DailyResolutionBucket value,
          $Res Function(_DailyResolutionBucket) _then) =
      __$DailyResolutionBucketCopyWithImpl;
  @override
  @useResult
  $Res call({DateTime date, int resolvedCount, Duration averageMttr});
}

/// @nodoc
class __$DailyResolutionBucketCopyWithImpl<$Res>
    implements _$DailyResolutionBucketCopyWith<$Res> {
  __$DailyResolutionBucketCopyWithImpl(this._self, this._then);

  final _DailyResolutionBucket _self;
  final $Res Function(_DailyResolutionBucket) _then;

  /// Create a copy of DailyResolutionBucket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? resolvedCount = null,
    Object? averageMttr = null,
  }) {
    return _then(_DailyResolutionBucket(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedCount: null == resolvedCount
          ? _self.resolvedCount
          : resolvedCount // ignore: cast_nullable_to_non_nullable
              as int,
      averageMttr: null == averageMttr
          ? _self.averageMttr
          : averageMttr // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc
mixin _$TaskResolutionEntry {
  String get agentId;
  String get taskId;
  DateTime get agentCreatedAt;

  /// First DONE/REJECTED timestamp, null if unresolved.
  DateTime? get resolvedAt;

  /// 'done' or 'rejected', null if unresolved.
  String? get resolution;

  /// Create a copy of TaskResolutionEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskResolutionEntryCopyWith<TaskResolutionEntry> get copyWith =>
      _$TaskResolutionEntryCopyWithImpl<TaskResolutionEntry>(
          this as TaskResolutionEntry, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskResolutionEntry &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.agentCreatedAt, agentCreatedAt) ||
                other.agentCreatedAt == agentCreatedAt) &&
            (identical(other.resolvedAt, resolvedAt) ||
                other.resolvedAt == resolvedAt) &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, agentId, taskId, agentCreatedAt, resolvedAt, resolution);

  @override
  String toString() {
    return 'TaskResolutionEntry(agentId: $agentId, taskId: $taskId, agentCreatedAt: $agentCreatedAt, resolvedAt: $resolvedAt, resolution: $resolution)';
  }
}

/// @nodoc
abstract mixin class $TaskResolutionEntryCopyWith<$Res> {
  factory $TaskResolutionEntryCopyWith(
          TaskResolutionEntry value, $Res Function(TaskResolutionEntry) _then) =
      _$TaskResolutionEntryCopyWithImpl;
  @useResult
  $Res call(
      {String agentId,
      String taskId,
      DateTime agentCreatedAt,
      DateTime? resolvedAt,
      String? resolution});
}

/// @nodoc
class _$TaskResolutionEntryCopyWithImpl<$Res>
    implements $TaskResolutionEntryCopyWith<$Res> {
  _$TaskResolutionEntryCopyWithImpl(this._self, this._then);

  final TaskResolutionEntry _self;
  final $Res Function(TaskResolutionEntry) _then;

  /// Create a copy of TaskResolutionEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? agentId = null,
    Object? taskId = null,
    Object? agentCreatedAt = null,
    Object? resolvedAt = freezed,
    Object? resolution = freezed,
  }) {
    return _then(_self.copyWith(
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: null == taskId
          ? _self.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      agentCreatedAt: null == agentCreatedAt
          ? _self.agentCreatedAt
          : agentCreatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedAt: freezed == resolvedAt
          ? _self.resolvedAt
          : resolvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      resolution: freezed == resolution
          ? _self.resolution
          : resolution // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [TaskResolutionEntry].
extension TaskResolutionEntryPatterns on TaskResolutionEntry {
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
    TResult Function(_TaskResolutionEntry value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionEntry() when $default != null:
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
    TResult Function(_TaskResolutionEntry value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionEntry():
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
    TResult? Function(_TaskResolutionEntry value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionEntry() when $default != null:
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
    TResult Function(String agentId, String taskId, DateTime agentCreatedAt,
            DateTime? resolvedAt, String? resolution)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionEntry() when $default != null:
        return $default(_that.agentId, _that.taskId, _that.agentCreatedAt,
            _that.resolvedAt, _that.resolution);
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
    TResult Function(String agentId, String taskId, DateTime agentCreatedAt,
            DateTime? resolvedAt, String? resolution)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionEntry():
        return $default(_that.agentId, _that.taskId, _that.agentCreatedAt,
            _that.resolvedAt, _that.resolution);
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
    TResult? Function(String agentId, String taskId, DateTime agentCreatedAt,
            DateTime? resolvedAt, String? resolution)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskResolutionEntry() when $default != null:
        return $default(_that.agentId, _that.taskId, _that.agentCreatedAt,
            _that.resolvedAt, _that.resolution);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TaskResolutionEntry implements TaskResolutionEntry {
  const _TaskResolutionEntry(
      {required this.agentId,
      required this.taskId,
      required this.agentCreatedAt,
      this.resolvedAt,
      this.resolution});

  @override
  final String agentId;
  @override
  final String taskId;
  @override
  final DateTime agentCreatedAt;

  /// First DONE/REJECTED timestamp, null if unresolved.
  @override
  final DateTime? resolvedAt;

  /// 'done' or 'rejected', null if unresolved.
  @override
  final String? resolution;

  /// Create a copy of TaskResolutionEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TaskResolutionEntryCopyWith<_TaskResolutionEntry> get copyWith =>
      __$TaskResolutionEntryCopyWithImpl<_TaskResolutionEntry>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TaskResolutionEntry &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.agentCreatedAt, agentCreatedAt) ||
                other.agentCreatedAt == agentCreatedAt) &&
            (identical(other.resolvedAt, resolvedAt) ||
                other.resolvedAt == resolvedAt) &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, agentId, taskId, agentCreatedAt, resolvedAt, resolution);

  @override
  String toString() {
    return 'TaskResolutionEntry(agentId: $agentId, taskId: $taskId, agentCreatedAt: $agentCreatedAt, resolvedAt: $resolvedAt, resolution: $resolution)';
  }
}

/// @nodoc
abstract mixin class _$TaskResolutionEntryCopyWith<$Res>
    implements $TaskResolutionEntryCopyWith<$Res> {
  factory _$TaskResolutionEntryCopyWith(_TaskResolutionEntry value,
          $Res Function(_TaskResolutionEntry) _then) =
      __$TaskResolutionEntryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String agentId,
      String taskId,
      DateTime agentCreatedAt,
      DateTime? resolvedAt,
      String? resolution});
}

/// @nodoc
class __$TaskResolutionEntryCopyWithImpl<$Res>
    implements _$TaskResolutionEntryCopyWith<$Res> {
  __$TaskResolutionEntryCopyWithImpl(this._self, this._then);

  final _TaskResolutionEntry _self;
  final $Res Function(_TaskResolutionEntry) _then;

  /// Create a copy of TaskResolutionEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? agentId = null,
    Object? taskId = null,
    Object? agentCreatedAt = null,
    Object? resolvedAt = freezed,
    Object? resolution = freezed,
  }) {
    return _then(_TaskResolutionEntry(
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: null == taskId
          ? _self.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      agentCreatedAt: null == agentCreatedAt
          ? _self.agentCreatedAt
          : agentCreatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedAt: freezed == resolvedAt
          ? _self.resolvedAt
          : resolvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      resolution: freezed == resolution
          ? _self.resolution
          : resolution // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
