import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:uuid/uuid.dart';

/// Handles user confirmation and rejection of individual change items
/// within a [ChangeSetEntity].
///
/// On confirmation, the corresponding tool call is dispatched via
/// [TaskToolDispatcher] and a [ChangeDecisionEntity] is persisted.
/// On rejection, only the decision is persisted (no tool dispatch).
///
/// After each item resolution, the change set's status is updated:
/// - All items resolved → [ChangeSetStatus.resolved]
/// - Some items resolved → [ChangeSetStatus.partiallyResolved]
class ChangeSetConfirmationService {
  ChangeSetConfirmationService({
    required AgentSyncService syncService,
    required TaskToolDispatcher toolDispatcher,
  })  : _syncService = syncService,
        _toolDispatcher = toolDispatcher;

  final AgentSyncService _syncService;
  final TaskToolDispatcher _toolDispatcher;

  static const _uuid = Uuid();

  /// Confirms a single change item at [itemIndex], dispatching its tool call
  /// and persisting the decision.
  ///
  /// Returns the [ToolExecutionResult] from the tool dispatch.
  Future<ToolExecutionResult> confirmItem(
    ChangeSetEntity changeSet,
    int itemIndex,
  ) async {
    // Re-read persisted state to guard against stale snapshots from the
    // caller (e.g. rapid repeated taps or concurrent clients).
    final current = await _freshChangeSet(changeSet);

    if (itemIndex < 0 || itemIndex >= current.items.length) {
      return const ToolExecutionResult(
        success: false,
        output: 'Invalid change item index',
        errorMessage: 'Item index out of range',
      );
    }

    final item = current.items[itemIndex];

    if (item.status != ChangeItemStatus.pending) {
      developer.log(
        'Skipping item $itemIndex (${item.toolName}) — already '
        '${item.status.name}',
        name: 'ChangeSetConfirmationService',
      );
      return ToolExecutionResult(
        success: false,
        output: 'Item already ${item.status.name}',
        errorMessage: 'Item is not pending',
      );
    }

    developer.log(
      'Confirming item $itemIndex (${item.toolName}) in change set '
      '${current.id}',
      name: 'ChangeSetConfirmationService',
    );

    // 1. Mark the item as confirmed and persist the decision BEFORE
    //    dispatching the tool. This ensures that if the process dies after
    //    a successful dispatch but before persistence, the item will not
    //    remain pending and be re-executed on retry.
    await _persistDecision(
      changeSet: current,
      itemIndex: itemIndex,
      toolName: item.toolName,
      verdict: ChangeDecisionVerdict.confirmed,
    );
    await _updateChangeSetItemStatus(
      current,
      itemIndex,
      ChangeItemStatus.confirmed,
    );

    // 2. Execute the tool call. If dispatch fails, revert the status back
    //    to pending so the user can retry.
    final result = await _toolDispatcher.dispatch(
      item.toolName,
      item.args,
      current.taskId,
    );

    if (!result.success) {
      developer.log(
        'Tool dispatch failed for item $itemIndex (${item.toolName}): '
        '${result.errorMessage ?? result.output} — reverting to pending',
        name: 'ChangeSetConfirmationService',
      );
      await _updateChangeSetItemStatus(
        current,
        itemIndex,
        ChangeItemStatus.pending,
      );
      return result;
    }

    return result;
  }

