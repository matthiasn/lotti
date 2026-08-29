import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/service/goal_assessment_service.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

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
        // ACTIONS only. Reading every message meant a long-lived agent's
        // whole conversation was materialized and decoded just to find its
        // reflections — once per goal on the Agents list, and again after any
        // agent update. The message kind is the indexed subtype, so this is a
        // narrow lookup rather than a scan.
        //
        // Deliberately NOT row-limited. The limit would apply to every action
        // before assessments are filtered out below, so an agent with enough
        // newer tool calls would silently lose a reflection that is still
        // stored — a correctness cost for a bound that the subtype filter
        // already makes unnecessary. A truly bounded read needs an
        // assessment-specific index, which is a schema change, not a
        // parameter.
        final entities = await repository.getEntitiesByAgentIdAndSubtype(
          agentId,
          type: AgentEntityTypes.agentMessage,
          subtype: AgentMessageKind.action.name,
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
          final dimensionRatings = <String, DayVerdict>{};
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
                  DayVerdictProvenance.values
                      .where((value) => value.name == content['provenance'])
                      .firstOrNull ??
                  DayVerdictProvenance.ratedByUser,
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
/// this build does not know is therefore read as [DayVerdict.mixed],
/// the honest middle: the day was reflected on and it was not a clean sweep.
///
/// Returns null only for a value that is not a string at all, which is
/// corruption rather than a version skew.
DayVerdict? _decodeRating(Object? raw) {
  if (raw is! String) return null;
  return DayVerdict.values.where((value) => value.name == raw).firstOrNull ??
      DayVerdict.mixed;
}

/// The record that stands for each day, keyed by UTC day.
///
/// A day can carry several records — the user reflects, then revises — so the
/// most recently created one wins. Ties on [GoalAssessmentRecord.createdAt]
/// fall back to the higher record id: the query orders by timestamp alone, so
/// tied rows come back in no defined order and two devices would otherwise
/// colour the same day differently from identical data.
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
    final wins =
        held == null ||
        record.createdAt.isAfter(held.createdAt) ||
        (record.createdAt == held.createdAt &&
            record.id.compareTo(held.id) > 0);
    if (wins) latest[day] = record;
  }
  return latest;
}

/// The verdict standing for each day, for surfaces that only need the colour.
Map<DateTime, DayVerdict> latestRatingsByDay(
  Iterable<GoalAssessmentRecord> records, {
  String? specVersionId,
}) => {
  for (final entry in latestAssessmentsByDay(
    records,
    specVersionId: specVersionId,
  ).entries)
    entry.key: entry.value.rating,
};

/// The verdict standing for one dimension on each day — a habit's or a
/// metric's own row in the reflection sheet, keyed by its criterion id.
///
/// Built on the same latest-record-per-day rule as [latestRatingsByDay], so
/// the dimension's colour on a habit card can never disagree with the day it
/// belongs to. Days whose latest record did not rate this dimension are
/// absent, not defaulted: the sheet only writes the rows the user touched,
/// and an untouched row is no verdict rather than a met one.
Map<DateTime, DayVerdict> latestDimensionRatingsByDay(
  Iterable<GoalAssessmentRecord> records, {
  required String criterionId,
  String? specVersionId,
}) => {
  for (final entry in latestAssessmentsByDay(
    records,
    specVersionId: specVersionId,
  ).entries)
    entry.key: ?entry.value.dimensionRatings[criterionId],
};
