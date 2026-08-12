import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/service/goal_measurable_capture_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';

@immutable
class GoalMeasurableCaptureDecision {
  const GoalMeasurableCaptureDecision({
    required this.sourceMessageId,
    required this.recorded,
    required this.entryCount,
    this.entryIds = const [],
    this.agentName,
    this.recordedAt,
  });

  final String sourceMessageId;
  final bool recorded;
  final int entryCount;
  final List<String> entryIds;
  final String? agentName;
  final DateTime? recordedAt;
}

final goalMeasurableCaptureServiceProvider =
    Provider<GoalMeasurableCaptureService>(
      (ref) => GoalMeasurableCaptureService(
        ref.watch(agentSyncServiceProvider),
        getIt<PersistenceLogic>(),
      ),
      name: 'goalMeasurableCaptureServiceProvider',
    );

final FutureProviderFamily<Map<String, GoalMeasurableCaptureDecision>, String>
goalMeasurableCaptureDecisionsProvider = FutureProvider.autoDispose
    .family<Map<String, GoalMeasurableCaptureDecision>, String>(
      (ref, agentId) async {
        ref.watch(agentUpdateStreamProvider(agentId));
        final repository = ref.watch(agentRepositoryProvider);
        final entities = await repository.getEntitiesByAgentId(
          agentId,
          type: AgentEntityTypes.agentMessage,
        );
        final actions = entities.whereType<AgentMessageEntity>().where(
          (entity) =>
              entity.metadata.toolName ==
                  GoalMeasurableCaptureToolNames.recorded ||
              entity.metadata.toolName ==
                  GoalMeasurableCaptureToolNames.dismissed,
        );
        final decisions = <String, GoalMeasurableCaptureDecision>{};
        for (final action in actions) {
          final payloadId = action.contentEntryId;
          if (payloadId == null) continue;
          final payload = await repository.getEntity(payloadId);
          if (payload is! AgentMessagePayloadEntity) continue;
          final sourceMessageId = payload.content['sourceMessageId'];
          if (sourceMessageId is! String || sourceMessageId.isEmpty) continue;
          final entryIds = payload.content['entryIds'];
          final recordedEntryIds = entryIds is List
              ? entryIds.whereType<String>().toList(growable: false)
              : const <String>[];
          decisions[sourceMessageId] = GoalMeasurableCaptureDecision(
            sourceMessageId: sourceMessageId,
            recorded:
                action.metadata.toolName ==
                GoalMeasurableCaptureToolNames.recorded,
            entryCount: recordedEntryIds.length,
            entryIds: recordedEntryIds,
            agentName: payload.content['agentName'] as String?,
            recordedAt: action.createdAt,
          );
        }
        return decisions;
      },
      name: 'goalMeasurableCaptureDecisionsProvider',
    );