  /// Rejects a single change item at [itemIndex] without dispatching
  /// any tool call.
  ///
  /// Returns `true` if the rejection was applied, `false` if the item
  /// was already resolved (no-op).
  Future<bool> rejectItem(
    ChangeSetEntity changeSet,
    int itemIndex, {
    String? reason,
  }) async {
    // Re-read persisted state to guard against stale snapshots.
    final current = await _freshChangeSet(changeSet);

    if (itemIndex < 0 || itemIndex >= current.items.length) {
      return false;
    }

    final item = current.items[itemIndex];

    if (item.status != ChangeItemStatus.pending) {
      developer.log(
        'Skipping reject for item $itemIndex (${item.toolName}) — already '
        '${item.status.name}',
        name: 'ChangeSetConfirmationService',
      );
      return false;
    }

    developer.log(
      'Rejecting item $itemIndex (${item.toolName}) in change set '
      '${current.id}',
      name: 'ChangeSetConfirmationService',
    );

    // 1. Persist the decision (no tool dispatch for rejections).
    await _persistDecision(
      changeSet: current,
      itemIndex: itemIndex,
      toolName: item.toolName,
      verdict: ChangeDecisionVerdict.rejected,
      rejectionReason: reason,
    );

    // 2. Update the change set item status and overall status.
    await _updateChangeSetItemStatus(
      current,
      itemIndex,
      ChangeItemStatus.rejected,
    );

    return true;
  }

  /// Confirms all pending items in the change set, returning the results
  /// of each tool dispatch.
  Future<List<ToolExecutionResult>> confirmAll(
    ChangeSetEntity changeSet,
  ) async {
    final results = <ToolExecutionResult>[];

    // Re-read the latest change set state before iterating so we don't
    // accidentally re-confirm already-resolved items.
    var current = await _freshChangeSet(changeSet);

    for (var i = 0; i < current.items.length; i++) {
      if (current.items[i].status == ChangeItemStatus.pending) {
        final result = await confirmItem(current, i);
        results.add(result);

        // Re-read the updated change set from the persisted state
        // so subsequent iterations see the latest item statuses.
        final updated = await _syncService.repository.getEntity(current.id);
        if (updated is ChangeSetEntity) {
          current = updated;
        }
      }
    }

    return results;
  }

  /// Re-reads the change set from the repository to get the latest persisted
  /// state. Falls back to [fallback] if the entity is not found or has an
  /// unexpected type.
  Future<ChangeSetEntity> _freshChangeSet(ChangeSetEntity fallback) async {
    final latest = await _syncService.repository.getEntity(fallback.id);
    return latest is ChangeSetEntity ? latest : fallback;
  }

  Future<void> _persistDecision({
    required ChangeSetEntity changeSet,
    required int itemIndex,
    required String toolName,
    required ChangeDecisionVerdict verdict,
    String? rejectionReason,
  }) async {
    final decision = AgentDomainEntity.changeDecision(
      id: _uuid.v4(),
      agentId: changeSet.agentId,
      changeSetId: changeSet.id,
      itemIndex: itemIndex,
      toolName: toolName,
      verdict: verdict,
      taskId: changeSet.taskId,
      rejectionReason: rejectionReason,
      createdAt: clock.now(),
      vectorClock: const VectorClock({}),
    );

    await _syncService.upsertEntity(decision);
  }

  Future<void> _updateChangeSetItemStatus(
    ChangeSetEntity changeSet,
    int itemIndex,
    ChangeItemStatus newStatus,
  ) async {
    // Re-read the latest entity to avoid overwriting concurrent updates.
    final latest = await _syncService.repository.getEntity(changeSet.id);
    final current = latest is ChangeSetEntity ? latest : changeSet;

    if (itemIndex < 0 || itemIndex >= current.items.length) {
      return;
    }

    final updatedItems = List<ChangeItem>.from(current.items);
    updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
      status: newStatus,
    );

    // Determine overall status.
    final allResolved = updatedItems.every(
      (item) => item.status != ChangeItemStatus.pending,
    );
    final anyResolved = updatedItems.any(
      (item) => item.status != ChangeItemStatus.pending,
    );

    final newSetStatus = allResolved
        ? ChangeSetStatus.resolved
        : anyResolved
            ? ChangeSetStatus.partiallyResolved
            : ChangeSetStatus.pending;

    final updatedChangeSet = current.copyWith(
      items: updatedItems,
      status: newSetStatus,
      resolvedAt: allResolved ? clock.now() : current.resolvedAt,
    );

    await _syncService.upsertEntity(updatedChangeSet);
  }
}
