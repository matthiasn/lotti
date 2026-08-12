import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/model/goal_measurable_record_offer.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:uuid/uuid.dart';

abstract final class GoalMeasurableCaptureToolNames {
  static const recorded = 'goal_record_measurable_offer_recorded';
  static const dismissed = 'goal_record_measurable_offer_dismissed';
}

class GoalMeasurableCaptureService {
  GoalMeasurableCaptureService(this._syncService, this._persistenceLogic);

  final AgentSyncService _syncService;
  final PersistenceLogic _persistenceLogic;
  static const _uuid = Uuid();

  Future<List<String>?> record({
    required String agentId,
    required String agentName,
    required GoalMeasurableRecordOffer offer,
    required List<GoalMeasurableRecordItem> items,
    required bool private,
    required String provenanceComment,
  }) async {
    if (items.isEmpty || items.any((item) => item.value <= 0)) return null;
    final entryIds = <String>[];
    for (final item in items) {
      final observedAt = DateTime(
        item.day.year,
        item.day.month,
        item.day.day,
        12,
      );
      final entry = await _persistenceLogic.createMeasurementEntry(
        data: MeasurementData(
          dateFrom: observedAt,
          dateTo: observedAt,
          value: item.value,
          dataTypeId: offer.dataTypeId,
        ),
        private: private,
        comment: provenanceComment,
      );
      if (entry == null) return null;
      entryIds.add(entry.meta.id);
    }
    await _recordDecision(
      agentId: agentId,
      offer: offer,
      toolName: GoalMeasurableCaptureToolNames.recorded,
      extra: <String, Object?>{
        'agentName': agentName,
        'entryIds': entryIds,
        'items': [
          for (final item in items)
            <String, Object?>{
              'day': item.day.toIso8601String(),
              'value': item.value,
              'estimated': item.estimated,
            },
        ],
      },
    );
    return entryIds;
  }

  Future<void> dismiss({
    required String agentId,
    required GoalMeasurableRecordOffer offer,
  }) => _recordDecision(
    agentId: agentId,
    offer: offer,
    toolName: GoalMeasurableCaptureToolNames.dismissed,
  );

  Future<void> _recordDecision({
    required String agentId,
    required GoalMeasurableRecordOffer offer,
    required String toolName,
    Map<String, Object?> extra = const {},
  }) async {
    final now = clock.now();
    final payloadId = _uuid.v4();
    final messageId = _uuid.v4();
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{
          'sourceMessageId': offer.sourceMessageId,
          'dataTypeId': offer.dataTypeId,
          'measurableName': offer.measurableName,
          'unitName': offer.unitName,
          ...extra,
        },
      ),
    );
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: messageId,
        agentId: agentId,
        threadId: offer.sourceMessageId,
        kind: AgentMessageKind.action,
        createdAt: now,
        vectorClock: null,
        metadata: AgentMessageMetadata(toolName: toolName),
        contentEntryId: payloadId,
        triggerSourceId: offer.sourceMessageId,
      ),
    );
  }
}
