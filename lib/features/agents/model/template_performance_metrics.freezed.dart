// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'template_performance_metrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TemplatePerformanceMetrics {
  String get templateId;
  int get totalWakes;
  int get successCount;
  int get failureCount;
  double get successRate;
  Duration? get averageDuration;
  DateTime? get firstWakeAt;
  DateTime? get lastWakeAt;
  int get activeInstanceCount;

  /// Create a copy of TemplatePerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TemplatePerformanceMetricsCopyWith<TemplatePerformanceMetrics>
      get copyWith =>
          _$TemplatePerformanceMetricsCopyWithImpl<TemplatePerformanceMetrics>(
              this as TemplatePerformanceMetrics, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TemplatePerformanceMetrics &&
            (identical(other.templateId, templateId) ||
                other.templateId == templateId) &&
            (identical(other.totalWakes, totalWakes) ||
                other.totalWakes == totalWakes) &&
            (identical(other.successCount, successCount) ||
                other.successCount == successCount) &&
            (identical(other.failureCount, failureCount) ||
                other.failureCount == failureCount) &&
            (identical(other.successRate, successRate) ||
                other.successRate == successRate) &&
            (identical(other.averageDuration, averageDuration) ||
                other.averageDuration == averageDuration) &&
            (identical(other.firstWakeAt, firstWakeAt) ||
                other.firstWakeAt == firstWakeAt) &&
            (identical(other.lastWakeAt, lastWakeAt) ||
                other.lastWakeAt == lastWakeAt) &&
            (identical(other.activeInstanceCount, activeInstanceCount) ||
                other.activeInstanceCount == activeInstanceCount));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      templateId,
      totalWakes,
      successCount,
      failureCount,
      successRate,
      averageDuration,
      firstWakeAt,
      lastWakeAt,
      activeInstanceCount);

  @override
  String toString() {
    return 'TemplatePerformanceMetrics(templateId: $templateId, totalWakes: $totalWakes, successCount: $successCount, failureCount: $failureCount, successRate: $successRate, averageDuration: $averageDuration, firstWakeAt: $firstWakeAt, lastWakeAt: $lastWakeAt, activeInstanceCount: $activeInstanceCount)';
  }
}

/// @nodoc
abstract mixin class $TemplatePerformanceMetricsCopyWith<$Res> {
  factory $TemplatePerformanceMetricsCopyWith(TemplatePerformanceMetrics value,
          $Res Function(TemplatePerformanceMetrics) _then) =
      _$TemplatePerformanceMetricsCopyWithImpl;
  @useResult
  $Res call(
      {String templateId,
      int totalWakes,
      int successCount,
      int failureCount,
      double successRate,
      Duration? averageDuration,
      DateTime? firstWakeAt,
      DateTime? lastWakeAt,
      int activeInstanceCount});
}

