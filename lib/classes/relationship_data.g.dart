// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relationship_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ContactChannel _$ContactChannelFromJson(Map<String, dynamic> json) =>
    _ContactChannel(
      type: $enumDecode(_$ContactChannelTypeEnumMap, json['type']),
      value: json['value'] as String,
      label: json['label'] as String?,
    );

Map<String, dynamic> _$ContactChannelToJson(_ContactChannel instance) =>
    <String, dynamic>{
      'type': _$ContactChannelTypeEnumMap[instance.type]!,
      'value': instance.value,
      'label': instance.label,
    };

const _$ContactChannelTypeEnumMap = {
  ContactChannelType.phone: 'phone',
  ContactChannelType.mobile: 'mobile',
  ContactChannelType.email: 'email',
  ContactChannelType.messaging: 'messaging',
};

RelationshipActive _$RelationshipActiveFromJson(Map<String, dynamic> json) =>
    RelationshipActive(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$RelationshipActiveToJson(RelationshipActive instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

RelationshipDormant _$RelationshipDormantFromJson(Map<String, dynamic> json) =>
    RelationshipDormant(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$RelationshipDormantToJson(
  RelationshipDormant instance,
) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt.toIso8601String(),
  'utcOffset': instance.utcOffset,
  'timezone': instance.timezone,
  'geolocation': instance.geolocation,
  'runtimeType': instance.$type,
};

RelationshipArchived _$RelationshipArchivedFromJson(
  Map<String, dynamic> json,
) => RelationshipArchived(
  id: json['id'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  utcOffset: (json['utcOffset'] as num).toInt(),
  timezone: json['timezone'] as String?,
  geolocation: json['geolocation'] == null
      ? null
      : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$RelationshipArchivedToJson(
  RelationshipArchived instance,
) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt.toIso8601String(),
  'utcOffset': instance.utcOffset,
  'timezone': instance.timezone,
  'geolocation': instance.geolocation,
  'runtimeType': instance.$type,
};

_RelationshipData _$RelationshipDataFromJson(
  Map<String, dynamic> json,
) => _RelationshipData(
  title: json['title'] as String,
  status: RelationshipStatus.fromJson(json['status'] as Map<String, dynamic>),
  nickname: json['nickname'] as String?,
  important: json['important'] as bool? ?? false,
  statusHistory:
      (json['statusHistory'] as List<dynamic>?)
          ?.map((e) => RelationshipStatus.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  checkInCadenceDays: (json['checkInCadenceDays'] as num?)?.toInt(),
  birthday: json['birthday'] == null
      ? null
      : DateTime.parse(json['birthday'] as String),
  profileId: json['profileId'] as String?,
  languageCode: json['languageCode'] as String?,
  coverArtId: json['coverArtId'] as String?,
  contactChannels:
      (json['contactChannels'] as List<dynamic>?)
          ?.map((e) => ContactChannel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  contactRefs:
      (json['contactRefs'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
);

Map<String, dynamic> _$RelationshipDataToJson(_RelationshipData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'status': instance.status,
      'nickname': instance.nickname,
      'important': instance.important,
      'statusHistory': instance.statusHistory,
      'checkInCadenceDays': instance.checkInCadenceDays,
      'birthday': instance.birthday?.toIso8601String(),
      'profileId': instance.profileId,
      'languageCode': instance.languageCode,
      'coverArtId': instance.coverArtId,
      'contactChannels': instance.contactChannels,
      'contactRefs': instance.contactRefs,
    };
