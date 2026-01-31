// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'time_history_header_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DayTimeSummary {
  /// Date at local noon to avoid DST artifacts.
  DateTime get day;

  /// Category ID to duration. Null key represents uncategorized entries.
  Map<String?, Duration> get durationByCategoryId;

  /// Precomputed total duration for this day.
  Duration get total;

  /// Create a copy of DayTimeSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DayTimeSummaryCopyWith<DayTimeSummary> get copyWith =>
      _$DayTimeSummaryCopyWithImpl<DayTimeSummary>(
          this as DayTimeSummary, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DayTimeSummary &&
            (identical(other.day, day) || other.day == day) &&
            const DeepCollectionEquality()
                .equals(other.durationByCategoryId, durationByCategoryId) &&
            (identical(other.total, total) || other.total == total));
  }

  @override
  int get hashCode => Object.hash(runtimeType, day,
      const DeepCollectionEquality().hash(durationByCategoryId), total);

  @override
  String toString() {
    return 'DayTimeSummary(day: $day, durationByCategoryId: $durationByCategoryId, total: $total)';
  }
}

/// @nodoc
abstract mixin class $DayTimeSummaryCopyWith<$Res> {
  factory $DayTimeSummaryCopyWith(
          DayTimeSummary value, $Res Function(DayTimeSummary) _then) =
      _$DayTimeSummaryCopyWithImpl;
  @useResult
  $Res call(
      {DateTime day,
      Map<String?, Duration> durationByCategoryId,
      Duration total});
}

