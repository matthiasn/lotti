import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
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
    required DayVerdict rating,
    required Map<String, DayVerdict> dimensionRatings,
    String? note,
    DayVerdictProvenance provenance = DayVerdictProvenance.ratedByUser,
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
            // `rating` stays readable by every shipped client. Versions before
            // `improving` existed decode by searching their own three-value
            // enum and DISCARD the whole record when nothing matches, taking
            // the note and the per-dimension verdicts with it — a synced day
            // would simply vanish on the other device. So the wire keeps the
            // nearest legacy verdict here and carries the real one alongside;
            // readers that understand `ratingV2` prefer it.
            'rating': _legacyRatingName(rating),
            if (rating != _legacyRating(rating)) 'ratingV2': rating.name,
            'note': note,
            'dimensionRatings': {
              for (final entry in dimensionRatings.entries)
                entry.key: _legacyRatingName(entry.value),
            },
            if (dimensionRatings.values.any(
              (value) => value != _legacyRating(value),
            ))
              'dimensionRatingsV2': {
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

/// The nearest verdict a client predating [DayVerdict.improving]
/// can decode.
///
/// "Some of it was missed, but the day moved the right way" collapses to
/// `mixed` there, which is the honest reading: it was not a clean sweep. Every
/// other verdict is its own legacy form.
DayVerdict _legacyRating(DayVerdict rating) =>
    rating == DayVerdict.improving ? DayVerdict.mixed : rating;

String _legacyRatingName(DayVerdict rating) => _legacyRating(rating).name;
