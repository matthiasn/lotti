// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'theming_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ThemingState {
  bool get enableTooltips;
  ThemeData? get darkTheme;
  ThemeData? get lightTheme;
  String? get darkThemeName;
  String? get lightThemeName;
  ThemeMode? get themeMode;

  /// Create a copy of ThemingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ThemingStateCopyWith<ThemingState> get copyWith =>
      _$ThemingStateCopyWithImpl<ThemingState>(
          this as ThemingState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ThemingState &&
            (identical(other.enableTooltips, enableTooltips) ||
                other.enableTooltips == enableTooltips) &&
            (identical(other.darkTheme, darkTheme) ||
                other.darkTheme == darkTheme) &&
            (identical(other.lightTheme, lightTheme) ||
                other.lightTheme == lightTheme) &&
            (identical(other.darkThemeName, darkThemeName) ||
                other.darkThemeName == darkThemeName) &&
            (identical(other.lightThemeName, lightThemeName) ||
                other.lightThemeName == lightThemeName) &&
            (identical(other.themeMode, themeMode) ||
                other.themeMode == themeMode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, enableTooltips, darkTheme,
      lightTheme, darkThemeName, lightThemeName, themeMode);

  @override
  String toString() {
    return 'ThemingState(enableTooltips: $enableTooltips, darkTheme: $darkTheme, lightTheme: $lightTheme, darkThemeName: $darkThemeName, lightThemeName: $lightThemeName, themeMode: $themeMode)';
  }
}

/// @nodoc
abstract mixin class $ThemingStateCopyWith<$Res> {
  factory $ThemingStateCopyWith(
          ThemingState value, $Res Function(ThemingState) _then) =
      _$ThemingStateCopyWithImpl;
  @useResult
  $Res call(
      {bool enableTooltips,
      ThemeData? darkTheme,
      ThemeData? lightTheme,
      String? darkThemeName,
      String? lightThemeName,
      ThemeMode? themeMode});
}

/// @nodoc
class _$ThemingStateCopyWithImpl<$Res> implements $ThemingStateCopyWith<$Res> {
  _$ThemingStateCopyWithImpl(this._self, this._then);

  final ThemingState _self;
  final $Res Function(ThemingState) _then;

