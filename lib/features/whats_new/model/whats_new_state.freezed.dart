// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'whats_new_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WhatsNewState {
  /// List of unseen release content, ordered by date descending (newest first).
  List<WhatsNewContent> get unseenContent;

  /// Create a copy of WhatsNewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WhatsNewStateCopyWith<WhatsNewState> get copyWith =>
      _$WhatsNewStateCopyWithImpl<WhatsNewState>(
          this as WhatsNewState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WhatsNewState &&
            const DeepCollectionEquality()
                .equals(other.unseenContent, unseenContent));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(unseenContent));

  @override
  String toString() {
    return 'WhatsNewState(unseenContent: $unseenContent)';
  }
}

/// @nodoc
abstract mixin class $WhatsNewStateCopyWith<$Res> {
  factory $WhatsNewStateCopyWith(
          WhatsNewState value, $Res Function(WhatsNewState) _then) =
      _$WhatsNewStateCopyWithImpl;
  @useResult
  $Res call({List<WhatsNewContent> unseenContent});
}

/// @nodoc
class _$WhatsNewStateCopyWithImpl<$Res>
    implements $WhatsNewStateCopyWith<$Res> {
  _$WhatsNewStateCopyWithImpl(this._self, this._then);

  final WhatsNewState _self;
  final $Res Function(WhatsNewState) _then;

  /// Create a copy of WhatsNewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unseenContent = null,
  }) {
    return _then(_self.copyWith(
      unseenContent: null == unseenContent
          ? _self.unseenContent
          : unseenContent // ignore: cast_nullable_to_non_nullable
              as List<WhatsNewContent>,
    ));
  }
}

/// Adds pattern-matching-related methods to [WhatsNewState].
extension WhatsNewStatePatterns on WhatsNewState {
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
    TResult Function(_WhatsNewState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WhatsNewState() when $default != null:
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
    TResult Function(_WhatsNewState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewState():
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
    TResult? Function(_WhatsNewState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewState() when $default != null:
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
    TResult Function(List<WhatsNewContent> unseenContent)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WhatsNewState() when $default != null:
        return $default(_that.unseenContent);
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
    TResult Function(List<WhatsNewContent> unseenContent) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewState():
        return $default(_that.unseenContent);
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
    TResult? Function(List<WhatsNewContent> unseenContent)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewState() when $default != null:
        return $default(_that.unseenContent);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _WhatsNewState extends WhatsNewState {
  const _WhatsNewState({final List<WhatsNewContent> unseenContent = const []})
      : _unseenContent = unseenContent,
        super._();

  /// List of unseen release content, ordered by date descending (newest first).
  final List<WhatsNewContent> _unseenContent;

  /// List of unseen release content, ordered by date descending (newest first).
  @override
  @JsonKey()
  List<WhatsNewContent> get unseenContent {
    if (_unseenContent is EqualUnmodifiableListView) return _unseenContent;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_unseenContent);
  }

  /// Create a copy of WhatsNewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WhatsNewStateCopyWith<_WhatsNewState> get copyWith =>
      __$WhatsNewStateCopyWithImpl<_WhatsNewState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WhatsNewState &&
            const DeepCollectionEquality()
                .equals(other._unseenContent, _unseenContent));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_unseenContent));

  @override
  String toString() {
    return 'WhatsNewState(unseenContent: $unseenContent)';
  }
}

/// @nodoc
abstract mixin class _$WhatsNewStateCopyWith<$Res>
    implements $WhatsNewStateCopyWith<$Res> {
  factory _$WhatsNewStateCopyWith(
          _WhatsNewState value, $Res Function(_WhatsNewState) _then) =
      __$WhatsNewStateCopyWithImpl;
  @override
  @useResult
  $Res call({List<WhatsNewContent> unseenContent});
}

/// @nodoc
class __$WhatsNewStateCopyWithImpl<$Res>
    implements _$WhatsNewStateCopyWith<$Res> {
  __$WhatsNewStateCopyWithImpl(this._self, this._then);

  final _WhatsNewState _self;
  final $Res Function(_WhatsNewState) _then;

  /// Create a copy of WhatsNewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? unseenContent = null,
  }) {
    return _then(_WhatsNewState(
      unseenContent: null == unseenContent
          ? _self._unseenContent
          : unseenContent // ignore: cast_nullable_to_non_nullable
              as List<WhatsNewContent>,
    ));
  }
}

// dart format on
