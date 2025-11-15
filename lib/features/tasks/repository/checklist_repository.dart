// ignore_for_file: comment_references

import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/services/task_summary_refresh_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_repository.g.dart';

@Riverpod(keepAlive: true)
ChecklistRepository checklistRepository(Ref ref) {
  return ChecklistRepository(ref);
}

class ChecklistRepository {
  ChecklistRepository(this._ref);

  final Ref _ref;
  final JournalDb _journalDb = getIt<JournalDb>();
  final LoggingService _loggingService = getIt<LoggingService>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  static const String _callingDomain = 'ChecklistRepository';

  /// Triggers a task summary refresh for all tasks linked to the given checklist
  Future<void> _triggerTaskSummaryRefresh(String checklistId) async {
    try {
      await _ref
          .read(taskSummaryRefreshServiceProvider)
          .triggerTaskSummaryRefreshForChecklist(
            checklistId: checklistId,
            callingDomain: _callingDomain,
          );
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: _callingDomain,
        subDomain: '_triggerTaskSummaryRefresh',
        stackTrace: stackTrace,
      );
      // Swallow the error to prevent persistence flow failures
    }
  }

  /// Creates a new checklist and optionally populates it with items.
  ///
  /// Parameters:
  /// - [taskId]: The task to attach this checklist to
  /// - [items]: Optional items to create with the checklist
  /// - [title]: Optional title for the checklist (defaults to 'TODOs')
  ///
  /// Returns a record containing:
  /// - [checklist]: The created Checklist entity or null if creation failed
  /// - [createdItems]: List of created items with their generated IDs
  Future<
      ({
        JournalEntity? checklist,
        List<({String id, String title, bool isChecked})> createdItems,
      })> createChecklist({
    required String? taskId,
    List<ChecklistItemData>? items,
    String? title,
  }) async {
    try {
      if (taskId == null) {
        return (
          checklist: null,
          createdItems: <({String id, String title, bool isChecked})>[]
        );
      }

      final task = await getIt<JournalDb>().journalEntityById(taskId);

      if (task is! Task) {
        return (
          checklist: null,
          createdItems: <({String id, String title, bool isChecked})>[]
        );
      }

      final categoryId = task.meta.categoryId;
      final meta = await _persistenceLogic.createMetadata();

      final newChecklist = Checklist(
        meta: meta.copyWith(categoryId: categoryId),
        data: ChecklistData(
          title: title ?? 'TODOs',
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
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createChecklistEntry',
        stackTrace: stackTrace,
      );
      return (
        checklist: null,
        createdItems: <({String id, String title, bool isChecked})>[]
      );
    }
  }

  Future<ChecklistItem?> createChecklistItem({
    required String checklistId,
    required String title,
    required bool isChecked,
    required String? categoryId,
  }) async {
    try {
      final meta = await _persistenceLogic.createMetadata();
      final newChecklistItem = ChecklistItem(
        meta: meta.copyWith(categoryId: categoryId),
        data: ChecklistItemData(
          title: title,
          isChecked: isChecked,
          linkedChecklists: [checklistId],
        ),
      );

      await _persistenceLogic.createDbEntity(newChecklistItem);

      // Trigger task summary refresh for linked tasks
      await _triggerTaskSummaryRefresh(checklistId);

      return newChecklistItem;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createChecklistEntry',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

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
        orElse: () async => _loggingService.captureException(
          'not a checklist',
          domain: 'persistence_logic',
          subDomain: 'updateChecklist',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateChecklist',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

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
            data: data,
          );

          await _persistenceLogic.updateDbEntity(
            updatedChecklist,
            linkedId: taskId,
          );

          // Trigger task summary refresh for linked tasks
          // Compute union of old and new linkedChecklists to handle both removals and additions
          final allChecklistIds = {
            ...checklistItem.data.linkedChecklists, // old linked checklists
            ...data.linkedChecklists, // new linked checklists
          };

          // Trigger refreshes concurrently for all affected checklists
          await Future.wait(
            allChecklistIds.map(_triggerTaskSummaryRefresh),
          );
        },
        orElse: () async => _loggingService.captureException(
          'not a checklist item',
          domain: 'persistence_logic',
          subDomain: 'updateChecklistItem',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateChecklistItem',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<ChecklistItem?> addItemToChecklist({
    required String checklistId,
    required String title,
    required bool isChecked,
    required String? categoryId,
  }) async {
    try {
      // Create the new checklist item first
      final newItem = await createChecklistItem(
        checklistId: checklistId,
        title: title,
        isChecked: isChecked,
        categoryId: categoryId,
      );

      if (newItem == null) {
        return null;
      }

      // Atomically update the checklist to include the new item
      // This fetches and updates in a single operation to avoid race conditions
      final checklist = await _journalDb.journalEntityById(checklistId);

      if (checklist is! Checklist) {
        _loggingService.captureException(
          'Entity is not a checklist',
          domain: 'persistence_logic',
          subDomain: 'addItemToChecklist',
        );
        return null;
      }

      await updateChecklist(
        checklistId: checklistId,
        data: checklist.data.copyWith(
          linkedChecklistItems: [
            ...checklist.data.linkedChecklistItems,
            newItem.id,
          ],
        ),
      );

      // Trigger task summary refresh for linked tasks
      await _triggerTaskSummaryRefresh(checklistId);

      return newItem;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addItemToChecklist',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Mark existing checklist items as completed for the given task.
  Future<({List<String> updated, List<String> skipped})>
      completeChecklistItemsForTask({
    required Task task,
    required List<String> itemIds,
  }) async {
    try {
      final allowedChecklistIds = task.data.checklistIds ?? const <String>[];
      if (allowedChecklistIds.isEmpty || itemIds.isEmpty) {
        return (updated: const <String>[], skipped: itemIds);
      }

      const maxBatchSize = 20;
      final normalizedIds =
          LinkedHashSet<String>.from(itemIds).take(maxBatchSize).toList();

      final updated = <String>[];
      final skipped = <String>[];

      final entityMap = <String, JournalEntity>{};
      for (final dbEntity
          in await _journalDb.entriesForIds(normalizedIds.toList()).get()) {
        entityMap[dbEntity.id] = fromDbEntity(dbEntity);
      }

      for (final id in normalizedIds) {
        final entity = entityMap[id];
        if (entity is! ChecklistItem) {
          skipped.add(id);
          continue;
        }

        final linkedChecklistIds = entity.data.linkedChecklists;
        final belongsToTask =
            linkedChecklistIds.any(allowedChecklistIds.contains);

        if (!belongsToTask || entity.data.isChecked) {
          skipped.add(id);
          continue;
        }

        final success = await updateChecklistItem(
          checklistItemId: entity.id,
          data: entity.data.copyWith(isChecked: true),
          taskId: task.id,
        );

        if (success) {
          updated.add(id);
        } else {
          skipped.add(id);
        }
      }

      // Any IDs beyond the batch limit are treated as skipped
      if (itemIds.length > maxBatchSize) {
        skipped.addAll(itemIds.skip(maxBatchSize));
      }

      return (updated: updated, skipped: skipped);
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: _callingDomain,
        subDomain: 'completeChecklistItemsForTask',
        stackTrace: stackTrace,
      );
      return (updated: const <String>[], skipped: itemIds);
    }
  }

  Future<List<ChecklistItem>> getChecklistItemsForTask({
    required Task task,
    required bool deletedOnly,
  }) async {
    final checklistIds = task.data.checklistIds ?? const <String>[];
    if (checklistIds.isEmpty) {
      return const [];
    }

    final query = _journalDb.select(_journalDb.journal)
      ..where((tbl) => tbl.type.equals('ChecklistItem'))
      ..where((tbl) => tbl.deleted.equals(deletedOnly));
    final dbEntities = await query.get();

    final items = <ChecklistItem>[];
    for (final dbEntity in dbEntities) {
      try {
        final entity = fromDbEntity(dbEntity);
        if (entity is! ChecklistItem) continue;
        final matches = entity.data.linkedChecklists.any(checklistIds.contains);
        final isDeleted = entity.meta.deletedAt != null;
        if (matches && deletedOnly == isDeleted) {
          items.add(entity);
        }
      } catch (error, stackTrace) {
        _loggingService.captureException(
          error,
          domain: _callingDomain,
          subDomain: 'getChecklistItemsForTask',
          stackTrace: stackTrace,
        );
      }
    }

    items.sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));
    return items;
  }
}
