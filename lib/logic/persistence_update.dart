part of 'persistence_logic.dart';

/// Entry-update operations of [PersistenceLogic]; same delegator pattern
/// as the create part so mocks keep intercepting the public methods.
mixin _PersistenceUpdateOps on _PersistenceLogicBase {
  @override
  Future<bool> updateJournalEntityTextImpl(
    String journalEntityId,
    EntryText entryText,
    DateTime dateTo,
  ) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final newMeta = await updateMetadata(journalEntity.meta, dateTo: dateTo);

      if (journalEntity is JournalEntry) {
        await updateDbEntity(
          journalEntity.copyWith(
            meta: newMeta,
            entryText: entryText,
          ),
        );
      }

      if (journalEntity is JournalAudio) {
        await updateDbEntity(
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
        await updateDbEntity(
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
        await updateDbEntity(
          journalEntity.copyWith(
            meta: newMeta,
            entryText: entryText,
          ),
        );
      }

      if (journalEntity is HabitCompletionEntry) {
        await updateDbEntity(
          journalEntity.copyWith(
            meta: newMeta,
            entryText: entryText,
          ),
        );
      }
    } catch (exception, stackTrace) {
      _loggingService.error(
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

  @override
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
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity is! JournalEntry) {
        return false;
      }

      final newMeta = await updateMetadata(
        journalEntity.meta,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      final updated = journalEntity.copyWith(
        meta: newMeta,
        entryText: entryText ?? journalEntity.entryText,
      );

      return await updateDbEntity(updated) ?? false;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateJournalEntry',
      );
      return false;
    }
  }

  @override
  Future<bool> updateTaskImpl({
    required String journalEntityId,
    required TaskData taskData,
    String? categoryId,
    EntryText? entryText,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        task: (Task task) async {
          final priorityChanged = task.data.priority != taskData.priority;
          await updateDbEntity(
            task.copyWith(
              meta: await updateMetadata(journalEntity.meta),
              entryText: entryText ?? task.entryText,
              data: taskData,
            ),
            beforeNotify: priorityChanged
                ? () => _journalDb.updateTaskPriorityColumn(
                    id: journalEntityId,
                    priority: taskData.priority.short,
                    rank: taskData.priority.rank,
                  )
                : null,
          );
        },
        orElse: () async {
          _loggingService.error(
            LogDomain.persistence,
            'not a task',
            subDomain: 'updateTask',
          );
        },
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateTask',
      );
    }
    return true;
  }

  @override
  Future<bool> updateEventImpl({
    required String journalEntityId,
    required EventData data,
    EntryText? entryText,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        event: (JournalEvent event) async {
          await updateDbEntity(
            event.copyWith(
              meta: await updateMetadata(journalEntity.meta),
              entryText: entryText,
              data: data,
            ),
          );
        },
        orElse: () async {
          _loggingService.error(
            LogDomain.persistence,
            'not an event',
            subDomain: 'updateEvent',
          );
        },
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateEvent',
      );
    }
    return true;
  }
}
