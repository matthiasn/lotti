import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_resolution_store.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Dispatch with optional trusted chat approval metadata, outside tool JSON.
typedef ApprovedTaskToolDispatch =
    Future<ToolExecutionResult> Function(
      String name,
      Map<String, dynamic> args,
      String taskId,
      ChecklistItemProvenance? approval,
    );

typedef ConfirmedDecisionCallback =
    Future<void> Function({
      required ChangeSetEntity changeSet,
      required ChangeItem item,
      required ChangeDecisionEntity decision,
    });

typedef ChangeSetResolvedCallback =
    Future<void> Function(ChangeSetEntity changeSet);

typedef _ClaimedDecision = ({
  ChangeSetEntity changeSet,
  ChangeDecisionEntity decision,
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
/// Failed confirmations normally revert to [ChangeItemStatus.pending] so the
/// user can retry. A dispatcher can mark a deterministic failure as
/// [ToolExecutionResult.nonRetryable]; such failures are recorded as agent
/// retractions and removed from the open list.
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
    this.approvedToolDispatcher,
  });

  final AgentSyncService _syncService;
  final AgentToolDispatch _toolDispatcher;
  final ApprovedTaskToolDispatch? approvedToolDispatcher;
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
  ) => _confirmItem(changeSet, itemIndex, ChecklistApprovalMode.individual);

  Future<ToolExecutionResult> _confirmItem(
    ChangeSetEntity changeSet,
    int itemIndex,
    ChecklistApprovalMode approvalMode,
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
      '${describeArgsForLog(dispatchArgs)}',
      subDomain: _sub,
    );

    final isChat =
        current.id == '${current.runKey}:actions' &&
        current.runKey.startsWith('query-chat:');
    final approvalHost = isChat && approvedToolDispatcher != null
        ? await _syncService.localHost()
        : null;

    // 1. Claim the item — an atomic pending -> confirmed compare-and-swap —
    //    and persist the decision BEFORE dispatching the tool, in one
    //    transaction: a failed decision write rolls the claim back instead
    //    of stranding the item confirmed but never applied. Of two
    //    concurrent confirms only one claims the item; the other stops here
    //    instead of applying the change a second time. And if the process
    //    dies after a successful dispatch, the item is not left pending to
    //    be re-executed on retry.
    final claim = await _claimDecision(
      current,
      itemIndex,
      decided: ChangeItemStatus.confirmed,
      verdict: ChangeDecisionVerdict.confirmed,
    );
    if (claim == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Change item is no longer pending',
        errorMessage: 'Concurrent change set update detected',
      );
    }
    final (changeSet: confirmedSet, :decision) = claim;

    // 2. Execute the tool call. If dispatch fails, either revert the status
    //    back to pending so the user can retry, or retract non-retryable stale
    //    proposals that can never succeed with their immutable arguments.
    //    Either write moves only this item, and only while it is still the
    //    `confirmed` this claim made it, so it cannot put back a sibling that
    //    was decided while the tool ran.
    late final ToolExecutionResult result;
    try {
      final approval = approvalHost == null
          ? null
          : ChecklistItemProvenance(
              approvedBy: 'user',
              approvalHost: approvalHost,
              approvedAt: decision.createdAt,
              approvalMode: approvalMode,
              originatingMessageId: current.runKey.substring(
                'query-chat:'.length,
              ),
              conversationId: current.threadId,
              changeSetId: current.id,
              decisionId: decision.id,
              agentId: current.agentId,
            );
      result = approvedToolDispatcher == null
          ? await _toolDispatcher(item.toolName, dispatchArgs, current.taskId)
          : await approvedToolDispatcher!(
              item.toolName,
              dispatchArgs,
              current.taskId,
              approval,
            );
    } catch (error, stackTrace) {
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
        errorMessage: 'Tool dispatch failed (${error.runtimeType})',
      );
    }

    if (!result.success) {
      final shouldAutoRetract = result.nonRetryable;
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        'Tool dispatch failed for item $itemIndex (${item.toolName}): '
        'failureKind=${_failureKindForLog(result)} — '
        '${shouldAutoRetract ? 'auto-retracting' : 'reverting to pending'}',
        subDomain: _sub,
      );
      if (shouldAutoRetract) {
        // The retraction is recorded only if the item was still ours to
        // retract — in the same transaction, so an item reopened meanwhile
        // is not left pending beside a decision saying it was retracted.
        final retractedSet = await _syncService.runInTransaction(() async {
          final retracted = await _resolution.transitionChangeSetItem(
            confirmedSet,
            itemIndex,
            from: const {ChangeItemStatus.confirmed},
            to: ChangeItemStatus.retracted,
          );
          if (retracted == null) return null;
          await _resolution.persistDecision(
            changeSet: current,
            itemIndex: itemIndex,
            toolName: item.toolName,
            verdict: ChangeDecisionVerdict.retracted,
            actor: DecisionActor.agent,
            retractionReason: _failedConfirmationRetractionReason(
              item,
              result,
            ),
            humanSummary: item.humanSummary,
            args: item.args,
          );
          return retracted;
        });
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
        final revertedSet = await _resolution.transitionChangeSetItem(
          confirmedSet,
          itemIndex,
          from: const {ChangeItemStatus.confirmed},
          to: ChangeItemStatus.pending,
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
        // The change has already been applied. Reverting the item to
        // pending would invite a retry that applies it a second time, so it
        // stays confirmed and the bookkeeping failure is only logged.
        _domainLogger?.error(
          LogDomain.agentWorkflow,
          e,
          message:
              'Post-confirmation handling failed for item $itemIndex '
              '(${item.toolName}) — the change was applied and stays '
              'confirmed',
          subDomain: _sub,
          stackTrace: s,
        );
      }
    }

    await _resolution.notifyChangeSetResolved(
      confirmedSet,
      _onChangeSetResolved,
    );

    return result;
  }

  /// Claims and records a decision atomically. A transaction can throw after
  /// committing when its sync outbox flush fails. The newly minted decision ID
  /// is this caller's commit witness: only if it survived may this caller
  /// continue dispatch or rejection side-effects. Another caller's confirmed
  /// status alone would not prove ownership. A rollback leaves no witness and
  /// propagates the original failure without applying anything.
  Future<_ClaimedDecision?> _claimDecision(
    ChangeSetEntity current,
    int itemIndex, {
    required ChangeItemStatus decided,
    required ChangeDecisionVerdict verdict,
    String? rejectionReason,
  }) async {
    _ClaimedDecision? candidate;
    try {
      return await _syncService.runInTransaction(() async {
        final claimed = await _resolution.claimChangeSetItem(
          current,
          itemIndex,
          decided: decided,
        );
        if (claimed == null) return null;
        final item = current.items[itemIndex];
        final decision = await _resolution.persistDecision(
          changeSet: current,
          itemIndex: itemIndex,
          toolName: item.toolName,
          verdict: verdict,
          rejectionReason: rejectionReason,
          humanSummary: item.humanSummary,
          args: item.args,
        );
        return candidate = (changeSet: claimed, decision: decision);
      });
    } catch (error, stackTrace) {
      final claim = candidate;
      if (claim == null ||
          await _syncService.repository.getEntity(claim.decision.id)
              is! ChangeDecisionEntity) {
        rethrow;
      }
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        message:
            'Decision committed despite a post-commit failure; '
            'continuing item $itemIndex (${verdict.name})',
        subDomain: _sub,
        stackTrace: stackTrace,
      );
      return claim;
    }
  }

  static String _failedConfirmationRetractionReason(
    ChangeItem item,
    ToolExecutionResult result,
  ) {
    final detail = (result.errorMessage?.trim().isNotEmpty ?? false)
        ? result.errorMessage!.trim()
        : result.output.trim();
    if (detail.isEmpty) {
      return 'Confirmed ${item.toolName} proposal failed while applying.';
    }
    return 'Confirmed ${item.toolName} proposal failed while applying: '
        '$detail';
  }

  /// Puts a decided item back to [ChangeItemStatus.pending] — the user's Undo
  /// on a confirmed or rejected proposal — and neutralises the verdict that
  /// stood for it: the newest user decision for the item is rewritten in
  /// place as [ChangeDecisionVerdict.deferred], dated now so the rewrite wins
  /// last-writer-wins on other devices (feedback extraction reads verdicts
  /// straight off the decisions, so a fresh neutral record next to the old
  /// one would leave the undone verdict training the template). When no
  /// decision can be found — decided on a device that has not synced it —
  /// a fresh deferred decision is recorded instead.
  ///
  /// [revert] undoes whatever a confirmed tool did, and runs only once the
  /// record says pending again, so a failed reopen never strands a reversed
  /// effect behind a confirmed row. If the revert refuses or throws, the
  /// record is put back the way it was — item status and verdict — and the
  /// method returns `false`, leaving the effect and the record in agreement.
  ///
  /// Returns `false` when the item is out of range, still pending, or
  /// retracted by the agent (nothing of the user's to undo).
  Future<bool> reopenItem(
    ChangeSetEntity changeSet,
    int itemIndex, {
    Future<bool> Function()? revert,
  }) async {
    final current = await _resolution.freshChangeSet(changeSet);
    if (itemIndex < 0 || itemIndex >= current.items.length) return false;
    final item = current.items[itemIndex];
    if (item.status != ChangeItemStatus.confirmed &&
        item.status != ChangeItemStatus.rejected) {
      _domainLogger?.log(
        LogDomain.agentWorkflow,
        'Skipping reopen for item $itemIndex (${item.toolName}) — '
        '${item.status.name}',
        subDomain: _sub,
      );
      return false;
    }

    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Reopening ${item.status.name} item $itemIndex (${item.toolName}) in '
      'change set ${DomainLogger.sanitizeId(current.id)}',
      subDomain: _sub,
    );
    final standing = await _latestUserDecision(current, itemIndex);
    // The verdict is neutralised in the same transaction that moves the item
    // back to pending, and only while the item still holds the decision this
    // method read: a concurrent change leaves both untouched.
    final reopenedWith = await _syncService.runInTransaction(() async {
      final reopened = await _resolution.transitionChangeSetItem(
        current,
        itemIndex,
        from: {item.status},
        to: ChangeItemStatus.pending,
      );
      if (reopened == null) return null;
      final ChangeDecisionEntity decision;
      if (standing == null) {
        decision = await _resolution.persistDecision(
          changeSet: current,
          itemIndex: itemIndex,
          toolName: item.toolName,
          verdict: ChangeDecisionVerdict.deferred,
          humanSummary: item.humanSummary,
          args: item.args,
        );
      } else {
        decision = standing.copyWith(
          verdict: ChangeDecisionVerdict.deferred,
          createdAt: clock.now(),
        );
        await _syncService.upsertEntity(decision);
      }
      return decision;
    });
    if (reopenedWith == null) return false;
    if (revert == null) return true;

    var reverted = false;
    try {
      reverted = await revert();
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        stackTrace: stackTrace,
        subDomain: _sub,
        message: 'Revert threw while reopening item $itemIndex',
      );
    }
    if (reverted) return true;

    // The effect stands, so the record must say so again.
    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Revert refused for item $itemIndex (${item.toolName}); restoring '
      '${item.status.name}',
      subDomain: _sub,
    );
    await _syncService.runInTransaction(() async {
      final restored = await _resolution.transitionChangeSetItem(
        current,
        itemIndex,
        from: const {ChangeItemStatus.pending},
        to: item.status,
      );
      if (restored == null) return;
      await _syncService.upsertEntity(
        reopenedWith.copyWith(
          verdict: item.status == ChangeItemStatus.confirmed
              ? ChangeDecisionVerdict.confirmed
              : ChangeDecisionVerdict.rejected,
          createdAt: clock.now(),
        ),
      );
    });
    return false;
  }

  /// The newest decision a user recorded for the item at [itemIndex] of
  /// [changeSet], or `null` when none is stored locally.
  Future<ChangeDecisionEntity?> _latestUserDecision(
    ChangeSetEntity changeSet,
    int itemIndex,
  ) async {
    final entities = await _syncService.repository.getEntitiesByAgentId(
      changeSet.agentId,
      type: AgentEntityTypes.changeDecision,
      limit: _decisionLookupLimit,
    );
    // Newest first.
    return entities.whereType<ChangeDecisionEntity>().firstWhereOrNull(
      (decision) =>
          decision.changeSetId == changeSet.id &&
          decision.itemIndex == itemIndex &&
          decision.actor == DecisionActor.user,
    );
  }

  /// How far back the newest-first decision read looks for an item's
  /// standing verdict; a decided item's decision is always recent.
  static const _decisionLookupLimit = 200;

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

    // 1. Claim the item — pending -> rejected — and persist the decision in
    //    one transaction (no tool dispatch for rejections). A confirm that
    //    claimed the item after this method read it wins: the rejection
    //    must not overwrite a change that was applied.
    final claim = await _claimDecision(
      current,
      itemIndex,
      decided: ChangeItemStatus.rejected,
      verdict: ChangeDecisionVerdict.rejected,
      rejectionReason: reason,
    );
    final rejectedSet = claim?.changeSet;
    if (rejectedSet == null) {
      _domainLogger?.log(
        LogDomain.agentWorkflow,
        'Skipping reject for item $itemIndex (${item.toolName}) — no longer '
        'pending',
        subDomain: _sub,
      );
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
        final result = await _confirmItem(
          current,
          i,
          ChecklistApprovalMode.confirmAll,
        );
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
    'relation',
    'startTime',
    'status',
    'summary',
    'targetTaskId',
    'timerId',
    'title',
  };

  static String describeArgsForLog(Map<String, dynamic> args) {
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
