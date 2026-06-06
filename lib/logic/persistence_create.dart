part of 'persistence_logic.dart';

/// Entry-creation operations of [PersistenceLogic].
///
/// Implementation bodies live here; the class keeps thin delegators so
/// mocktail mocks of [PersistenceLogic] still intercept every public
/// method (extension methods cannot be mocked).
extension PersistenceCreateOps on PersistenceLogic {
  Future<QuantitativeEntry?> createQuantitativeEntryImpl(
    QuantitativeData data,
  ) async {
    try {
      final journalEntity = QuantitativeEntry(
        data: data,
        meta: await createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: json.encode(data),
        ),
      );
      await createDbEntity(
        journalEntity,
        shouldAddGeolocation: false,
      );
      return journalEntity;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createQuantitativeEntry',
      );
    }

    return null;
  }

  Future<WorkoutEntry?> createWorkoutEntryImpl(WorkoutData data) async {
    try {
      final workout = WorkoutEntry(
        data: data,
        meta: await createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: data.id,
        ),
      );

      await createDbEntity(
        workout,
        shouldAddGeolocation: false,
      );

      return workout;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createWorkoutEntry',
      );
    }

    return null;
  }

  Future<bool> createSurveyEntryImpl({
    required SurveyData data,
    String? linkedId,
  }) async {
    try {
      final journalEntity = JournalEntity.survey(
        data: data,
        meta: await createMetadata(
          dateFrom: data.taskResult.startDate,
          dateTo: data.taskResult.endDate,
          uuidV5Input: json.encode(data),
        ),
      );

      await createDbEntity(journalEntity, linkedId: linkedId);
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createSurveyEntry',
      );
    }

    return true;
  }

  Future<MeasurementEntry?> createMeasurementEntryImpl({
    required MeasurementData data,
    required bool private,
    String? linkedId,
    String? comment,
  }) async {
    try {
      final measurementEntry = MeasurementEntry(
        data: data,
        meta: await createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: json.encode(data),
          private: private,
        ),
        entryText: entryTextFromPlain(comment),
      );

      // clock.now() so tests can pin the "is this a live entry" gate with
      // withClock instead of racing the wall clock.
      final shouldAddGeolocation =
          data.dateFrom.difference(clock.now()).inMinutes.abs() < 1 &&
          data.dateTo.difference(clock.now()).inMinutes.abs() < 1;

      await createDbEntity(
        measurementEntry,
        linkedId: linkedId,
        shouldAddGeolocation: shouldAddGeolocation,
      );

      _updateNotifications.notify({measurementEntry.data.dataTypeId});

      return measurementEntry;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createMeasurementEntry',
      );
    }

    return null;
  }

  Future<HabitCompletionEntry?> createHabitCompletionEntryImpl({
    required HabitCompletionData data,
    required HabitDefinition? habitDefinition,
    String? linkedId,
    String? comment,
  }) async {
    try {
      final habitCompletionEntry = HabitCompletionEntry(
        data: data,
        meta: await createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: json.encode(data),
          private: habitDefinition?.private,
        ),
        entryText: entryTextFromPlain(comment),
      );

      // clock.now() so tests can pin the "is this a live entry" gate with
      // withClock instead of racing the wall clock.
      final shouldAddGeolocation =
          data.dateFrom.difference(clock.now()).inMinutes.abs() < 1 &&
          data.dateTo.difference(clock.now()).inMinutes.abs() < 1;

      final saved = await createDbEntity(
        habitCompletionEntry,
        linkedId: linkedId,
        shouldAddGeolocation: shouldAddGeolocation,
      );

      if (saved != true) {
        return null;
      }

      if (habitDefinition != null) {
        await getIt<NotificationService>().scheduleHabitNotification(
          habitDefinition,
          daysToAdd: 1,
        );
      }

      return habitCompletionEntry;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createMeasurementEntry',
      );
    }

    return null;
  }

  Future<Task?> createTaskEntryImpl({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) async {
    try {
      final task = Task(
        data: data,
        entryText: entryText,
        meta: await createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: json.encode(data),
          categoryId: categoryId,
          starred: false,
        ),
      );

      await createDbEntity(task, linkedId: linkedId);

      return task;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createTaskEntry',
      );
    }

    return null;
  }

  Future<AiResponseEntry?> createAiResponseEntryImpl({
    required AiResponseData data,
    DateTime? dateFrom,
    String? linkedId,
    String? categoryId,
  }) async {
    try {
      final aiResponse = AiResponseEntry(
        data: data,
        meta: await createMetadata(
          dateFrom: dateFrom ?? DateTime.now(),
          dateTo: DateTime.now(),
          uuidV5Input: json.encode(data),
          categoryId: categoryId,
          starred: false,
        ),
      );

      await createDbEntity(aiResponse, linkedId: linkedId);

      if (linkedId != null) {
        _updateNotifications.notify({linkedId});
      }

      return aiResponse;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createAiResponseEntry',
      );
    }

    return null;
  }

  Future<JournalEvent?> createEventEntryImpl({
    required EventData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) async {
    try {
      final journalEvent = JournalEvent(
        data: data,
        entryText: entryText,
        meta: await createMetadata(
          starred: true,
          categoryId: categoryId,
        ),
      );

      await createDbEntity(journalEvent, linkedId: linkedId);

      return journalEvent;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createEventEntry',
      );
    }

    return null;
  }
}
