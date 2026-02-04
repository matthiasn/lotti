// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'day_plan_voice_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DayPlanLlmState {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is DayPlanLlmState);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DayPlanLlmState()';
  }
}

/// @nodoc
class $DayPlanLlmStateCopyWith<$Res> {
  $DayPlanLlmStateCopyWith(
      DayPlanLlmState _, $Res Function(DayPlanLlmState) __);
}

/// Adds pattern-matching-related methods to [DayPlanLlmState].
extension DayPlanLlmStatePatterns on DayPlanLlmState {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DayPlanLlmStateIdle value)? idle,
    TResult Function(DayPlanLlmStateProcessing value)? processing,
    TResult Function(DayPlanLlmStateCompleted value)? completed,
    TResult Function(DayPlanLlmStateError value)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanLlmStateIdle() when idle != null:
        return idle(_that);
      case DayPlanLlmStateProcessing() when processing != null:
        return processing(_that);
      case DayPlanLlmStateCompleted() when completed != null:
        return completed(_that);
      case DayPlanLlmStateError() when error != null:
        return error(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(DayPlanLlmStateIdle value) idle,
    required TResult Function(DayPlanLlmStateProcessing value) processing,
    required TResult Function(DayPlanLlmStateCompleted value) completed,
    required TResult Function(DayPlanLlmStateError value) error,
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanLlmStateIdle():
        return idle(_that);
      case DayPlanLlmStateProcessing():
        return processing(_that);
      case DayPlanLlmStateCompleted():
        return completed(_that);
      case DayPlanLlmStateError():
        return error(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DayPlanLlmStateIdle value)? idle,
    TResult? Function(DayPlanLlmStateProcessing value)? processing,
    TResult? Function(DayPlanLlmStateCompleted value)? completed,
    TResult? Function(DayPlanLlmStateError value)? error,
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanLlmStateIdle() when idle != null:
        return idle(_that);
      case DayPlanLlmStateProcessing() when processing != null:
        return processing(_that);
      case DayPlanLlmStateCompleted() when completed != null:
        return completed(_that);
      case DayPlanLlmStateError() when error != null:
        return error(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? processing,
    TResult Function(List<DayPlanActionResult> actions)? completed,
    TResult Function(DayPlanVoiceErrorType errorType)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanLlmStateIdle() when idle != null:
        return idle();
      case DayPlanLlmStateProcessing() when processing != null:
        return processing();
      case DayPlanLlmStateCompleted() when completed != null:
        return completed(_that.actions);
      case DayPlanLlmStateError() when error != null:
        return error(_that.errorType);
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
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() processing,
    required TResult Function(List<DayPlanActionResult> actions) completed,
    required TResult Function(DayPlanVoiceErrorType errorType) error,
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanLlmStateIdle():
        return idle();
      case DayPlanLlmStateProcessing():
        return processing();
      case DayPlanLlmStateCompleted():
        return completed(_that.actions);
      case DayPlanLlmStateError():
        return error(_that.errorType);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? processing,
    TResult? Function(List<DayPlanActionResult> actions)? completed,
    TResult? Function(DayPlanVoiceErrorType errorType)? error,
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanLlmStateIdle() when idle != null:
        return idle();
      case DayPlanLlmStateProcessing() when processing != null:
        return processing();
      case DayPlanLlmStateCompleted() when completed != null:
        return completed(_that.actions);
      case DayPlanLlmStateError() when error != null:
        return error(_that.errorType);
      case _:
        return null;
    }
  }
}

/// @nodoc

class DayPlanLlmStateIdle implements DayPlanLlmState {
  const DayPlanLlmStateIdle();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is DayPlanLlmStateIdle);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DayPlanLlmState.idle()';
  }
}

/// @nodoc

class DayPlanLlmStateProcessing implements DayPlanLlmState {
  const DayPlanLlmStateProcessing();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DayPlanLlmStateProcessing);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DayPlanLlmState.processing()';
  }
}

