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
          final rating = GoalAssessmentRating.values
              .where((value) => value.name == content['rating'])
              .firstOrNull;
          final specVersionId = content['specVersionId'];
          if (day == null || rating == null || specVersionId is! String) {
            continue;
          }
          final rawDimensions = content['dimensionRatings'];
          final dimensionRatings = <String, GoalAssessmentRating>{};
          if (rawDimensions is Map) {
            for (final entry in rawDimensions.entries) {
              if (entry.key is! String || entry.value is! String) continue;
              final value = GoalAssessmentRating.values
                  .where((rating) => rating.name == entry.value)
                  .firstOrNull;
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