/// @nodoc
class _$DayTimeSummaryCopyWithImpl<$Res>
    implements $DayTimeSummaryCopyWith<$Res> {
  _$DayTimeSummaryCopyWithImpl(this._self, this._then);

  final DayTimeSummary _self;
  final $Res Function(DayTimeSummary) _then;

  /// Create a copy of DayTimeSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? day = null,
    Object? durationByCategoryId = null,
    Object? total = null,
  }) {
    return _then(_self.copyWith(
      day: null == day
          ? _self.day
          : day // ignore: cast_nullable_to_non_nullable
              as DateTime,
      durationByCategoryId: null == durationByCategoryId
          ? _self.durationByCategoryId
          : durationByCategoryId // ignore: cast_nullable_to_non_nullable
              as Map<String?, Duration>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// Adds pattern-matching-related methods to [DayTimeSummary].
extension DayTimeSummaryPatterns on DayTimeSummary {
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
    TResult Function(_DayTimeSummary value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DayTimeSummary() when $default != null:
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
    TResult Function(_DayTimeSummary value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DayTimeSummary():
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
    TResult? Function(_DayTimeSummary value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DayTimeSummary() when $default != null:
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
    TResult Function(DateTime day, Map<String?, Duration> durationByCategoryId,
            Duration total)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DayTimeSummary() when $default != null:
        return $default(_that.day, _that.durationByCategoryId, _that.total);
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
    TResult Function(DateTime day, Map<String?, Duration> durationByCategoryId,
            Duration total)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DayTimeSummary():
        return $default(_that.day, _that.durationByCategoryId, _that.total);
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
    TResult? Function(DateTime day, Map<String?, Duration> durationByCategoryId,
            Duration total)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DayTimeSummary() when $default != null:
        return $default(_that.day, _that.durationByCategoryId, _that.total);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _DayTimeSummary implements DayTimeSummary {
  const _DayTimeSummary(
      {required this.day,
      required final Map<String?, Duration> durationByCategoryId,
      required this.total})
      : _durationByCategoryId = durationByCategoryId;

  /// Date at local noon to avoid DST artifacts.
  @override
  final DateTime day;

  /// Category ID to duration. Null key represents uncategorized entries.
  final Map<String?, Duration> _durationByCategoryId;

  /// Category ID to duration. Null key represents uncategorized entries.
  @override
  Map<String?, Duration> get durationByCategoryId {
    if (_durationByCategoryId is EqualUnmodifiableMapView)
      return _durationByCategoryId;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_durationByCategoryId);
  }

  /// Precomputed total duration for this day.
  @override
  final Duration total;

  /// Create a copy of DayTimeSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DayTimeSummaryCopyWith<_DayTimeSummary> get copyWith =>
      __$DayTimeSummaryCopyWithImpl<_DayTimeSummary>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DayTimeSummary &&
            (identical(other.day, day) || other.day == day) &&
            const DeepCollectionEquality()
                .equals(other._durationByCategoryId, _durationByCategoryId) &&
            (identical(other.total, total) || other.total == total));
  }

  @override
  int get hashCode => Object.hash(runtimeType, day,
      const DeepCollectionEquality().hash(_durationByCategoryId), total);

  @override
  String toString() {
    return 'DayTimeSummary(day: $day, durationByCategoryId: $durationByCategoryId, total: $total)';
  }
}

/// @nodoc
abstract mixin class _$DayTimeSummaryCopyWith<$Res>
    implements $DayTimeSummaryCopyWith<$Res> {
  factory _$DayTimeSummaryCopyWith(
          _DayTimeSummary value, $Res Function(_DayTimeSummary) _then) =
      __$DayTimeSummaryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime day,
      Map<String?, Duration> durationByCategoryId,
      Duration total});
}

/// @nodoc
class __$DayTimeSummaryCopyWithImpl<$Res>
    implements _$DayTimeSummaryCopyWith<$Res> {
  __$DayTimeSummaryCopyWithImpl(this._self, this._then);

  final _DayTimeSummary _self;
  final $Res Function(_DayTimeSummary) _then;

  /// Create a copy of DayTimeSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? day = null,
    Object? durationByCategoryId = null,
    Object? total = null,
  }) {
    return _then(_DayTimeSummary(
      day: null == day
          ? _self.day
          : day // ignore: cast_nullable_to_non_nullable
              as DateTime,
      durationByCategoryId: null == durationByCategoryId
          ? _self._durationByCategoryId
          : durationByCategoryId // ignore: cast_nullable_to_non_nullable
              as Map<String?, Duration>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc
mixin _$TimeHistoryData {
  /// Days ordered newest to oldest.
  List<DayTimeSummary> get days;

  /// Earliest day in the loaded range.
  DateTime get earliestDay;

  /// Latest day in the loaded range.
  DateTime get latestDay;

  /// Maximum daily total across loaded range, for Y-axis normalization.
  Duration get maxDailyTotal;

  /// Consistent category order for stacking.
  List<String> get categoryOrder;

  /// Whether more days are currently being loaded.
  bool get isLoadingMore;

  /// Whether there are more days available to load.
  bool get canLoadMore;

  /// Precomputed stacked heights per day per category.
  /// Maps day (at noon) -> categoryId -> cumulative height from lower cats.
  StackedHeights get stackedHeights;

  /// Create a copy of TimeHistoryData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TimeHistoryDataCopyWith<TimeHistoryData> get copyWith =>
      _$TimeHistoryDataCopyWithImpl<TimeHistoryData>(
          this as TimeHistoryData, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TimeHistoryData &&
            const DeepCollectionEquality().equals(other.days, days) &&
            (identical(other.earliestDay, earliestDay) ||
                other.earliestDay == earliestDay) &&
            (identical(other.latestDay, latestDay) ||
                other.latestDay == latestDay) &&
            (identical(other.maxDailyTotal, maxDailyTotal) ||
                other.maxDailyTotal == maxDailyTotal) &&
            const DeepCollectionEquality()
                .equals(other.categoryOrder, categoryOrder) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore) &&
            (identical(other.canLoadMore, canLoadMore) ||
                other.canLoadMore == canLoadMore) &&
            const DeepCollectionEquality()
                .equals(other.stackedHeights, stackedHeights));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(days),
      earliestDay,
      latestDay,
      maxDailyTotal,
      const DeepCollectionEquality().hash(categoryOrder),
      isLoadingMore,
      canLoadMore,
      const DeepCollectionEquality().hash(stackedHeights));

  @override
  String toString() {
    return 'TimeHistoryData(days: $days, earliestDay: $earliestDay, latestDay: $latestDay, maxDailyTotal: $maxDailyTotal, categoryOrder: $categoryOrder, isLoadingMore: $isLoadingMore, canLoadMore: $canLoadMore, stackedHeights: $stackedHeights)';
  }
}

/// @nodoc
abstract mixin class $TimeHistoryDataCopyWith<$Res> {
  factory $TimeHistoryDataCopyWith(
          TimeHistoryData value, $Res Function(TimeHistoryData) _then) =
      _$TimeHistoryDataCopyWithImpl;
  @useResult
  $Res call(
      {List<DayTimeSummary> days,
      DateTime earliestDay,
      DateTime latestDay,
      Duration maxDailyTotal,
      List<String> categoryOrder,
      bool isLoadingMore,
      bool canLoadMore,
      StackedHeights stackedHeights});
}

/// @nodoc
class _$TimeHistoryDataCopyWithImpl<$Res>
    implements $TimeHistoryDataCopyWith<$Res> {
  _$TimeHistoryDataCopyWithImpl(this._self, this._then);

  final TimeHistoryData _self;
  final $Res Function(TimeHistoryData) _then;

  /// Create a copy of TimeHistoryData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? days = null,
    Object? earliestDay = null,
    Object? latestDay = null,
    Object? maxDailyTotal = null,
    Object? categoryOrder = null,
    Object? isLoadingMore = null,
    Object? canLoadMore = null,
    Object? stackedHeights = null,
  }) {
    return _then(_self.copyWith(
      days: null == days
          ? _self.days
          : days // ignore: cast_nullable_to_non_nullable
              as List<DayTimeSummary>,
      earliestDay: null == earliestDay
          ? _self.earliestDay
          : earliestDay // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latestDay: null == latestDay
          ? _self.latestDay
          : latestDay // ignore: cast_nullable_to_non_nullable
              as DateTime,
      maxDailyTotal: null == maxDailyTotal
          ? _self.maxDailyTotal
          : maxDailyTotal // ignore: cast_nullable_to_non_nullable
              as Duration,
      categoryOrder: null == categoryOrder
          ? _self.categoryOrder
          : categoryOrder // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isLoadingMore: null == isLoadingMore
          ? _self.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      canLoadMore: null == canLoadMore
          ? _self.canLoadMore
          : canLoadMore // ignore: cast_nullable_to_non_nullable
              as bool,
      stackedHeights: null == stackedHeights
          ? _self.stackedHeights
          : stackedHeights // ignore: cast_nullable_to_non_nullable
              as StackedHeights,
    ));
  }
}

