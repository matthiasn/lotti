// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'messages.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$OutboxIsolateMessage {
  SyncConfig get syncConfig => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)
        init,
    required TResult Function(SyncConfig syncConfig) restart,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)?
        init,
    TResult? Function(SyncConfig syncConfig)? restart,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)?
        init,
    TResult Function(SyncConfig syncConfig)? restart,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OutboxIsolateInitMessage value) init,
    required TResult Function(OutboxIsolateRestartMessage value) restart,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OutboxIsolateInitMessage value)? init,
    TResult? Function(OutboxIsolateRestartMessage value)? restart,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OutboxIsolateInitMessage value)? init,
    TResult Function(OutboxIsolateRestartMessage value)? restart,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $OutboxIsolateMessageCopyWith<OutboxIsolateMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OutboxIsolateMessageCopyWith<$Res> {
  factory $OutboxIsolateMessageCopyWith(OutboxIsolateMessage value,
          $Res Function(OutboxIsolateMessage) then) =
      _$OutboxIsolateMessageCopyWithImpl<$Res, OutboxIsolateMessage>;
  @useResult
  $Res call({SyncConfig syncConfig});

  $SyncConfigCopyWith<$Res> get syncConfig;
}

/// @nodoc
class _$OutboxIsolateMessageCopyWithImpl<$Res,
        $Val extends OutboxIsolateMessage>
    implements $OutboxIsolateMessageCopyWith<$Res> {
  _$OutboxIsolateMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? syncConfig = null,
  }) {
    return _then(_value.copyWith(
      syncConfig: null == syncConfig
          ? _value.syncConfig
          : syncConfig // ignore: cast_nullable_to_non_nullable
              as SyncConfig,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $SyncConfigCopyWith<$Res> get syncConfig {
    return $SyncConfigCopyWith<$Res>(_value.syncConfig, (value) {
      return _then(_value.copyWith(syncConfig: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OutboxIsolateInitMessageImplCopyWith<$Res>
    implements $OutboxIsolateMessageCopyWith<$Res> {
  factory _$$OutboxIsolateInitMessageImplCopyWith(
          _$OutboxIsolateInitMessageImpl value,
          $Res Function(_$OutboxIsolateInitMessageImpl) then) =
      __$$OutboxIsolateInitMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SyncConfig syncConfig,
      SendPort syncDbConnectPort,
      SendPort loggingDbConnectPort,
      SendPort settingsDbConnectPort,
      bool allowInvalidCert,
      Directory docDir});

  @override
  $SyncConfigCopyWith<$Res> get syncConfig;
}

/// @nodoc
class __$$OutboxIsolateInitMessageImplCopyWithImpl<$Res>
    extends _$OutboxIsolateMessageCopyWithImpl<$Res,
        _$OutboxIsolateInitMessageImpl>
    implements _$$OutboxIsolateInitMessageImplCopyWith<$Res> {
  __$$OutboxIsolateInitMessageImplCopyWithImpl(
      _$OutboxIsolateInitMessageImpl _value,
      $Res Function(_$OutboxIsolateInitMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? syncConfig = null,
    Object? syncDbConnectPort = null,
    Object? loggingDbConnectPort = null,
    Object? settingsDbConnectPort = null,
    Object? allowInvalidCert = null,
    Object? docDir = null,
  }) {
    return _then(_$OutboxIsolateInitMessageImpl(
      syncConfig: null == syncConfig
          ? _value.syncConfig
          : syncConfig // ignore: cast_nullable_to_non_nullable
              as SyncConfig,
      syncDbConnectPort: null == syncDbConnectPort
          ? _value.syncDbConnectPort
          : syncDbConnectPort // ignore: cast_nullable_to_non_nullable
              as SendPort,
      loggingDbConnectPort: null == loggingDbConnectPort
          ? _value.loggingDbConnectPort
          : loggingDbConnectPort // ignore: cast_nullable_to_non_nullable
              as SendPort,
      settingsDbConnectPort: null == settingsDbConnectPort
          ? _value.settingsDbConnectPort
          : settingsDbConnectPort // ignore: cast_nullable_to_non_nullable
              as SendPort,
      allowInvalidCert: null == allowInvalidCert
          ? _value.allowInvalidCert
          : allowInvalidCert // ignore: cast_nullable_to_non_nullable
              as bool,
      docDir: null == docDir
          ? _value.docDir
          : docDir // ignore: cast_nullable_to_non_nullable
              as Directory,
    ));
  }
}

/// @nodoc

class _$OutboxIsolateInitMessageImpl implements OutboxIsolateInitMessage {
  _$OutboxIsolateInitMessageImpl(
      {required this.syncConfig,
      required this.syncDbConnectPort,
      required this.loggingDbConnectPort,
      required this.settingsDbConnectPort,
      required this.allowInvalidCert,
      required this.docDir});

  @override
  final SyncConfig syncConfig;
  @override
  final SendPort syncDbConnectPort;
  @override
  final SendPort loggingDbConnectPort;
  @override
  final SendPort settingsDbConnectPort;
  @override
  final bool allowInvalidCert;
  @override
  final Directory docDir;

  @override
  String toString() {
    return 'OutboxIsolateMessage.init(syncConfig: $syncConfig, syncDbConnectPort: $syncDbConnectPort, loggingDbConnectPort: $loggingDbConnectPort, settingsDbConnectPort: $settingsDbConnectPort, allowInvalidCert: $allowInvalidCert, docDir: $docDir)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OutboxIsolateInitMessageImpl &&
            (identical(other.syncConfig, syncConfig) ||
                other.syncConfig == syncConfig) &&
            (identical(other.syncDbConnectPort, syncDbConnectPort) ||
                other.syncDbConnectPort == syncDbConnectPort) &&
            (identical(other.loggingDbConnectPort, loggingDbConnectPort) ||
                other.loggingDbConnectPort == loggingDbConnectPort) &&
            (identical(other.settingsDbConnectPort, settingsDbConnectPort) ||
                other.settingsDbConnectPort == settingsDbConnectPort) &&
            (identical(other.allowInvalidCert, allowInvalidCert) ||
                other.allowInvalidCert == allowInvalidCert) &&
            (identical(other.docDir, docDir) || other.docDir == docDir));
  }

  @override
  int get hashCode => Object.hash(runtimeType, syncConfig, syncDbConnectPort,
      loggingDbConnectPort, settingsDbConnectPort, allowInvalidCert, docDir);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$OutboxIsolateInitMessageImplCopyWith<_$OutboxIsolateInitMessageImpl>
      get copyWith => __$$OutboxIsolateInitMessageImplCopyWithImpl<
          _$OutboxIsolateInitMessageImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)
        init,
    required TResult Function(SyncConfig syncConfig) restart,
  }) {
    return init(syncConfig, syncDbConnectPort, loggingDbConnectPort,
        settingsDbConnectPort, allowInvalidCert, docDir);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)?
        init,
    TResult? Function(SyncConfig syncConfig)? restart,
  }) {
    return init?.call(syncConfig, syncDbConnectPort, loggingDbConnectPort,
        settingsDbConnectPort, allowInvalidCert, docDir);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)?
        init,
    TResult Function(SyncConfig syncConfig)? restart,
    required TResult orElse(),
  }) {
    if (init != null) {
      return init(syncConfig, syncDbConnectPort, loggingDbConnectPort,
          settingsDbConnectPort, allowInvalidCert, docDir);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OutboxIsolateInitMessage value) init,
    required TResult Function(OutboxIsolateRestartMessage value) restart,
  }) {
    return init(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OutboxIsolateInitMessage value)? init,
    TResult? Function(OutboxIsolateRestartMessage value)? restart,
  }) {
    return init?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OutboxIsolateInitMessage value)? init,
    TResult Function(OutboxIsolateRestartMessage value)? restart,
    required TResult orElse(),
  }) {
    if (init != null) {
      return init(this);
    }
    return orElse();
  }
}

