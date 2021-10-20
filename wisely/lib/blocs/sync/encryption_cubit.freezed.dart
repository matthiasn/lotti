// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'encryption_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
class _$EncryptionStateTearOff {
  const _$EncryptionStateTearOff();

  _EncryptionState call({String? sharedKey, ImapConfig? imapConfig}) {
    return _EncryptionState(
      sharedKey: sharedKey,
      imapConfig: imapConfig,
    );
  }

  Loading loading() {
    return Loading();
  }

  Generating generating() {
    return Generating();
  }

  Empty empty() {
    return Empty();
  }
}

/// @nodoc
const $EncryptionState = _$EncryptionStateTearOff();

/// @nodoc
mixin _$EncryptionState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig) $default, {
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_EncryptionState value) $default, {
    required TResult Function(Loading value) loading,
    required TResult Function(Generating value) generating,
    required TResult Function(Empty value) empty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EncryptionStateCopyWith<$Res> {
  factory $EncryptionStateCopyWith(
          EncryptionState value, $Res Function(EncryptionState) then) =
      _$EncryptionStateCopyWithImpl<$Res>;
}

/// @nodoc
class _$EncryptionStateCopyWithImpl<$Res>
    implements $EncryptionStateCopyWith<$Res> {
  _$EncryptionStateCopyWithImpl(this._value, this._then);

  final EncryptionState _value;
  // ignore: unused_field
  final $Res Function(EncryptionState) _then;
}

/// @nodoc
abstract class _$EncryptionStateCopyWith<$Res> {
  factory _$EncryptionStateCopyWith(
          _EncryptionState value, $Res Function(_EncryptionState) then) =
      __$EncryptionStateCopyWithImpl<$Res>;
  $Res call({String? sharedKey, ImapConfig? imapConfig});

  $ImapConfigCopyWith<$Res>? get imapConfig;
}

/// @nodoc
class __$EncryptionStateCopyWithImpl<$Res>
    extends _$EncryptionStateCopyWithImpl<$Res>
    implements _$EncryptionStateCopyWith<$Res> {
  __$EncryptionStateCopyWithImpl(
      _EncryptionState _value, $Res Function(_EncryptionState) _then)
      : super(_value, (v) => _then(v as _EncryptionState));

  @override
  _EncryptionState get _value => super._value as _EncryptionState;

  @override
  $Res call({
    Object? sharedKey = freezed,
    Object? imapConfig = freezed,
  }) {
    return _then(_EncryptionState(
      sharedKey: sharedKey == freezed
          ? _value.sharedKey
          : sharedKey // ignore: cast_nullable_to_non_nullable
              as String?,
      imapConfig: imapConfig == freezed
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig?,
    ));
  }

  @override
  $ImapConfigCopyWith<$Res>? get imapConfig {
    if (_value.imapConfig == null) {
      return null;
    }

    return $ImapConfigCopyWith<$Res>(_value.imapConfig!, (value) {
      return _then(_value.copyWith(imapConfig: value));
    });
  }
}

/// @nodoc

class _$_EncryptionState implements _EncryptionState {
  _$_EncryptionState({this.sharedKey, this.imapConfig});

  @override
  final String? sharedKey;
  @override
  final ImapConfig? imapConfig;

  @override
  String toString() {
    return 'EncryptionState(sharedKey: $sharedKey, imapConfig: $imapConfig)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _EncryptionState &&
            (identical(other.sharedKey, sharedKey) ||
                other.sharedKey == sharedKey) &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, sharedKey, imapConfig);

  @JsonKey(ignore: true)
  @override
  _$EncryptionStateCopyWith<_EncryptionState> get copyWith =>
      __$EncryptionStateCopyWithImpl<_EncryptionState>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig) $default, {
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return $default(sharedKey, imapConfig);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
  }) {
    return $default?.call(sharedKey, imapConfig);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
    required TResult orElse(),
  }) {
    if ($default != null) {
      return $default(sharedKey, imapConfig);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_EncryptionState value) $default, {
    required TResult Function(Loading value) loading,
    required TResult Function(Generating value) generating,
    required TResult Function(Empty value) empty,
  }) {
    return $default(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
  }) {
    return $default?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
    required TResult orElse(),
  }) {
    if ($default != null) {
      return $default(this);
    }
    return orElse();
  }
}

