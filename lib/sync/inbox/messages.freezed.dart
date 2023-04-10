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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$InboxIsolateMessage {
  SyncConfig get syncConfig => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            SyncConfig syncConfig,
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)
        init,
    required TResult Function(SyncConfig syncConfig) restart,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            SyncConfig syncConfig,
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)?
        init,
    TResult? Function(SyncConfig syncConfig)? restart,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            SyncConfig syncConfig,
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)?
        init,
    TResult Function(SyncConfig syncConfig)? restart,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InboxIsolateInitMessage value) init,
    required TResult Function(InboxIsolateRestartMessage value) restart,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InboxIsolateInitMessage value)? init,
    TResult? Function(InboxIsolateRestartMessage value)? restart,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InboxIsolateInitMessage value)? init,
    TResult Function(InboxIsolateRestartMessage value)? restart,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $InboxIsolateMessageCopyWith<InboxIsolateMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InboxIsolateMessageCopyWith<$Res> {
  factory $InboxIsolateMessageCopyWith(
          InboxIsolateMessage value, $Res Function(InboxIsolateMessage) then) =
      _$InboxIsolateMessageCopyWithImpl<$Res, InboxIsolateMessage>;
  @useResult
  $Res call({SyncConfig syncConfig});

  $SyncConfigCopyWith<$Res> get syncConfig;
}

/// @nodoc
class _$InboxIsolateMessageCopyWithImpl<$Res, $Val extends InboxIsolateMessage>
    implements $InboxIsolateMessageCopyWith<$Res> {
  _$InboxIsolateMessageCopyWithImpl(this._value, this._then);

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
abstract class _$$InboxIsolateInitMessageCopyWith<$Res>
    implements $InboxIsolateMessageCopyWith<$Res> {
  factory _$$InboxIsolateInitMessageCopyWith(_$InboxIsolateInitMessage value,
          $Res Function(_$InboxIsolateInitMessage) then) =
      __$$InboxIsolateInitMessageCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SyncConfig syncConfig,
      SendPort loggingDbConnectPort,
      SendPort journalDbConnectPort,
      SendPort settingsDbConnectPort,
      bool allowInvalidCert,
      String? hostHash,
      Directory docDir,
      int lastReadUid});

  @override
  $SyncConfigCopyWith<$Res> get syncConfig;
}

