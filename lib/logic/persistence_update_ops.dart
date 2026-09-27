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

  /// Applies [change] to the data of the stored task [journalEntityId], and
  /// [entryText] when given, and writes the result on that row
  /// ([writeOnStored]).
  ///
  /// [change] is handed the data as stored, never a copy a screen or a tool
  /// call read earlier, and sets only the fields its writer sets: a version
  /// stored meanwhile — by sync, the agent, or another screen — is built on
  /// again rather than replaced, so a field another writer set is never
  /// silently put back (`specs/tla/TaskFieldWrites.tla`, NoLostFieldEdit).
  /// The checklist list stays the stored one — `ChecklistRepository.
  /// updateTaskChecklistIds` owns it — and the stored record of applied
  /// agent changes is kept ([TaskDataOnStored.onStored], ADR 0098).
  ///
  /// [onlyIf], when given, is asked of the stored task in the same build,
  /// so a condition on the task — its category, say — holds for the row the
  /// change is written on, not only for one read earlier; when it answers
  /// false nothing is written.
  ///
  /// Returns the task as stored afterwards — unchanged when [change] leaves
  /// it as it is or [onlyIf] refuses it — or `null` when it does not exist,
  /// is not a task, or the write failed.
  Future<Task?> updateTaskImpl({
    required String journalEntityId,
    required TaskData Function(TaskData stored) change,
    EntryText? entryText,
    bool Function(Task stored)? onlyIf,
  }) async {
    try {
      Task? result;
      final stored = await writeOnStored(
        journalDb: journalDb,
        persistenceLogic: logic,
        id: journalEntityId,
        build: (stored) async {
          result = null;
          if (stored is! Task) {
            loggingService.error(
              LogDomain.persistence,
              'not a task',
              subDomain: 'updateTask',
            );
            return null;
          }
          if (onlyIf != null && !onlyIf(stored)) {
            result = stored;
            return null;
          }
          final data = change(stored.data).onStored(stored.data);
          final text = entryText ?? stored.entryText;
          if (data == stored.data && text == stored.entryText) {
            result = stored;
            return null;
          }
          return result = stored.copyWith(
            meta: await logic.updateMetadata(stored.meta),
            entryText: text,
            data: data,
          );
        },
        beforeNotify: (stored, updated) =>
            stored is Task &&
                updated is Task &&
                stored.data.priority != updated.data.priority
            ? () => journalDb.updateTaskPriorityColumn(
                id: journalEntityId,
                priority: updated.data.priority.short,
                rank: updated.data.priority.rank,
              )
            : null,
      );
      return stored ? result : null;
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateTask',
      );
      return null;
    }
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
