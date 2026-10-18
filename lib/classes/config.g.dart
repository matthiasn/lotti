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
      attestation: json['attestation'] == null
          ? null
          : BundleAttestation.fromJson(
              json['attestation'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$MatrixConfigToJson(_MatrixConfig instance) =>
    <String, dynamic>{
      'homeServer': instance.homeServer,
      'user': instance.user,
      'password': instance.password,
      'attestation': ?instance.attestation,
    };

_BundleAttestation _$BundleAttestationFromJson(Map<String, dynamic> json) =>
    _BundleAttestation(
      kid: json['kid'] as String,
      iat: (json['iat'] as num).toInt(),
      exp: (json['exp'] as num).toInt(),
      sig: json['sig'] as String,
    );

Map<String, dynamic> _$BundleAttestationToJson(_BundleAttestation instance) =>
    <String, dynamic>{
      'kid': instance.kid,
      'iat': instance.iat,
      'exp': instance.exp,
      'sig': instance.sig,
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
  att: json['att'] == null
      ? null
      : BundleAttestation.fromJson(json['att'] as Map<String, dynamic>),
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
  'att': ?instance.att,
};

const _$SyncBundleKindEnumMap = {
  SyncBundleKind.provisioned: 'provisioned',
  SyncBundleKind.handover: 'handover',
};
