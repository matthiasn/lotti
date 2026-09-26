import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/logic/persistence_collaborator_base.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;
import 'package:lotti/logic/persistence_logic_contract.dart';
import 'package:lotti/logic/write_on_stored.dart';
import 'package:lotti/services/domain_logging.dart';

/// Entry-update operations of [PersistenceLogic].
///
/// Metadata updates and the DB write route back through the facade
/// ([PersistenceLogicContract]) so test subclasses overriding those keep
/// intercepting the calls.
class PersistenceUpdateOps extends PersistenceCollaboratorBase {
  PersistenceUpdateOps(super.logic);

  Future<bool> updateJournalEntityTextImpl(
    String journalEntityId,
    EntryText entryText,
    DateTime dateTo,
  ) async {
    try {
      final journalEntity = await journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final newMeta = await logic.updateMetadata(
        journalEntity.meta,
        dateTo: dateTo,
      );

      if (journalEntity is JournalEntry) {
        await logic.updateDbEntity(
          journalEntity.copyWith(
            meta: newMeta,
            entryText: entryText,
          ),
        );
      }

      if (journalEntity is JournalAudio) {
        await logic.updateDbEntity(
          journalEntity.copyWith(
            meta: newMeta.copyWith(
              flag: newMeta.flag == EntryFlag.import
                  ? EntryFlag.none
                  : newMeta.flag,
            ),
            entryText: entryText,
          ),
        );
      }

      if (journalEntity is JournalImage) {
        await logic.updateDbEntity(
          journalEntity.copyWith(
            meta: newMeta.copyWith(
              flag: newMeta.flag == EntryFlag.import
                  ? EntryFlag.none
                  : newMeta.flag,
            ),
            entryText: entryText,
          ),
        );
      }

      if (journalEntity is MeasurementEntry) {
        await logic.updateDbEntity(
          journalEntity.copyWith(
            meta: newMeta,
            entryText: entryText,
          ),
        );
      }

      if (journalEntity is HabitCompletionEntry) {
        await logic.updateDbEntity(
          journalEntity.copyWith(
            meta: newMeta,
            entryText: entryText,
          ),
        );
      }
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateJournalEntityText',
      );
      // Mirror updateJournalEntity's contract: a caught exception means the
      // write did not commit, so callers must see a failure return rather
      // than a silently-true result with a logged exception.
      return false;
    }
    return true;
  }

  Future<bool> updateJournalEntryImpl({
    required String journalEntityId,
    EntryText? entryText,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (entryText == null && dateFrom == null && dateTo == null) {
      return false;
    }

    try {
      final journalEntity = await journalDb.journalEntityById(journalEntityId);

      if (journalEntity is! JournalEntry) {
        return false;
      }

      final newMeta = await logic.updateMetadata(
        journalEntity.meta,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      final updated = journalEntity.copyWith(
        meta: newMeta,
        entryText: entryText ?? journalEntity.entryText,
      );

      return await logic.updateDbEntity(updated) ?? false;
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateJournalEntry',
      );
      return false;
    }
  }

  Future<bool> updateTaskImpl({
    required String journalEntityId,
    required TaskData taskData,
    String? categoryId,
    EntryText? entryText,
  }) async {
    try {
      // Written on the stored task, which keeps its own checklist list: the
      // caller's [taskData] may be a screen's copy from before a checklist
      // was added (ChecklistRepository.updateTaskChecklistIds owns that
      // list; specs/tla/ChecklistMembership.tla).
      return await writeOnStored(
        journalDb: journalDb,
        persistenceLogic: logic,
        id: journalEntityId,
        build: (stored) async {
          if (stored is! Task) {
            loggingService.error(
              LogDomain.persistence,
              'not a task',
              subDomain: 'updateTask',
            );
            return null;
          }
          return stored.copyWith(
            meta: await logic.updateMetadata(stored.meta),
            entryText: entryText ?? stored.entryText,
            data: taskData.copyWith(checklistIds: stored.data.checklistIds),
          );
        },
        beforeNotify: (stored, _) =>
            stored is Task && stored.data.priority != taskData.priority
            ? () => journalDb.updateTaskPriorityColumn(
                id: journalEntityId,
                priority: taskData.priority.short,
                rank: taskData.priority.rank,
              )
            : null,
      );
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateTask',
      );
    }
    return true;
  }

  Future<bool> updateEventImpl({
    required String journalEntityId,
    required EventData data,
    EntryText? entryText,
  }) async {
    try {
      final journalEntity = await journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        event: (JournalEvent event) async {
          await logic.updateDbEntity(
            event.copyWith(
              meta: await logic.updateMetadata(journalEntity.meta),
              entryText: entryText,
              data: data,
            ),
          );
        },
        orElse: () async {
          loggingService.error(
            LogDomain.persistence,
            'not an event',
            subDomain: 'updateEvent',
          );
        },
      );
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateEvent',
      );
    }
    return true;
  }
}