/// @nodoc
class __$$InboxIsolateInitMessageCopyWithImpl<$Res>
    extends _$InboxIsolateMessageCopyWithImpl<$Res, _$InboxIsolateInitMessage>
    implements _$$InboxIsolateInitMessageCopyWith<$Res> {
  __$$InboxIsolateInitMessageCopyWithImpl(_$InboxIsolateInitMessage _value,
      $Res Function(_$InboxIsolateInitMessage) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? syncConfig = null,
    Object? loggingDbConnectPort = null,
    Object? journalDbConnectPort = null,
    Object? settingsDbConnectPort = null,
    Object? allowInvalidCert = null,
    Object? hostHash = freezed,
    Object? docDir = null,
    Object? lastReadUid = null,
  }) {
    return _then(_$InboxIsolateInitMessage(
      syncConfig: null == syncConfig
          ? _value.syncConfig
          : syncConfig // ignore: cast_nullable_to_non_nullable
              as SyncConfig,
      loggingDbConnectPort: null == loggingDbConnectPort
          ? _value.loggingDbConnectPort
          : loggingDbConnectPort // ignore: cast_nullable_to_non_nullable
              as SendPort,
      journalDbConnectPort: null == journalDbConnectPort
          ? _value.journalDbConnectPort
          : journalDbConnectPort // ignore: cast_nullable_to_non_nullable
              as SendPort,
      settingsDbConnectPort: null == settingsDbConnectPort
          ? _value.settingsDbConnectPort
          : settingsDbConnectPort // ignore: cast_nullable_to_non_nullable
              as SendPort,
      allowInvalidCert: null == allowInvalidCert
          ? _value.allowInvalidCert
          : allowInvalidCert // ignore: cast_nullable_to_non_nullable
              as bool,
      hostHash: freezed == hostHash
          ? _value.hostHash
          : hostHash // ignore: cast_nullable_to_non_nullable
              as String?,
      docDir: null == docDir
          ? _value.docDir
          : docDir // ignore: cast_nullable_to_non_nullable
              as Directory,
      lastReadUid: null == lastReadUid
          ? _value.lastReadUid
          : lastReadUid // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$InboxIsolateInitMessage implements InboxIsolateInitMessage {
  _$InboxIsolateInitMessage(
      {required this.syncConfig,
      required this.loggingDbConnectPort,
      required this.journalDbConnectPort,
      required this.settingsDbConnectPort,
      required this.allowInvalidCert,
      required this.hostHash,
      required this.docDir,
      required this.lastReadUid});

  @override
  final SyncConfig syncConfig;
  @override
  final SendPort loggingDbConnectPort;
  @override
  final SendPort journalDbConnectPort;
  @override
  final SendPort settingsDbConnectPort;
  @override
  final bool allowInvalidCert;
  @override
  final String? hostHash;
  @override
  final Directory docDir;
  @override
  final int lastReadUid;

  @override
  String toString() {
    return 'InboxIsolateMessage.init(syncConfig: $syncConfig, loggingDbConnectPort: $loggingDbConnectPort, journalDbConnectPort: $journalDbConnectPort, settingsDbConnectPort: $settingsDbConnectPort, allowInvalidCert: $allowInvalidCert, hostHash: $hostHash, docDir: $docDir, lastReadUid: $lastReadUid)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InboxIsolateInitMessage &&
            (identical(other.syncConfig, syncConfig) ||
                other.syncConfig == syncConfig) &&
            (identical(other.loggingDbConnectPort, loggingDbConnectPort) ||
                other.loggingDbConnectPort == loggingDbConnectPort) &&
            (identical(other.journalDbConnectPort, journalDbConnectPort) ||
                other.journalDbConnectPort == journalDbConnectPort) &&
            (identical(other.settingsDbConnectPort, settingsDbConnectPort) ||
                other.settingsDbConnectPort == settingsDbConnectPort) &&
            (identical(other.allowInvalidCert, allowInvalidCert) ||
                other.allowInvalidCert == allowInvalidCert) &&
            (identical(other.hostHash, hostHash) ||
                other.hostHash == hostHash) &&
            (identical(other.docDir, docDir) || other.docDir == docDir) &&
            (identical(other.lastReadUid, lastReadUid) ||
                other.lastReadUid == lastReadUid));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      syncConfig,
      loggingDbConnectPort,
      journalDbConnectPort,
      settingsDbConnectPort,
      allowInvalidCert,
      hostHash,
      docDir,
      lastReadUid);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$InboxIsolateInitMessageCopyWith<_$InboxIsolateInitMessage> get copyWith =>
      __$$InboxIsolateInitMessageCopyWithImpl<_$InboxIsolateInitMessage>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            SyncConfig syncConfig,
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)
        init,
    required TResult Function(SyncConfig syncConfig) restart,
  }) {
    return init(syncConfig, loggingDbConnectPort, journalDbConnectPort,
        settingsDbConnectPort, allowInvalidCert, hostHash, docDir, lastReadUid);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            SyncConfig syncConfig,
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)?
        init,
    TResult? Function(SyncConfig syncConfig)? restart,
  }) {
    return init?.call(syncConfig, loggingDbConnectPort, journalDbConnectPort,
        settingsDbConnectPort, allowInvalidCert, hostHash, docDir, lastReadUid);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            SyncConfig syncConfig,
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)?
        init,
    TResult Function(SyncConfig syncConfig)? restart,
    required TResult orElse(),
  }) {
    if (init != null) {
      return init(
          syncConfig,
          loggingDbConnectPort,
          journalDbConnectPort,
          settingsDbConnectPort,
          allowInvalidCert,
          hostHash,
          docDir,
          lastReadUid);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InboxIsolateInitMessage value) init,
    required TResult Function(InboxIsolateRestartMessage value) restart,
  }) {
    return init(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InboxIsolateInitMessage value)? init,
    TResult? Function(InboxIsolateRestartMessage value)? restart,
  }) {
    return init?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InboxIsolateInitMessage value)? init,
    TResult Function(InboxIsolateRestartMessage value)? restart,
    required TResult orElse(),
  }) {
    if (init != null) {
      return init(this);
    }
    return orElse();
  }
}

