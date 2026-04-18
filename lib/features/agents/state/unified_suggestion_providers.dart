import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_suggestion_providers.g.dart';

/// One pending proposal in the unified suggestion list.
///
/// Carries the full owning [ChangeSetEntity] and the item's zero-based
/// index within its items list, plus the item itself for convenience.
/// This shape is what the UI widget needs to hand directly to
/// `ChangeSetConfirmationService.confirmItem(changeSet, itemIndex)` or
/// `rejectItem(...)` — the service itself re-reads a fresh snapshot
/// before mutating, so stale fields are harmless.
class PendingSuggestion {
  const PendingSuggestion({
    required this.changeSet,
    required this.itemIndex,
    required this.item,
    required this.fingerprint,
  });

  final ChangeSetEntity changeSet;
  final int itemIndex;
  final ChangeItem item;
  final String fingerprint;
}

/// What the consolidated `AgentSuggestionsPanel` renders for a single task.
///
/// [open] feeds the active suggestion list the user can act on. [activity]
/// feeds the collapsed "recent activity" strip so the user can see what
/// the agent has already confirmed, rejected, or autonomously retracted.
class UnifiedSuggestionList {
  const UnifiedSuggestionList({
    required this.open,
    required this.activity,
  });

  const UnifiedSuggestionList.empty() : open = const [], activity = const [];

  final List<PendingSuggestion> open;
  final List<LedgerEntry> activity;

  bool get isEmpty => open.isEmpty && activity.isEmpty;
}

/// Builds a [UnifiedSuggestionList] for a task.
///
/// Resolves the task agent, watches its update stream for reactive
/// invalidation, and queries both the pending change sets (so the UI can
/// dispatch confirm/reject through the existing
/// `ChangeSetConfirmationService` contract) and the proposal ledger (so
/// the activity strip can show recently-resolved / retracted items).
@riverpod
Future<UnifiedSuggestionList> unifiedSuggestionList(
  Ref ref,
  String taskId,
) async {
  final agent = ref
      .watch(taskAgentProvider(taskId))
      .value
      ?.mapOrNull(agent: (a) => a);
  if (agent == null) return const UnifiedSuggestionList.empty();

  ref.watch(agentUpdateStreamProvider(agent.agentId));

  final repo = ref.watch(agentRepositoryProvider);

  final pendingSets = await repo.getPendingChangeSets(
    agent.agentId,
    taskId: taskId,
  );
  final pendingChangeSets = pendingSets.whereType<ChangeSetEntity>().toList();

  final open = <PendingSuggestion>[];
  final seenFingerprints = <String>{};
  for (final cs in pendingChangeSets) {
    for (var i = 0; i < cs.items.length; i++) {
      final item = cs.items[i];
      if (item.status != ChangeItemStatus.pending) continue;
      final fingerprint = ChangeItem.fingerprint(item);
      // Race-condition dedup: two wakes may have produced sets with the
      // exact same fingerprint before persistence-time dedup kicks in.
      if (!seenFingerprints.add(fingerprint)) continue;
      open.add(
        PendingSuggestion(
          changeSet: cs,
          itemIndex: i,
          item: item,
          fingerprint: fingerprint,
        ),
      );
    }
  }
  open.sort((a, b) => b.changeSet.createdAt.compareTo(a.changeSet.createdAt));

  final ledger = await repo.getProposalLedger(agent.agentId, taskId: taskId);

  return UnifiedSuggestionList(open: open, activity: ledger.resolved);
}
