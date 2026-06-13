import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_collaborator_base.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;
import 'package:lotti/logic/persistence_logic_contract.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/entry_utils.dart';

/// Entry-creation operations of [PersistenceLogic].
///
/// Implements the `*Impl` builders. Metadata creation and the DB write go
/// back through the facade ([PersistenceLogicContract]) so test subclasses
/// that override those methods keep intercepting the calls.
class PersistenceCreateOps extends PersistenceCollaboratorBase {
  PersistenceCreateOps(super.logic);

  Future<QuantitativeEntry?> createQuantitativeEntryImpl(
    QuantitativeData data,
  ) async {
    try {
      final journalEntity = QuantitativeEntry(
        data: data,
        meta: await logic.createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: json.encode(data),
        ),
      );
      await logic.createDbEntity(
        journalEntity,
        shouldAddGeolocation: false,
      );
      return journalEntity;
    } catch (exception, stackTrace) {
      loggingService.error(
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
        meta: await logic.createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: data.id,
        ),
      );

      await logic.createDbEntity(
        workout,
        shouldAddGeolocation: false,
      );

      return workout;
    } catch (exception, stackTrace) {
      loggingService.error(
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
        meta: await logic.createMetadata(
          dateFrom: data.taskResult.startDate,
          dateTo: data.taskResult.endDate,
          uuidV5Input: json.encode(data),
        ),
      );

      await logic.createDbEntity(journalEntity, linkedId: linkedId);
    } catch (exception, stackTrace) {
      loggingService.error(
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
        meta: await logic.createMetadata(
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

      await logic.createDbEntity(
        measurementEntry,
        linkedId: linkedId,
        shouldAddGeolocation: shouldAddGeolocation,
      );

      updateNotifications.notify({measurementEntry.data.dataTypeId});

      return measurementEntry;
    } catch (exception, stackTrace) {
      loggingService.error(
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
        meta: await logic.createMetadata(
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

      final saved = await logic.createDbEntity(
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
      loggingService.error(
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
        meta: await logic.createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: json.encode(data),
          categoryId: categoryId,
          starred: false,
        ),
      );

      await logic.createDbEntity(task, linkedId: linkedId);

      return task;
    } catch (exception, stackTrace) {
      loggingService.error(
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
        meta: await logic.createMetadata(
          dateFrom: dateFrom ?? DateTime.now(),
          dateTo: DateTime.now(),
          uuidV5Input: json.encode(data),
          categoryId: categoryId,
          starred: false,
        ),
      );

      await logic.createDbEntity(aiResponse, linkedId: linkedId);

      if (linkedId != null) {
        updateNotifications.notify({linkedId});
      }

      return aiResponse;
    } catch (exception, stackTrace) {
      loggingService.error(
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
        meta: await logic.createMetadata(
          starred: true,
          categoryId: categoryId,
        ),
      );

      await logic.createDbEntity(journalEvent, linkedId: linkedId);

      return journalEvent;
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createEventEntry',
      );
    }

    return null;
  }
}
