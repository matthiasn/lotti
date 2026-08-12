import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:uuid/uuid.dart';

abstract final class GoalAssessmentToolNames {
  static const record = 'goal_record_daily_assessment';
  static const suggest = 'goal_suggest_daily_assessment';
}

class GoalAssessmentService {
  GoalAssessmentService(this._syncService);

  final AgentSyncService _syncService;
  static const _uuid = Uuid();

  Future<String> record({
    required String agentId,
    required DateTime day,
    required String specVersionId,
    required GoalAssessmentRating rating,
    required Map<String, GoalAssessmentRating> dimensionRatings,
    String? note,
    GoalAssessmentProvenance provenance = GoalAssessmentProvenance.ratedByUser,
    String? suggestedBy,
  }) async {
    final now = clock.now();
    final payloadId = _uuid.v4();
    final recordId = _uuid.v4();
    await _syncService.runInTransaction(() async {
      await _syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: <String, Object?>{
            'recordId': recordId,
            'day': day.toIso8601String(),
            'specVersionId': specVersionId,
            'rating': rating.name,
            'note': note,
            'dimensionRatings': {
              for (final entry in dimensionRatings.entries)
                entry.key: entry.value.name,
            },
            'provenance': provenance.name,
            'suggestedBy': suggestedBy,
          },
        ),
      );
      await _syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: recordId,
          agentId: agentId,
          threadId: recordId,
          kind: AgentMessageKind.action,
          createdAt: now,
          vectorClock: null,
          metadata: const AgentMessageMetadata(
            toolName: GoalAssessmentToolNames.record,
          ),
          contentEntryId: payloadId,
        ),
      );
    });
    return recordId;
  }
}
