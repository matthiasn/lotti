// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ImapConfig _$ImapConfigFromJson(Map<String, dynamic> json) {
  return _ImapConfig.fromJson(json);
}

/// @nodoc
mixin _$ImapConfig {
  String get host => throw _privateConstructorUsedError;
  String get folder => throw _privateConstructorUsedError;
  String get userName => throw _privateConstructorUsedError;
  String get password => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ImapConfigCopyWith<ImapConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImapConfigCopyWith<$Res> {
  factory $ImapConfigCopyWith(
          ImapConfig value, $Res Function(ImapConfig) then) =
      _$ImapConfigCopyWithImpl<$Res, ImapConfig>;
  @useResult
  $Res call(
      {String host, String folder, String userName, String password, int port});
}

/// @nodoc
class _$ImapConfigCopyWithImpl<$Res, $Val extends ImapConfig>
    implements $ImapConfigCopyWith<$Res> {
  _$ImapConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? folder = null,
    Object? userName = null,
    Object? password = null,
    Object? port = null,
  }) {
    return _then(_value.copyWith(
      host: null == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      folder: null == folder
          ? _value.folder
          : folder // ignore: cast_nullable_to_non_nullable
              as String,
      userName: null == userName
          ? _value.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ImapConfigImplCopyWith<$Res>
    implements $ImapConfigCopyWith<$Res> {
  factory _$$ImapConfigImplCopyWith(
          _$ImapConfigImpl value, $Res Function(_$ImapConfigImpl) then) =
      __$$ImapConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String host, String folder, String userName, String password, int port});
}

/// @nodoc
class __$$ImapConfigImplCopyWithImpl<$Res>
    extends _$ImapConfigCopyWithImpl<$Res, _$ImapConfigImpl>
    implements _$$ImapConfigImplCopyWith<$Res> {
  __$$ImapConfigImplCopyWithImpl(
      _$ImapConfigImpl _value, $Res Function(_$ImapConfigImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? folder = null,
    Object? userName = null,
    Object? password = null,
    Object? port = null,
  }) {
    return _then(_$ImapConfigImpl(
      host: null == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      folder: null == folder
          ? _value.folder
          : folder // ignore: cast_nullable_to_non_nullable
              as String,
      userName: null == userName
          ? _value.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ImapConfigImpl implements _ImapConfig {
  const _$ImapConfigImpl(
      {required this.host,
      required this.folder,
      required this.userName,
      required this.password,
      required this.port});

  factory _$ImapConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$ImapConfigImplFromJson(json);

  @override
  final String host;
  @override
  final String folder;
  @override
  final String userName;
  @override
  final String password;
  @override
  final int port;

  @override
  String toString() {
    return 'ImapConfig(host: $host, folder: $folder, userName: $userName, password: $password, port: $port)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImapConfigImpl &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.folder, folder) || other.folder == folder) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.port, port) || other.port == port));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, host, folder, userName, password, port);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ImapConfigImplCopyWith<_$ImapConfigImpl> get copyWith =>
      __$$ImapConfigImplCopyWithImpl<_$ImapConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ImapConfigImplToJson(
      this,
    );
  }
}

abstract class _ImapConfig implements ImapConfig {
  const factory _ImapConfig(
      {required final String host,
      required final String folder,
      required final String userName,
      required final String password,
      required final int port}) = _$ImapConfigImpl;

  factory _ImapConfig.fromJson(Map<String, dynamic> json) =
      _$ImapConfigImpl.fromJson;

  @override
  String get host;
  @override
  String get folder;
  @override
  String get userName;
  @override
  String get password;
  @override
  int get port;
  @override
  @JsonKey(ignore: true)
  _$$ImapConfigImplCopyWith<_$ImapConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SyncConfig _$SyncConfigFromJson(Map<String, dynamic> json) {
  return _SyncConfig.fromJson(json);
}

/// @nodoc
mixin _$SyncConfig {
  ImapConfig get imapConfig => throw _privateConstructorUsedError;
  String get sharedSecret => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SyncConfigCopyWith<SyncConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncConfigCopyWith<$Res> {
  factory $SyncConfigCopyWith(
          SyncConfig value, $Res Function(SyncConfig) then) =
      _$SyncConfigCopyWithImpl<$Res, SyncConfig>;
  @useResult
  $Res call({ImapConfig imapConfig, String sharedSecret});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class _$SyncConfigCopyWithImpl<$Res, $Val extends SyncConfig>
    implements $SyncConfigCopyWith<$Res> {
  _$SyncConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? sharedSecret = null,
  }) {
    return _then(_value.copyWith(
      imapConfig: null == imapConfig
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
      sharedSecret: null == sharedSecret
          ? _value.sharedSecret
          : sharedSecret // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_value.imapConfig, (value) {
      return _then(_value.copyWith(imapConfig: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SyncConfigImplCopyWith<$Res>
    implements $SyncConfigCopyWith<$Res> {
  factory _$$SyncConfigImplCopyWith(
          _$SyncConfigImpl value, $Res Function(_$SyncConfigImpl) then) =
      __$$SyncConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({ImapConfig imapConfig, String sharedSecret});

  @override
  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$SyncConfigImplCopyWithImpl<$Res>
    extends _$SyncConfigCopyWithImpl<$Res, _$SyncConfigImpl>
    implements _$$SyncConfigImplCopyWith<$Res> {
  __$$SyncConfigImplCopyWithImpl(
      _$SyncConfigImpl _value, $Res Function(_$SyncConfigImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? sharedSecret = null,
  }) {
    return _then(_$SyncConfigImpl(
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
}

/// @nodoc
@JsonSerializable()
class _$SyncConfigImpl implements _SyncConfig {
  const _$SyncConfigImpl(
      {required this.imapConfig, required this.sharedSecret});

  factory _$SyncConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncConfigImplFromJson(json);

  @override
  final ImapConfig imapConfig;
  @override
  final String sharedSecret;

  @override
  String toString() {
    return 'SyncConfig(imapConfig: $imapConfig, sharedSecret: $sharedSecret)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncConfigImpl &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig) &&
            (identical(other.sharedSecret, sharedSecret) ||
                other.sharedSecret == sharedSecret));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, imapConfig, sharedSecret);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncConfigImplCopyWith<_$SyncConfigImpl> get copyWith =>
      __$$SyncConfigImplCopyWithImpl<_$SyncConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncConfigImplToJson(
      this,
    );
  }
}

abstract class _SyncConfig implements SyncConfig {
  const factory _SyncConfig(
      {required final ImapConfig imapConfig,
      required final String sharedSecret}) = _$SyncConfigImpl;

  factory _SyncConfig.fromJson(Map<String, dynamic> json) =
      _$SyncConfigImpl.fromJson;

  @override
  ImapConfig get imapConfig;
  @override
  String get sharedSecret;
  @override
  @JsonKey(ignore: true)
  _$$SyncConfigImplCopyWith<_$SyncConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