abstract class InboxIsolateInitMessage implements InboxIsolateMessage {
  factory InboxIsolateInitMessage(
      {required final SyncConfig syncConfig,
      required final SendPort loggingDbConnectPort,
      required final SendPort journalDbConnectPort,
      required final SendPort settingsDbConnectPort,
      required final bool allowInvalidCert,
      required final String? hostHash,
      required final Directory docDir,
      required final int lastReadUid}) = _$InboxIsolateInitMessage;

  @override
  SyncConfig get syncConfig;
  SendPort get loggingDbConnectPort;
  SendPort get journalDbConnectPort;
  SendPort get settingsDbConnectPort;
  bool get allowInvalidCert;
  String? get hostHash;
  Directory get docDir;
  int get lastReadUid;
  @override
  @JsonKey(ignore: true)
  _$$InboxIsolateInitMessageCopyWith<_$InboxIsolateInitMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InboxIsolateRestartMessageCopyWith<$Res>
    implements $InboxIsolateMessageCopyWith<$Res> {
  factory _$$InboxIsolateRestartMessageCopyWith(
          _$InboxIsolateRestartMessage value,
          $Res Function(_$InboxIsolateRestartMessage) then) =
      __$$InboxIsolateRestartMessageCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({SyncConfig syncConfig});

  @override
  $SyncConfigCopyWith<$Res> get syncConfig;
}

/// @nodoc
class __$$InboxIsolateRestartMessageCopyWithImpl<$Res>
    extends _$InboxIsolateMessageCopyWithImpl<$Res,
        _$InboxIsolateRestartMessage>
    implements _$$InboxIsolateRestartMessageCopyWith<$Res> {
  __$$InboxIsolateRestartMessageCopyWithImpl(
      _$InboxIsolateRestartMessage _value,
      $Res Function(_$InboxIsolateRestartMessage) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? syncConfig = null,
  }) {
    return _then(_$InboxIsolateRestartMessage(
      syncConfig: null == syncConfig
          ? _value.syncConfig
          : syncConfig // ignore: cast_nullable_to_non_nullable
              as SyncConfig,
    ));
  }
}

/// @nodoc

class _$InboxIsolateRestartMessage implements InboxIsolateRestartMessage {
  _$InboxIsolateRestartMessage({required this.syncConfig});

  @override
  final SyncConfig syncConfig;

  @override
  String toString() {
    return 'InboxIsolateMessage.restart(syncConfig: $syncConfig)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InboxIsolateRestartMessage &&
            (identical(other.syncConfig, syncConfig) ||
                other.syncConfig == syncConfig));
  }

  @override
  int get hashCode => Object.hash(runtimeType, syncConfig);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$InboxIsolateRestartMessageCopyWith<_$InboxIsolateRestartMessage>
      get copyWith => __$$InboxIsolateRestartMessageCopyWithImpl<
          _$InboxIsolateRestartMessage>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            SyncConfig syncConfig,
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)
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
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)?
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
            SendPort loggingDbConnectPort,
            SendPort journalDbConnectPort,
            SendPort settingsDbConnectPort,
            bool allowInvalidCert,
            String? hostHash,
            Directory docDir,
            int lastReadUid)?
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
    required TResult Function(InboxIsolateInitMessage value) init,
    required TResult Function(InboxIsolateRestartMessage value) restart,
  }) {
    return restart(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InboxIsolateInitMessage value)? init,
    TResult? Function(InboxIsolateRestartMessage value)? restart,
  }) {
    return restart?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InboxIsolateInitMessage value)? init,
    TResult Function(InboxIsolateRestartMessage value)? restart,
    required TResult orElse(),
  }) {
    if (restart != null) {
      return restart(this);
    }
    return orElse();
  }
}

abstract class InboxIsolateRestartMessage implements InboxIsolateMessage {
  factory InboxIsolateRestartMessage({required final SyncConfig syncConfig}) =
      _$InboxIsolateRestartMessage;

