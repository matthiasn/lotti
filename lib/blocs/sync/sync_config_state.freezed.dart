// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_config_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$SyncConfigState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncConfigStateCopyWith<$Res> {
  factory $SyncConfigStateCopyWith(
          SyncConfigState value, $Res Function(SyncConfigState) then) =
      _$SyncConfigStateCopyWithImpl<$Res, SyncConfigState>;
}

/// @nodoc
class _$SyncConfigStateCopyWithImpl<$Res, $Val extends SyncConfigState>
    implements $SyncConfigStateCopyWith<$Res> {
  _$SyncConfigStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$_ConfiguredCopyWith<$Res> {
  factory _$$_ConfiguredCopyWith(
          _$_Configured value, $Res Function(_$_Configured) then) =
      __$$_ConfiguredCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig, String sharedSecret});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$_ConfiguredCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$_Configured>
    implements _$$_ConfiguredCopyWith<$Res> {
  __$$_ConfiguredCopyWithImpl(
      _$_Configured _value, $Res Function(_$_Configured) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? sharedSecret = null,
  }) {
    return _then(_$_Configured(
      imapConfig: null == imapConfig
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
      sharedSecret: null == sharedSecret
          ? _value.sharedSecret
          : sharedSecret // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_value.imapConfig, (value) {
      return _then(_value.copyWith(imapConfig: value));
    });
  }
}

/// @nodoc

class _$_Configured implements _Configured {
  _$_Configured({required this.imapConfig, required this.sharedSecret});

  @override
  final ImapConfig imapConfig;
  @override
  final String sharedSecret;

