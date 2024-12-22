import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence/persistence_logic.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_repository.g.dart';

@Riverpod(keepAlive: true)
ChecklistRepository checklistRepository(Ref ref) {
  return ChecklistRepository();
}

class ChecklistRepository {
  final JournalDb _journalDb = getIt<JournalDb>();
  final VectorClockService _vectorClockService = getIt<VectorClockService>();
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  Future<JournalEntity?> createChecklist({
    required String? taskId,
    List<ChecklistItemData>? items,
  }) async {
    try {
      if (taskId == null) {
        return null;
      }

      final task = await getIt<JournalDb>().journalEntityById(taskId);

      if (task is! Task) {
        return null;
      }

      final newChecklist = Checklist(
        meta: await _persistenceLogic.createMetadata(),
        data: ChecklistData(
          title: task.data.title,
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
      _loggingDb.captureException(
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
  }) async {
    try {
      final newChecklistItem = ChecklistItem(
        meta: await _persistenceLogic.createMetadata(),
        data: ChecklistItemData(
          title: title,
          isChecked: false,
          linkedChecklists: [checklistId],
        ),
      );

      await _persistenceLogic.createDbEntity(newChecklistItem);

      return newChecklistItem;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
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
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(checklistId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        checklist: (Checklist checklist) async {
          final vc = await _vectorClockService.getNextVectorClock(
            previous: journalEntity.meta.vectorClock,
          );

          final oldMeta = journalEntity.meta;
          final newMeta = oldMeta.copyWith(
            updatedAt: now,
            vectorClock: vc,
          );

          final updatedChecklist = checklist.copyWith(
            meta: newMeta,
            data: data,
          );

          await _persistenceLogic.updateDbEntity(
            updatedChecklist,
            enqueueSync: true,
          );
        },
        orElse: () async => _loggingDb.captureException(
          'not a checklist',
          domain: 'persistence_logic',
          subDomain: 'updateChecklist',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
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
  }) async {
    try {
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(checklistItemId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        checklistItem: (ChecklistItem checklistItem) async {
          final vc = await _vectorClockService.getNextVectorClock(
            previous: journalEntity.meta.vectorClock,
          );

          final oldMeta = journalEntity.meta;
          final newMeta = oldMeta.copyWith(
            updatedAt: now,
            vectorClock: vc,
          );

          final updatedChecklist = checklistItem.copyWith(
            meta: newMeta,
            data: data,
          );

          await _persistenceLogic.updateDbEntity(
            updatedChecklist,
            enqueueSync: true,
          );
        },
        orElse: () async => _loggingDb.captureException(
          'not a checklist item',
          domain: 'persistence_logic',
          subDomain: 'updateChecklistItem',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateChecklistItem',
        stackTrace: stackTrace,
      );
    }
    return true;
  }
}
