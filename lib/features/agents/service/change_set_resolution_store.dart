import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Resolution state and side-effects for the change-set confirmation flow:
/// placeholder→actual ID capture, sibling-id propagation, migration
/// cascade-reject, decision persistence and the change-set-resolved
/// notification.
///
/// Owned by `ChangeSetConfirmationService` as a standalone collaborator;
/// it carries the in-memory placeholder→actual task-ID map that
/// `create_follow_up_task` confirmations produce and subsequent
/// `migrate_checklist_item` confirmations consume.
class ChangeSetResolutionStore {
  ChangeSetResolutionStore({
    required this._syncService,
    required this._subDomain,
    this._domainLogger,
  });

  final AgentSyncService _syncService;
  final String _subDomain;
  final DomainLogger? _domainLogger;

  static const _uuid = Uuid();

  /// Maps placeholder task IDs (from `create_follow_up_task`) to actual
  /// task IDs after successful dispatch. Persists across calls within the
  /// same store instance.
  final Map<String, String> _resolvedIds = {};

  /// Returns the actual task ID captured for [placeholderId] in this store
  /// instance, or `null` when the placeholder has not been resolved yet.
  String? resolvedIdFor(String placeholderId) => _resolvedIds[placeholderId];

  /// After a successful `create_follow_up_task` dispatch, captures the
  /// placeholder→actual ID mapping.
  void captureResolvedId(ChangeItem item, ToolExecutionResult result) {
    if (item.toolName != TaskAgentToolNames.createFollowUpTask) return;
    if (!result.success) return;

    final placeholderId = item.args['_placeholderTaskId'];
    final actualId = result.mutatedEntityId;
    if (placeholderId is String && actualId != null && actualId.isNotEmpty) {
      _resolvedIds[placeholderId] = actualId;
      _domainLogger?.log(
        LogDomain.agentWorkflow,
        'Captured placeholder resolution: '
        '${DomainLogger.sanitizeId(placeholderId)} → '
        '${DomainLogger.sanitizeId(actualId)}',
        subDomain: _subDomain,
      );
    }
  }

  /// After a successful `create_follow_up_task` dispatch, updates sibling
  /// `migrate_checklist_item` items in the same change set so that their
  /// `targetTaskId` args point to the actual task ID instead of the
  /// placeholder. This persists the mapping into the DB so it survives
  /// service disposal / app restart.
  ///
  /// Re-reads the set and writes it in one transaction, changing nothing but
  /// those arguments: a write of an earlier read would put back whatever a
  /// concurrent claim changed in between — a migration confirmed and applied
  /// meanwhile would read `pending` again and could be applied a second time
  /// (`specs/tla/ChangeSetLifecycle.tla`, `AppliedStaysDecided`).
  Future<void> persistResolvedIdToSiblings(
    ChangeItem item,
    ToolExecutionResult result,
    ChangeSetEntity changeSet,
  ) async {
    if (item.toolName != TaskAgentToolNames.createFollowUpTask) return;
    if (!result.success) return;

    final placeholderId = item.args['_placeholderTaskId'];
    final actualId = result.mutatedEntityId;
    if (placeholderId is! String || actualId == null || actualId.isEmpty) {
      return;
    }

    final persisted = await _syncService.runInTransaction(() async {
      final fresh = await freshChangeSet(changeSet);
      var changed = false;
      final updatedItems = fresh.items.map((i) {
        if (i.toolName == TaskAgentToolNames.migrateChecklistItem &&
            i.args['targetTaskId'] == placeholderId) {
          changed = true;
          return i.withArgs({...i.args, 'targetTaskId': actualId});
        }
        return i;
      }).toList();
      if (!changed) return null;
      await _syncService.upsertEntity(fresh.copyWith(items: updatedItems));
      return fresh;
    });

    if (persisted != null) {
      _domainLogger?.log(
        LogDomain.agentWorkflow,
        'Persisted resolved targetTaskId '
        '(${DomainLogger.sanitizeId(actualId)}) to sibling migration items '
        'in change set ${DomainLogger.sanitizeId(persisted.id)}',
        subDomain: _subDomain,
      );
    }
  }