  @override
  String toString() {
    return 'SyncConfigState.configured(imapConfig: $imapConfig, sharedSecret: $sharedSecret)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Configured &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig) &&
            (identical(other.sharedSecret, sharedSecret) ||
                other.sharedSecret == sharedSecret));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imapConfig, sharedSecret);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ConfiguredCopyWith<_$_Configured> get copyWith =>
      __$$_ConfiguredCopyWithImpl<_$_Configured>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return configured(imapConfig, sharedSecret);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) {
    return configured?.call(imapConfig, sharedSecret);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if (configured != null) {
      return configured(imapConfig, sharedSecret);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) {
    return configured(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) {
    return configured?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) {
    if (configured != null) {
      return configured(this);
    }
    return orElse();
  }
}

abstract class _Configured implements SyncConfigState {
  factory _Configured(
      {required final ImapConfig imapConfig,
      required final String sharedSecret}) = _$_Configured;

  ImapConfig get imapConfig;
  String get sharedSecret;
  @JsonKey(ignore: true)
  _$$_ConfiguredCopyWith<_$_Configured> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_ImapSavedCopyWith<$Res> {
  factory _$$_ImapSavedCopyWith(
          _$_ImapSaved value, $Res Function(_$_ImapSaved) then) =
      __$$_ImapSavedCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$_ImapSavedCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$_ImapSaved>
    implements _$$_ImapSavedCopyWith<$Res> {
  __$$_ImapSavedCopyWithImpl(
      _$_ImapSaved _value, $Res Function(_$_ImapSaved) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
  }) {
    return _then(_$_ImapSaved(
      imapConfig: null == imapConfig
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_value.imapConfig, (value) {
      return _then(_value.copyWith(imapConfig: value));
    });
  }
}

/// @nodoc

class _$_ImapSaved implements _ImapSaved {
  _$_ImapSaved({required this.imapConfig});

  @override
  final ImapConfig imapConfig;

  @override
  String toString() {
    return 'SyncConfigState.imapSaved(imapConfig: $imapConfig)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ImapSaved &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imapConfig);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ImapSavedCopyWith<_$_ImapSaved> get copyWith =>
      __$$_ImapSavedCopyWithImpl<_$_ImapSaved>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return imapSaved(imapConfig);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) {
    return imapSaved?.call(imapConfig);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if (imapSaved != null) {
      return imapSaved(imapConfig);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) {
    return imapSaved(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) {
    return imapSaved?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) {
    if (imapSaved != null) {
      return imapSaved(this);
    }
    return orElse();
  }
}

abstract class _ImapSaved implements SyncConfigState {
  factory _ImapSaved({required final ImapConfig imapConfig}) = _$_ImapSaved;

  ImapConfig get imapConfig;
  @JsonKey(ignore: true)
  _$$_ImapSavedCopyWith<_$_ImapSaved> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_ImapValidCopyWith<$Res> {
  factory _$$_ImapValidCopyWith(
          _$_ImapValid value, $Res Function(_$_ImapValid) then) =
      __$$_ImapValidCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$_ImapValidCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$_ImapValid>
    implements _$$_ImapValidCopyWith<$Res> {
  __$$_ImapValidCopyWithImpl(
      _$_ImapValid _value, $Res Function(_$_ImapValid) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
  }) {
    return _then(_$_ImapValid(
      imapConfig: null == imapConfig
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_value.imapConfig, (value) {
      return _then(_value.copyWith(imapConfig: value));
    });
  }
}

/// @nodoc

class _$_ImapValid implements _ImapValid {
  _$_ImapValid({required this.imapConfig});

  @override
  final ImapConfig imapConfig;

  @override
  String toString() {
    return 'SyncConfigState.imapValid(imapConfig: $imapConfig)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ImapValid &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imapConfig);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ImapValidCopyWith<_$_ImapValid> get copyWith =>
      __$$_ImapValidCopyWithImpl<_$_ImapValid>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return imapValid(imapConfig);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) {
    return imapValid?.call(imapConfig);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if (imapValid != null) {
      return imapValid(imapConfig);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) {
    return imapValid(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) {
    return imapValid?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) {
    if (imapValid != null) {
      return imapValid(this);
    }
    return orElse();
  }
}

abstract class _ImapValid implements SyncConfigState {
  factory _ImapValid({required final ImapConfig imapConfig}) = _$_ImapValid;

  ImapConfig get imapConfig;
  @JsonKey(ignore: true)
  _$$_ImapValidCopyWith<_$_ImapValid> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_ImapTestingCopyWith<$Res> {
  factory _$$_ImapTestingCopyWith(
          _$_ImapTesting value, $Res Function(_$_ImapTesting) then) =
      __$$_ImapTestingCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$_ImapTestingCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$_ImapTesting>
    implements _$$_ImapTestingCopyWith<$Res> {
  __$$_ImapTestingCopyWithImpl(
      _$_ImapTesting _value, $Res Function(_$_ImapTesting) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
  }) {
    return _then(_$_ImapTesting(
      imapConfig: null == imapConfig
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_value.imapConfig, (value) {
      return _then(_value.copyWith(imapConfig: value));
    });
  }
}

/// @nodoc

class _$_ImapTesting implements _ImapTesting {
  _$_ImapTesting({required this.imapConfig});

  @override
  final ImapConfig imapConfig;

  @override
  String toString() {
    return 'SyncConfigState.imapTesting(imapConfig: $imapConfig)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ImapTesting &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imapConfig);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ImapTestingCopyWith<_$_ImapTesting> get copyWith =>
      __$$_ImapTestingCopyWithImpl<_$_ImapTesting>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return imapTesting(imapConfig);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) {
    return imapTesting?.call(imapConfig);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if (imapTesting != null) {
      return imapTesting(imapConfig);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) {
    return imapTesting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) {
    return imapTesting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) {
    if (imapTesting != null) {
      return imapTesting(this);
    }
    return orElse();
  }
}

abstract class _ImapTesting implements SyncConfigState {
  factory _ImapTesting({required final ImapConfig imapConfig}) = _$_ImapTesting;

  ImapConfig get imapConfig;
  @JsonKey(ignore: true)
  _$$_ImapTestingCopyWith<_$_ImapTesting> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_ImapInvalidCopyWith<$Res> {
  factory _$$_ImapInvalidCopyWith(
          _$_ImapInvalid value, $Res Function(_$_ImapInvalid) then) =
      __$$_ImapInvalidCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig, String errorMessage});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$_ImapInvalidCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$_ImapInvalid>
    implements _$$_ImapInvalidCopyWith<$Res> {
  __$$_ImapInvalidCopyWithImpl(
      _$_ImapInvalid _value, $Res Function(_$_ImapInvalid) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? errorMessage = null,
  }) {
    return _then(_$_ImapInvalid(
      imapConfig: null == imapConfig
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
      errorMessage: null == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_value.imapConfig, (value) {
      return _then(_value.copyWith(imapConfig: value));
    });
  }
}

/// @nodoc

class _$_ImapInvalid implements _ImapInvalid {
  _$_ImapInvalid({required this.imapConfig, required this.errorMessage});

  @override
  final ImapConfig imapConfig;
  @override
  final String errorMessage;

  @override
  String toString() {
    return 'SyncConfigState.imapInvalid(imapConfig: $imapConfig, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ImapInvalid &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imapConfig, errorMessage);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ImapInvalidCopyWith<_$_ImapInvalid> get copyWith =>
      __$$_ImapInvalidCopyWithImpl<_$_ImapInvalid>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return imapInvalid(imapConfig, errorMessage);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) {
    return imapInvalid?.call(imapConfig, errorMessage);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if (imapInvalid != null) {
      return imapInvalid(imapConfig, errorMessage);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) {
    return imapInvalid(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) {
    return imapInvalid?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) {
    if (imapInvalid != null) {
      return imapInvalid(this);
    }
    return orElse();
  }
}

abstract class _ImapInvalid implements SyncConfigState {
  factory _ImapInvalid(
      {required final ImapConfig imapConfig,
      required final String errorMessage}) = _$_ImapInvalid;

  ImapConfig get imapConfig;
  String get errorMessage;
  @JsonKey(ignore: true)
  _$$_ImapInvalidCopyWith<_$_ImapInvalid> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_LoadingCopyWith<$Res> {
  factory _$$_LoadingCopyWith(
          _$_Loading value, $Res Function(_$_Loading) then) =
      __$$_LoadingCopyWithImpl<$Res>;
}

/// @nodoc
class __$$_LoadingCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$_Loading>
    implements _$$_LoadingCopyWith<$Res> {
  __$$_LoadingCopyWithImpl(_$_Loading _value, $Res Function(_$_Loading) _then)
      : super(_value, _then);
}

/// @nodoc

class _$_Loading implements _Loading {
  _$_Loading();

  @override
  String toString() {
    return 'SyncConfigState.loading()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$_Loading);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class _Loading implements SyncConfigState {
  factory _Loading() = _$_Loading;
}

/// @nodoc
abstract class _$$_GeneratingCopyWith<$Res> {
  factory _$$_GeneratingCopyWith(
          _$_Generating value, $Res Function(_$_Generating) then) =
      __$$_GeneratingCopyWithImpl<$Res>;
}

/// @nodoc
class __$$_GeneratingCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$_Generating>
    implements _$$_GeneratingCopyWith<$Res> {
  __$$_GeneratingCopyWithImpl(
      _$_Generating _value, $Res Function(_$_Generating) _then)
      : super(_value, _then);
}

/// @nodoc

class _$_Generating implements _Generating {
  _$_Generating();

  @override
  String toString() {
    return 'SyncConfigState.generating()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$_Generating);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return generating();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) {
    return generating?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if (generating != null) {
      return generating();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) {
    return generating(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) {
    return generating?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) {
    if (generating != null) {
      return generating(this);
    }
    return orElse();
  }
}

abstract class _Generating implements SyncConfigState {
  factory _Generating() = _$_Generating;
}

/// @nodoc
abstract class _$$_EmptyCopyWith<$Res> {
  factory _$$_EmptyCopyWith(_$_Empty value, $Res Function(_$_Empty) then) =
      __$$_EmptyCopyWithImpl<$Res>;
}

/// @nodoc
class __$$_EmptyCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$_Empty>
    implements _$$_EmptyCopyWith<$Res> {
  __$$_EmptyCopyWithImpl(_$_Empty _value, $Res Function(_$_Empty) _then)
      : super(_value, _then);
}

/// @nodoc

class _$_Empty implements _Empty {
  _$_Empty();

  @override
  String toString() {
    return 'SyncConfigState.empty()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$_Empty);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(ImapConfig imapConfig, String sharedSecret)
        configured,
    required TResult Function(ImapConfig imapConfig) imapSaved,
    required TResult Function(ImapConfig imapConfig) imapValid,
    required TResult Function(ImapConfig imapConfig) imapTesting,
    required TResult Function(ImapConfig imapConfig, String errorMessage)
        imapInvalid,
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return empty();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult? Function(ImapConfig imapConfig)? imapSaved,
    TResult? Function(ImapConfig imapConfig)? imapValid,
    TResult? Function(ImapConfig imapConfig)? imapTesting,
    TResult? Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult? Function()? loading,
    TResult? Function()? generating,
    TResult? Function()? empty,
  }) {
    return empty?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(ImapConfig imapConfig, String sharedSecret)? configured,
    TResult Function(ImapConfig imapConfig)? imapSaved,
    TResult Function(ImapConfig imapConfig)? imapValid,
    TResult Function(ImapConfig imapConfig)? imapTesting,
    TResult Function(ImapConfig imapConfig, String errorMessage)? imapInvalid,
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if (empty != null) {
      return empty();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Configured value) configured,
    required TResult Function(_ImapSaved value) imapSaved,
    required TResult Function(_ImapValid value) imapValid,
    required TResult Function(_ImapTesting value) imapTesting,
    required TResult Function(_ImapInvalid value) imapInvalid,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Generating value) generating,
    required TResult Function(_Empty value) empty,
  }) {
    return empty(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Configured value)? configured,
    TResult? Function(_ImapSaved value)? imapSaved,
    TResult? Function(_ImapValid value)? imapValid,
    TResult? Function(_ImapTesting value)? imapTesting,
    TResult? Function(_ImapInvalid value)? imapInvalid,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Generating value)? generating,
    TResult? Function(_Empty value)? empty,
  }) {
    return empty?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Configured value)? configured,
    TResult Function(_ImapSaved value)? imapSaved,
    TResult Function(_ImapValid value)? imapValid,
    TResult Function(_ImapTesting value)? imapTesting,
    TResult Function(_ImapInvalid value)? imapInvalid,
    TResult Function(_Loading value)? loading,
    TResult Function(_Generating value)? generating,
    TResult Function(_Empty value)? empty,
    required TResult orElse(),
  }) {
    if (empty != null) {
      return empty(this);
    }
    return orElse();
  }
}

abstract class _Empty implements SyncConfigState {
  factory _Empty() = _$_Empty;
}
