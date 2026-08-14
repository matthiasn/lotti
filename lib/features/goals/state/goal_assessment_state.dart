import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/service/goal_assessment_service.dart';

final goalAssessmentServiceProvider = Provider<GoalAssessmentService>(
  (ref) => GoalAssessmentService(ref.watch(agentSyncServiceProvider)),
  name: 'goalAssessmentServiceProvider',
);

final FutureProviderFamily<List<GoalAssessmentRecord>, String>
goalAssessmentHistoryProvider = FutureProvider.autoDispose
    .family<List<GoalAssessmentRecord>, String>(
      (ref, agentId) async {
        ref.watch(agentUpdateStreamProvider(agentId));
        final repository = ref.watch(agentRepositoryProvider);
        final entities = await repository.getEntitiesByAgentId(
          agentId,
          type: AgentEntityTypes.agentMessage,
        );
        final actions = entities.whereType<AgentMessageEntity>().where(
          (action) =>
              action.metadata.toolName == GoalAssessmentToolNames.record &&
              action.contentEntryId != null,
        );
        final payloadIds = actions
            .map((action) => action.contentEntryId!)
            .toSet();
        final payloads = payloadIds.isEmpty
            ? const <String, AgentDomainEntity>{}
            : await repository.getEntitiesByIds(payloadIds);
        final records = <GoalAssessmentRecord>[];
        for (final action in actions) {
          final payload = payloads[action.contentEntryId];
          if (payload is! AgentMessagePayloadEntity) continue;
          final content = payload.content;
          final day = DateTime.tryParse(content['day'] as String? ?? '');
          // `ratingV2` carries the real verdict; `rating` is the nearest form
          // an older client can read. Prefer the richer one when present.
          final rating = _decodeRating(
            content['ratingV2'] ?? content['rating'],
          );
          final specVersionId = content['specVersionId'];
          if (day == null || rating == null || specVersionId is! String) {
            continue;
          }
          final rawDimensions =
              content['dimensionRatingsV2'] ?? content['dimensionRatings'];
          final dimensionRatings = <String, GoalAssessmentRating>{};
          if (rawDimensions is Map) {
            for (final entry in rawDimensions.entries) {
              if (entry.key is! String || entry.value is! String) continue;
              final value = _decodeRating(entry.value);
              if (value != null) dimensionRatings[entry.key as String] = value;
            }
          }
          records.add(
            GoalAssessmentRecord(
              id: content['recordId'] as String? ?? action.id,
              day: day,
              specVersionId: specVersionId,
              rating: rating,
              note: content['note'] as String?,
              dimensionRatings: dimensionRatings,
              createdAt: action.createdAt,
              provenance:
                  GoalAssessmentProvenance.values
                      .where((value) => value.name == content['provenance'])
                      .firstOrNull ??
                  GoalAssessmentProvenance.ratedByUser,
              suggestedBy: content['suggestedBy'] as String?,
            ),
          );
        }
        records.sort((a, b) {
          final byDay = b.day.compareTo(a.day);
          return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
        });
        return records;
      },
      name: 'goalAssessmentHistoryProvider',
    );

/// Decodes a persisted rating name, degrading rather than dropping.
///
/// A record whose rating cannot be read is skipped entirely by the caller, so
/// an unknown name would make the whole day's reflection — note, per-dimension
/// verdicts and all — vanish from a device running an older build. A value
/// this build does not know is therefore read as [GoalAssessmentRating.mixed],
/// the honest middle: the day was reflected on and it was not a clean sweep.
///
/// Returns null only for a value that is not a string at all, which is
/// corruption rather than a version skew.
GoalAssessmentRating? _decodeRating(Object? raw) {
  if (raw is! String) return null;
  return GoalAssessmentRating.values
          .where((value) => value.name == raw)
          .firstOrNull ??
      GoalAssessmentRating.mixed;
}

/// The record that stands for each day, keyed by UTC day.
///
/// A day can carry several records — the user reflects, then revises — so the
/// most recently created one wins. Ties on [GoalAssessmentRecord.createdAt]
/// keep the first seen, which makes the result stable rather than dependent on
/// however the store happened to order two writes in the same instant.
///
/// [specVersionId] restricts the result to reflections recorded against one
/// version of the goal. Spec versions are immutable and the history keeps them
/// all, so without it a verdict passed on the OLD criteria would colour the
/// same date under the new ones — a judgement of a goal that no longer exists.
Map<DateTime, GoalAssessmentRecord> latestAssessmentsByDay(
  Iterable<GoalAssessmentRecord> records, {
  String? specVersionId,
}) {
  final latest = <DateTime, GoalAssessmentRecord>{};
  for (final record in records) {
    if (specVersionId != null && record.specVersionId != specVersionId) {
      continue;
    }
    final day = DateTime.utc(
      record.day.year,
      record.day.month,
      record.day.day,
    );
    final held = latest[day];
    if (held == null || record.createdAt.isAfter(held.createdAt)) {
      latest[day] = record;
    }
  }
  return latest;
}

/// The verdict standing for each day, for surfaces that only need the colour.
Map<DateTime, GoalAssessmentRating> latestRatingsByDay(
  Iterable<GoalAssessmentRecord> records, {
  String? specVersionId,
}) => {
  for (final entry in latestAssessmentsByDay(
    records,
    specVersionId: specVersionId,
  ).entries)
    entry.key: entry.value.rating,
};
