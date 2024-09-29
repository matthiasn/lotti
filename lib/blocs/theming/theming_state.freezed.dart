// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'theming_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ThemingState {
  bool get enableTooltips => throw _privateConstructorUsedError;
  ThemeData? get darkTheme => throw _privateConstructorUsedError;
  ThemeData? get lightTheme => throw _privateConstructorUsedError;
  String? get darkThemeName => throw _privateConstructorUsedError;
  String? get lightThemeName => throw _privateConstructorUsedError;
  ThemeMode? get themeMode => throw _privateConstructorUsedError;

  /// Create a copy of ThemingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ThemingStateCopyWith<ThemingState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ThemingStateCopyWith<$Res> {
  factory $ThemingStateCopyWith(
          ThemingState value, $Res Function(ThemingState) then) =
      _$ThemingStateCopyWithImpl<$Res, ThemingState>;
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
class _$ThemingStateCopyWithImpl<$Res, $Val extends ThemingState>
    implements $ThemingStateCopyWith<$Res> {
  _$ThemingStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      enableTooltips: null == enableTooltips
          ? _value.enableTooltips
          : enableTooltips // ignore: cast_nullable_to_non_nullable
              as bool,
      darkTheme: freezed == darkTheme
          ? _value.darkTheme
          : darkTheme // ignore: cast_nullable_to_non_nullable
              as ThemeData?,
      lightTheme: freezed == lightTheme
          ? _value.lightTheme
          : lightTheme // ignore: cast_nullable_to_non_nullable
              as ThemeData?,
      darkThemeName: freezed == darkThemeName
          ? _value.darkThemeName
          : darkThemeName // ignore: cast_nullable_to_non_nullable
              as String?,
      lightThemeName: freezed == lightThemeName
          ? _value.lightThemeName
          : lightThemeName // ignore: cast_nullable_to_non_nullable
              as String?,
      themeMode: freezed == themeMode
          ? _value.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as ThemeMode?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ThemingStateImplCopyWith<$Res>
    implements $ThemingStateCopyWith<$Res> {
  factory _$$ThemingStateImplCopyWith(
          _$ThemingStateImpl value, $Res Function(_$ThemingStateImpl) then) =
      __$$ThemingStateImplCopyWithImpl<$Res>;
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
class __$$ThemingStateImplCopyWithImpl<$Res>
    extends _$ThemingStateCopyWithImpl<$Res, _$ThemingStateImpl>
    implements _$$ThemingStateImplCopyWith<$Res> {
  __$$ThemingStateImplCopyWithImpl(
      _$ThemingStateImpl _value, $Res Function(_$ThemingStateImpl) _then)
      : super(_value, _then);

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
    return _then(_$ThemingStateImpl(
      enableTooltips: null == enableTooltips
          ? _value.enableTooltips
          : enableTooltips // ignore: cast_nullable_to_non_nullable
              as bool,
      darkTheme: freezed == darkTheme
          ? _value.darkTheme
          : darkTheme // ignore: cast_nullable_to_non_nullable
              as ThemeData?,
      lightTheme: freezed == lightTheme
          ? _value.lightTheme
          : lightTheme // ignore: cast_nullable_to_non_nullable
              as ThemeData?,
      darkThemeName: freezed == darkThemeName
          ? _value.darkThemeName
          : darkThemeName // ignore: cast_nullable_to_non_nullable
              as String?,
      lightThemeName: freezed == lightThemeName
          ? _value.lightThemeName
          : lightThemeName // ignore: cast_nullable_to_non_nullable
              as String?,
      themeMode: freezed == themeMode
          ? _value.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as ThemeMode?,
    ));
  }
}

/// @nodoc

class _$ThemingStateImpl implements _ThemingState {
  _$ThemingStateImpl(
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

  @override
  String toString() {
    return 'ThemingState(enableTooltips: $enableTooltips, darkTheme: $darkTheme, lightTheme: $lightTheme, darkThemeName: $darkThemeName, lightThemeName: $lightThemeName, themeMode: $themeMode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ThemingStateImpl &&
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

  /// Create a copy of ThemingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ThemingStateImplCopyWith<_$ThemingStateImpl> get copyWith =>
      __$$ThemingStateImplCopyWithImpl<_$ThemingStateImpl>(this, _$identity);
}

abstract class _ThemingState implements ThemingState {
  factory _ThemingState(
      {required final bool enableTooltips,
      final ThemeData? darkTheme,
      final ThemeData? lightTheme,
      final String? darkThemeName,
      final String? lightThemeName,
      final ThemeMode? themeMode}) = _$ThemingStateImpl;

  @override
  bool get enableTooltips;
  @override
  ThemeData? get darkTheme;
  @override
  ThemeData? get lightTheme;
  @override
  String? get darkThemeName;
  @override
  String? get lightThemeName;
  @override
  ThemeMode? get themeMode;

  /// Create a copy of ThemingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ThemingStateImplCopyWith<_$ThemingStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
