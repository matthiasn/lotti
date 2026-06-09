part of 'change_set_confirmation_service.dart';

/// Resolution side-effects for [ChangeSetConfirmationService]: sibling-id
/// propagation, migration cascade-reject, decision persistence and the
/// change-set-resolved notification. Split from the main file for size.
extension ChangeSetConfirmationResolution on ChangeSetConfirmationService {
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
        LogDomain.agentWorkflow,
        'Persisted resolved targetTaskId '
        '(${DomainLogger.sanitizeId(actualId)}) to sibling migration items '
        'in change set ${DomainLogger.sanitizeId(fresh.id)}',
        subDomain: ChangeSetConfirmationService._sub,
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
          LogDomain.agentWorkflow,
          'Cascade-rejecting migration item $i — target task rejected',
          subDomain: ChangeSetConfirmationService._sub,
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
        LogDomain.agentWorkflow,
        'Captured placeholder resolution: '
        '${DomainLogger.sanitizeId(placeholderId)} → '
        '${DomainLogger.sanitizeId(actualId)}',
        subDomain: ChangeSetConfirmationService._sub,
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
    String? retractionReason,
    String? humanSummary,
    Map<String, dynamic>? args,
  }) async {
    final decision =
        AgentDomainEntity.changeDecision(
              id: ChangeSetConfirmationService._uuid.v4(),
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

  Future<ChangeSetEntity?> _updateChangeSetItemStatus(
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

  Future<void> _notifyChangeSetResolved(ChangeSetEntity fallback) async {
    final callback = _onChangeSetResolved;
    if (callback == null) return;

    try {
      await callback(await _freshChangeSet(fallback));
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        message:
            'Post-resolution notification sync failed for change set '
            '${DomainLogger.sanitizeId(fallback.id)}',
        subDomain: ChangeSetConfirmationService._sub,
        stackTrace: stackTrace,
      );
    }
  }
}