/// @nodoc

class DayPlanLlmStateCompleted implements DayPlanLlmState {
  const DayPlanLlmStateCompleted(
      {required final List<DayPlanActionResult> actions})
      : _actions = actions;

  final List<DayPlanActionResult> _actions;
  List<DayPlanActionResult> get actions {
    if (_actions is EqualUnmodifiableListView) return _actions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_actions);
  }

  /// Create a copy of DayPlanLlmState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DayPlanLlmStateCompletedCopyWith<DayPlanLlmStateCompleted> get copyWith =>
      _$DayPlanLlmStateCompletedCopyWithImpl<DayPlanLlmStateCompleted>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DayPlanLlmStateCompleted &&
            const DeepCollectionEquality().equals(other._actions, _actions));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_actions));

  @override
  String toString() {
    return 'DayPlanLlmState.completed(actions: $actions)';
  }
}

/// @nodoc
abstract mixin class $DayPlanLlmStateCompletedCopyWith<$Res>
    implements $DayPlanLlmStateCopyWith<$Res> {
  factory $DayPlanLlmStateCompletedCopyWith(DayPlanLlmStateCompleted value,
          $Res Function(DayPlanLlmStateCompleted) _then) =
      _$DayPlanLlmStateCompletedCopyWithImpl;
  @useResult
  $Res call({List<DayPlanActionResult> actions});
}

/// @nodoc
class _$DayPlanLlmStateCompletedCopyWithImpl<$Res>
    implements $DayPlanLlmStateCompletedCopyWith<$Res> {
  _$DayPlanLlmStateCompletedCopyWithImpl(this._self, this._then);

  final DayPlanLlmStateCompleted _self;
  final $Res Function(DayPlanLlmStateCompleted) _then;

  /// Create a copy of DayPlanLlmState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? actions = null,
  }) {
    return _then(DayPlanLlmStateCompleted(
      actions: null == actions
          ? _self._actions
          : actions // ignore: cast_nullable_to_non_nullable
              as List<DayPlanActionResult>,
    ));
  }
}

/// @nodoc

class DayPlanLlmStateError implements DayPlanLlmState {
  const DayPlanLlmStateError({required this.errorType});

  final DayPlanVoiceErrorType errorType;

  /// Create a copy of DayPlanLlmState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DayPlanLlmStateErrorCopyWith<DayPlanLlmStateError> get copyWith =>
      _$DayPlanLlmStateErrorCopyWithImpl<DayPlanLlmStateError>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DayPlanLlmStateError &&
            (identical(other.errorType, errorType) ||
                other.errorType == errorType));
  }

  @override
  int get hashCode => Object.hash(runtimeType, errorType);

  @override
  String toString() {
    return 'DayPlanLlmState.error(errorType: $errorType)';
  }
}

/// @nodoc
abstract mixin class $DayPlanLlmStateErrorCopyWith<$Res>
    implements $DayPlanLlmStateCopyWith<$Res> {
  factory $DayPlanLlmStateErrorCopyWith(DayPlanLlmStateError value,
          $Res Function(DayPlanLlmStateError) _then) =
      _$DayPlanLlmStateErrorCopyWithImpl;
  @useResult
  $Res call({DayPlanVoiceErrorType errorType});
}

/// @nodoc
class _$DayPlanLlmStateErrorCopyWithImpl<$Res>
    implements $DayPlanLlmStateErrorCopyWith<$Res> {
  _$DayPlanLlmStateErrorCopyWithImpl(this._self, this._then);

  final DayPlanLlmStateError _self;
  final $Res Function(DayPlanLlmStateError) _then;

  /// Create a copy of DayPlanLlmState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? errorType = null,
  }) {
    return _then(DayPlanLlmStateError(
      errorType: null == errorType
          ? _self.errorType
          : errorType // ignore: cast_nullable_to_non_nullable
              as DayPlanVoiceErrorType,
    ));
  }
}

// dart format on
