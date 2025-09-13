// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ImapConfig _$ImapConfigFromJson(Map<String, dynamic> json) => _ImapConfig(
      host: json['host'] as String,
      folder: json['folder'] as String,
      userName: json['userName'] as String,
      password: json['password'] as String,
      port: (json['port'] as num).toInt(),
    );

Map<String, dynamic> _$ImapConfigToJson(_ImapConfig instance) =>
    <String, dynamic>{
      'host': instance.host,
      'folder': instance.folder,
      'userName': instance.userName,
      'password': instance.password,
      'port': instance.port,
    };

_MatrixConfig _$MatrixConfigFromJson(Map<String, dynamic> json) =>
    _MatrixConfig(
      homeServer: json['homeServer'] as String,
      user: json['user'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$MatrixConfigToJson(_MatrixConfig instance) =>
    <String, dynamic>{
      'homeServer': instance.homeServer,
      'user': instance.user,
      'password': instance.password,
    };

_SyncConfig _$SyncConfigFromJson(Map<String, dynamic> json) => _SyncConfig(
      imapConfig:
          ImapConfig.fromJson(json['imapConfig'] as Map<String, dynamic>),
      sharedSecret: json['sharedSecret'] as String,
    );

Map<String, dynamic> _$SyncConfigToJson(_SyncConfig instance) =>
    <String, dynamic>{
      'imapConfig': instance.imapConfig,
      'sharedSecret': instance.sharedSecret,
    };