/// Adds pattern-matching-related methods to [TimeHistoryData].
extension TimeHistoryDataPatterns on TimeHistoryData {
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
    TResult Function(_TimeHistoryData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TimeHistoryData() when $default != null:
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
    TResult Function(_TimeHistoryData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeHistoryData():
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
    TResult? Function(_TimeHistoryData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeHistoryData() when $default != null:
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
            List<DayTimeSummary> days,
            DateTime earliestDay,
            DateTime latestDay,
            Duration maxDailyTotal,
            List<String> categoryOrder,
            bool isLoadingMore,
            bool canLoadMore,
            StackedHeights stackedHeights)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TimeHistoryData() when $default != null:
        return $default(
            _that.days,
            _that.earliestDay,
            _that.latestDay,
            _that.maxDailyTotal,
            _that.categoryOrder,
            _that.isLoadingMore,
            _that.canLoadMore,
            _that.stackedHeights);
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
            List<DayTimeSummary> days,
            DateTime earliestDay,
            DateTime latestDay,
            Duration maxDailyTotal,
            List<String> categoryOrder,
            bool isLoadingMore,
            bool canLoadMore,
            StackedHeights stackedHeights)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeHistoryData():
        return $default(
            _that.days,
            _that.earliestDay,
            _that.latestDay,
            _that.maxDailyTotal,
            _that.categoryOrder,
            _that.isLoadingMore,
            _that.canLoadMore,
            _that.stackedHeights);
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
            List<DayTimeSummary> days,
            DateTime earliestDay,
            DateTime latestDay,
            Duration maxDailyTotal,
            List<String> categoryOrder,
            bool isLoadingMore,
            bool canLoadMore,
            StackedHeights stackedHeights)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeHistoryData() when $default != null:
        return $default(
            _that.days,
            _that.earliestDay,
            _that.latestDay,
            _that.maxDailyTotal,
            _that.categoryOrder,
            _that.isLoadingMore,
            _that.canLoadMore,
            _that.stackedHeights);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TimeHistoryData implements TimeHistoryData {
  const _TimeHistoryData(
      {required final List<DayTimeSummary> days,
      required this.earliestDay,
      required this.latestDay,
      required this.maxDailyTotal,
      required final List<String> categoryOrder,
      required this.isLoadingMore,
      required this.canLoadMore,
      required final StackedHeights stackedHeights})
      : _days = days,
        _categoryOrder = categoryOrder,
        _stackedHeights = stackedHeights;

  /// Days ordered newest to oldest.
  final List<DayTimeSummary> _days;

  /// Days ordered newest to oldest.
  @override
  List<DayTimeSummary> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  /// Earliest day in the loaded range.
  @override
  final DateTime earliestDay;

  /// Latest day in the loaded range.
  @override
  final DateTime latestDay;

  /// Maximum daily total across loaded range, for Y-axis normalization.
  @override
  final Duration maxDailyTotal;

  /// Consistent category order for stacking.
  final List<String> _categoryOrder;

  /// Consistent category order for stacking.
  @override
  List<String> get categoryOrder {
    if (_categoryOrder is EqualUnmodifiableListView) return _categoryOrder;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categoryOrder);
  }