  /// When a `create_follow_up_task` item is rejected, cascade-rejects all
  /// pending `migrate_checklist_item` siblings whose `targetTaskId` matches
  /// the placeholder. Without the target task, those migrations can never
  /// succeed.
  ///
  /// Each sibling is claimed like a user rejection — `pending` to `rejected`
  /// together with its decision, in one transaction — so the cascade neither
  /// overwrites a sibling decided meanwhile nor writes back a stale copy of
  /// the rest of the set.
  Future<void> cascadeRejectMigrationItems(
    ChangeSetEntity changeSet,
    String placeholderId,
    String? reason,
  ) async {
    final fresh = await freshChangeSet(changeSet);
    for (var i = 0; i < fresh.items.length; i++) {
      final sibling = fresh.items[i];
      if (sibling.toolName == TaskAgentToolNames.migrateChecklistItem &&
          sibling.status == ChangeItemStatus.pending &&
          sibling.args['targetTaskId'] == placeholderId) {
        final rejected = await _syncService.runInTransaction(() async {
          final claimed = await claimChangeSetItem(
            fresh,
            i,
            decided: ChangeItemStatus.rejected,
          );
          if (claimed == null) return null;
          await persistDecision(
            changeSet: fresh,
            itemIndex: i,
            toolName: sibling.toolName,
            verdict: ChangeDecisionVerdict.rejected,
            rejectionReason: reason ?? 'Target follow-up task was rejected',
            humanSummary: sibling.humanSummary,
            args: sibling.args,
          );
          return claimed;
        });
        if (rejected != null) {
          _domainLogger?.log(
            LogDomain.agentWorkflow,
            'Cascade-rejected migration item $i — target task rejected',
            subDomain: _subDomain,
          );
        }
      }
    }
  }

  /// Re-reads the change set from the repository to get the latest persisted
  /// state. Falls back to [fallback] if the entity is not found or has an
  /// unexpected type. Chat-owned sets fail closed with an empty tombstone
  /// instead: they cannot be recreated after chat deletion.
  Future<ChangeSetEntity> freshChangeSet(ChangeSetEntity fallback) async {
    final latest = await _syncService.repository.getEntity(fallback.id);
    if (latest is ChangeSetEntity) return latest;
    // Chat sets are always persisted at human approval. Missing means the chat
    // was deleted, never an invitation to recreate its executable snapshot.
    if (fallback.id.startsWith('query-chat:')) {
      return fallback.copyWith(items: const [], deletedAt: clock.now());
    }
    return fallback;
  }

  /// Persists a [ChangeDecisionEntity] recording the [verdict] for the item
  /// at [itemIndex] of [changeSet] and returns it.
  Future<ChangeDecisionEntity> persistDecision({
    required ChangeSetEntity changeSet,
    required int itemIndex,
    required String toolName,
    required ChangeDecisionVerdict verdict,
    DecisionActor actor = DecisionActor.user,
    String? rejectionReason,
    String? retractionReason,
    String? humanSummary,
    Map<String, dynamic>? args,
  }) async {
    final decision =
        AgentDomainEntity.changeDecision(
              id: _uuid.v4(),
              agentId: changeSet.agentId,
              changeSetId: changeSet.id,
              itemIndex: itemIndex,
              toolName: toolName,
              verdict: verdict,
              actor: actor,
              taskId: changeSet.taskId,
              rejectionReason: rejectionReason,
              retractionReason: retractionReason,
              humanSummary: humanSummary,
              args: args,
              createdAt: clock.now(),
              vectorClock: const VectorClock({}),
            )
            as ChangeDecisionEntity;

    await _syncService.upsertEntity(decision);
    return decision;
  }