abstract class OutboxIsolateInitMessage implements OutboxIsolateMessage {
  factory OutboxIsolateInitMessage(
      {required final SyncConfig syncConfig,
      required final SendPort syncDbConnectPort,
      required final SendPort loggingDbConnectPort,
      required final SendPort settingsDbConnectPort,
      required final bool allowInvalidCert,
      required final Directory docDir}) = _$OutboxIsolateInitMessageImpl;

  @override
  SyncConfig get syncConfig;
  SendPort get syncDbConnectPort;
  SendPort get loggingDbConnectPort;
  SendPort get settingsDbConnectPort;
  bool get allowInvalidCert;
  Directory get docDir;
  @override
  @JsonKey(ignore: true)
  _$$OutboxIsolateInitMessageImplCopyWith<_$OutboxIsolateInitMessageImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$OutboxIsolateRestartMessageImplCopyWith<$Res>
    implements $OutboxIsolateMessageCopyWith<$Res> {
  factory _$$OutboxIsolateRestartMessageImplCopyWith(
          _$OutboxIsolateRestartMessageImpl value,
          $Res Function(_$OutboxIsolateRestartMessageImpl) then) =
      __$$OutboxIsolateRestartMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({SyncConfig syncConfig});

  @override
  $SyncConfigCopyWith<$Res> get syncConfig;
}

/// @nodoc
class __$$OutboxIsolateRestartMessageImplCopyWithImpl<$Res>
    extends _$OutboxIsolateMessageCopyWithImpl<$Res,
        _$OutboxIsolateRestartMessageImpl>
    implements _$$OutboxIsolateRestartMessageImplCopyWith<$Res> {
  __$$OutboxIsolateRestartMessageImplCopyWithImpl(
      _$OutboxIsolateRestartMessageImpl _value,
      $Res Function(_$OutboxIsolateRestartMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? syncConfig = null,
  }) {
    return _then(_$OutboxIsolateRestartMessageImpl(
      syncConfig: null == syncConfig
          ? _value.syncConfig
          : syncConfig // ignore: cast_nullable_to_non_nullable
              as SyncConfig,
    ));
  }
}

/// @nodoc

class _$OutboxIsolateRestartMessageImpl implements OutboxIsolateRestartMessage {
  _$OutboxIsolateRestartMessageImpl({required this.syncConfig});

