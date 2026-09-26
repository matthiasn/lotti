// ignore_for_file: comment_references

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/model/membership_list.dart';
import 'package:lotti/features/tasks/repository/checklist_membership_intents.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/logic/write_on_stored.dart';
import 'package:lotti/services/domain_logging.dart';

/// Keep-alive provider exposing the singleton [ChecklistRepository].
final checklistRepositoryProvider = Provider<ChecklistRepository>(
  checklistRepository,
  name: 'checklistRepositoryProvider',
);

ChecklistRepository checklistRepository(Ref _) {
  return ChecklistRepository();
}

/// Persistence boundary for checklists and checklist items.
///
/// Owns the DB writes that the checklist controllers delegate to: creating
/// checklists/items, updating their data, attaching, moving and deleting
/// items, and bulk-loading a task's items. All mutations go through
/// [PersistenceLogic] (which stamps metadata and fans out sync), and failures
/// are logged rather than thrown so the optimistic UI state in the
/// controllers is not torn down.
///
/// Membership — which checklists a task lists, which items a checklist
/// lists, which checklist an item names — is only ever changed on the stored
/// rows ([updateChecklist], [updateTaskChecklistIds], [updateChecklistItem]),
/// and an operation that writes more than one row records its intent first
/// ([ChecklistMembershipIntents]) so the next start finishes it if the app
/// dies half-way ([replayMembershipIntents]). ADR 0089 and
/// `specs/tla/ChecklistMembership.tla` say why.
class ChecklistRepository {
  ChecklistRepository({ChecklistMembershipIntents? intents})
    : _intents = intents ?? ChecklistMembershipIntents();

  final JournalDb _journalDb = getIt<JournalDb>();
  final DomainLogger _loggingService = getIt<DomainLogger>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final ChecklistMembershipIntents _intents;

