import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

typedef ConfirmedDecisionCallback =
    Future<void> Function({
      required ChangeSetEntity changeSet,
      required ChangeItem item,
      required ChangeDecisionEntity decision,
    });

/// Handles user confirmation and rejection of individual change items
/// within a [ChangeSetEntity].
///
/// On confirmation, the corresponding tool call is dispatched via
/// [AgentToolDispatch] and a [ChangeDecisionEntity] is persisted.
/// On rejection, only the decision is persisted (no tool dispatch).
///
/// After each item resolution, the change set's status is updated:
/// - All items resolved → [ChangeSetStatus.resolved]
/// - Some items resolved → [ChangeSetStatus.partiallyResolved]
///
/// For task-split workflows, manages cross-item ID resolution:
/// when `create_follow_up_task` succeeds, the placeholder→actual mapping
/// is stored in [_resolvedIds] so subsequent `migrate_checklist_item`
/// items can resolve the target task ID.
class ChangeSetConfirmationService {
  ChangeSetConfirmationService({
    required AgentSyncService syncService,
    required AgentToolDispatch toolDispatcher,
    required LabelsRepository labelsRepository,
    DomainLogger? domainLogger,
    ConfirmedDecisionCallback? onConfirmedDecision,
  }) : _syncService = syncService,
       _toolDispatcher = toolDispatcher,
       _labelsRepository = labelsRepository,
       _domainLogger = domainLogger,
       _onConfirmedDecision = onConfirmedDecision;

  final AgentSyncService _syncService;
  final AgentToolDispatch _toolDispatcher;
  final LabelsRepository _labelsRepository;
  final DomainLogger? _domainLogger;
  final ConfirmedDecisionCallback? _onConfirmedDecision;

  static const _uuid = Uuid();
  static const _sub = 'ChangeSetConfirmation';

