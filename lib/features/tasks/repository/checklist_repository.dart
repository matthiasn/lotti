// ignore_for_file: comment_references

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';
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
/// checklists/items, updating their data, attaching items, and bulk-loading a
/// task's items. All mutations go through [PersistenceLogic] (which stamps
/// metadata and fans out sync), and failures are logged rather than thrown so
/// the optimistic UI state in the controllers is not torn down.
class ChecklistRepository {
  ChecklistRepository();

  final JournalDb _journalDb = getIt<JournalDb>();
  final DomainLogger _loggingService = getIt<DomainLogger>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

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

      await _persistenceLogic.createDbEntity(newChecklist);

      await _persistenceLogic.updateTask(
        journalEntityId: task.id,
        entryText: task.entryText,
        taskData: task.data.copyWith(
          checklistIds: [
            ...?task.data.checklistIds,
            newChecklist.meta.id,
          ],
        ),
      );

      final createdItemsList = <({String id, String title, bool isChecked})>[];

      if (items != null) {
        final createdIds = <String>[];

        for (final item in items) {
          final checklistItem = await createChecklistItem(
            checklistId: newChecklist.meta.id,
            title: item.title,
            isChecked: item.isChecked,
            categoryId: newChecklist.meta.categoryId,
            checkedBy: item.checkedBy,
            checkedAt: item.checkedAt,
            approvalHistory: item.approvalHistory,
          );
          if (checklistItem != null) {
            createdIds.add(checklistItem.id);
            createdItemsList.add((
              id: checklistItem.id,
              title: item.title,
              isChecked: item.isChecked,
            ));
          }
        }

        await updateChecklist(
          checklistId: newChecklist.meta.id,
          data: newChecklist.data.copyWith(
            linkedChecklistItems: createdIds,
          ),
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
  /// With [createIfMissing] false, only reuse/list an existing live checklist:
  /// inspect the bounded generations even across missing rows (partial sync),
  /// then return null without creating a container. A replay whose items were
  /// all deleted uses this to preserve unrelated items in a live checklist.
  Future<String?> derivedChecklistFor({
    required String taskId,
    required String uuidV5Input,
    String title = 'Todos',
    bool createIfMissing = true,
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
        if (!createIfMissing) continue;
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
        final listed = task.data.checklistIds ?? const <String>[];
        if (!listed.contains(id)) {
          await _persistenceLogic.updateTask(
            journalEntityId: task.id,
            entryText: task.entryText,
            taskData: task.data.copyWith(checklistIds: [...listed, id]),
          );
        }
        return id;
      }
    }
    if (!createIfMissing) return null;
    final created = await createChecklist(taskId: taskId, title: title);
    return created.checklist?.meta.id;
  }

  /// Creates a standalone [ChecklistItem] linked back to [checklistId].
  ///
  /// Does *not* add the item to the parent checklist's `linkedChecklistItems`;
  /// callers that need the bidirectional link should use [addItemToChecklist]
  /// (or update the checklist themselves). [checkedBy] defaults to
  /// [ChangeSource.user]. Approval history is persisted in the same write.
  /// The item's id is derived from [uuidV5Input] when given
  /// (`MetadataService.generateId`), and random otherwise.
  /// Returns the created item, or `null` on failure.
  Future<ChecklistItem?> createChecklistItem({
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
      final meta = await _persistenceLogic.createMetadata(
        uuidV5Input: uuidV5Input,
      );
      final newChecklistItem = ChecklistItem(
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

      await _persistenceLogic.createDbEntity(newChecklistItem);

      return newChecklistItem;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createChecklistEntry',
      );
      return null;
    }
  }

  /// Replaces the [data] of the checklist [checklistId] and refreshes its
  /// metadata. Returns `false` only when the entity does not exist; a
  /// type-mismatch or write error is logged and still returns `true`.
  Future<bool> updateChecklist({
    required String checklistId,
    required ChecklistData data,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(checklistId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        checklist: (Checklist checklist) async {
          final updatedChecklist = checklist.copyWith(
            meta: await _persistenceLogic.updateMetadata(
              journalEntity.meta,
            ),
            data: data,
          );

          await _persistenceLogic.updateDbEntity(updatedChecklist);
        },
        orElse: () async => _loggingService.error(
          LogDomain.persistence,
          'not a checklist',
          subDomain: 'updateChecklist',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateChecklist',
      );
    }
    return true;
  }

  /// Replaces the [data] of the checklist item [checklistItemId] and refreshes
  /// its metadata. [taskId] is threaded through as the `linkedId` so the write
  /// notification reaches the task's listeners. Same return semantics as
  /// [updateChecklist].
  Future<bool> updateChecklistItem({
    required String checklistItemId,
    required ChecklistItemData data,
    required String? taskId,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(checklistItemId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        checklistItem: (ChecklistItem checklistItem) async {
          final updatedChecklist = checklistItem.copyWith(
            meta: await _persistenceLogic.updateMetadata(journalEntity.meta),
            data: data.stampedAfter(checklistItem.data, clock.now()),
          );

          await _persistenceLogic.updateDbEntity(
            updatedChecklist,
            linkedId: taskId,
          );
        },
        orElse: () async => _loggingService.error(
          LogDomain.persistence,
          'not a checklist item',
          subDomain: 'updateChecklistItem',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateChecklistItem',
      );
    }
    return true;
  }

  /// Creates an item and links it into the checklist in one call.
  ///
  /// Unlike [createChecklistItem], this re-reads the checklist after creating
  /// the item and appends the new id to `linkedChecklistItems`, keeping the
  /// link bidirectional. Returns the created item, or `null` on any failure.
  /// [uuidV5Input] derives the item's id, as in [createChecklistItem]; the
  /// checklist lists an id once however often it is added.
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
      // Create the new checklist item first
      final newItem = await createChecklistItem(
        checklistId: checklistId,
        title: title,
        isChecked: isChecked,
        categoryId: categoryId,
        checkedBy: checkedBy,
        checkedAt: checkedAt,
        approvalHistory: approvalHistory,
        uuidV5Input: uuidV5Input,
      );

      if (newItem == null) {
        return null;
      }

      // Atomically update the checklist to include the new item
      // This fetches and updates in a single operation to avoid race conditions
      final checklist = await _journalDb.journalEntityById(checklistId);

      if (checklist is! Checklist) {
        _loggingService.error(
          LogDomain.persistence,
          'Entity is not a checklist',
          subDomain: 'addItemToChecklist',
        );
        return null;
      }

      if (!checklist.data.linkedChecklistItems.contains(newItem.id)) {
        await updateChecklist(
          checklistId: checklistId,
          data: checklist.data.copyWith(
            linkedChecklistItems: [
              ...checklist.data.linkedChecklistItems,
              newItem.id,
            ],
          ),
        );
      }

      return newItem;
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
