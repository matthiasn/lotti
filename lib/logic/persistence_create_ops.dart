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
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/entry_utils.dart';

/// Entry-creation operations of [PersistenceLogic].
///
/// Implements the `*Impl` builders. Metadata creation and the DB write go
/// back through the facade ([PersistenceLogicContract]) so test subclasses
/// that override those methods keep intercepting the calls.
class PersistenceCreateOps extends PersistenceCollaboratorBase {
  PersistenceCreateOps(super.logic);

  /// Stores a health sample, returning the entity when the database accepted a
  /// change and `null` when nothing was written.
  ///
  /// Discrete samples are keyed by their whole payload: a re-imported sample
  /// hashes to the id it already has, `createDbEntity` writes with
  /// `overwrite: false`, and the duplicate is rejected row by row.
  ///
  /// Cumulative days ([CumulativeQuantityData]) are keyed by type and day
  /// instead, and **updated in place** when the total differs — see
  /// [cumulativeQuantityEntryId]. Keyed by payload, a day whose total rose after
  /// import (a wearable that syncs overnight, a phone that caught up) became a
  /// second row beside the stale one, and a day whose total was unchanged was
  /// "rejected" indistinguishably from one that never reached the database.
  Future<QuantitativeEntry?> createQuantitativeEntryImpl(
    QuantitativeData data,
  ) async {
    try {
      return data is CumulativeQuantityData
          ? await _upsertCumulativeDay(data)
          : await _createQuantitativeEntry(data, json.encode(data));
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

  /// Writes a fresh row under the id derived from [uuidV5Input], honouring the
  /// write verdict: `null` when the database rejected it as a duplicate.
  Future<QuantitativeEntry?> _createQuantitativeEntry(
    QuantitativeData data,
    String uuidV5Input,
  ) async {
    final entry = QuantitativeEntry(
      data: data,
      meta: await logic.createMetadata(
        dateFrom: data.dateFrom,
        dateTo: data.dateTo,
        uuidV5Input: uuidV5Input,
      ),
    );
    final applied = await logic.createDbEntity(
      entry,
      shouldAddGeolocation: false,
    );
    return (applied ?? false) ? entry : null;
  }

  /// The deterministic uuidV5 input for one cumulative day: its type, its
  /// local calendar date and the importing installation's sync [host], so
  /// every import of that day on that installation addresses the same row
  /// whatever total it read.
  ///
  /// The host is part of the key on purpose. Two devices importing the same
  /// day would otherwise race for one row through sync and land as a conflict;
  /// kept apart, each writes its own row and the readers' per-day maximum
  /// merges them, exactly as it merged the payload-keyed rows before. The
  /// hardware model would not do: two phones of the same model, or two whose
  /// device-info lookup failed, share one.
  static String cumulativeQuantityEntryId(
    CumulativeQuantityData data, {
    required String? host,
  }) {
    return 'cumulative:${data.dataType}:${data.dateFrom.ymd}:$host';
  }

  /// Creates the day's row, or rewrites it when the stored total differs.
  ///
  /// Returns `null` when the stored day already carries the same total, so an
  /// import over an unchanged range still reports nothing new. Only the value
  /// decides: the day in progress carries "now" as its end, which advances on
  /// every background refresh, and rewriting (and syncing) three rows every ten
  /// minutes to move an end time nobody reads is not a change worth a write.
  Future<QuantitativeEntry?> _upsertCumulativeDay(
    CumulativeQuantityData data,
  ) async {
    final uuidV5Input = cumulativeQuantityEntryId(
      data,
      host: await vectorClockService.getHost(),
    );
    final existing = await journalDb.journalEntityById(
      metadataService.generateId(uuidV5Input: uuidV5Input),
    );

    if (existing is QuantitativeEntry) {
      if (existing.data.value == data.value) {
        return null;
      }
      final updated = existing.copyWith(
        data: data,
        meta: await logic.updateMetadata(
          existing.meta,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
        ),
      );
      final applied = await logic.updateDbEntity(updated);
      return (applied ?? false) ? updated : null;
    }

    return _createQuantitativeEntry(data, uuidV5Input);
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

      final applied = await logic.createDbEntity(
        workout,
        shouldAddGeolocation: false,
      );

      return (applied ?? false) ? workout : null;
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
        // and tell the caller the write failed — it did not. The UI then skips
        // its confirmation toast and, because it clears the optimistic-
        // celebration flag, replays the celebration when the row's
        // `completedToday` flip finally arrives.
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
