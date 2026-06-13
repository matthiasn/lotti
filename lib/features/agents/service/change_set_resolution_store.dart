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

    // Re-read the change set to get the latest item statuses.
    final fresh = await freshChangeSet(changeSet);
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
        LogDomain.agentWorkflow,
        'Persisted resolved targetTaskId '
        '(${DomainLogger.sanitizeId(actualId)}) to sibling migration items '
        'in change set ${DomainLogger.sanitizeId(fresh.id)}',
        subDomain: _subDomain,
      );
    }
  }

  /// When a `create_follow_up_task` item is rejected, cascade-rejects all
  /// pending `migrate_checklist_item` siblings whose `targetTaskId` matches
  /// the placeholder. Without the target task, those migrations can never
  /// succeed.
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
        _domainLogger?.log(
          LogDomain.agentWorkflow,
          'Cascade-rejecting migration item $i — target task rejected',
          subDomain: _subDomain,
        );

        await persistDecision(
          changeSet: fresh,
          itemIndex: i,
          toolName: sibling.toolName,
          verdict: ChangeDecisionVerdict.rejected,
          rejectionReason: reason ?? 'Target follow-up task was rejected',
          humanSummary: sibling.humanSummary,
          args: sibling.args,
        );

        await updateChangeSetItemStatus(
          fresh,
          i,
          ChangeItemStatus.rejected,
        );
      }
    }
  }

  /// Re-reads the change set from the repository to get the latest persisted
  /// state. Falls back to [fallback] if the entity is not found or has an
  /// unexpected type.
  Future<ChangeSetEntity> freshChangeSet(ChangeSetEntity fallback) async {
    final latest = await _syncService.repository.getEntity(fallback.id);
    return latest is ChangeSetEntity ? latest : fallback;
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

  /// Sets the status of the item at [itemIndex] to [newStatus] on the latest
  /// persisted state of [changeSet], derives the new set status and
  /// `resolvedAt`, and upserts the result.
  ///
  /// Returns the updated entity, or `null` when [itemIndex] is out of range
  /// for the latest persisted state.
  Future<ChangeSetEntity?> updateChangeSetItemStatus(
    ChangeSetEntity changeSet,
    int itemIndex,
    ChangeItemStatus newStatus,
  ) async {
    // Re-read the latest entity to avoid overwriting concurrent updates.
    final latest = await _syncService.repository.getEntity(changeSet.id);
    final current = latest is ChangeSetEntity ? latest : changeSet;

    if (itemIndex < 0 || itemIndex >= current.items.length) {
      return null;
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

    final updated = current.copyWith(
      items: updatedItems,
      status: newSetStatus,
      resolvedAt: resolvedAt,
    );
    await _syncService.upsertEntity(updated);
    return updated;
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