abstract class _EncryptionState implements EncryptionState {
  factory _EncryptionState({String? sharedKey, ImapConfig? imapConfig}) =
      _$_EncryptionState;

  String? get sharedKey;
  ImapConfig? get imapConfig;
  @JsonKey(ignore: true)
  _$EncryptionStateCopyWith<_EncryptionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LoadingCopyWith<$Res> {
  factory $LoadingCopyWith(Loading value, $Res Function(Loading) then) =
      _$LoadingCopyWithImpl<$Res>;
}

/// @nodoc
class _$LoadingCopyWithImpl<$Res> extends _$EncryptionStateCopyWithImpl<$Res>
    implements $LoadingCopyWith<$Res> {
  _$LoadingCopyWithImpl(Loading _value, $Res Function(Loading) _then)
      : super(_value, (v) => _then(v as Loading));

  @override
  Loading get _value => super._value as Loading;
}

/// @nodoc

class _$Loading implements Loading {
  _$Loading();

  @override
  String toString() {
    return 'EncryptionState.loading()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Loading);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig) $default, {
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
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
  TResult map<TResult extends Object?>(
    TResult Function(_EncryptionState value) $default, {
    required TResult Function(Loading value) loading,
    required TResult Function(Generating value) generating,
    required TResult Function(Empty value) empty,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class Loading implements EncryptionState {
  factory Loading() = _$Loading;
}

/// @nodoc
abstract class $GeneratingCopyWith<$Res> {
  factory $GeneratingCopyWith(
          Generating value, $Res Function(Generating) then) =
      _$GeneratingCopyWithImpl<$Res>;
}

/// @nodoc
class _$GeneratingCopyWithImpl<$Res> extends _$EncryptionStateCopyWithImpl<$Res>
    implements $GeneratingCopyWith<$Res> {
  _$GeneratingCopyWithImpl(Generating _value, $Res Function(Generating) _then)
      : super(_value, (v) => _then(v as Generating));

  @override
  Generating get _value => super._value as Generating;
}

/// @nodoc

class _$Generating implements Generating {
  _$Generating();

  @override
  String toString() {
    return 'EncryptionState.generating()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Generating);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig) $default, {
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return generating();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
  }) {
    return generating?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
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
  TResult map<TResult extends Object?>(
    TResult Function(_EncryptionState value) $default, {
    required TResult Function(Loading value) loading,
    required TResult Function(Generating value) generating,
    required TResult Function(Empty value) empty,
  }) {
    return generating(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
  }) {
    return generating?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
    required TResult orElse(),
  }) {
    if (generating != null) {
      return generating(this);
    }
    return orElse();
  }
}

abstract class Generating implements EncryptionState {
  factory Generating() = _$Generating;
}

/// @nodoc
abstract class $EmptyCopyWith<$Res> {
  factory $EmptyCopyWith(Empty value, $Res Function(Empty) then) =
      _$EmptyCopyWithImpl<$Res>;
}

/// @nodoc
class _$EmptyCopyWithImpl<$Res> extends _$EncryptionStateCopyWithImpl<$Res>
    implements $EmptyCopyWith<$Res> {
  _$EmptyCopyWithImpl(Empty _value, $Res Function(Empty) _then)
      : super(_value, (v) => _then(v as Empty));

  @override
  Empty get _value => super._value as Empty;
}

/// @nodoc

class _$Empty implements Empty {
  _$Empty();

  @override
  String toString() {
    return 'EncryptionState.empty()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Empty);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig) $default, {
    required TResult Function() loading,
    required TResult Function() generating,
    required TResult Function() empty,
  }) {
    return empty();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
    TResult Function()? loading,
    TResult Function()? generating,
    TResult Function()? empty,
  }) {
    return empty?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String? sharedKey, ImapConfig? imapConfig)? $default, {
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
  TResult map<TResult extends Object?>(
    TResult Function(_EncryptionState value) $default, {
    required TResult Function(Loading value) loading,
    required TResult Function(Generating value) generating,
    required TResult Function(Empty value) empty,
  }) {
    return empty(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
  }) {
    return empty?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EncryptionState value)? $default, {
    TResult Function(Loading value)? loading,
    TResult Function(Generating value)? generating,
    TResult Function(Empty value)? empty,
    required TResult orElse(),
  }) {
    if (empty != null) {
      return empty(this);
    }
    return orElse();
  }
}

abstract class Empty implements EncryptionState {
  factory Empty() = _$Empty;
}
