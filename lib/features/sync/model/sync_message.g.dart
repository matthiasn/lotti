// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BackfillRequestEntry _$BackfillRequestEntryFromJson(
  Map<String, dynamic> json,
) => _BackfillRequestEntry(
  hostId: json['hostId'] as String,
  counter: (json['counter'] as num).toInt(),
);

Map<String, dynamic> _$BackfillRequestEntryToJson(
  _BackfillRequestEntry instance,
) => <String, dynamic>{'hostId': instance.hostId, 'counter': instance.counter};

_SyncCounterRange _$SyncCounterRangeFromJson(Map<String, dynamic> json) =>
    _SyncCounterRange(
      start: (json['start'] as num).toInt(),
      end: (json['end'] as num).toInt(),
    );

Map<String, dynamic> _$SyncCounterRangeToJson(_SyncCounterRange instance) =>
    <String, dynamic>{'start': instance.start, 'end': instance.end};

SyncJournalEntity _$SyncJournalEntityFromJson(Map<String, dynamic> json) =>
    SyncJournalEntity(
      id: json['id'] as String,
      jsonPath: json['jsonPath'] as String,
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      entryLinks: (json['entryLinks'] as List<dynamic>?)
          ?.map((e) => EntryLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      originatingHostId: json['originatingHostId'] as String?,
      coveredVectorClocks: (json['coveredVectorClocks'] as List<dynamic>?)
          ?.map((e) => VectorClock.fromJson(e as Map<String, dynamic>))
          .toList(),
      includeAttachments: json['includeAttachments'] as bool?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncJournalEntityToJson(SyncJournalEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jsonPath': instance.jsonPath,
      'vectorClock': instance.vectorClock,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'entryLinks': instance.entryLinks,
      'originatingHostId': instance.originatingHostId,
      'coveredVectorClocks': instance.coveredVectorClocks,
      'includeAttachments': instance.includeAttachments,
      'runtimeType': instance.$type,
    };

const _$SyncEntryStatusEnumMap = {
  SyncEntryStatus.initial: 'initial',
  SyncEntryStatus.update: 'update',
};

SyncEntityDefinition _$SyncEntityDefinitionFromJson(
  Map<String, dynamic> json,
) => SyncEntityDefinition(
  entityDefinition: EntityDefinition.fromJson(
    json['entityDefinition'] as Map<String, dynamic>,
  ),
  status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncEntityDefinitionToJson(
  SyncEntityDefinition instance,
) => <String, dynamic>{
  'entityDefinition': instance.entityDefinition,
  'status': _$SyncEntryStatusEnumMap[instance.status]!,
  'runtimeType': instance.$type,
};

SyncEntryLink _$SyncEntryLinkFromJson(Map<String, dynamic> json) =>
    SyncEntryLink(
      entryLink: EntryLink.fromJson(json['entryLink'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      originatingHostId: json['originatingHostId'] as String?,
      coveredVectorClocks: (json['coveredVectorClocks'] as List<dynamic>?)
          ?.map((e) => VectorClock.fromJson(e as Map<String, dynamic>))
          .toList(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncEntryLinkToJson(SyncEntryLink instance) =>
    <String, dynamic>{
      'entryLink': instance.entryLink,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'originatingHostId': instance.originatingHostId,
      'coveredVectorClocks': instance.coveredVectorClocks,
      'runtimeType': instance.$type,
    };

SyncAiConfig _$SyncAiConfigFromJson(Map<String, dynamic> json) => SyncAiConfig(
  aiConfig: AiConfig.fromJson(json['aiConfig'] as Map<String, dynamic>),
  status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncAiConfigToJson(SyncAiConfig instance) =>
    <String, dynamic>{
      'aiConfig': instance.aiConfig,
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'runtimeType': instance.$type,
    };

SyncSyncNodeProfile _$SyncSyncNodeProfileFromJson(Map<String, dynamic> json) =>
    SyncSyncNodeProfile(
      profile: SyncNodeProfile.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncSyncNodeProfileToJson(
  SyncSyncNodeProfile instance,
) => <String, dynamic>{
  'profile': instance.profile,
  'runtimeType': instance.$type,
};

SyncAiConfigDelete _$SyncAiConfigDeleteFromJson(Map<String, dynamic> json) =>
    SyncAiConfigDelete(
      id: json['id'] as String,
      hardDelete: json['hardDelete'] as bool?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncAiConfigDeleteToJson(SyncAiConfigDelete instance) =>
    <String, dynamic>{
      'id': instance.id,
      'hardDelete': instance.hardDelete,
      'runtimeType': instance.$type,
    };

SyncSavedTaskFilter _$SyncSavedTaskFilterFromJson(Map<String, dynamic> json) =>
    SyncSavedTaskFilter(
      filter: SavedTaskFilter.fromJson(json['filter'] as Map<String, dynamic>),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncSavedTaskFilterToJson(
  SyncSavedTaskFilter instance,
) => <String, dynamic>{
  'filter': instance.filter,
  'status': _$SyncEntryStatusEnumMap[instance.status]!,
  'runtimeType': instance.$type,
};

SyncSavedTaskFilterDelete _$SyncSavedTaskFilterDeleteFromJson(
  Map<String, dynamic> json,
) => SyncSavedTaskFilterDelete(
  id: json['id'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncSavedTaskFilterDeleteToJson(
  SyncSavedTaskFilterDelete instance,
) => <String, dynamic>{'id': instance.id, 'runtimeType': instance.$type};

SyncConfigFlag _$SyncConfigFlagFromJson(Map<String, dynamic> json) =>
    SyncConfigFlag(
      name: json['name'] as String,
      description: json['description'] as String,
      status: json['status'] as bool,
      originatingHostId: json['originatingHostId'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncConfigFlagToJson(SyncConfigFlag instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'status': instance.status,
      'originatingHostId': instance.originatingHostId,
      'runtimeType': instance.$type,
    };

SyncThemingSelection _$SyncThemingSelectionFromJson(
  Map<String, dynamic> json,
) => SyncThemingSelection(
  lightThemeName: json['lightThemeName'] as String,
  darkThemeName: json['darkThemeName'] as String,
  themeMode: json['themeMode'] as String,
  updatedAt: (json['updatedAt'] as num).toInt(),
  status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncThemingSelectionToJson(
  SyncThemingSelection instance,
) => <String, dynamic>{
  'lightThemeName': instance.lightThemeName,
  'darkThemeName': instance.darkThemeName,
  'themeMode': instance.themeMode,
  'updatedAt': instance.updatedAt,
  'status': _$SyncEntryStatusEnumMap[instance.status]!,
  'runtimeType': instance.$type,
};

SyncDailyOsUserName _$SyncDailyOsUserNameFromJson(Map<String, dynamic> json) =>
    SyncDailyOsUserName(
      userName: json['userName'] as String,
      updatedAt: (json['updatedAt'] as num).toInt(),
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncDailyOsUserNameToJson(
  SyncDailyOsUserName instance,
) => <String, dynamic>{
  'userName': instance.userName,
  'updatedAt': instance.updatedAt,
  'status': _$SyncEntryStatusEnumMap[instance.status]!,
  'runtimeType': instance.$type,
};

SyncNotification _$SyncNotificationFromJson(Map<String, dynamic> json) =>
    SyncNotification(
      id: json['id'] as String,
      jsonPath: json['jsonPath'] as String,
      vectorClock: VectorClock.fromJson(
        json['vectorClock'] as Map<String, dynamic>,
      ),
      originatingHostId: json['originatingHostId'] as String,
      coveredVectorClocks: (json['coveredVectorClocks'] as List<dynamic>?)
          ?.map((e) => VectorClock.fromJson(e as Map<String, dynamic>))
          .toList(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncNotificationToJson(SyncNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jsonPath': instance.jsonPath,
      'vectorClock': instance.vectorClock,
      'originatingHostId': instance.originatingHostId,
      'coveredVectorClocks': instance.coveredVectorClocks,
      'runtimeType': instance.$type,
    };

SyncNotificationStateUpdate _$SyncNotificationStateUpdateFromJson(
  Map<String, dynamic> json,
) => SyncNotificationStateUpdate(
  id: json['id'] as String,
  vectorClock: VectorClock.fromJson(
    json['vectorClock'] as Map<String, dynamic>,
  ),
  originatingHostId: json['originatingHostId'] as String,
  seenAt: json['seenAt'] == null
      ? null
      : DateTime.parse(json['seenAt'] as String),
  actedOnAt: json['actedOnAt'] == null
      ? null
      : DateTime.parse(json['actedOnAt'] as String),
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncNotificationStateUpdateToJson(
  SyncNotificationStateUpdate instance,
) => <String, dynamic>{
  'id': instance.id,
  'vectorClock': instance.vectorClock,
  'originatingHostId': instance.originatingHostId,
  'seenAt': instance.seenAt?.toIso8601String(),
  'actedOnAt': instance.actedOnAt?.toIso8601String(),
  'deletedAt': instance.deletedAt?.toIso8601String(),
  'runtimeType': instance.$type,
};

SyncOnboardingSnapshotBegin _$SyncOnboardingSnapshotBeginFromJson(
  Map<String, dynamic> json,
) => SyncOnboardingSnapshotBegin(
  protocolVersion: (json['protocolVersion'] as num).toInt(),
  roundId: json['roundId'] as String,
  senderHostId: json['senderHostId'] as String,
  senderUserId: json['senderUserId'] as String,
  senderDeviceId: json['senderDeviceId'] as String,
  recipientUserId: json['recipientUserId'] as String,
  recipientDeviceId: json['recipientDeviceId'] as String,
  coverageUpperBounds: Map<String, int>.from(
    json['coverageUpperBounds'] as Map,
  ),
  leaseSeconds: (json['leaseSeconds'] as num).toInt(),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncOnboardingSnapshotBeginToJson(
  SyncOnboardingSnapshotBegin instance,
) => <String, dynamic>{
  'protocolVersion': instance.protocolVersion,
  'roundId': instance.roundId,
  'senderHostId': instance.senderHostId,
  'senderUserId': instance.senderUserId,
  'senderDeviceId': instance.senderDeviceId,
  'recipientUserId': instance.recipientUserId,
  'recipientDeviceId': instance.recipientDeviceId,
  'coverageUpperBounds': instance.coverageUpperBounds,
  'leaseSeconds': instance.leaseSeconds,
  'runtimeType': instance.$type,
};

SyncOnboardingSnapshotAccepted _$SyncOnboardingSnapshotAcceptedFromJson(
  Map<String, dynamic> json,
) => SyncOnboardingSnapshotAccepted(
  protocolVersion: (json['protocolVersion'] as num).toInt(),
  roundId: json['roundId'] as String,
  senderHostId: json['senderHostId'] as String,
  senderUserId: json['senderUserId'] as String,
  senderDeviceId: json['senderDeviceId'] as String,
  recipientHostId: json['recipientHostId'] as String,
  recipientDeviceId: json['recipientDeviceId'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncOnboardingSnapshotAcceptedToJson(
  SyncOnboardingSnapshotAccepted instance,
) => <String, dynamic>{
  'protocolVersion': instance.protocolVersion,
  'roundId': instance.roundId,
  'senderHostId': instance.senderHostId,
  'senderUserId': instance.senderUserId,
  'senderDeviceId': instance.senderDeviceId,
  'recipientHostId': instance.recipientHostId,
  'recipientDeviceId': instance.recipientDeviceId,
  'runtimeType': instance.$type,
};

SyncOnboardingTerminalCounters _$SyncOnboardingTerminalCountersFromJson(
  Map<String, dynamic> json,
) => SyncOnboardingTerminalCounters(
  protocolVersion: (json['protocolVersion'] as num).toInt(),
  roundId: json['roundId'] as String,
  senderHostId: json['senderHostId'] as String,
  recipientUserId: json['recipientUserId'] as String,
  recipientDeviceId: json['recipientDeviceId'] as String,
  ranges: (json['ranges'] as List<dynamic>)
      .map((e) => SyncCounterRange.fromJson(e as Map<String, dynamic>))
      .toList(),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncOnboardingTerminalCountersToJson(
  SyncOnboardingTerminalCounters instance,
) => <String, dynamic>{
  'protocolVersion': instance.protocolVersion,
  'roundId': instance.roundId,
  'senderHostId': instance.senderHostId,
  'recipientUserId': instance.recipientUserId,
  'recipientDeviceId': instance.recipientDeviceId,
  'ranges': instance.ranges.map((e) => e.toJson()).toList(),
  'runtimeType': instance.$type,
};

SyncOnboardingSnapshotEnd _$SyncOnboardingSnapshotEndFromJson(
  Map<String, dynamic> json,
) => SyncOnboardingSnapshotEnd(
  protocolVersion: (json['protocolVersion'] as num).toInt(),
  roundId: json['roundId'] as String,
  senderHostId: json['senderHostId'] as String,
  recipientUserId: json['recipientUserId'] as String,
  recipientDeviceId: json['recipientDeviceId'] as String,
  reason: $enumDecode(_$OnboardingSyncEndReasonEnumMap, json['reason']),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncOnboardingSnapshotEndToJson(
  SyncOnboardingSnapshotEnd instance,
) => <String, dynamic>{
  'protocolVersion': instance.protocolVersion,
  'roundId': instance.roundId,
  'senderHostId': instance.senderHostId,
  'recipientUserId': instance.recipientUserId,
  'recipientDeviceId': instance.recipientDeviceId,
  'reason': _$OnboardingSyncEndReasonEnumMap[instance.reason]!,
  'runtimeType': instance.$type,
};

const _$OnboardingSyncEndReasonEnumMap = {
  OnboardingSyncEndReason.complete: 'complete',
  OnboardingSyncEndReason.aborted: 'aborted',
};

SyncBackfillRequest _$SyncBackfillRequestFromJson(Map<String, dynamic> json) =>
    SyncBackfillRequest(
      entries: (json['entries'] as List<dynamic>)
          .map((e) => BackfillRequestEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      requesterId: json['requesterId'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncBackfillRequestToJson(
  SyncBackfillRequest instance,
) => <String, dynamic>{
  'entries': instance.entries,
  'requesterId': instance.requesterId,
  'runtimeType': instance.$type,
};

SyncBackfillResponse _$SyncBackfillResponseFromJson(
  Map<String, dynamic> json,
) => SyncBackfillResponse(
  hostId: json['hostId'] as String,
  counter: (json['counter'] as num).toInt(),
  deleted: json['deleted'] as bool,
  unresolvable: json['unresolvable'] as bool?,
  entryId: json['entryId'] as String?,
  payloadType: $enumDecodeNullable(
    _$SyncSequencePayloadTypeEnumMap,
    json['payloadType'],
  ),
  payloadId: json['payloadId'] as String?,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncBackfillResponseToJson(
  SyncBackfillResponse instance,
) => <String, dynamic>{
  'hostId': instance.hostId,
  'counter': instance.counter,
  'deleted': instance.deleted,
  'unresolvable': instance.unresolvable,
  'entryId': instance.entryId,
  'payloadType': _$SyncSequencePayloadTypeEnumMap[instance.payloadType],
  'payloadId': instance.payloadId,
  'runtimeType': instance.$type,
};

const _$SyncSequencePayloadTypeEnumMap = {
  SyncSequencePayloadType.journalEntity: 'journalEntity',
  SyncSequencePayloadType.entryLink: 'entryLink',
  SyncSequencePayloadType.agentEntity: 'agentEntity',
  SyncSequencePayloadType.agentLink: 'agentLink',
  SyncSequencePayloadType.notification: 'notification',
  SyncSequencePayloadType.notificationStateUpdate: 'notificationStateUpdate',
  SyncSequencePayloadType.consumptionEvent: 'consumptionEvent',
};

SyncMediaRequest _$SyncMediaRequestFromJson(Map<String, dynamic> json) =>
    SyncMediaRequest(
      entryIds: (json['entryIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      requesterId: json['requesterId'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncMediaRequestToJson(SyncMediaRequest instance) =>
    <String, dynamic>{
      'entryIds': instance.entryIds,
      'requesterId': instance.requesterId,
      'runtimeType': instance.$type,
    };

SyncAgentEntity _$SyncAgentEntityFromJson(Map<String, dynamic> json) =>
    SyncAgentEntity(
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      agentEntity: json['agentEntity'] == null
          ? null
          : AgentDomainEntity.fromJson(
              json['agentEntity'] as Map<String, dynamic>,
            ),
      jsonPath: json['jsonPath'] as String?,
      originatingHostId: json['originatingHostId'] as String?,
      coveredVectorClocks: (json['coveredVectorClocks'] as List<dynamic>?)
          ?.map((e) => VectorClock.fromJson(e as Map<String, dynamic>))
          .toList(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncAgentEntityToJson(SyncAgentEntity instance) =>
    <String, dynamic>{
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'agentEntity': instance.agentEntity,
      'jsonPath': instance.jsonPath,
      'originatingHostId': instance.originatingHostId,
      'coveredVectorClocks': instance.coveredVectorClocks,
      'runtimeType': instance.$type,
    };

SyncAgentLink _$SyncAgentLinkFromJson(Map<String, dynamic> json) =>
    SyncAgentLink(
      status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
      agentLink: json['agentLink'] == null
          ? null
          : AgentLink.fromJson(json['agentLink'] as Map<String, dynamic>),
      jsonPath: json['jsonPath'] as String?,
      originatingHostId: json['originatingHostId'] as String?,
      coveredVectorClocks: (json['coveredVectorClocks'] as List<dynamic>?)
          ?.map((e) => VectorClock.fromJson(e as Map<String, dynamic>))
          .toList(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncAgentLinkToJson(SyncAgentLink instance) =>
    <String, dynamic>{
      'status': _$SyncEntryStatusEnumMap[instance.status]!,
      'agentLink': instance.agentLink,
      'jsonPath': instance.jsonPath,
      'originatingHostId': instance.originatingHostId,
      'coveredVectorClocks': instance.coveredVectorClocks,
      'runtimeType': instance.$type,
    };

SyncConsumptionEvent _$SyncConsumptionEventFromJson(
  Map<String, dynamic> json,
) => SyncConsumptionEvent(
  event: AiConsumptionEvent.fromJson(json['event'] as Map<String, dynamic>),
  status: $enumDecode(_$SyncEntryStatusEnumMap, json['status']),
  originatingHostId: json['originatingHostId'] as String?,
  coveredVectorClocks: (json['coveredVectorClocks'] as List<dynamic>?)
      ?.map((e) => VectorClock.fromJson(e as Map<String, dynamic>))
      .toList(),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SyncConsumptionEventToJson(
  SyncConsumptionEvent instance,
) => <String, dynamic>{
  'event': instance.event,
  'status': _$SyncEntryStatusEnumMap[instance.status]!,
  'originatingHostId': instance.originatingHostId,
  'coveredVectorClocks': instance.coveredVectorClocks,
  'runtimeType': instance.$type,
};

SyncAgentBundle _$SyncAgentBundleFromJson(Map<String, dynamic> json) =>
    SyncAgentBundle(
      agentId: json['agentId'] as String,
      wakeRunKey: json['wakeRunKey'] as String,
      entities:
          (json['entities'] as List<dynamic>?)
              ?.map((e) => SyncAgentEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SyncAgentEntity>[],
      links:
          (json['links'] as List<dynamic>?)
              ?.map((e) => SyncAgentLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SyncAgentLink>[],
      jsonPath: json['jsonPath'] as String?,
      originatingHostId: json['originatingHostId'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncAgentBundleToJson(SyncAgentBundle instance) =>
    <String, dynamic>{
      'agentId': instance.agentId,
      'wakeRunKey': instance.wakeRunKey,
      'entities': instance.entities,
      'links': instance.links,
      'jsonPath': instance.jsonPath,
      'originatingHostId': instance.originatingHostId,
      'runtimeType': instance.$type,
    };

SyncOutboxBundle _$SyncOutboxBundleFromJson(Map<String, dynamic> json) =>
    SyncOutboxBundle(
      children: (json['children'] as List<dynamic>)
          .map((e) => SyncMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      jsonPath: json['jsonPath'] as String?,
      originatingHostId: json['originatingHostId'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SyncOutboxBundleToJson(SyncOutboxBundle instance) =>
    <String, dynamic>{
      'children': instance.children,
      'jsonPath': instance.jsonPath,
      'originatingHostId': instance.originatingHostId,
      'runtimeType': instance.$type,
    };
