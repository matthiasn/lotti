import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';

final pendingWakeRecordsProvider = FutureProvider<List<PendingWakeRecord>>((
  ref,
) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));

  final agentService = ref.watch(agentServiceProvider);
  final repository = ref.watch(agentRepositoryProvider);
  final identities = await agentService.listAgents();
  final statesByAgentId = await repository.getAgentStatesByAgentIds(
    identities.map((identity) => identity.agentId).toList(),
  );

  final records = <PendingWakeRecord>[];
  for (final identity in identities) {
    final state = statesByAgentId[identity.agentId];
    if (state == null || state.deletedAt != null) {
      continue;
    }

    final nextWakeAt = state.nextWakeAt;
    if (nextWakeAt != null) {
      records.add(
        PendingWakeRecord(
          agent: identity,
          state: state,
          type: PendingWakeType.pending,
          dueAt: nextWakeAt,
        ),
      );
    }

    final scheduledWakeAt = state.scheduledWakeAt;
    if (scheduledWakeAt != null) {
      records.add(
        PendingWakeRecord(
          agent: identity,
          state: state,
          type: PendingWakeType.scheduled,
          dueAt: scheduledWakeAt,
        ),
      );
    }
  }

  records.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  return records;
});

// ignore: specify_nonobvious_property_types
final pendingWakeTargetTitleProvider = FutureProvider.family<String?, String?>((
  ref,
  String? entryId,
) async {
  if (entryId == null || entryId.isEmpty) {
    return null;
  }

  final journalDb = ref.watch(journalDbProvider);
  final entry = await journalDb.journalEntityById(entryId);

  return switch (entry) {
    Task(:final data) => data.title,
    ProjectEntry(:final data) => data.title,
    _ => null,
  };
});
