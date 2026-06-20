// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_node_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SyncNodeProfile _$SyncNodeProfileFromJson(Map<String, dynamic> json) =>
    _SyncNodeProfile(
      hostId: json['hostId'] as String,
      displayName: json['displayName'] as String,
      platform: json['platform'] as String,
      capabilities: (json['capabilities'] as List<dynamic>)
          .map((e) => $enumDecode(_$NodeCapabilityEnumMap, e))
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      osVersion: json['osVersion'] as String?,
      cpuModel: json['cpuModel'] as String?,
      ramMb: (json['ramMb'] as num?)?.toInt(),
      gpuModel: json['gpuModel'] as String?,
      appVersion: json['appVersion'] as String?,
    );

Map<String, dynamic> _$SyncNodeProfileToJson(_SyncNodeProfile instance) =>
    <String, dynamic>{
      'hostId': instance.hostId,
      'displayName': instance.displayName,
      'platform': instance.platform,
      'capabilities': instance.capabilities
          .map((e) => _$NodeCapabilityEnumMap[e]!)
          .toList(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'osVersion': instance.osVersion,
      'cpuModel': instance.cpuModel,
      'ramMb': instance.ramMb,
      'gpuModel': instance.gpuModel,
      'appVersion': instance.appVersion,
    };

const _$NodeCapabilityEnumMap = {
  NodeCapability.mlxAudio: 'mlxAudio',
  NodeCapability.omlxLlm: 'omlxLlm',
  NodeCapability.ollamaLlm: 'ollamaLlm',
  NodeCapability.voxtral: 'voxtral',
  NodeCapability.whisper: 'whisper',
};
