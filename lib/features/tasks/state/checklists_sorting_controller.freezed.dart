// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklists_sorting_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChecklistsSortingState {
  /// Whether sorting mode is currently active.
  bool get isSorting;

  /// Map of checklist IDs to their expansion state before sorting began.
  /// Used to restore expansion states when exiting sorting mode.
  Map<String, bool> get preExpansionStates;

  /// Create a copy of ChecklistsSortingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChecklistsSortingStateCopyWith<ChecklistsSortingState> get copyWith =>
      _$ChecklistsSortingStateCopyWithImpl<ChecklistsSortingState>(
          this as ChecklistsSortingState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChecklistsSortingState &&
            (identical(other.isSorting, isSorting) ||
                other.isSorting == isSorting) &&
            const DeepCollectionEquality()
                .equals(other.preExpansionStates, preExpansionStates));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isSorting,
      const DeepCollectionEquality().hash(preExpansionStates));

  @override
  String toString() {
    return 'ChecklistsSortingState(isSorting: $isSorting, preExpansionStates: $preExpansionStates)';
  }
}

/// @nodoc
abstract mixin class $ChecklistsSortingStateCopyWith<$Res> {
  factory $ChecklistsSortingStateCopyWith(ChecklistsSortingState value,
          $Res Function(ChecklistsSortingState) _then) =
      _$ChecklistsSortingStateCopyWithImpl;
  @useResult
  $Res call({bool isSorting, Map<String, bool> preExpansionStates});
}

/// @nodoc
class _$ChecklistsSortingStateCopyWithImpl<$Res>
    implements $ChecklistsSortingStateCopyWith<$Res> {
  _$ChecklistsSortingStateCopyWithImpl(this._self, this._then);

  final ChecklistsSortingState _self;
  final $Res Function(ChecklistsSortingState) _then;

  /// Create a copy of ChecklistsSortingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isSorting = null,
    Object? preExpansionStates = null,
  }) {
    return _then(_self.copyWith(
      isSorting: null == isSorting
          ? _self.isSorting
          : isSorting // ignore: cast_nullable_to_non_nullable
              as bool,
      preExpansionStates: null == preExpansionStates
          ? _self.preExpansionStates
          : preExpansionStates // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChecklistsSortingState].
extension ChecklistsSortingStatePatterns on ChecklistsSortingState {
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
    TResult Function(_ChecklistsSortingState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChecklistsSortingState() when $default != null:
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
    TResult Function(_ChecklistsSortingState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistsSortingState():
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
    TResult? Function(_ChecklistsSortingState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistsSortingState() when $default != null:
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
    TResult Function(bool isSorting, Map<String, bool> preExpansionStates)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChecklistsSortingState() when $default != null:
        return $default(_that.isSorting, _that.preExpansionStates);
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
    TResult Function(bool isSorting, Map<String, bool> preExpansionStates)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistsSortingState():
        return $default(_that.isSorting, _that.preExpansionStates);
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
    TResult? Function(bool isSorting, Map<String, bool> preExpansionStates)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistsSortingState() when $default != null:
        return $default(_that.isSorting, _that.preExpansionStates);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ChecklistsSortingState implements ChecklistsSortingState {
  const _ChecklistsSortingState(
      {this.isSorting = false,
      final Map<String, bool> preExpansionStates = const <String, bool>{}})
      : _preExpansionStates = preExpansionStates;

  /// Whether sorting mode is currently active.
  @override
  @JsonKey()
  final bool isSorting;

  /// Map of checklist IDs to their expansion state before sorting began.
  /// Used to restore expansion states when exiting sorting mode.
  final Map<String, bool> _preExpansionStates;

  /// Map of checklist IDs to their expansion state before sorting began.
  /// Used to restore expansion states when exiting sorting mode.
  @override
  @JsonKey()
  Map<String, bool> get preExpansionStates {
    if (_preExpansionStates is EqualUnmodifiableMapView)
      return _preExpansionStates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_preExpansionStates);
  }

  /// Create a copy of ChecklistsSortingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChecklistsSortingStateCopyWith<_ChecklistsSortingState> get copyWith =>
      __$ChecklistsSortingStateCopyWithImpl<_ChecklistsSortingState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChecklistsSortingState &&
            (identical(other.isSorting, isSorting) ||
                other.isSorting == isSorting) &&
            const DeepCollectionEquality()
                .equals(other._preExpansionStates, _preExpansionStates));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isSorting,
      const DeepCollectionEquality().hash(_preExpansionStates));

  @override
  String toString() {
    return 'ChecklistsSortingState(isSorting: $isSorting, preExpansionStates: $preExpansionStates)';
  }
}

/// @nodoc
abstract mixin class _$ChecklistsSortingStateCopyWith<$Res>
    implements $ChecklistsSortingStateCopyWith<$Res> {
  factory _$ChecklistsSortingStateCopyWith(_ChecklistsSortingState value,
          $Res Function(_ChecklistsSortingState) _then) =
      __$ChecklistsSortingStateCopyWithImpl;
  @override
  @useResult
  $Res call({bool isSorting, Map<String, bool> preExpansionStates});
}

/// @nodoc
class __$ChecklistsSortingStateCopyWithImpl<$Res>
    implements _$ChecklistsSortingStateCopyWith<$Res> {
  __$ChecklistsSortingStateCopyWithImpl(this._self, this._then);

  final _ChecklistsSortingState _self;
  final $Res Function(_ChecklistsSortingState) _then;

  /// Create a copy of ChecklistsSortingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? isSorting = null,
    Object? preExpansionStates = null,
  }) {
    return _then(_ChecklistsSortingState(
      isSorting: null == isSorting
          ? _self.isSorting
          : isSorting // ignore: cast_nullable_to_non_nullable
              as bool,
      preExpansionStates: null == preExpansionStates
          ? _self._preExpansionStates
          : preExpansionStates // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
    ));
  }
}

// dart format on