  /// Maps placeholder task IDs (from `create_follow_up_task`) to actual
  /// task IDs after successful dispatch. Persists across calls within the
  /// same service instance.
  final Map<String, String> _resolvedIds = {};

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
      _domainLogger?.log(
        LogDomains.agentWorkflow,
        'Skipping item $itemIndex (${item.toolName}) — already '
        '${item.status.name}',
        subDomain: _sub,
      );
      return ToolExecutionResult(
        success: false,
        output: 'Item already ${item.status.name}',
        errorMessage: 'Item is not pending',
      );
    }

    // For migration items, resolve the placeholder targetTaskId before
    // dispatch.
    final dispatchArgs = _resolveArgsIfNeeded(item, current);
    if (dispatchArgs == null) {
      // Resolution failed — target task not yet created.
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: target task has not been created yet. '
            'Confirm the follow-up task first.',
        errorMessage: 'Unresolved placeholder targetTaskId',
      );
    }

    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Confirming item $itemIndex (${item.toolName}) in change set '
      '${current.id}, dispatchArgs: $dispatchArgs',
      subDomain: _sub,
    );

    // 1. Mark the item as confirmed and persist the decision BEFORE
    //    dispatching the tool. This ensures that if the process dies after
    //    a successful dispatch but before persistence, the item will not
    //    remain pending and be re-executed on retry.
    final decision = await _persistDecision(
      changeSet: current,
      itemIndex: itemIndex,
      toolName: item.toolName,
      verdict: ChangeDecisionVerdict.confirmed,
      humanSummary: item.humanSummary,
      args: item.args,
    );
    await _updateChangeSetItemStatus(
      current,
      itemIndex,
      ChangeItemStatus.confirmed,
    );

    // 2. Execute the tool call. If dispatch fails, revert the status back
    //    to pending so the user can retry.
    final result = await _toolDispatcher(
      item.toolName,
      dispatchArgs,
      current.taskId,
    );

    if (!result.success) {
      _domainLogger?.error(
        LogDomains.agentWorkflow,
        'Tool dispatch failed for item $itemIndex (${item.toolName}): '
        '${result.errorMessage ?? result.output} — reverting to pending',
        subDomain: _sub,
      );
      await _updateChangeSetItemStatus(
        current,
        itemIndex,
        ChangeItemStatus.pending,
      );
      return result;
    }

    // 3. After successful create_follow_up_task, store the placeholder→actual
    //    mapping for subsequent migration items and persist the resolved ID
    //    into sibling migration items so a service restart doesn't lose it.
    _captureResolvedId(item, result);
    await _persistResolvedIdToSiblings(item, result, current);

    if (_onConfirmedDecision != null) {
      try {
        await _onConfirmedDecision(
          changeSet: current,
          item: item,
          decision: decision,
        );
      } catch (e, s) {
        _domainLogger?.error(
          LogDomains.agentWorkflow,
          'Post-confirmation handling failed for item $itemIndex '
          '(${item.toolName}) — reverting to pending',
          subDomain: _sub,
          error: e,
          stackTrace: s,
        );
        await _updateChangeSetItemStatus(
          current,
          itemIndex,
          ChangeItemStatus.pending,
        );
        return ToolExecutionResult(
          success: false,
          output: 'Error: failed to persist confirmed action state',
          errorMessage: e.toString(),
        );
      }
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
      _domainLogger?.log(
        LogDomains.agentWorkflow,
        'Skipping reject for item $itemIndex (${item.toolName}) — already '
        '${item.status.name}',
        subDomain: _sub,
      );
      return false;
    }

    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Rejecting item $itemIndex (${item.toolName}) in change set '
      '${current.id}',
      subDomain: _sub,
    );

    // 1. Persist the decision (no tool dispatch for rejections).
    await _persistDecision(
      changeSet: current,
      itemIndex: itemIndex,
      toolName: item.toolName,
      verdict: ChangeDecisionVerdict.rejected,
      rejectionReason: reason,
      humanSummary: item.humanSummary,
      args: item.args,
    );

    // 2. Update the change set item status and overall status.
    await _updateChangeSetItemStatus(
      current,
      itemIndex,
      ChangeItemStatus.rejected,
    );

    // 3. For rejected label assignments, automatically suppress the label
    //    so the agent does not re-propose it in future wakes.
    if (item.toolName == TaskAgentToolNames.assignTaskLabel) {
      final labelId = item.args['id'];
      if (labelId is String) {
        await _labelsRepository.suppressLabelOnTask(
          taskId: current.taskId,
          labelId: labelId,
        );
      }
    }

    // 4. For rejected follow-up tasks, cascade-reject sibling migration
    //    items that reference this task's placeholder — they can never
    //    succeed without the target task.
    if (item.toolName == TaskAgentToolNames.createFollowUpTask) {
      final placeholderId = item.args['_placeholderTaskId'];
      if (placeholderId is String) {
        await _cascadeRejectMigrationItems(current, placeholderId, reason);
      }
    }

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

  /// Resolves args for migration items that reference a placeholder
  /// targetTaskId.
  ///
  /// Returns the (possibly modified) args map, or `null` if the placeholder
  /// cannot be resolved (target task not yet created).
  ///
  /// Distinguishes three cases for targetTaskId:
  /// 1. In-memory resolved → substitute with actual ID.
  /// 2. Known placeholder (a matching create_follow_up_task exists in the
  ///    change set) but not yet resolved → return `null` to block dispatch.
  /// 3. Already a real ID (e.g. persisted by [_persistResolvedIdToSiblings]
  ///    in a prior service instance) → return args as-is.
  Map<String, dynamic>? _resolveArgsIfNeeded(
    ChangeItem item,
    ChangeSetEntity changeSet,
  ) {
    final contextualArgs = _injectDispatchContext(item, changeSet);

    if (item.toolName != TaskAgentToolNames.migrateChecklistItem) {
      return contextualArgs;
    }

    final targetTaskId = contextualArgs['targetTaskId'];
    if (targetTaskId is! String || targetTaskId.isEmpty) {
      return contextualArgs;
    }

    // Case 1: in-memory resolution from this service instance.
    final resolved = _resolvedIds[targetTaskId];
    if (resolved != null) {
      return {...contextualArgs, 'targetTaskId': resolved};
    }

    // Case 2: check if targetTaskId is a known placeholder in this change set.
    final isPlaceholder = changeSet.items.any(
      (i) =>
          i.toolName == TaskAgentToolNames.createFollowUpTask &&
          i.args['_placeholderTaskId'] == targetTaskId,
    );
    if (isPlaceholder) {
      // Block: the follow-up task must be confirmed first.
      return null;
    }

    // Case 3: targetTaskId is a real ID (already resolved by a prior
    // service instance via _persistResolvedIdToSiblings).
    return contextualArgs;
  }

  Map<String, dynamic> _injectDispatchContext(
    ChangeItem item,
    ChangeSetEntity changeSet,
  ) {
    if (item.toolName != TaskAgentToolNames.createTimeEntry) {
      return item.args;
    }

    return {
      ...item.args,
      timeEntryReferenceTimestampArg: changeSet.createdAt.toIso8601String(),
    };
  }

  /// After a successful `create_follow_up_task` dispatch, updates sibling
  /// `migrate_checklist_item` items in the same change set so that their
  /// `targetTaskId` args point to the actual task ID instead of the
  /// placeholder. This persists the mapping into the DB so it survives
  /// service disposal / app restart.
  Future<void> _persistResolvedIdToSiblings(
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

    // Re-read the change set to get the latest item statuses.
    final fresh = await _freshChangeSet(changeSet);
    var changed = false;
    final updatedItems = fresh.items.map((i) {
      if (i.toolName == TaskAgentToolNames.migrateChecklistItem &&
          i.args['targetTaskId'] == placeholderId) {
        changed = true;
        return i.copyWith(args: {...i.args, 'targetTaskId': actualId});
      }
      return i;
    }).toList();

    if (changed) {
      await _syncService.upsertEntity(fresh.copyWith(items: updatedItems));
      _domainLogger?.log(
        LogDomains.agentWorkflow,
        'Persisted resolved targetTaskId ($actualId) to sibling '
        'migration items in change set ${fresh.id}',
        subDomain: _sub,
      );
    }
  }

  /// When a `create_follow_up_task` item is rejected, cascade-rejects all
  /// pending `migrate_checklist_item` siblings whose `targetTaskId` matches
  /// the placeholder. Without the target task, those migrations can never
  /// succeed.
  Future<void> _cascadeRejectMigrationItems(
    ChangeSetEntity changeSet,
    String placeholderId,
    String? reason,
  ) async {
    final fresh = await _freshChangeSet(changeSet);
    for (var i = 0; i < fresh.items.length; i++) {
      final sibling = fresh.items[i];
      if (sibling.toolName == TaskAgentToolNames.migrateChecklistItem &&
          sibling.status == ChangeItemStatus.pending &&
          sibling.args['targetTaskId'] == placeholderId) {
        _domainLogger?.log(
          LogDomains.agentWorkflow,
          'Cascade-rejecting migration item $i — target task rejected',
          subDomain: _sub,
        );

        await _persistDecision(
          changeSet: fresh,
          itemIndex: i,
          toolName: sibling.toolName,
          verdict: ChangeDecisionVerdict.rejected,
          rejectionReason: reason ?? 'Target follow-up task was rejected',
          humanSummary: sibling.humanSummary,
          args: sibling.args,
        );

        await _updateChangeSetItemStatus(
          fresh,
          i,
          ChangeItemStatus.rejected,
        );
      }
    }
  }

  /// After a successful `create_follow_up_task` dispatch, captures the
  /// placeholder→actual ID mapping.
  void _captureResolvedId(ChangeItem item, ToolExecutionResult result) {
    if (item.toolName != TaskAgentToolNames.createFollowUpTask) return;
    if (!result.success) return;

    final placeholderId = item.args['_placeholderTaskId'];
    final actualId = result.mutatedEntityId;
    if (placeholderId is String && actualId != null && actualId.isNotEmpty) {
      _resolvedIds[placeholderId] = actualId;
      _domainLogger?.log(
        LogDomains.agentWorkflow,
        'Captured placeholder resolution: $placeholderId → $actualId',
        subDomain: _sub,
      );
    }
  }

  /// Re-reads the change set from the repository to get the latest persisted
  /// state. Falls back to [fallback] if the entity is not found or has an
  /// unexpected type.
  Future<ChangeSetEntity> _freshChangeSet(ChangeSetEntity fallback) async {
    final latest = await _syncService.repository.getEntity(fallback.id);
    return latest is ChangeSetEntity ? latest : fallback;
  }

  Future<ChangeDecisionEntity> _persistDecision({
    required ChangeSetEntity changeSet,
    required int itemIndex,
    required String toolName,
    required ChangeDecisionVerdict verdict,
    DecisionActor actor = DecisionActor.user,
    String? rejectionReason,
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
              humanSummary: humanSummary,
              args: args,
              createdAt: clock.now(),
              vectorClock: const VectorClock({}),
            )
            as ChangeDecisionEntity;

    await _syncService.upsertEntity(decision);
    return decision;
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

    final newSetStatus = ChangeItem.deriveSetStatus(updatedItems);
    final resolvedAt = ChangeItem.deriveResolvedAt(
      newStatus: newSetStatus,
      existingResolvedAt: current.resolvedAt,
      now: clock.now(),
    );

    await _syncService.upsertEntity(
      current.copyWith(
        items: updatedItems,
        status: newSetStatus,
        resolvedAt: resolvedAt,
      ),
    );
  }
}