  /// Create a copy of ThemingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableTooltips = null,
    Object? darkTheme = freezed,
    Object? lightTheme = freezed,
    Object? darkThemeName = freezed,
    Object? lightThemeName = freezed,
    Object? themeMode = freezed,
  }) {
    return _then(_self.copyWith(
      enableTooltips: null == enableTooltips
          ? _self.enableTooltips
          : enableTooltips // ignore: cast_nullable_to_non_nullable
              as bool,
      darkTheme: freezed == darkTheme
          ? _self.darkTheme
          : darkTheme // ignore: cast_nullable_to_non_nullable
              as ThemeData?,
      lightTheme: freezed == lightTheme
          ? _self.lightTheme
          : lightTheme // ignore: cast_nullable_to_non_nullable
              as ThemeData?,
      darkThemeName: freezed == darkThemeName
          ? _self.darkThemeName
          : darkThemeName // ignore: cast_nullable_to_non_nullable
              as String?,
      lightThemeName: freezed == lightThemeName
          ? _self.lightThemeName
          : lightThemeName // ignore: cast_nullable_to_non_nullable
              as String?,
      themeMode: freezed == themeMode
          ? _self.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as ThemeMode?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ThemingState].
extension ThemingStatePatterns on ThemingState {
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
    TResult Function(_ThemingState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ThemingState() when $default != null:
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
    TResult Function(_ThemingState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemingState():
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
    TResult? Function(_ThemingState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemingState() when $default != null:
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
            bool enableTooltips,
            ThemeData? darkTheme,
            ThemeData? lightTheme,
            String? darkThemeName,
            String? lightThemeName,
            ThemeMode? themeMode)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ThemingState() when $default != null:
        return $default(_that.enableTooltips, _that.darkTheme, _that.lightTheme,
            _that.darkThemeName, _that.lightThemeName, _that.themeMode);
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
            bool enableTooltips,
            ThemeData? darkTheme,
            ThemeData? lightTheme,
            String? darkThemeName,
            String? lightThemeName,
            ThemeMode? themeMode)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemingState():
        return $default(_that.enableTooltips, _that.darkTheme, _that.lightTheme,
            _that.darkThemeName, _that.lightThemeName, _that.themeMode);
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
            bool enableTooltips,
            ThemeData? darkTheme,
            ThemeData? lightTheme,
            String? darkThemeName,
            String? lightThemeName,
            ThemeMode? themeMode)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemingState() when $default != null:
        return $default(_that.enableTooltips, _that.darkTheme, _that.lightTheme,
            _that.darkThemeName, _that.lightThemeName, _that.themeMode);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ThemingState implements ThemingState {
  _ThemingState(
      {required this.enableTooltips,
      this.darkTheme,
      this.lightTheme,
      this.darkThemeName,
      this.lightThemeName,
      this.themeMode});

  @override
  final bool enableTooltips;
  @override
  final ThemeData? darkTheme;
  @override
  final ThemeData? lightTheme;
  @override
  final String? darkThemeName;
  @override
  final String? lightThemeName;
  @override
  final ThemeMode? themeMode;

  /// Create a copy of ThemingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ThemingStateCopyWith<_ThemingState> get copyWith =>
      __$ThemingStateCopyWithImpl<_ThemingState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ThemingState &&
            (identical(other.enableTooltips, enableTooltips) ||
                other.enableTooltips == enableTooltips) &&
            (identical(other.darkTheme, darkTheme) ||
                other.darkTheme == darkTheme) &&
            (identical(other.lightTheme, lightTheme) ||
                other.lightTheme == lightTheme) &&
            (identical(other.darkThemeName, darkThemeName) ||
                other.darkThemeName == darkThemeName) &&
            (identical(other.lightThemeName, lightThemeName) ||
                other.lightThemeName == lightThemeName) &&
            (identical(other.themeMode, themeMode) ||
                other.themeMode == themeMode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, enableTooltips, darkTheme,
      lightTheme, darkThemeName, lightThemeName, themeMode);

  @override
  String toString() {
    return 'ThemingState(enableTooltips: $enableTooltips, darkTheme: $darkTheme, lightTheme: $lightTheme, darkThemeName: $darkThemeName, lightThemeName: $lightThemeName, themeMode: $themeMode)';
  }
}

/// @nodoc
abstract mixin class _$ThemingStateCopyWith<$Res>
    implements $ThemingStateCopyWith<$Res> {
  factory _$ThemingStateCopyWith(
          _ThemingState value, $Res Function(_ThemingState) _then) =
      __$ThemingStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool enableTooltips,
      ThemeData? darkTheme,
      ThemeData? lightTheme,
      String? darkThemeName,
      String? lightThemeName,
      ThemeMode? themeMode});
}

/// @nodoc
class __$ThemingStateCopyWithImpl<$Res>
    implements _$ThemingStateCopyWith<$Res> {
  __$ThemingStateCopyWithImpl(this._self, this._then);

  final _ThemingState _self;
  final $Res Function(_ThemingState) _then;

  /// Create a copy of ThemingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? enableTooltips = null,
    Object? darkTheme = freezed,
    Object? lightTheme = freezed,
    Object? darkThemeName = freezed,
    Object? lightThemeName = freezed,
    Object? themeMode = freezed,
  }) {
    return _then(_ThemingState(
      enableTooltips: null == enableTooltips
          ? _self.enableTooltips
          : enableTooltips // ignore: cast_nullable_to_non_nullable
              as bool,
      darkTheme: freezed == darkTheme
          ? _self.darkTheme
          : darkTheme // ignore: cast_nullable_to_non_nullable
              as ThemeData?,
      lightTheme: freezed == lightTheme
          ? _self.lightTheme
          : lightTheme // ignore: cast_nullable_to_non_nullable
              as ThemeData?,
      darkThemeName: freezed == darkThemeName
          ? _self.darkThemeName
          : darkThemeName // ignore: cast_nullable_to_non_nullable
              as String?,
      lightThemeName: freezed == lightThemeName
          ? _self.lightThemeName
          : lightThemeName // ignore: cast_nullable_to_non_nullable
              as String?,
      themeMode: freezed == themeMode
          ? _self.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as ThemeMode?,
    ));
  }
}

// dart format on
