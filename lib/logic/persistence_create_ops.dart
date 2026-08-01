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
        // Scheduling the next reminder is a side effect of a completion that
        // has already been written. Letting it throw here would return null
        // and tell the caller the write failed — it did not — so the user
        // would get no confirmation for a completion that is in the database,
        // and would likely tap again and record a duplicate.
        try {
          await getIt<NotificationService>().scheduleHabitNotification(
            habitDefinition,
            daysToAdd: 1,
          );
        } catch (exception, stackTrace) {
          loggingService.error(
            LogDomain.persistence,
            exception,
            stackTrace: stackTrace,
            subDomain: 'createHabitCompletionEntry.scheduleNotification',
          );
        }
      }

      return habitCompletionEntry;
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createHabitCompletionEntry',
      );
    }

    return null;
  }

  Future<Task?> createTaskEntryImpl({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
    List<String>? labelIds,
    bool? private,
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
          labelIds: labelIds,
          starred: false,
          // Only a link-free creation context supplies this: with a
          // `linkedId`, `createDbEntity` copies privacy off the linked entity
          // instead. Without either, a task created from a private parent
          // persists as public.
          private: private,
        ),
      );

      // The write's own verdict, not just the absence of a throw.
      // `createDbEntity` returns `res.applied` and burns the unbound vector
      // clock when a write is *rejected* rather than failing — discarding that
      // returned a Task that does not exist in the database, which every
      // caller then navigates to, links, or confirms as created.
      final saved = await logic.createDbEntity(task, linkedId: linkedId);
      if (saved != true) return null;

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
    String? id,
  }) async {
    try {
      final metadata = await logic.createMetadata(
        dateFrom: dateFrom ?? DateTime.now(),
        dateTo: DateTime.now(),
        uuidV5Input: json.encode(data),
        categoryId: categoryId,
        starred: false,
      );
      final aiResponse = AiResponseEntry(
        data: data,
        meta: id == null ? metadata : metadata.copyWith(id: id),
      );

      final persisted = await logic.createDbEntity(
        aiResponse,
        linkedId: linkedId,
      );
      if (persisted != true) return null;

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