  /// Claims the item at [itemIndex] for a decision: moves it from `pending`
  /// to [decided] — `confirmed` or `rejected` — in one transaction, or
  /// returns `null` when it is no longer pending: another confirm, a
  /// rejection or a retraction got there first. Drift serializes
  /// transactions, so of two concurrent claimants exactly one wins; a losing
  /// confirm must not dispatch, and a losing reject must not overwrite a
  /// change that was applied (`specs/tla/ChangeSetConfirm.tla`,
  /// `AtMostOnceApply`, `RejectedMeansNotApplied`).
  Future<ChangeSetEntity?> claimChangeSetItem(
    ChangeSetEntity changeSet,
    int itemIndex, {
    ChangeItemStatus decided = ChangeItemStatus.confirmed,
  }) => transitionChangeSetItem(
    changeSet,
    itemIndex,
    from: const {ChangeItemStatus.pending},
    to: decided,
  );

  /// Moves the item at [itemIndex] from one of the statuses in [from] to
  /// [to], on the latest persisted state of [changeSet], and derives the set
  /// status and `resolvedAt` — all in one transaction. Returns the updated
  /// entity, or `null` when the item is out of range or no longer in a
  /// [from] status, in which case nothing is written.
  ///
  /// Every status change of a stored set goes through here, and changes
  /// only its own item: a read of the set followed by a later write of all
  /// of it would put back whatever another writer changed in between — a
  /// failed dispatch reverting its own item would revert a sibling confirmed
  /// meanwhile to `pending`, inviting a second apply
  /// (`specs/tla/ChangeSetLifecycle.tla`, `AppliedStaysDecided`). Checking
  /// [from] keeps a writer from undoing a decision it did not make: a failed
  /// dispatch reverts only an item still `confirmed`.
  ///
  /// A writer that acts on a decision it made or read earlier passes that
  /// version of the item as [observed]: the move then also requires the
  /// item's [ChangeItem.revision] to be unchanged. The status alone cannot
  /// tell the decision apart from a later one with the same status — an item
  /// reopened and confirmed again while the first dispatch ran is
  /// `confirmed` again, and that dispatch's failure must not revert it.
  Future<ChangeSetEntity?> transitionChangeSetItem(
    ChangeSetEntity changeSet,
    int itemIndex, {
    required Set<ChangeItemStatus> from,
    required ChangeItemStatus to,
    ChangeItem? observed,
  }) => _syncService.runInTransaction(() async {
    // An unpersisted set is judged by the caller's snapshot, a deleted chat
    // set is gone.
    final latest = await _syncService.repository.getEntity(changeSet.id);
    if (latest is! ChangeSetEntity && changeSet.id.startsWith('query-chat:')) {
      return null;
    }
    final current = latest is ChangeSetEntity ? latest : changeSet;
    if (itemIndex < 0 ||
        itemIndex >= current.items.length ||
        !from.contains(current.items[itemIndex].status) ||
        (observed != null &&
            current.items[itemIndex].revision != observed.revision)) {
      return null;
    }
    final updated = _withItemStatus(current, itemIndex, to);
    await _syncService.upsertEntity(updated);
    return updated;
  });

  /// [current] with the item at [itemIndex] set to [newStatus] and the set
  /// status and `resolvedAt` derived from it.
  static ChangeSetEntity _withItemStatus(
    ChangeSetEntity current,
    int itemIndex,
    ChangeItemStatus newStatus,
  ) {
    final updatedItems = List<ChangeItem>.from(current.items);
    updatedItems[itemIndex] = updatedItems[itemIndex].withStatus(newStatus);
    final newSetStatus = ChangeItem.deriveSetStatus(updatedItems);
    return current.copyWith(
      items: updatedItems,
      status: newSetStatus,
      resolvedAt: ChangeItem.deriveResolvedAt(
        newStatus: newSetStatus,
        existingResolvedAt: current.resolvedAt,
        now: clock.now(),
      ),
    );
  }

  /// Invokes [callback] with the freshest persisted state of [fallback].
  /// Callback errors are logged and swallowed; a `null` callback is a no-op.
  Future<void> notifyChangeSetResolved(
    ChangeSetEntity fallback,
    Future<void> Function(ChangeSetEntity changeSet)? callback,
  ) async {
    if (callback == null) return;

    try {
      await callback(await freshChangeSet(fallback));
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        message:
            'Post-resolution notification sync failed for change set '
            '${DomainLogger.sanitizeId(fallback.id)}',
        subDomain: _subDomain,
        stackTrace: stackTrace,
      );
    }
  }
}
