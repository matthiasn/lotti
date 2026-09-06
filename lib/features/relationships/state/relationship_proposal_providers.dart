import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/relationship_proposal_service.dart';
import 'package:lotti/features/relationships/workflow/relationship_tool_dispatcher.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';

final Provider<RelationshipToolDispatcher> relationshipToolDispatcherProvider =
    Provider(
      (ref) => RelationshipToolDispatcher(
        relationshipRepository: ref.watch(relationshipRepositoryProvider),
        persistenceLogic: getIt<PersistenceLogic>(),
        entitiesCacheService: getIt<EntitiesCacheService>(),
        taskAgentService: ref.watch(taskAgentServiceProvider),
      ),
    );

final Provider<ChangeSetConfirmationService>
relationshipChangeSetConfirmationServiceProvider = Provider(
  (ref) => ChangeSetConfirmationService(
    syncService: ref.watch(agentSyncServiceProvider),
    toolDispatcher: ref.watch(relationshipToolDispatcherProvider).dispatch,
    labelsRepository: ref.watch(labelsRepositoryProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
);

final Provider<RelationshipProposalService>
relationshipProposalServiceProvider = Provider(
  (ref) => RelationshipProposalService(
    confirmation: ref.watch(relationshipChangeSetConfirmationServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    journalDb: ref.watch(journalDbProvider),
    relationshipRepository: ref.watch(relationshipRepositoryProvider),
    taskRemover: ref.watch(relationshipToolDispatcherProvider).removeTask,
  ),
);

/// The shared suggestion rows plus durable destinations of confirmed tasks.
class RelationshipProposalSnapshot {
  const RelationshipProposalSnapshot({
    required this.suggestions,
    this.receipts = const {},
    this.runKeys = const {},
  });
  const RelationshipProposalSnapshot.empty()
    : suggestions = const UnifiedSuggestionList.empty(),
      receipts = const {},
      runKeys = const {};
  final UnifiedSuggestionList suggestions;
  final Map<String, Task> receipts;
  final Map<String, String> runKeys;
  static String itemKey(String setId, int index) => '$setId:$index';
}

/// Relationship-scoped ledger read. Agent updates refresh only this band;
/// hosts keep the previous value while the asynchronous read is running.
final FutureProviderFamily<RelationshipProposalSnapshot, String>
relationshipSuggestionListProvider = FutureProvider.autoDispose
    .family<RelationshipProposalSnapshot, String>((ref, relationshipId) async {
      final agentId = relationshipAgentIdFor(relationshipId);
      ref.watch(agentUpdateStreamProvider(agentId));
      final repository = ref.watch(agentRepositoryProvider);
      final ledger = await repository.getProposalLedger(
        agentId,
        taskId: relationshipId,
      );
      final seen = <String>{};
      final open = <PendingSuggestion>[];
      for (final set in ledger.pendingSets) {
        for (var index = 0; index < set.items.length; index++) {
          final item = set.items[index];
          if (item.status != ChangeItemStatus.pending) continue;
          final fingerprint = ChangeItem.fingerprint(item);
          if (!seen.add(fingerprint)) continue;
          open.add(
            PendingSuggestion(
              changeSet: set,
              itemIndex: index,
              item: item,
              fingerprint: fingerprint,
            ),
          );
        }
      }
      final runKeys = {
        for (final set in ledger.pendingSets) set.id: set.runKey,
      };
      for (final entry in ledger.resolved) {
        if (entry.runKey case final String runKey) {
          runKeys[entry.changeSetId] = runKey;
        }
      }
      final receipts = <String, Task>{};
      if (ledger.resolved.isNotEmpty) {
        final decisions =
            (await repository.getEntitiesByAgentId(
                  agentId,
                  type: AgentEntityTypes.changeDecision,
                ))
                .whereType<ChangeDecisionEntity>()
                .where((d) => d.deletedAt == null)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final seenDecisions = <String>{};
        for (final decision in decisions) {
          final key = RelationshipProposalSnapshot.itemKey(
            decision.changeSetId,
            decision.itemIndex,
          );
          if (!seenDecisions.add(key) ||
              decision.verdict != ChangeDecisionVerdict.confirmed) {
            continue;
          }
          final raw = decision.args?[RelationshipProposalService.receiptKey];
          final task = RelationshipProposalService.decodeReceipt(raw);
          if (task != null) receipts[key] = task;
        }
      }
      for (final entry in ledger.resolved) {
        final key = RelationshipProposalSnapshot.itemKey(
          entry.changeSetId,
          entry.itemIndex,
        );
        if (entry.status == ChangeItemStatus.confirmed &&
            !receipts.containsKey(key)) {
          final local = ref
              .read(relationshipProposalServiceProvider)
              .cachedReceipt(entry.changeSetId, entry.itemIndex);
          if (local != null) receipts[key] = local;
        }
      }
      final activityKeys = <String>{};
      return RelationshipProposalSnapshot(
        suggestions: UnifiedSuggestionList(
          open: open,
          activity: [
            for (final entry in ledger.resolved)
              if (activityKeys.add(
                RelationshipProposalSnapshot.itemKey(
                  entry.changeSetId,
                  entry.itemIndex,
                ),
              ))
                entry,
          ],
        ),
        receipts: receipts,
        runKeys: runKeys,
      );
    });

/// Briefly marks newly confirmed tasks on the person's linked-task card.
final relationshipTaskHighlightProvider =
    NotifierProvider<RelationshipTaskHighlight, Set<String>>(
      RelationshipTaskHighlight.new,
    );

class RelationshipTaskHighlight extends Notifier<Set<String>> {
  final _timers = <String, Timer>{};

  @override
  Set<String> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
    });
    return {};
  }

  void highlight(String taskId) {
    _timers.remove(taskId)?.cancel();
    state = {...state, taskId};
    _timers[taskId] = Timer(const Duration(seconds: 3), () {
      _timers.remove(taskId);
      state = {...state}..remove(taskId);
    });
  }
}