  @override
  final SyncConfig syncConfig;

  @override
  String toString() {
    return 'OutboxIsolateMessage.restart(syncConfig: $syncConfig)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OutboxIsolateRestartMessageImpl &&
            (identical(other.syncConfig, syncConfig) ||
                other.syncConfig == syncConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, syncConfig);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$OutboxIsolateRestartMessageImplCopyWith<_$OutboxIsolateRestartMessageImpl>
      get copyWith => __$$OutboxIsolateRestartMessageImplCopyWithImpl<
          _$OutboxIsolateRestartMessageImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)
        init,
    required TResult Function(SyncConfig syncConfig) restart,
  }) {
    return restart(syncConfig);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)?
        init,
    TResult? Function(SyncConfig syncConfig)? restart,
  }) {
    return restart?.call(syncConfig);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            SyncConfig syncConfig,
            SendPort syncDbConnectPort,
            SendPort loggingDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            Directory docDir)?
        init,
    TResult Function(SyncConfig syncConfig)? restart,
    required TResult orElse(),
  }) {
    if (restart != null) {
      return restart(syncConfig);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OutboxIsolateInitMessage value) init,
    required TResult Function(OutboxIsolateRestartMessage value) restart,
  }) {
    return restart(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OutboxIsolateInitMessage value)? init,
    TResult? Function(OutboxIsolateRestartMessage value)? restart,
  }) {
    return restart?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OutboxIsolateInitMessage value)? init,
    TResult Function(OutboxIsolateRestartMessage value)? restart,
    required TResult orElse(),
  }) {
    if (restart != null) {
      return restart(this);
    }
    return orElse();
  }
}

abstract class OutboxIsolateRestartMessage implements OutboxIsolateMessage {
  factory OutboxIsolateRestartMessage({required final SyncConfig syncConfig}) =
      _$OutboxIsolateRestartMessageImpl;

  @override
  SyncConfig get syncConfig;
  @override
  @JsonKey(ignore: true)
  _$$OutboxIsolateRestartMessageImplCopyWith<_$OutboxIsolateRestartMessageImpl>
      get copyWith => throw _privateConstructorUsedError;
}
