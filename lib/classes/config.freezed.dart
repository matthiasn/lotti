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

  /// Serializes this ImapConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
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

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, host, folder, userName, password, port);

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ImapConfigImplCopyWith<_$ImapConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MatrixConfig _$MatrixConfigFromJson(Map<String, dynamic> json) {
  return _MatrixConfig.fromJson(json);
}

/// @nodoc
mixin _$MatrixConfig {
  String get homeServer => throw _privateConstructorUsedError;
  String get user => throw _privateConstructorUsedError;
  String get password => throw _privateConstructorUsedError;

  /// Serializes this MatrixConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatrixConfigCopyWith<MatrixConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatrixConfigCopyWith<$Res> {
  factory $MatrixConfigCopyWith(
          MatrixConfig value, $Res Function(MatrixConfig) then) =
      _$MatrixConfigCopyWithImpl<$Res, MatrixConfig>;
  @useResult
  $Res call({String homeServer, String user, String password});
}

/// @nodoc
class _$MatrixConfigCopyWithImpl<$Res, $Val extends MatrixConfig>
    implements $MatrixConfigCopyWith<$Res> {
  _$MatrixConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? homeServer = null,
    Object? user = null,
    Object? password = null,
  }) {
    return _then(_value.copyWith(
      homeServer: null == homeServer
          ? _value.homeServer
          : homeServer // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MatrixConfigImplCopyWith<$Res>
    implements $MatrixConfigCopyWith<$Res> {
  factory _$$MatrixConfigImplCopyWith(
          _$MatrixConfigImpl value, $Res Function(_$MatrixConfigImpl) then) =
      __$$MatrixConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String homeServer, String user, String password});
}

/// @nodoc
class __$$MatrixConfigImplCopyWithImpl<$Res>
    extends _$MatrixConfigCopyWithImpl<$Res, _$MatrixConfigImpl>
    implements _$$MatrixConfigImplCopyWith<$Res> {
  __$$MatrixConfigImplCopyWithImpl(
      _$MatrixConfigImpl _value, $Res Function(_$MatrixConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? homeServer = null,
    Object? user = null,
    Object? password = null,
  }) {
    return _then(_$MatrixConfigImpl(
      homeServer: null == homeServer
          ? _value.homeServer
          : homeServer // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MatrixConfigImpl implements _MatrixConfig {
  const _$MatrixConfigImpl(
      {required this.homeServer, required this.user, required this.password});

  factory _$MatrixConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatrixConfigImplFromJson(json);

  @override
  final String homeServer;
  @override
  final String user;
  @override
  final String password;

  @override
  String toString() {
    return 'MatrixConfig(homeServer: $homeServer, user: $user, password: $password)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatrixConfigImpl &&
            (identical(other.homeServer, homeServer) ||
                other.homeServer == homeServer) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.password, password) ||
                other.password == password));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, homeServer, user, password);

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatrixConfigImplCopyWith<_$MatrixConfigImpl> get copyWith =>
      __$$MatrixConfigImplCopyWithImpl<_$MatrixConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatrixConfigImplToJson(
      this,
    );
  }
}

abstract class _MatrixConfig implements MatrixConfig {
  const factory _MatrixConfig(
      {required final String homeServer,
      required final String user,
      required final String password}) = _$MatrixConfigImpl;

  factory _MatrixConfig.fromJson(Map<String, dynamic> json) =
      _$MatrixConfigImpl.fromJson;

  @override
  String get homeServer;
  @override
  String get user;
  @override
  String get password;

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatrixConfigImplCopyWith<_$MatrixConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SyncConfig _$SyncConfigFromJson(Map<String, dynamic> json) {
  return _SyncConfig.fromJson(json);
}

/// @nodoc
mixin _$SyncConfig {
  ImapConfig get imapConfig => throw _privateConstructorUsedError;
  String get sharedSecret => throw _privateConstructorUsedError;

  /// Serializes this SyncConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
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

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
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

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, imapConfig, sharedSecret);

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncConfigImplCopyWith<_$SyncConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
