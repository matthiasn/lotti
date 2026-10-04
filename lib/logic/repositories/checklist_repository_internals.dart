part of 'checklist_repository.dart';

/// The single-row steps behind ChecklistRepository's operations: creating an item or row, applying a move or a checklist delete, and replaying one membership intent.
extension _ChecklistRepositoryInternals on ChecklistRepository {
  /// A new [ChecklistItem] naming [checklistId], not yet stored. The item's
  /// id is derived from [uuidV5Input] when given
  /// (`MetadataService.generateId`), and random otherwise; [checkedBy]
  /// defaults to [ChangeSource.user].
  Future<ChecklistItem> _newChecklistItem({
    required String checklistId,
    required String title,
    required bool isChecked,
    required String? categoryId,
    ChangeSource? checkedBy,
    DateTime? checkedAt,
    List<ChecklistItemProvenance> approvalHistory = const [],
    String? uuidV5Input,
  }) async {
    final meta = await _persistenceLogic.createMetadata(
      uuidV5Input: uuidV5Input,
    );
    return ChecklistItem(
      meta: meta.copyWith(categoryId: categoryId),
      data: ChecklistItemData(
        title: title,
        isChecked: isChecked,
        linkedChecklists: [checklistId],
        checkedBy: checkedBy ?? ChangeSource.user,
        checkedAt: checkedAt,
        approvalHistory: approvalHistory,
      ).stampedAfter(null, clock.now()),
    );
  }

  /// Stores the new [entity]; `false` when it is not stored.
  ///
  /// A refused creation (`false`) counts when a row exists under the id —
  /// a derived id (ADR 0075) another device already created, which is then
  /// listed like this one. A write that reported no result (`null`) or
  /// threw does not: listing an id with no stored row would clear the
  /// operation's intent over nothing.
  Future<bool> _createRow(JournalEntity entity) async {
    try {
      return switch (await _persistenceLogic.createDbEntity(entity)) {
        true => true,
        false => await _journalDb.journalEntityById(entity.id) != null,
        null => false,
      };
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createChecklistEntry',
      );
      return false;
    }
  }

  /// Deletes the live items naming the checklist [checklistId] — all of
  /// them, or those of [only] — found by their back-link, not by its list:
  /// a list can lack an item whose listing has not arrived, and two
  /// concurrent deletions of a checklist merge into one side's row, whose
  /// list can lack the other side's items. Returns whether all are deleted.
  Future<bool> _deleteItemsNaming(
    String checklistId, {
    Set<String>? only,
  }) async {
    var deleted = true;
    for (final item in await _journalDb.checklistItemsNaming([checklistId])) {
      if (only != null && !only.contains(item.meta.id)) continue;
      if (!await _deleteEntity(item.meta.id)) deleted = false;
    }
    return deleted;
  }

  /// [backLinked]: a replay found the move's back-link write landed, so the
  /// item's back-link is not written again ([MembershipIntent]'s `mark`).
  Future<({Checklist? target, bool done})> _applyMove({
    required String itemId,
    required String fromId,
    required String toId,
    required String? taskId,
    List<String> Function(List<String> stored)? place,
    bool backLinked = false,
  }) async {
    if (await _journalDb.journalEntityById(itemId) is! ChecklistItem) {
      // A deleted item is not moved; unlisting it from the source is all
      // that is left.
      final source = await _changeItems(
        fromId,
        (ids) => withoutMember(ids, itemId),
      );
      return (target: null, done: source.done);
    }
    // The back-link decides where the item is shown (ADR 0105): it names the
    // target alone.
    final linked =
        backLinked ||
        await updateChecklistItem(
              checklistItemId: itemId,
              taskId: taskId,
              change: (stored) => stored.copyWith(linkedChecklists: [toId]),
            ) !=
            null;
    // A target deleted meanwhile takes the item with it.
    final targetGone = await _journalDb.journalEntityByIdIncludingDeleted(toId);
    final target = targetGone is Checklist && targetGone.isDeleted
        ? (
            written: null,
            done: await _deleteItemsNaming(toId, only: {itemId}),
          )
        : await _changeItems(toId, place ?? (ids) => withMember(ids, itemId));
    final source = await _changeItems(
      fromId,
      (ids) => withoutMember(ids, itemId),
    );
    return (
      target: target.written,
      done: linked && target.done && source.done,
    );
  }

  Future<({bool deleted, bool detached, bool swept})> _applyDeleteChecklist({
    required String checklistId,
    required String? taskId,
  }) async {
    final detached =
        taskId == null ||
        await _changeTaskChecklists(
          taskId,
          (ids) => withoutMember(ids, checklistId),
        );
    if (!detached) {
      _loggingService.error(
        LogDomain.tasks,
        'Failed to remove checklist ID ($checklistId) from task ($taskId)',
        subDomain: 'deleteChecklist',
      );
    }
    final deleted =
        await _journalDb.journalEntityById(checklistId) == null ||
        await _deleteEntity(checklistId);
    if (!deleted) return (deleted: false, detached: detached, swept: false);
    return (
      deleted: true,
      detached: detached,
      swept: await _sweep(checklistId),
    );
  }

  /// Applies [intent] again on the stored rows; whether nothing of it is
  /// left to do. A write of the operation's own that already landed is not
  /// repeated ([MembershipIntent]'s `mark`): a later version of that row
  /// is another device's choice.
  Future<bool> _replayIntent(MembershipIntent intent) async => switch (intent) {
    ListItemsIntent(:final checklistId, :final itemIds) =>
      await _replayListItems(checklistId, itemIds),
    MoveItemIntent(:final itemId, :final fromId, :final toId, :final mark) =>
      (await _applyMove(
        itemId: itemId,
        fromId: fromId,
        toId: toId,
        taskId: null,
        backLinked: await _landed(itemId, mark),
      )).done,
    DeleteItemIntent(:final itemId, :final checklistId, :final mark) =>
      (await _changeItems(
            checklistId,
            (ids) => withoutMember(ids, itemId),
          )).done &&
          // A null mark: still in its undo window when the app died, so the
          // delete never started and is completed now.
          ((mark != null && await _landed(itemId, mark)) ||
              await _journalDb.journalEntityById(itemId) == null ||
              await _deleteEntity(itemId)),
    ListChecklistIntent(
      :final checklistId,
      :final taskId,
      :final restate,
    ) =>
      await _journalDb.journalEntityById(checklistId) is! Checklist ||
          await _journalDb.journalEntityById(taskId) is! Task ||
          await updateTaskChecklistIds(
            taskId: taskId,
            change: (ids) => withMember(ids, checklistId),
            restate: restate,
          ),
    DeleteChecklistIntent(
      :final checklistId,
      :final taskId,
      :final mark,
    ) =>
      // Deleted already: kept alive since by a conflict's resolution, it is
      // neither unlisted nor deleted again — only swept, while deleted.
      await _landed(checklistId, mark)
          ? await _sweep(checklistId)
          : await _applyDeleteChecklist(
              checklistId: checklistId,
              taskId: taskId,
            ).then(
              (result) => result.deleted && result.detached && result.swept,
            ),
    SweepChecklistIntent(:final checklistId) => await _sweep(checklistId),
  };
}
