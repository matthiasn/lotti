// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'linked_tasks_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LinkedTasksState {
  /// Whether manage mode is active (shows unlink X buttons).
  bool get manageMode;

  /// Create a copy of LinkedTasksState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LinkedTasksStateCopyWith<LinkedTasksState> get copyWith =>
      _$LinkedTasksStateCopyWithImpl<LinkedTasksState>(
          this as LinkedTasksState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LinkedTasksState &&
            (identical(other.manageMode, manageMode) ||
                other.manageMode == manageMode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, manageMode);

  @override
  String toString() {
    return 'LinkedTasksState(manageMode: $manageMode)';
  }
}

/// @nodoc
abstract mixin class $LinkedTasksStateCopyWith<$Res> {
  factory $LinkedTasksStateCopyWith(
          LinkedTasksState value, $Res Function(LinkedTasksState) _then) =
      _$LinkedTasksStateCopyWithImpl;
  @useResult
  $Res call({bool manageMode});
}

/// @nodoc
class _$LinkedTasksStateCopyWithImpl<$Res>
    implements $LinkedTasksStateCopyWith<$Res> {
  _$LinkedTasksStateCopyWithImpl(this._self, this._then);

  final LinkedTasksState _self;
  final $Res Function(LinkedTasksState) _then;

  /// Create a copy of LinkedTasksState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? manageMode = null,
  }) {
    return _then(_self.copyWith(
      manageMode: null == manageMode
          ? _self.manageMode
          : manageMode // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [LinkedTasksState].
extension LinkedTasksStatePatterns on LinkedTasksState {
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
    TResult Function(_LinkedTasksState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LinkedTasksState() when $default != null:
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
    TResult Function(_LinkedTasksState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LinkedTasksState():
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
    TResult? Function(_LinkedTasksState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LinkedTasksState() when $default != null:
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
    TResult Function(bool manageMode)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LinkedTasksState() when $default != null:
        return $default(_that.manageMode);
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
    TResult Function(bool manageMode) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LinkedTasksState():
        return $default(_that.manageMode);
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
    TResult? Function(bool manageMode)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LinkedTasksState() when $default != null:
        return $default(_that.manageMode);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _LinkedTasksState implements LinkedTasksState {
  const _LinkedTasksState({this.manageMode = false});

  /// Whether manage mode is active (shows unlink X buttons).
  @override
  @JsonKey()
  final bool manageMode;

  /// Create a copy of LinkedTasksState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LinkedTasksStateCopyWith<_LinkedTasksState> get copyWith =>
      __$LinkedTasksStateCopyWithImpl<_LinkedTasksState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LinkedTasksState &&
            (identical(other.manageMode, manageMode) ||
                other.manageMode == manageMode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, manageMode);

  @override
  String toString() {
    return 'LinkedTasksState(manageMode: $manageMode)';
  }
}

/// @nodoc
abstract mixin class _$LinkedTasksStateCopyWith<$Res>
    implements $LinkedTasksStateCopyWith<$Res> {
  factory _$LinkedTasksStateCopyWith(
          _LinkedTasksState value, $Res Function(_LinkedTasksState) _then) =
      __$LinkedTasksStateCopyWithImpl;
  @override
  @useResult
  $Res call({bool manageMode});
}

/// @nodoc
class __$LinkedTasksStateCopyWithImpl<$Res>
    implements _$LinkedTasksStateCopyWith<$Res> {
  __$LinkedTasksStateCopyWithImpl(this._self, this._then);

  final _LinkedTasksState _self;
  final $Res Function(_LinkedTasksState) _then;

  /// Create a copy of LinkedTasksState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? manageMode = null,
  }) {
    return _then(_LinkedTasksState(
      manageMode: null == manageMode
          ? _self.manageMode
          : manageMode // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