  @override
  SyncConfig get syncConfig;
  @override
  @JsonKey(ignore: true)
  _$$InboxIsolateRestartMessageCopyWith<_$InboxIsolateRestartMessage>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$IsolateInboxMessage {
  int get lastReadUid => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int lastReadUid) setLastReadUid,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int lastReadUid)? setLastReadUid,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int lastReadUid)? setLastReadUid,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(IsolateInboxLastReadMessage value) setLastReadUid,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(IsolateInboxLastReadMessage value)? setLastReadUid,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(IsolateInboxLastReadMessage value)? setLastReadUid,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $IsolateInboxMessageCopyWith<IsolateInboxMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IsolateInboxMessageCopyWith<$Res> {
  factory $IsolateInboxMessageCopyWith(
          IsolateInboxMessage value, $Res Function(IsolateInboxMessage) then) =
      _$IsolateInboxMessageCopyWithImpl<$Res, IsolateInboxMessage>;
  @useResult
  $Res call({int lastReadUid});
}

/// @nodoc
class _$IsolateInboxMessageCopyWithImpl<$Res, $Val extends IsolateInboxMessage>
    implements $IsolateInboxMessageCopyWith<$Res> {
  _$IsolateInboxMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lastReadUid = null,
  }) {
    return _then(_value.copyWith(
      lastReadUid: null == lastReadUid
          ? _value.lastReadUid
          : lastReadUid // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$IsolateInboxLastReadMessageCopyWith<$Res>
    implements $IsolateInboxMessageCopyWith<$Res> {
  factory _$$IsolateInboxLastReadMessageCopyWith(
          _$IsolateInboxLastReadMessage value,
          $Res Function(_$IsolateInboxLastReadMessage) then) =
      __$$IsolateInboxLastReadMessageCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int lastReadUid});
}

/// @nodoc
class __$$IsolateInboxLastReadMessageCopyWithImpl<$Res>
    extends _$IsolateInboxMessageCopyWithImpl<$Res,
        _$IsolateInboxLastReadMessage>
    implements _$$IsolateInboxLastReadMessageCopyWith<$Res> {
  __$$IsolateInboxLastReadMessageCopyWithImpl(
      _$IsolateInboxLastReadMessage _value,
      $Res Function(_$IsolateInboxLastReadMessage) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lastReadUid = null,
  }) {
    return _then(_$IsolateInboxLastReadMessage(
      lastReadUid: null == lastReadUid
          ? _value.lastReadUid
          : lastReadUid // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$IsolateInboxLastReadMessage implements IsolateInboxLastReadMessage {
  _$IsolateInboxLastReadMessage({required this.lastReadUid});

  @override
  final int lastReadUid;

  @override
  String toString() {
    return 'IsolateInboxMessage.setLastReadUid(lastReadUid: $lastReadUid)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IsolateInboxLastReadMessage &&
            (identical(other.lastReadUid, lastReadUid) ||
                other.lastReadUid == lastReadUid));
  }

  @override
  int get hashCode => Object.hash(runtimeType, lastReadUid);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$IsolateInboxLastReadMessageCopyWith<_$IsolateInboxLastReadMessage>
      get copyWith => __$$IsolateInboxLastReadMessageCopyWithImpl<
          _$IsolateInboxLastReadMessage>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int lastReadUid) setLastReadUid,
  }) {
    return setLastReadUid(lastReadUid);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int lastReadUid)? setLastReadUid,
  }) {
    return setLastReadUid?.call(lastReadUid);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int lastReadUid)? setLastReadUid,
    required TResult orElse(),
  }) {
    if (setLastReadUid != null) {
      return setLastReadUid(lastReadUid);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(IsolateInboxLastReadMessage value) setLastReadUid,
  }) {
    return setLastReadUid(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(IsolateInboxLastReadMessage value)? setLastReadUid,
  }) {
    return setLastReadUid?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(IsolateInboxLastReadMessage value)? setLastReadUid,
    required TResult orElse(),
  }) {
    if (setLastReadUid != null) {
      return setLastReadUid(this);
    }
    return orElse();
  }
}

abstract class IsolateInboxLastReadMessage implements IsolateInboxMessage {
  factory IsolateInboxLastReadMessage({required final int lastReadUid}) =
      _$IsolateInboxLastReadMessage;

  @override
  int get lastReadUid;
  @override
  @JsonKey(ignore: true)
  _$$IsolateInboxLastReadMessageCopyWith<_$IsolateInboxLastReadMessage>
      get copyWith => throw _privateConstructorUsedError;
}