/// @nodoc
class _$TemplatePerformanceMetricsCopyWithImpl<$Res>
    implements $TemplatePerformanceMetricsCopyWith<$Res> {
  _$TemplatePerformanceMetricsCopyWithImpl(this._self, this._then);

  final TemplatePerformanceMetrics _self;
  final $Res Function(TemplatePerformanceMetrics) _then;

  /// Create a copy of TemplatePerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? templateId = null,
    Object? totalWakes = null,
    Object? successCount = null,
    Object? failureCount = null,
    Object? successRate = null,
    Object? averageDuration = freezed,
    Object? firstWakeAt = freezed,
    Object? lastWakeAt = freezed,
    Object? activeInstanceCount = null,
  }) {
    return _then(_self.copyWith(
      templateId: null == templateId
          ? _self.templateId
          : templateId // ignore: cast_nullable_to_non_nullable
              as String,
      totalWakes: null == totalWakes
          ? _self.totalWakes
          : totalWakes // ignore: cast_nullable_to_non_nullable
              as int,
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
      averageDuration: freezed == averageDuration
          ? _self.averageDuration
          : averageDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
      firstWakeAt: freezed == firstWakeAt
          ? _self.firstWakeAt
          : firstWakeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastWakeAt: freezed == lastWakeAt
          ? _self.lastWakeAt
          : lastWakeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      activeInstanceCount: null == activeInstanceCount
          ? _self.activeInstanceCount
          : activeInstanceCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [TemplatePerformanceMetrics].
extension TemplatePerformanceMetricsPatterns on TemplatePerformanceMetrics {
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
    TResult Function(_TemplatePerformanceMetrics value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TemplatePerformanceMetrics() when $default != null:
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
    TResult Function(_TemplatePerformanceMetrics value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplatePerformanceMetrics():
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
    TResult? Function(_TemplatePerformanceMetrics value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplatePerformanceMetrics() when $default != null:
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
            String templateId,
            int totalWakes,
            int successCount,
            int failureCount,
            double successRate,
            Duration? averageDuration,
            DateTime? firstWakeAt,
            DateTime? lastWakeAt,
            int activeInstanceCount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TemplatePerformanceMetrics() when $default != null:
        return $default(
            _that.templateId,
            _that.totalWakes,
            _that.successCount,
            _that.failureCount,
            _that.successRate,
            _that.averageDuration,
            _that.firstWakeAt,
            _that.lastWakeAt,
            _that.activeInstanceCount);
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
            String templateId,
            int totalWakes,
            int successCount,
            int failureCount,
            double successRate,
            Duration? averageDuration,
            DateTime? firstWakeAt,
            DateTime? lastWakeAt,
            int activeInstanceCount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplatePerformanceMetrics():
        return $default(
            _that.templateId,
            _that.totalWakes,
            _that.successCount,
            _that.failureCount,
            _that.successRate,
            _that.averageDuration,
            _that.firstWakeAt,
            _that.lastWakeAt,
            _that.activeInstanceCount);
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
            String templateId,
            int totalWakes,
            int successCount,
            int failureCount,
            double successRate,
            Duration? averageDuration,
            DateTime? firstWakeAt,
            DateTime? lastWakeAt,
            int activeInstanceCount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TemplatePerformanceMetrics() when $default != null:
        return $default(
            _that.templateId,
            _that.totalWakes,
            _that.successCount,
            _that.failureCount,
            _that.successRate,
            _that.averageDuration,
            _that.firstWakeAt,
            _that.lastWakeAt,
            _that.activeInstanceCount);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TemplatePerformanceMetrics implements TemplatePerformanceMetrics {
  const _TemplatePerformanceMetrics(
      {required this.templateId,
      required this.totalWakes,
      required this.successCount,
      required this.failureCount,
      required this.successRate,
      required this.averageDuration,
      required this.firstWakeAt,
      required this.lastWakeAt,
      required this.activeInstanceCount});

  @override
  final String templateId;
  @override
  final int totalWakes;
  @override
  final int successCount;
  @override
  final int failureCount;
  @override
  final double successRate;
  @override
  final Duration? averageDuration;
  @override
  final DateTime? firstWakeAt;
  @override
  final DateTime? lastWakeAt;
  @override
  final int activeInstanceCount;

  /// Create a copy of TemplatePerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TemplatePerformanceMetricsCopyWith<_TemplatePerformanceMetrics>
      get copyWith => __$TemplatePerformanceMetricsCopyWithImpl<
          _TemplatePerformanceMetrics>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TemplatePerformanceMetrics &&
            (identical(other.templateId, templateId) ||
                other.templateId == templateId) &&
            (identical(other.totalWakes, totalWakes) ||
                other.totalWakes == totalWakes) &&
            (identical(other.successCount, successCount) ||
                other.successCount == successCount) &&
            (identical(other.failureCount, failureCount) ||
                other.failureCount == failureCount) &&
            (identical(other.successRate, successRate) ||
                other.successRate == successRate) &&
            (identical(other.averageDuration, averageDuration) ||
                other.averageDuration == averageDuration) &&
            (identical(other.firstWakeAt, firstWakeAt) ||
                other.firstWakeAt == firstWakeAt) &&
            (identical(other.lastWakeAt, lastWakeAt) ||
                other.lastWakeAt == lastWakeAt) &&
            (identical(other.activeInstanceCount, activeInstanceCount) ||
                other.activeInstanceCount == activeInstanceCount));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      templateId,
      totalWakes,
      successCount,
      failureCount,
      successRate,
      averageDuration,
      firstWakeAt,
      lastWakeAt,
      activeInstanceCount);

  @override
  String toString() {
    return 'TemplatePerformanceMetrics(templateId: $templateId, totalWakes: $totalWakes, successCount: $successCount, failureCount: $failureCount, successRate: $successRate, averageDuration: $averageDuration, firstWakeAt: $firstWakeAt, lastWakeAt: $lastWakeAt, activeInstanceCount: $activeInstanceCount)';
  }
}

/// @nodoc
abstract mixin class _$TemplatePerformanceMetricsCopyWith<$Res>
    implements $TemplatePerformanceMetricsCopyWith<$Res> {
  factory _$TemplatePerformanceMetricsCopyWith(
          _TemplatePerformanceMetrics value,
          $Res Function(_TemplatePerformanceMetrics) _then) =
      __$TemplatePerformanceMetricsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String templateId,
      int totalWakes,
      int successCount,
      int failureCount,
      double successRate,
      Duration? averageDuration,
      DateTime? firstWakeAt,
      DateTime? lastWakeAt,
      int activeInstanceCount});
}

/// @nodoc
class __$TemplatePerformanceMetricsCopyWithImpl<$Res>
    implements _$TemplatePerformanceMetricsCopyWith<$Res> {
  __$TemplatePerformanceMetricsCopyWithImpl(this._self, this._then);

  final _TemplatePerformanceMetrics _self;
  final $Res Function(_TemplatePerformanceMetrics) _then;

  /// Create a copy of TemplatePerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? templateId = null,
    Object? totalWakes = null,
    Object? successCount = null,
    Object? failureCount = null,
    Object? successRate = null,
    Object? averageDuration = freezed,
    Object? firstWakeAt = freezed,
    Object? lastWakeAt = freezed,
    Object? activeInstanceCount = null,
  }) {
    return _then(_TemplatePerformanceMetrics(
      templateId: null == templateId
          ? _self.templateId
          : templateId // ignore: cast_nullable_to_non_nullable
              as String,
      totalWakes: null == totalWakes
          ? _self.totalWakes
          : totalWakes // ignore: cast_nullable_to_non_nullable
              as int,
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
      averageDuration: freezed == averageDuration
          ? _self.averageDuration
          : averageDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
      firstWakeAt: freezed == firstWakeAt
          ? _self.firstWakeAt
          : firstWakeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastWakeAt: freezed == lastWakeAt
          ? _self.lastWakeAt
          : lastWakeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      activeInstanceCount: null == activeInstanceCount
          ? _self.activeInstanceCount
          : activeInstanceCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