  /// Whether more days are currently being loaded.
  @override
  final bool isLoadingMore;

  /// Whether there are more days available to load.
  @override
  final bool canLoadMore;

  /// Precomputed stacked heights per day per category.
  /// Maps day (at noon) -> categoryId -> cumulative height from lower cats.
  final StackedHeights _stackedHeights;

  /// Precomputed stacked heights per day per category.
  /// Maps day (at noon) -> categoryId -> cumulative height from lower cats.
  @override
  StackedHeights get stackedHeights {
    if (_stackedHeights is EqualUnmodifiableMapView) return _stackedHeights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_stackedHeights);
  }

  /// Create a copy of TimeHistoryData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TimeHistoryDataCopyWith<_TimeHistoryData> get copyWith =>
      __$TimeHistoryDataCopyWithImpl<_TimeHistoryData>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TimeHistoryData &&
            const DeepCollectionEquality().equals(other._days, _days) &&
            (identical(other.earliestDay, earliestDay) ||
                other.earliestDay == earliestDay) &&
            (identical(other.latestDay, latestDay) ||
                other.latestDay == latestDay) &&
            (identical(other.maxDailyTotal, maxDailyTotal) ||
                other.maxDailyTotal == maxDailyTotal) &&
            const DeepCollectionEquality()
                .equals(other._categoryOrder, _categoryOrder) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore) &&
            (identical(other.canLoadMore, canLoadMore) ||
                other.canLoadMore == canLoadMore) &&
            const DeepCollectionEquality()
                .equals(other._stackedHeights, _stackedHeights));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_days),
      earliestDay,
      latestDay,
      maxDailyTotal,
      const DeepCollectionEquality().hash(_categoryOrder),
      isLoadingMore,
      canLoadMore,
      const DeepCollectionEquality().hash(_stackedHeights));

  @override
  String toString() {
    return 'TimeHistoryData(days: $days, earliestDay: $earliestDay, latestDay: $latestDay, maxDailyTotal: $maxDailyTotal, categoryOrder: $categoryOrder, isLoadingMore: $isLoadingMore, canLoadMore: $canLoadMore, stackedHeights: $stackedHeights)';
  }
}

/// @nodoc
abstract mixin class _$TimeHistoryDataCopyWith<$Res>
    implements $TimeHistoryDataCopyWith<$Res> {
  factory _$TimeHistoryDataCopyWith(
          _TimeHistoryData value, $Res Function(_TimeHistoryData) _then) =
      __$TimeHistoryDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<DayTimeSummary> days,
      DateTime earliestDay,
      DateTime latestDay,
      Duration maxDailyTotal,
      List<String> categoryOrder,
      bool isLoadingMore,
      bool canLoadMore,
      StackedHeights stackedHeights});
}

/// @nodoc
class __$TimeHistoryDataCopyWithImpl<$Res>
    implements _$TimeHistoryDataCopyWith<$Res> {
  __$TimeHistoryDataCopyWithImpl(this._self, this._then);

  final _TimeHistoryData _self;
  final $Res Function(_TimeHistoryData) _then;

  /// Create a copy of TimeHistoryData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? days = null,
    Object? earliestDay = null,
    Object? latestDay = null,
    Object? maxDailyTotal = null,
    Object? categoryOrder = null,
    Object? isLoadingMore = null,
    Object? canLoadMore = null,
    Object? stackedHeights = null,
  }) {
    return _then(_TimeHistoryData(
      days: null == days
          ? _self._days
          : days // ignore: cast_nullable_to_non_nullable
              as List<DayTimeSummary>,
      earliestDay: null == earliestDay
          ? _self.earliestDay
          : earliestDay // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latestDay: null == latestDay
          ? _self.latestDay
          : latestDay // ignore: cast_nullable_to_non_nullable
              as DateTime,
      maxDailyTotal: null == maxDailyTotal
          ? _self.maxDailyTotal
          : maxDailyTotal // ignore: cast_nullable_to_non_nullable
              as Duration,
      categoryOrder: null == categoryOrder
          ? _self._categoryOrder
          : categoryOrder // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isLoadingMore: null == isLoadingMore
          ? _self.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      canLoadMore: null == canLoadMore
          ? _self.canLoadMore
          : canLoadMore // ignore: cast_nullable_to_non_nullable
              as bool,
      stackedHeights: null == stackedHeights
          ? _self._stackedHeights
          : stackedHeights // ignore: cast_nullable_to_non_nullable
              as StackedHeights,
    ));
  }
}

// dart format on
