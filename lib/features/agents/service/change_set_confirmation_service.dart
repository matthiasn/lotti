import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_resolution_store.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/running_timer_update_handler.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';

typedef ConfirmedDecisionCallback =
    Future<void> Function({
      required ChangeSetEntity changeSet,
      required ChangeItem item,
      required ChangeDecisionEntity decision,
    });

typedef ChangeSetResolvedCallback =
    Future<void> Function(ChangeSetEntity changeSet);

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
/// Failed confirmations normally revert to [ChangeItemStatus.pending] so the
/// user can retry. Stale `update_running_timer` confirmations are the
/// exception: once the active timer has changed, retrying the same proposal is
/// invalid, so the service records an agent retraction and removes it from the
/// open suggestion list.
///
/// For task-split workflows, manages cross-item ID resolution:
/// when `create_follow_up_task` succeeds, the placeholder→actual mapping
/// is stored in the [ChangeSetResolutionStore] so subsequent
/// `migrate_checklist_item` items can resolve the target task ID.
class ChangeSetConfirmationService {
  ChangeSetConfirmationService({
    required this._syncService,
    required this._toolDispatcher,
    required this._labelsRepository,
    this._domainLogger,
    this._onConfirmedDecision,
    this._onChangeSetResolved,
  });

  final AgentSyncService _syncService;
  final AgentToolDispatch _toolDispatcher;
  final LabelsRepository _labelsRepository;
  final DomainLogger? _domainLogger;
  final ConfirmedDecisionCallback? _onConfirmedDecision;
  final ChangeSetResolvedCallback? _onChangeSetResolved;

  static const _sub = 'ChangeSetConfirmation';

