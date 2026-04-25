// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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

_SyncProvisioningBundle _$SyncProvisioningBundleFromJson(
  Map<String, dynamic> json,
) => _SyncProvisioningBundle(
  v: (json['v'] as num).toInt(),
  kind: $enumDecode(_$SyncBundleKindEnumMap, json['kind']),
  homeServer: json['homeServer'] as String,
  user: json['user'] as String,
  password: json['password'] as String,
  roomId: json['roomId'] as String,
);

Map<String, dynamic> _$SyncProvisioningBundleToJson(
  _SyncProvisioningBundle instance,
) => <String, dynamic>{
  'v': instance.v,
  'kind': _$SyncBundleKindEnumMap[instance.kind]!,
  'homeServer': instance.homeServer,
  'user': instance.user,
  'password': instance.password,
  'roomId': instance.roomId,
};

const _$SyncBundleKindEnumMap = {
  SyncBundleKind.provisioned: 'provisioned',
  SyncBundleKind.handover: 'handover',
};
