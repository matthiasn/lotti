// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_ImapConfig _$$_ImapConfigFromJson(Map<String, dynamic> json) =>
    _$_ImapConfig(
      host: json['host'] as String,
      userName: json['userName'] as String,
      password: json['password'] as String,
      port: json['port'] as int,
    );

Map<String, dynamic> _$$_ImapConfigToJson(_$_ImapConfig instance) =>
    <String, dynamic>{
      'host': instance.host,
      'userName': instance.userName,
      'password': instance.password,
      'port': instance.port,
    };

_$_SyncConfig _$$_SyncConfigFromJson(Map<String, dynamic> json) =>
    _$_SyncConfig(
      imapConfig:
          ImapConfig.fromJson(json['imapConfig'] as Map<String, dynamic>),
      sharedSecret: json['sharedSecret'] as String,
    );

Map<String, dynamic> _$$_SyncConfigToJson(_$_SyncConfig instance) =>
    <String, dynamic>{
      'imapConfig': instance.imapConfig,
      'sharedSecret': instance.sharedSecret,
    };
