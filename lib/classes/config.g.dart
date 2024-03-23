// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ImapConfigImpl _$$ImapConfigImplFromJson(Map<String, dynamic> json) =>
    _$ImapConfigImpl(
      host: json['host'] as String,
      folder: json['folder'] as String,
      userName: json['userName'] as String,
      password: json['password'] as String,
      port: json['port'] as int,
    );

Map<String, dynamic> _$$ImapConfigImplToJson(_$ImapConfigImpl instance) =>
    <String, dynamic>{
      'host': instance.host,
      'folder': instance.folder,
      'userName': instance.userName,
      'password': instance.password,
      'port': instance.port,
    };

_$MatrixConfigImpl _$$MatrixConfigImplFromJson(Map<String, dynamic> json) =>
    _$MatrixConfigImpl(
      homeServer: json['homeServer'] as String,
      user: json['user'] as String,
      password: json['password'] as String,
      roomId: json['roomId'] as String?,
    );

Map<String, dynamic> _$$MatrixConfigImplToJson(_$MatrixConfigImpl instance) =>
    <String, dynamic>{
      'homeServer': instance.homeServer,
      'user': instance.user,
      'password': instance.password,
      'roomId': instance.roomId,
    };

_$SyncConfigImpl _$$SyncConfigImplFromJson(Map<String, dynamic> json) =>
    _$SyncConfigImpl(
      imapConfig:
          ImapConfig.fromJson(json['imapConfig'] as Map<String, dynamic>),
      sharedSecret: json['sharedSecret'] as String,
    );

Map<String, dynamic> _$$SyncConfigImplToJson(_$SyncConfigImpl instance) =>
    <String, dynamic>{
      'imapConfig': instance.imapConfig,
      'sharedSecret': instance.sharedSecret,
    };
