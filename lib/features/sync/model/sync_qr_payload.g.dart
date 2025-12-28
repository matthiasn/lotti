// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_qr_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SyncQrPayload _$SyncQrPayloadFromJson(Map<String, dynamic> json) =>
    _SyncQrPayload(
      version: (json['version'] as num).toInt(),
      encryptedData: json['encryptedData'] as String,
    );

Map<String, dynamic> _$SyncQrPayloadToJson(_SyncQrPayload instance) =>
    <String, dynamic>{
      'version': instance.version,
      'encryptedData': instance.encryptedData,
    };
