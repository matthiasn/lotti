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
abstract class _$$ConfiguredImplCopyWith<$Res> {
  factory _$$ConfiguredImplCopyWith(
          _$ConfiguredImpl value, $Res Function(_$ConfiguredImpl) then) =
      __$$ConfiguredImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig, String sharedSecret});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$ConfiguredImplCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$ConfiguredImpl>
    implements _$$ConfiguredImplCopyWith<$Res> {
  __$$ConfiguredImplCopyWithImpl(
      _$ConfiguredImpl _value, $Res Function(_$ConfiguredImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? sharedSecret = null,
  }) {
    return _then(_$ConfiguredImpl(
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

class _$ConfiguredImpl implements _Configured {
  _$ConfiguredImpl({required this.imapConfig, required this.sharedSecret});

  @override
  final ImapConfig imapConfig;
  @override
  final String sharedSecret;

  @override
  String toString() {
    return 'SyncConfigState.configured(imapConfig: $imapConfig, sharedSecret: $sharedSecret)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConfiguredImpl &&
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
  _$$ConfiguredImplCopyWith<_$ConfiguredImpl> get copyWith =>
      __$$ConfiguredImplCopyWithImpl<_$ConfiguredImpl>(this, _$identity);

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
      required final String sharedSecret}) = _$ConfiguredImpl;

  ImapConfig get imapConfig;
  String get sharedSecret;
  @JsonKey(ignore: true)
  _$$ConfiguredImplCopyWith<_$ConfiguredImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ImapSavedImplCopyWith<$Res> {
  factory _$$ImapSavedImplCopyWith(
          _$ImapSavedImpl value, $Res Function(_$ImapSavedImpl) then) =
      __$$ImapSavedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$ImapSavedImplCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$ImapSavedImpl>
    implements _$$ImapSavedImplCopyWith<$Res> {
  __$$ImapSavedImplCopyWithImpl(
      _$ImapSavedImpl _value, $Res Function(_$ImapSavedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
  }) {
    return _then(_$ImapSavedImpl(
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

class _$ImapSavedImpl implements _ImapSaved {
  _$ImapSavedImpl({required this.imapConfig});

  @override
  final ImapConfig imapConfig;

  @override
  String toString() {
    return 'SyncConfigState.imapSaved(imapConfig: $imapConfig)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImapSavedImpl &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imapConfig);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ImapSavedImplCopyWith<_$ImapSavedImpl> get copyWith =>
      __$$ImapSavedImplCopyWithImpl<_$ImapSavedImpl>(this, _$identity);

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
  factory _ImapSaved({required final ImapConfig imapConfig}) = _$ImapSavedImpl;

  ImapConfig get imapConfig;
  @JsonKey(ignore: true)
  _$$ImapSavedImplCopyWith<_$ImapSavedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ImapValidImplCopyWith<$Res> {
  factory _$$ImapValidImplCopyWith(
          _$ImapValidImpl value, $Res Function(_$ImapValidImpl) then) =
      __$$ImapValidImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$ImapValidImplCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$ImapValidImpl>
    implements _$$ImapValidImplCopyWith<$Res> {
  __$$ImapValidImplCopyWithImpl(
      _$ImapValidImpl _value, $Res Function(_$ImapValidImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
  }) {
    return _then(_$ImapValidImpl(
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

class _$ImapValidImpl implements _ImapValid {
  _$ImapValidImpl({required this.imapConfig});

  @override
  final ImapConfig imapConfig;

  @override
  String toString() {
    return 'SyncConfigState.imapValid(imapConfig: $imapConfig)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImapValidImpl &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imapConfig);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ImapValidImplCopyWith<_$ImapValidImpl> get copyWith =>
      __$$ImapValidImplCopyWithImpl<_$ImapValidImpl>(this, _$identity);

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
  factory _ImapValid({required final ImapConfig imapConfig}) = _$ImapValidImpl;

  ImapConfig get imapConfig;
  @JsonKey(ignore: true)
  _$$ImapValidImplCopyWith<_$ImapValidImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ImapTestingImplCopyWith<$Res> {
  factory _$$ImapTestingImplCopyWith(
          _$ImapTestingImpl value, $Res Function(_$ImapTestingImpl) then) =
      __$$ImapTestingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$ImapTestingImplCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$ImapTestingImpl>
    implements _$$ImapTestingImplCopyWith<$Res> {
  __$$ImapTestingImplCopyWithImpl(
      _$ImapTestingImpl _value, $Res Function(_$ImapTestingImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
  }) {
    return _then(_$ImapTestingImpl(
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

class _$ImapTestingImpl implements _ImapTesting {
  _$ImapTestingImpl({required this.imapConfig});

  @override
  final ImapConfig imapConfig;

  @override
  String toString() {
    return 'SyncConfigState.imapTesting(imapConfig: $imapConfig)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImapTestingImpl &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imapConfig);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ImapTestingImplCopyWith<_$ImapTestingImpl> get copyWith =>
      __$$ImapTestingImplCopyWithImpl<_$ImapTestingImpl>(this, _$identity);

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
  factory _ImapTesting({required final ImapConfig imapConfig}) =
      _$ImapTestingImpl;

  ImapConfig get imapConfig;
  @JsonKey(ignore: true)
  _$$ImapTestingImplCopyWith<_$ImapTestingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ImapInvalidImplCopyWith<$Res> {
  factory _$$ImapInvalidImplCopyWith(
          _$ImapInvalidImpl value, $Res Function(_$ImapInvalidImpl) then) =
      __$$ImapInvalidImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ImapConfig imapConfig, String errorMessage});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$ImapInvalidImplCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$ImapInvalidImpl>
    implements _$$ImapInvalidImplCopyWith<$Res> {
  __$$ImapInvalidImplCopyWithImpl(
      _$ImapInvalidImpl _value, $Res Function(_$ImapInvalidImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? errorMessage = null,
  }) {
    return _then(_$ImapInvalidImpl(
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

class _$ImapInvalidImpl implements _ImapInvalid {
  _$ImapInvalidImpl({required this.imapConfig, required this.errorMessage});

  @override
  final ImapConfig imapConfig;
  @override
  final String errorMessage;

  @override
  String toString() {
    return 'SyncConfigState.imapInvalid(imapConfig: $imapConfig, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImapInvalidImpl &&
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
  _$$ImapInvalidImplCopyWith<_$ImapInvalidImpl> get copyWith =>
      __$$ImapInvalidImplCopyWithImpl<_$ImapInvalidImpl>(this, _$identity);

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
      required final String errorMessage}) = _$ImapInvalidImpl;

  ImapConfig get imapConfig;
  String get errorMessage;
  @JsonKey(ignore: true)
  _$$ImapInvalidImplCopyWith<_$ImapInvalidImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$LoadingImplCopyWith<$Res> {
  factory _$$LoadingImplCopyWith(
          _$LoadingImpl value, $Res Function(_$LoadingImpl) then) =
      __$$LoadingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$LoadingImplCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$LoadingImpl>
    implements _$$LoadingImplCopyWith<$Res> {
  __$$LoadingImplCopyWithImpl(
      _$LoadingImpl _value, $Res Function(_$LoadingImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$LoadingImpl implements _Loading {
  _$LoadingImpl();

  @override
  String toString() {
    return 'SyncConfigState.loading()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$LoadingImpl);
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
  factory _Loading() = _$LoadingImpl;
}

/// @nodoc
abstract class _$$GeneratingImplCopyWith<$Res> {
  factory _$$GeneratingImplCopyWith(
          _$GeneratingImpl value, $Res Function(_$GeneratingImpl) then) =
      __$$GeneratingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$GeneratingImplCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$GeneratingImpl>
    implements _$$GeneratingImplCopyWith<$Res> {
  __$$GeneratingImplCopyWithImpl(
      _$GeneratingImpl _value, $Res Function(_$GeneratingImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$GeneratingImpl implements _Generating {
  _$GeneratingImpl();

  @override
  String toString() {
    return 'SyncConfigState.generating()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$GeneratingImpl);
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
  factory _Generating() = _$GeneratingImpl;
}

/// @nodoc
abstract class _$$EmptyImplCopyWith<$Res> {
  factory _$$EmptyImplCopyWith(
          _$EmptyImpl value, $Res Function(_$EmptyImpl) then) =
      __$$EmptyImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$EmptyImplCopyWithImpl<$Res>
    extends _$SyncConfigStateCopyWithImpl<$Res, _$EmptyImpl>
    implements _$$EmptyImplCopyWith<$Res> {
  __$$EmptyImplCopyWithImpl(
      _$EmptyImpl _value, $Res Function(_$EmptyImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$EmptyImpl implements _Empty {
  _$EmptyImpl();

  @override
  String toString() {
    return 'SyncConfigState.empty()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$EmptyImpl);
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
  factory _Empty() = _$EmptyImpl;
}
