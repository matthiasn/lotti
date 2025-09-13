// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_progress_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskProgressState {
  Duration get progress;
  Duration get estimate;

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskProgressStateCopyWith<TaskProgressState> get copyWith =>
      _$TaskProgressStateCopyWithImpl<TaskProgressState>(
          this as TaskProgressState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskProgressState &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.estimate, estimate) ||
                other.estimate == estimate));
  }

  @override
  int get hashCode => Object.hash(runtimeType, progress, estimate);

  @override
  String toString() {
    return 'TaskProgressState(progress: $progress, estimate: $estimate)';
  }
}

/// @nodoc
abstract mixin class $TaskProgressStateCopyWith<$Res> {
  factory $TaskProgressStateCopyWith(
          TaskProgressState value, $Res Function(TaskProgressState) _then) =
      _$TaskProgressStateCopyWithImpl;
  @useResult
  $Res call({Duration progress, Duration estimate});
}

/// @nodoc
class _$TaskProgressStateCopyWithImpl<$Res>
    implements $TaskProgressStateCopyWith<$Res> {
  _$TaskProgressStateCopyWithImpl(this._self, this._then);

  final TaskProgressState _self;
  final $Res Function(TaskProgressState) _then;

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
    Object? estimate = null,
  }) {
    return _then(_self.copyWith(
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      estimate: null == estimate
          ? _self.estimate
          : estimate // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// Adds pattern-matching-related methods to [TaskProgressState].
extension TaskProgressStatePatterns on TaskProgressState {
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
    TResult Function(_TaskProgressState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskProgressState() when $default != null:
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
    TResult Function(_TaskProgressState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskProgressState():
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
    TResult? Function(_TaskProgressState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskProgressState() when $default != null:
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
    TResult Function(Duration progress, Duration estimate)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskProgressState() when $default != null:
        return $default(_that.progress, _that.estimate);
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
    TResult Function(Duration progress, Duration estimate) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskProgressState():
        return $default(_that.progress, _that.estimate);
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
    TResult? Function(Duration progress, Duration estimate)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskProgressState() when $default != null:
        return $default(_that.progress, _that.estimate);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TaskProgressState implements TaskProgressState {
  const _TaskProgressState({required this.progress, required this.estimate});

  @override
  final Duration progress;
  @override
  final Duration estimate;

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TaskProgressStateCopyWith<_TaskProgressState> get copyWith =>
      __$TaskProgressStateCopyWithImpl<_TaskProgressState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TaskProgressState &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.estimate, estimate) ||
                other.estimate == estimate));
  }

  @override
  int get hashCode => Object.hash(runtimeType, progress, estimate);

  @override
  String toString() {
    return 'TaskProgressState(progress: $progress, estimate: $estimate)';
  }
}

/// @nodoc
abstract mixin class _$TaskProgressStateCopyWith<$Res>
    implements $TaskProgressStateCopyWith<$Res> {
  factory _$TaskProgressStateCopyWith(
          _TaskProgressState value, $Res Function(_TaskProgressState) _then) =
      __$TaskProgressStateCopyWithImpl;
  @override
  @useResult
  $Res call({Duration progress, Duration estimate});
}

/// @nodoc
class __$TaskProgressStateCopyWithImpl<$Res>
    implements _$TaskProgressStateCopyWith<$Res> {
  __$TaskProgressStateCopyWithImpl(this._self, this._then);

  final _TaskProgressState _self;
  final $Res Function(_TaskProgressState) _then;

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? progress = null,
    Object? estimate = null,
  }) {
    return _then(_TaskProgressState(
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      estimate: null == estimate
          ? _self.estimate
          : estimate // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

// dart format on