  /// Resolution state and persistence side-effects (placeholder→actual ID
  /// capture, sibling propagation, cascade-reject, decision persistence and
  /// the resolved notification), extracted into a standalone collaborator.
  late final ChangeSetResolutionStore _resolution = ChangeSetResolutionStore(
    syncService: _syncService,
    subDomain: _sub,
    domainLogger: _domainLogger,
  );

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
    final current = await _resolution.freshChangeSet(changeSet);

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
        LogDomain.agentWorkflow,
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
      LogDomain.agentWorkflow,
      'Confirming item $itemIndex (${item.toolName}) in change set '
      '${DomainLogger.sanitizeId(current.id)}, '
      '${_describeArgsForLog(dispatchArgs)}',
      subDomain: _sub,
    );

    // 1. Mark the item as confirmed and persist the decision BEFORE
    //    dispatching the tool. This ensures that if the process dies after
    //    a successful dispatch but before persistence, the item will not
    //    remain pending and be re-executed on retry.
    final decision = await _resolution.persistDecision(
      changeSet: current,
      itemIndex: itemIndex,
      toolName: item.toolName,
      verdict: ChangeDecisionVerdict.confirmed,
      humanSummary: item.humanSummary,
      args: item.args,
    );
    final confirmedSet = await _resolution.updateChangeSetItemStatus(
      current,
      itemIndex,
      ChangeItemStatus.confirmed,
    );
    if (confirmedSet == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Change item could not be updated',
        errorMessage: 'Concurrent change set update detected',
      );
    }

    // 2. Execute the tool call. If dispatch fails, either revert the status
    //    back to pending so the user can retry, or retract non-retryable stale
    //    timer proposals that can never succeed after the active timer changed.
    late final ToolExecutionResult result;
    var dispatchThrew = false;
    try {
      result = await _toolDispatcher(
        item.toolName,
        dispatchArgs,
        current.taskId,
      );
    } catch (error, stackTrace) {
      dispatchThrew = true;
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        message: 'Tool dispatch threw for item $itemIndex (${item.toolName})',
        subDomain: _sub,
        stackTrace: stackTrace,
      );
      result = ToolExecutionResult(
        success: false,
        output: 'Error: failed to apply ${item.toolName}',
        errorMessage: _dispatchFailureMessage(item.toolName, error),
      );
    }

    if (!result.success) {
      final shouldAutoRetract = _shouldAutoRetractFailedConfirmation(
        item,
        result,
        dispatchThrew: dispatchThrew,
      );
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        'Tool dispatch failed for item $itemIndex (${item.toolName}): '
        'failureKind=${_failureKindForLog(result)} — '
        '${shouldAutoRetract ? 'auto-retracting' : 'reverting to pending'}',
        subDomain: _sub,
      );
      if (shouldAutoRetract) {
        await _resolution.persistDecision(
          changeSet: current,
          itemIndex: itemIndex,
          toolName: item.toolName,
          verdict: ChangeDecisionVerdict.retracted,
          actor: DecisionActor.agent,
          retractionReason: _failedConfirmationRetractionReason(result),
          humanSummary: item.humanSummary,
          args: item.args,
        );
        final retractedSet = await _resolution.updateChangeSetItemStatus(
          confirmedSet,
          itemIndex,
          ChangeItemStatus.retracted,
        );
        if (retractedSet == null) {
          _domainLogger?.error(
            LogDomain.agentWorkflow,
            'Failed to mark item $itemIndex (${item.toolName}) as retracted '
            'after dispatch failure',
            subDomain: _sub,
          );
          return const ToolExecutionResult(
            success: false,
            output: 'Error: failed to retract stale proposal',
            errorMessage: 'Failed to update failed confirmation status',
          );
        }

        await _resolution.notifyChangeSetResolved(
          retractedSet,
          _onChangeSetResolved,
        );
      } else {
        final revertedSet = await _resolution.updateChangeSetItemStatus(
          confirmedSet,
          itemIndex,
          ChangeItemStatus.pending,
        );
        if (revertedSet == null) {
          _domainLogger?.error(
            LogDomain.agentWorkflow,
            'Failed to revert item $itemIndex (${item.toolName}) to pending '
            'after dispatch failure',
            subDomain: _sub,
          );
          return const ToolExecutionResult(
            success: false,
            output: 'Error: failed to revert proposal after dispatch failure',
            errorMessage: 'Failed to update failed confirmation status',
          );
        }
      }
      return result;
    }

    // 3. After successful create_follow_up_task, store the placeholder→actual
    //    mapping for subsequent migration items and persist the resolved ID
    //    into sibling migration items so a service restart doesn't lose it.
    _resolution.captureResolvedId(item, result);
    await _resolution.persistResolvedIdToSiblings(item, result, current);

    if (_onConfirmedDecision != null) {
      try {
        await _onConfirmedDecision(
          changeSet: current,
          item: item,
          decision: decision,
        );
      } catch (e, s) {
        _domainLogger?.error(
          LogDomain.agentWorkflow,
          e,
          message:
              'Post-confirmation handling failed for item $itemIndex '
              '(${item.toolName}) — reverting to pending',
          subDomain: _sub,
          stackTrace: s,
        );
        await _resolution.updateChangeSetItemStatus(
          current,
          itemIndex,
          ChangeItemStatus.pending,
        );
        return ToolExecutionResult(
          success: false,
          output: 'Error: failed to persist confirmed action state',
          errorMessage: 'Post-confirmation handling failed (${e.runtimeType})',
        );
      }
    }

    await _resolution.notifyChangeSetResolved(
      confirmedSet,
      _onChangeSetResolved,
    );

    return result;
  }

  static const Set<String> _autoRetractableRunningTimerFailures = {
    RunningTimerUpdateFailure.invalidSummary,
    RunningTimerUpdateFailure.invalidTimerId,
    RunningTimerUpdateFailure.noActiveTimer,
    RunningTimerUpdateFailure.sourceTaskMismatch,
    RunningTimerUpdateFailure.timerIdMismatch,
    RunningTimerUpdateFailure.unsupportedEntityType,
  };

  static String _dispatchFailureMessage(String toolName, Object error) {
    if (toolName == TaskAgentToolNames.updateRunningTimer &&
        _looksLikeNoActiveTimerError(error)) {
      return RunningTimerUpdateFailure.noActiveTimer;
    }
    return 'Tool dispatch failed (${error.runtimeType})';
  }

  static bool _looksLikeNoActiveTimerError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('no active timer') ||
        text.contains('no timer is currently running');
  }

  /// Running-timer proposals are tied to a specific in-memory active timer.
  /// Once that timer stops, switches task, or changes id, retrying the same
  /// proposal cannot succeed. Retracting the item records that stale context
  /// for the next wake and removes the dead action from the user's list.
  static bool _shouldAutoRetractFailedConfirmation(
    ChangeItem item,
    ToolExecutionResult result, {
    required bool dispatchThrew,
  }) {
    if (item.toolName != TaskAgentToolNames.updateRunningTimer) {
      return false;
    }
    if (dispatchThrew) return true;

    final error = result.errorMessage;
    return error != null &&
        _autoRetractableRunningTimerFailures.contains(error);
  }

  static String _failedConfirmationRetractionReason(
    ToolExecutionResult result,
  ) {
    final detail = (result.errorMessage?.trim().isNotEmpty ?? false)
        ? result.errorMessage!.trim()
        : result.output.trim();
    if (detail.isEmpty) {
      return 'Confirmed update_running_timer proposal failed while applying.';
    }
    return 'Confirmed update_running_timer proposal failed while applying: '
        '$detail';
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
    final current = await _resolution.freshChangeSet(changeSet);

    if (itemIndex < 0 || itemIndex >= current.items.length) {
      return false;
    }

    final item = current.items[itemIndex];

    if (item.status != ChangeItemStatus.pending) {
      _domainLogger?.log(
        LogDomain.agentWorkflow,
        'Skipping reject for item $itemIndex (${item.toolName}) — already '
        '${item.status.name}',
        subDomain: _sub,
      );
      return false;
    }

    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Rejecting item $itemIndex (${item.toolName}) in change set '
      '${DomainLogger.sanitizeId(current.id)}',
      subDomain: _sub,
    );

    // 1. Persist the decision (no tool dispatch for rejections).
    await _resolution.persistDecision(
      changeSet: current,
      itemIndex: itemIndex,
      toolName: item.toolName,
      verdict: ChangeDecisionVerdict.rejected,
      rejectionReason: reason,
      humanSummary: item.humanSummary,
      args: item.args,
    );

    // 2. Update the change set item status and overall status.
    final rejectedSet = await _resolution.updateChangeSetItemStatus(
      current,
      itemIndex,
      ChangeItemStatus.rejected,
    );
    if (rejectedSet == null) {
      return false;
    }

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
        await _resolution.cascadeRejectMigrationItems(
          current,
          placeholderId,
          reason,
        );
      }
    }

    await _resolution.notifyChangeSetResolved(
      rejectedSet,
      _onChangeSetResolved,
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
    var current = await _resolution.freshChangeSet(changeSet);

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
  /// 3. Already a real ID (e.g. persisted by
  ///    [ChangeSetResolutionStore.persistResolvedIdToSiblings] in a prior
  ///    service instance) → return args as-is.
  Map<String, dynamic>? _resolveArgsIfNeeded(
    ChangeItem item,
    ChangeSetEntity changeSet,
  ) {
    final contextualArgs = item.args;

    if (item.toolName != TaskAgentToolNames.migrateChecklistItem) {
      return contextualArgs;
    }

    final targetTaskId = contextualArgs['targetTaskId'];
    if (targetTaskId is! String || targetTaskId.isEmpty) {
      return contextualArgs;
    }

    // Case 1: in-memory resolution from this service instance.
    final resolved = _resolution.resolvedIdFor(targetTaskId);
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
    // service instance via ChangeSetResolutionStore.persistResolvedIdToSiblings).
    return contextualArgs;
  }

  static const _safeLogArgNames = {
    '_placeholderTaskId',
    'dueDate',
    'endTime',
    'entryId',
    'id',
    'items',
    'labels',
    'languageCode',
    'minutes',
    'priority',
    'reason',
    'startTime',
    'status',
    'summary',
    'targetTaskId',
    'timerId',
    'title',
  };

  /// Test seam for the PII-safe arg formatter — pure, no state.
  @visibleForTesting
  static String debugDescribeArgsForLog(Map<String, dynamic> args) =>
      _describeArgsForLog(args);

  static String _describeArgsForLog(Map<String, dynamic> args) {
    final knownNames =
        args.keys
            .where((key) => _safeLogArgNames.contains(key))
            .cast<String>()
            .toList()
          ..sort();
    final unknownCount = args.length - knownNames.length;
    return 'argCount=${args.length}, '
        'knownArgs=[${knownNames.join(',')}], '
        'unknownArgCount=$unknownCount';
  }

  static String _failureKindForLog(ToolExecutionResult result) {
    if (result.policyDenied) return 'policyDenied';
    if (result.errorMessage != null) return 'toolError';
    return 'toolFailure';
  }
}
