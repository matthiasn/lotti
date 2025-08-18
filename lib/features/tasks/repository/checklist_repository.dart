import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
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

  Future<JournalEntity?> createChecklist({
    required String? taskId,
    List<ChecklistItemData>? items,
    String? title,
  }) async {
    try {
      if (taskId == null) {
        return null;
      }

      final task = await getIt<JournalDb>().journalEntityById(taskId);

      if (task is! Task) {
        return null;
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
          }
        }

        await updateChecklist(
          checklistId: newChecklist.meta.id,
          data: newChecklist.data.copyWith(
            linkedChecklistItems: createdIds,
          ),
        );
      }

      return newChecklist;
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
}
