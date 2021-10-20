// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imap_config.dart';

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