  /// Creates a new checklist and optionally populates it with items.
  ///
  /// Parameters:
  /// - [taskId]: The task to attach this checklist to
  /// - [items]: Optional items to create with the checklist
  /// - [title]: Optional title for the checklist (defaults to 'Todos')
  /// - [uuidV5Input]: Optional input the checklist's id is derived from
  ///   (`MetadataService.generateId`), for a caller that must create the
  ///   same checklist on every device
  ///
  /// The checklist is listed on the task, and its items on the checklist,
  /// under recorded intents ([ListChecklistIntent], [ListItemsIntent]).
  ///
  /// Returns a record containing:
  /// - [checklist]: The created Checklist entity or null if creation failed
  /// - [createdItems]: List of created items with their generated IDs
  Future<
    ({
      JournalEntity? checklist,
      List<({String id, String title, bool isChecked})> createdItems,
    })
  >
  createChecklist({
    required String? taskId,
    List<ChecklistItemData>? items,
    String? title,
    String? uuidV5Input,
  }) async {
    try {
      if (taskId == null) {
        return (
          checklist: null,
          createdItems: <({String id, String title, bool isChecked})>[],
        );
      }

      final task = await getIt<JournalDb>().journalEntityById(taskId);

      if (task is! Task) {
        return (
          checklist: null,
          createdItems: <({String id, String title, bool isChecked})>[],
        );
      }

      final categoryId = task.meta.categoryId;
      final meta = await _persistenceLogic.createMetadata(
        uuidV5Input: uuidV5Input,
      );

      final newChecklist = Checklist(
        meta: meta.copyWith(categoryId: categoryId),
        data: ChecklistData(
          title: title ?? 'Todos',
          linkedChecklistItems: [],
          linkedTasks: [task.id],
        ),
      );

      // Every item is built before anything is written, so a failure here
      // leaves nothing half-created.
      final built = [
        for (final item in items ?? const <ChecklistItemData>[])
          await _newChecklistItem(
            checklistId: newChecklist.meta.id,
            title: item.title,
            isChecked: item.isChecked,
            categoryId: newChecklist.meta.categoryId,
            checkedBy: item.checkedBy,
            checkedAt: item.checkedAt,
            approvalHistory: item.approvalHistory,
          ),
      ];

      await _intents.run(
        ListChecklistIntent(checklistId: newChecklist.meta.id, taskId: task.id),
        () async {
          await _persistenceLogic.createDbEntity(newChecklist);
          return updateTaskChecklistIds(
            taskId: task.id,
            change: (ids) => withMember(ids, newChecklist.meta.id),
          );
        },
        done: (listed) => listed,
      );

      final createdItemsList = <({String id, String title, bool isChecked})>[];

      if (built.isNotEmpty) {
        await _intents.run(
          ListItemsIntent(
            checklistId: newChecklist.meta.id,
            itemIds: [for (final item in built) item.id],
          ),
          () async {
            final createdIds = <String>[];
            for (final item in built) {
              if (await _createItemRow(item)) {
                createdIds.add(item.id);
                createdItemsList.add((
                  id: item.id,
                  title: item.data.title,
                  isChecked: item.data.isChecked,
                ));
              }
            }
            return updateChecklist(
              checklistId: newChecklist.meta.id,
              change: (stored) => stored.copyWith(
                linkedChecklistItems: createdIds.fold(
                  stored.linkedChecklistItems,
                  withMember,
                ),
              ),
            );
          },
          done: (listed) => listed != null,
        );
      }

      return (checklist: newChecklist, createdItems: createdItemsList);
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createChecklistEntry',
      );
      return (
        checklist: null,
        createdItems: <({String id, String title, bool isChecked})>[],
      );
    }
  }

  /// How many deleted generations of a derived checklist
  /// [derivedChecklistFor] steps past before it gives up on a derived id.
  static const _derivedChecklistGenerations = 8;

  /// The checklist of the task [taskId] that every device derives from
  /// [uuidV5Input], for a caller that must end up with one checklist however
  /// many devices apply its change — a confirmed agent change applied on two
  /// devices before they sync (ADR 0075). Returns its id, or `null` when the
  /// task is gone or the checklist could not be created.
  ///
  /// The checklist and the task update that lists it sync apart, so another
  /// device's checklist can be here while the task does not list it yet. A
  /// live checklist under the derived id is therefore reused, and listed on
  /// the task if it is not. One the user deleted moves on to the next
  /// generation's id — `$uuidV5Input:1`, then `:2` — which every device that
  /// knows the same deletions derives alike. Otherwise it is created.
  Future<String?> derivedChecklistFor({
    required String taskId,
    required String uuidV5Input,
    String title = 'Todos',
  }) async {
    for (
      var generation = 0;
      generation < _derivedChecklistGenerations;
      generation++
    ) {
      final input = generation == 0 ? uuidV5Input : '$uuidV5Input:$generation';
      final id = MetadataService.deterministicId(input);
      final existing = (await _journalDb.journalEntityMapForIdsIncludingDeleted(
        [id],
      ))[id];
      if (existing == null) {
        final created = await createChecklist(
          taskId: taskId,
          title: title,
          uuidV5Input: input,
        );
        return created.checklist?.meta.id;
      }
      if (existing is Checklist && existing.meta.deletedAt == null) {
        final task = await _journalDb.journalEntityById(taskId);
        if (task is! Task) return null;
        await updateTaskChecklistIds(
          taskId: taskId,
          change: (ids) => withMember(ids, id),
        );
        return id;
      }
    }
    final created = await createChecklist(taskId: taskId, title: title);
    return created.checklist?.meta.id;
  }

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

  /// Stores the new [item]; `false` when the write failed.
  Future<bool> _createItemRow(ChecklistItem item) async {
    try {
      await _persistenceLogic.createDbEntity(item);
      return true;
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

  /// Applies [change] to the data of the stored checklist [checklistId] and
  /// writes the result on that row ([writeOnStored]).
  ///
  /// [change] is handed the data as stored, never a copy a screen read
  /// earlier: a version stored meanwhile — by sync, the agent, or another
  /// screen — is built on again rather than replaced, so no item it listed
  /// is dropped (`specs/tla/ChecklistMembership.tla`). Returns the checklist
  /// as stored afterwards (unchanged when [change] leaves the data as it
  /// is), or `null` when it does not exist, is not a checklist, or the write
  /// failed.
  Future<Checklist?> updateChecklist({
    required String checklistId,
    required ChecklistData Function(ChecklistData stored) change,
  }) async {
    try {
      Checklist? result;
      final stored = await writeOnStored(
        journalDb: _journalDb,
        persistenceLogic: _persistenceLogic,
        id: checklistId,
        build: (entity) async {
          result = null;
          if (entity is! Checklist) {
            _loggingService.error(
              LogDomain.persistence,
              'not a checklist',
              subDomain: 'updateChecklist',
            );
            return null;
          }
          final data = change(entity.data);
          if (data == entity.data) {
            result = entity;
            return null;
          }
          return result = entity.copyWith(
            meta: await _persistenceLogic.updateMetadata(entity.meta),
            data: data,
          );
        },
      );
      return stored ? result : null;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateChecklist',
      );
      return null;
    }
  }

  /// Applies [change] to the checklist ids of the stored task [taskId] and
  /// writes the result on that row ([writeOnStored]).
  ///
  /// The one writer of `TaskData.checklistIds`: every other task write keeps
  /// the list as stored (`PersistenceLogic.updateTask`), so a status or
  /// estimate saved from a screen's copy of the task cannot drop a checklist
  /// added since (`specs/tla/ChecklistMembership.tla`). Returns whether the
  /// list is stored — `true` when [change] leaves it as it is.
  Future<bool> updateTaskChecklistIds({
    required String taskId,
    required List<String> Function(List<String> stored) change,
  }) async {
    try {
      var isTask = true;
      final stored = await writeOnStored(
        journalDb: _journalDb,
        persistenceLogic: _persistenceLogic,
        id: taskId,
        build: (entity) async {
          if (entity is! Task) {
            isTask = false;
            return null;
          }
          final current = entity.data.checklistIds ?? const <String>[];
          final next = change(current);
          if (listEquals(next, current)) return null;
          return entity.copyWith(
            meta: await _persistenceLogic.updateMetadata(entity.meta),
            data: entity.data.copyWith(checklistIds: next),
          );
        },
      );
      return stored && isTask;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateTaskChecklistIds',
      );
      return false;
    }
  }

  /// Applies [change] to the data of the stored checklist item
  /// [checklistItemId] and writes the result on that row ([writeOnStored]).
  ///
  /// [change] is handed the item as stored, so a writer changes only the
  /// fields it means to — a check from a screen whose state predates a move
  /// or a rename never writes the old checklist or title back
  /// (`specs/tla/ChecklistMembership.tla`, `RebaseItems`). [taskId] is
  /// threaded through as the `linkedId` so the write notification reaches the
  /// task's listeners. Returns the item as stored afterwards (unchanged when
  /// [change] leaves it as it is), or `null` when it does not exist, is not a
  /// checklist item, or the write failed.
  Future<ChecklistItem?> updateChecklistItem({
    required String checklistItemId,
    required ChecklistItemData Function(ChecklistItemData stored) change,
    required String? taskId,
  }) async {
    try {
      ChecklistItem? result;
      final stored = await writeOnStored(
        journalDb: _journalDb,
        persistenceLogic: _persistenceLogic,
        id: checklistItemId,
        linkedId: taskId,
        build: (entity) async {
          result = null;
          if (entity is! ChecklistItem) {
            _loggingService.error(
              LogDomain.persistence,
              'not a checklist item',
              subDomain: 'updateChecklistItem',
            );
            return null;
          }
          final data = change(entity.data);
          if (data == entity.data) {
            result = entity;
            return null;
          }
          return result = entity.copyWith(
            meta: await _persistenceLogic.updateMetadata(entity.meta),
            data: data.stampedAfter(entity.data, clock.now()),
          );
        },
      );
      return stored ? result : null;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateChecklistItem',
      );
      return null;
    }
  }

  /// Creates an item and lists it on the checklist [checklistId], under a
  /// recorded [ListItemsIntent]: an item the app died before listing is
  /// listed at the next start. Returns the created item, or `null` on any
  /// failure. [uuidV5Input] derives the item's id
  /// (`MetadataService.generateId`); the checklist lists an id once however
  /// often it is added.
  Future<ChecklistItem?> addItemToChecklist({
    required String checklistId,
    required String title,
    required bool isChecked,
    required String? categoryId,
    ChangeSource? checkedBy,
    DateTime? checkedAt,
    List<ChecklistItemProvenance> approvalHistory = const [],
    String? uuidV5Input,
  }) async {
    try {
      final newItem = await _newChecklistItem(
        checklistId: checklistId,
        title: title,
        isChecked: isChecked,
        categoryId: categoryId,
        checkedBy: checkedBy,
        checkedAt: checkedAt,
        approvalHistory: approvalHistory,
        uuidV5Input: uuidV5Input,
      );
      return await _intents.run(
        ListItemsIntent(checklistId: checklistId, itemIds: [newItem.id]),
        () async {
          if (!await _createItemRow(newItem)) return null;
          // Listed on the checklist as stored, so an item that synced in or
          // was added by another writer meanwhile stays listed too.
          final checklist = await updateChecklist(
            checklistId: checklistId,
            change: (stored) => stored.copyWith(
              linkedChecklistItems: withMember(
                stored.linkedChecklistItems,
                newItem.id,
              ),
            ),
          );
          return checklist == null ? null : newItem;
        },
        done: (item) => item != null,
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'addItemToChecklist',
      );
      return null;
    }
  }

  /// Applies [change] to the stored checklist [checklistId]'s item list.
  /// `done` is whether nothing is left to do: the change is stored, or the
  /// checklist is gone and there is nothing to change.
  Future<({Checklist? written, bool done})> _changeItems(
    String checklistId,
    List<String> Function(List<String> stored) change,
  ) async {
    if (await _journalDb.journalEntityById(checklistId) is! Checklist) {
      return (written: null, done: true);
    }
    final written = await updateChecklist(
      checklistId: checklistId,
      change: (stored) => stored.copyWith(
        linkedChecklistItems: change(stored.linkedChecklistItems),
      ),
    );
    return (written: written, done: written != null);
  }

  /// Applies [change] to the stored task [taskId]'s checklist ids; `done` as
  /// in [_changeItems].
  Future<bool> _changeTaskChecklists(
    String taskId,
    List<String> Function(List<String> stored) change,
  ) async =>
      await _journalDb.journalEntityById(taskId) is! Task ||
      await updateTaskChecklistIds(taskId: taskId, change: change);

  /// Moves the item [itemId] from the checklist [fromId] to [toId], under a
  /// recorded [MoveItemIntent]: the item's back-link first, then the target's
  /// list — where [place] puts it, appended by default — then the source's.
  /// Returns the target checklist as stored afterwards, or `null` when it
  /// could not be written. A move whose writes did not all land stays
  /// recorded, and the next start finishes it.
  Future<Checklist?> moveItem({
    required String itemId,
    required String fromId,
    required String toId,
    required String? taskId,
    List<String> Function(List<String> stored)? place,
  }) async {
    try {
      final moved = await _intents.run(
        MoveItemIntent(itemId: itemId, fromId: fromId, toId: toId),
        () => _applyMove(
          itemId: itemId,
          fromId: fromId,
          toId: toId,
          taskId: taskId,
          place: place,
        ),
        done: (moved) => moved.done,
      );
      return moved.target;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'moveItem',
      );
      return null;
    }
  }

  Future<({Checklist? target, bool done})> _applyMove({
    required String itemId,
    required String fromId,
    required String toId,
    required String? taskId,
    List<String> Function(List<String> stored)? place,
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
    final backLinked =
        await updateChecklistItem(
          checklistItemId: itemId,
          taskId: taskId,
          change: (stored) => stored.copyWith(
            linkedChecklists: withMember(
              withoutMember(stored.linkedChecklists, fromId),
              toId,
            ),
          ),
        ) !=
        null;
    final target = await _changeItems(
      toId,
      place ?? (ids) => withMember(ids, itemId),
    );
    final source = await _changeItems(
      fromId,
      (ids) => withoutMember(ids, itemId),
    );
    return (
      target: target.written,
      done: backLinked && target.done && source.done,
    );
  }

  /// Deletions waiting out their undo window, by key.
  final Map<String, Timer> _pendingDeletions = {};

  /// Starts deleting the item [itemId] the user removed from the checklist
  /// [checklistId]: records a [DeleteItemIntent], unlists the item at once,
  /// and deletes it when [undoWindow] has passed — unless the user undoes
  /// first ([undoItemDeletion]). The window is timed here, not by the row
  /// the user swiped, which leaves the screen with the item. Should the app
  /// die in between, the next start deletes the item, as the user last saw
  /// it. Returns the deletion's key, or `null` when it could not be
  /// recorded.
  Future<String?> beginItemDeletion({
    required String itemId,
    required String checklistId,
    required Duration undoWindow,
  }) async {
    try {
      final key = await _intents.record(
        DeleteItemIntent(itemId: itemId, checklistId: checklistId),
      );
      await _changeItems(checklistId, (ids) => withoutMember(ids, itemId));
      _pendingDeletions[key] = Timer(
        undoWindow,
        () => unawaited(completeItemDeletion(key: key, itemId: itemId)),
      );
      return key;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'beginItemDeletion',
      );
      return null;
    }
  }

  /// Deletes the item [itemId] once its undo window has closed, and drops
  /// the deletion recorded under [key] — kept for the next start if the
  /// delete did not land.
  Future<bool> completeItemDeletion({
    required String key,
    required String itemId,
  }) async {
    _pendingDeletions.remove(key)?.cancel();
    final deleted =
        await _journalDb.journalEntityById(itemId) == null ||
        await _deleteEntity(itemId);
    if (deleted) await _intents.clear(key);
    return deleted;
  }

  /// Lists the item [itemId] on the checklist [checklistId] again — the user
  /// undid its deletion — cancels the pending delete and drops the deletion
  /// recorded under [key].
  Future<Checklist?> undoItemDeletion({
    required String key,
    required String itemId,
    required String checklistId,
  }) async {
    _pendingDeletions.remove(key)?.cancel();
    final relisted = await _changeItems(
      checklistId,
      (ids) => withMember(ids, itemId),
    );
    // Listed again, or its checklist is gone: either way the deletion is
    // off, and a replay must not complete it.
    await _intents.clear(key);
    return relisted.written;
  }

  /// Deletes the checklist [checklistId] and removes it from the task
  /// [taskId]'s list, under a recorded [DeleteChecklistIntent]. Returns
  /// `false` only when the checklist itself could not be deleted.
  Future<bool> deleteChecklist({
    required String checklistId,
    required String taskId,
  }) async {
    final result = await _intents.run(
      DeleteChecklistIntent(checklistId: checklistId, taskId: taskId),
      () => _applyDeleteChecklist(checklistId: checklistId, taskId: taskId),
      done: (result) => result.deleted && result.detached,
    );
    return result.deleted;
  }

  Future<({bool deleted, bool detached})> _applyDeleteChecklist({
    required String checklistId,
    required String taskId,
  }) async {
    final deleted =
        await _journalDb.journalEntityById(checklistId) == null ||
        await _deleteEntity(checklistId);
    if (!deleted) return (deleted: false, detached: false);
    final detached = await _changeTaskChecklists(
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
    return (deleted: true, detached: detached);
  }

  Future<bool> _deleteEntity(String id) =>
      JournalRepository().deleteJournalEntity(id);

  /// Finishes every membership operation the app died in the middle of, from
  /// the intents it recorded ([ChecklistMembershipIntents]). Each is applied
  /// again on the stored rows — idempotently, so an operation that did
  /// finish, or a replay that dies too, is harmless — and dropped once every
  /// write of it has landed; one that did not stays for the next start. Runs
  /// once at startup.
  Future<void> replayMembershipIntents() async {
    final pending = await _intents.pending();
    for (final MapEntry(:key, value: intent) in pending.entries) {
      try {
        final done = switch (intent) {
          ListItemsIntent(:final checklistId, :final itemIds) =>
            await _replayListItems(checklistId, itemIds),
          MoveItemIntent(:final itemId, :final fromId, :final toId) =>
            (await _applyMove(
              itemId: itemId,
              fromId: fromId,
              toId: toId,
              taskId: null,
            )).done,
          DeleteItemIntent(:final itemId, :final checklistId) =>
            (await _changeItems(
                  checklistId,
                  (ids) => withoutMember(ids, itemId),
                )).done &&
                (await _journalDb.journalEntityById(itemId) == null ||
                    await _deleteEntity(itemId)),
          ListChecklistIntent(:final checklistId, :final taskId) =>
            await _journalDb.journalEntityById(checklistId) is! Checklist ||
                await _changeTaskChecklists(
                  taskId,
                  (ids) => withMember(ids, checklistId),
                ),
          DeleteChecklistIntent(:final checklistId, :final taskId) =>
            await _applyDeleteChecklist(
              checklistId: checklistId,
              taskId: taskId,
            ).then((result) => result.deleted && result.detached),
          // Written by a build that knew an operation this one does not.
          null => true,
        };
        if (done) await _intents.clear(key);
      } catch (exception, stackTrace) {
        // Kept for the next start.
        _loggingService.error(
          LogDomain.persistence,
          exception,
          stackTrace: stackTrace,
          subDomain: 'replayMembershipIntents',
        );
      }
    }
  }

  /// Lists the items of [itemIds] that exist on the checklist [checklistId].
  Future<bool> _replayListItems(
    String checklistId,
    List<String> itemIds,
  ) async {
    final live = [
      for (final id in itemIds)
        if (await _journalDb.journalEntityById(id) is ChecklistItem) id,
    ];
    if (live.isEmpty) return true;
    return (await _changeItems(
      checklistId,
      (ids) => live.fold(ids, withMember),
    )).done;
  }

  /// Loads every non-deleted [ChecklistItem] belonging to [task], newest
  /// first.
  ///
  /// Resolves the task's checklists, then their `linkedChecklistItems`, via two
  /// indexed bulk-by-id lookups (see the inline note for the slow full-scan
  /// shape this replaced). Returns `const []` when the task has no checklists.
  Future<List<ChecklistItem>> getChecklistItemsForTask({
    required Task task,
  }) async {
    final checklistIds = task.data.checklistIds ?? const <String>[];
    if (checklistIds.isEmpty) {
      return const [];
    }

    // The previous shape filtered only on `type='ChecklistItem'` and
    // `deleted=false`, materialised every ChecklistItem the device
    // had ever seen, JSON-decoded each one, and matched by
    // `linkedChecklists` in Dart — 558 ms in the 2026-05-10
    // super-slow log on the agent hot path. The Checklist entity
    // already lists its child ChecklistItem ids in
    // `data.linkedChecklistItems`, so two indexed bulk-by-id lookups
    // give us exactly the items we need.
    final checklistDbRows = await _journalDb
        .journalEntitiesByIdsUnorderedAllPrivate(checklistIds)
        .get();

    final itemIds = <String>{};
    for (final dbEntity in checklistDbRows) {
      try {
        final entity = fromDbEntity(dbEntity);
        if (entity is Checklist) {
          itemIds.addAll(entity.data.linkedChecklistItems);
        }
      } catch (error, stackTrace) {
        _loggingService.error(
          LogDomain.tasks,
          error,
          stackTrace: stackTrace,
          subDomain: 'getChecklistItemsForTask',
        );
      }
    }
    if (itemIds.isEmpty) return const [];

    final itemDbRows = await _journalDb
        .journalEntitiesByIdsUnorderedAllPrivate(
          itemIds.toList(growable: false),
        )
        .get();

    final items = <ChecklistItem>[];
    for (final dbEntity in itemDbRows) {
      try {
        final entity = fromDbEntity(dbEntity);
        if (entity is ChecklistItem && entity.meta.deletedAt == null) {
          items.add(entity);
        }
      } catch (error, stackTrace) {
        _loggingService.error(
          LogDomain.tasks,
          error,
          stackTrace: stackTrace,
          subDomain: 'getChecklistItemsForTask',
        );
      }
    }

    items.sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));
    return items;
  }
}
