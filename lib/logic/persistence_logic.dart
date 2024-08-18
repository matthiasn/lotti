import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/ai/ai_logic.dart';
import 'package:lotti/services/asr_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/entry_utils.dart';
import 'package:lotti/utils/location.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:uuid/uuid.dart';

class PersistenceLogic {
  PersistenceLogic() {
    init();
  }

  final JournalDb _journalDb = getIt<JournalDb>();
  final VectorClockService _vectorClockService = getIt<VectorClockService>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final OutboxService _outboxService = getIt<OutboxService>();
  final uuid = const Uuid();
  DeviceLocation? location;

  Future<void> init() async {
    if (!Platform.isWindows) {
      location = DeviceLocation();
    }
  }

  Future<QuantitativeEntry?> createQuantitativeEntry(
    QuantitativeData data,
  ) async {
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      final dateFrom = data.dateFrom;
      final dateTo = data.dateTo;

      final journalEntity = QuantitativeEntry(
        data: data,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: id,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      );
      await createDbEntity(journalEntity, enqueueSync: true);
      return journalEntity;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createQuantitativeEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<WorkoutEntry?> createWorkoutEntry(WorkoutData data) async {
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();
      final dateFrom = data.dateFrom;
      final dateTo = data.dateTo;

      final workout = WorkoutEntry(
        data: data,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: data.id,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      );
      await createDbEntity(workout, enqueueSync: true);

      return workout;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createWorkoutEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<bool> createSurveyEntry({
    required SurveyData data,
    String? linkedId,
  }) async {
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      final journalEntity = JournalEntity.survey(
        data: data,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: data.taskResult.startDate ?? now,
          dateTo: data.taskResult.endDate ?? now,
          id: id,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      );

      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linkedId,
      );
      addGeolocation(journalEntity.meta.id);
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createSurveyEntry',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  Future<MeasurementEntry?> createMeasurementEntry({
    required MeasurementData data,
    required bool private,
    String? linkedId,
    String? comment,
  }) async {
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      final measurementEntry = MeasurementEntry(
        data: data,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          id: id,
          private: private,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        entryText: entryTextFromPlain(comment),
      );

      await createDbEntity(
        measurementEntry,
        enqueueSync: true,
        linkedId: linkedId,
      );

      if (data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
          data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1) {
        addGeolocation(measurementEntry.meta.id);
      }

      return measurementEntry;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createMeasurementEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<HabitCompletionEntry?> createHabitCompletionEntry({
    required HabitCompletionData data,
    required HabitDefinition? habitDefinition,
    String? linkedId,
    String? comment,
  }) async {
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));
      final defaultStoryId = habitDefinition?.defaultStoryId;
      final tagIds = defaultStoryId != null ? [defaultStoryId] : <String>[];

      final habitCompletionEntry = HabitCompletionEntry(
        data: data,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          id: id,
          vectorClock: vc,
          private: habitDefinition?.private ?? false,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
          tagIds: tagIds,
        ),
        entryText: entryTextFromPlain(comment),
      );

      await createDbEntity(
        habitCompletionEntry,
        enqueueSync: true,
        linkedId: linkedId,
      );

      if (data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
          data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1) {
        addGeolocation(habitCompletionEntry.meta.id);
      }

      return habitCompletionEntry;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createMeasurementEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<Task?> createTaskEntry({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) async {
    try {
      final now = DateTime.now();
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));
      final vc = await _vectorClockService.getNextVectorClock();

      final task = Task(
        data: data,
        entryText: entryText,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          id: id,
          categoryId: categoryId,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
          starred: true,
        ),
      );

      await createDbEntity(
        task,
        enqueueSync: true,
        linkedId: linkedId,
      );
      addGeolocation(task.meta.id);
      return task;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createTaskEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<JournalEvent?> createEventEntry({
    required EventData data,
    required EntryText entryText,
    String? linkedId,
  }) async {
    try {
      final now = DateTime.now();
      final id = uuid.v1();
      final vc = await _vectorClockService.getNextVectorClock();

      final journalEvent = JournalEvent(
        data: data,
        entryText: entryText,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          id: id,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
          starred: true,
        ),
      );

      await createDbEntity(
        journalEvent,
        enqueueSync: true,
        linkedId: linkedId,
      );
      addGeolocation(journalEvent.meta.id);
      return journalEvent;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createEventEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<JournalEntity?> createImageEntry(
    ImageData imageData, {
    String? linkedId,
  }) async {
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(imageData));

      final dateFrom = imageData.capturedAt;
      final dateTo = imageData.capturedAt;
      final journalEntity = JournalEntity.journalImage(
        data: imageData,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: id,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
          flag: EntryFlag.import,
        ),
        geolocation: imageData.geolocation,
      );
      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linkedId,
      );
      return journalEntity;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createImageEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<JournalAudio?> createAudioEntry(
    AudioNote audioNote, {
    required String? language,
    String? linkedId,
  }) async {
    try {
      final autoTranscribe = await getIt<JournalDb>().getConfigFlag(
        autoTranscribeFlag,
      );

      final audioData = AudioData(
        audioDirectory: audioNote.audioDirectory,
        duration: audioNote.duration,
        audioFile: audioNote.audioFile,
        dateTo: audioNote.createdAt.add(audioNote.duration),
        dateFrom: audioNote.createdAt,
        autoTranscribeWasActive: autoTranscribe,
        language: language,
      );

      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(audioData));

      final dateFrom = audioData.dateFrom;
      final dateTo = audioData.dateTo;
      final journalEntity = JournalAudio(
        data: audioData,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: id,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
          flag: EntryFlag.import,
        ),
      );
      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linkedId,
      );
      addGeolocation(journalEntity.meta.id);

      if (autoTranscribe) {
        await getIt<AsrService>().enqueue(entry: journalEntity);
      }

      return journalEntity;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createAudioEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<JournalEntity?> createTextEntry(
    EntryText entryText, {
    required DateTime started,
    required String id,
    String? linkedId,
  }) async {
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();

      final journalEntity = JournalEntity.journalEntry(
        entryText: entryText,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: started,
          dateTo: now,
          id: id,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      );
      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linkedId,
      );
      addGeolocation(journalEntity.meta.id);
      return journalEntity;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createTextEntry',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> createLink({
    required String fromId,
    required String toId,
  }) async {
    final now = DateTime.now();
    final link = EntryLink.basic(
      id: uuid.v1(),
      fromId: fromId,
      toId: toId,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
    );

    final res = await _journalDb.upsertEntryLink(link);
    _updateNotifications.notify({link.fromId, link.toId});

    await _outboxService.enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      ),
    );
    return res != 0;
  }

  Future<int> removeLink({
    required String fromId,
    required String toId,
  }) async {
    final res = _journalDb.removeLink(fromId: fromId, toId: toId);
    _updateNotifications.notify({fromId, toId});
    return res;
  }

  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool enqueueSync = false,
    String? linkedId,
  }) async {
    final tagsService = getIt<TagsService>();
    JournalEntity? linked;

    if (linkedId != null) {
      linked = await _journalDb.journalEntityById(linkedId);
    }

    try {
      final linkedTagIds = linked?.meta.tagIds;
      final storyTags = tagsService.getFilteredStoryTagIds(linkedTagIds);

      final withTags = journalEntity.copyWith(
        meta: journalEntity.meta.copyWith(
          private: linked?.meta.private,
          tagIds: <String>{
            ...?journalEntity.meta.tagIds,
            ...storyTags,
          }.toList(),
        ),
      );

      final res = await _journalDb.updateJournalEntity(withTags);
      _updateNotifications.notify(withTags.affectedIds);

      final saved = res != 0;
      await _journalDb.addTagged(withTags);

      if (saved && enqueueSync) {
        await _outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            journalEntity: withTags,
            status: SyncEntryStatus.initial,
          ),
        );
      }

      if (linked != null) {
        await createLink(
          fromId: linked.meta.id,
          toId: withTags.meta.id,
        );
      }

      await getIt<NotificationService>().updateBadge();

      return saved;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createDbEntity',
        stackTrace: stackTrace,
      );
      debugPrint('Exception $exception');
    }
    return null;
  }

  Future<bool> updateJournalEntityText(
    String journalEntityId,
    EntryText entryText,
    DateTime dateTo,
  ) async {
    try {
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final vc = await _vectorClockService.getNextVectorClock(
        previous: journalEntity.meta.vectorClock,
      );

      final oldMeta = journalEntity.meta;
      final newMeta = oldMeta.copyWith(
        updatedAt: now,
        vectorClock: vc,
        dateTo: dateTo,
      );

      if (journalEntity is JournalEntry) {
        final newJournalEntry = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newJournalEntry, enqueueSync: true);
      }

      if (journalEntity is JournalAudio) {
        final newJournalAudio = journalEntity.copyWith(
          meta: newMeta.copyWith(
            flag: oldMeta.flag == EntryFlag.import
                ? EntryFlag.none
                : oldMeta.flag,
          ),
          entryText: entryText,
        );

        await updateDbEntity(newJournalAudio, enqueueSync: true);
      }

      if (journalEntity is JournalImage) {
        final newJournalImage = journalEntity.copyWith(
          meta: newMeta.copyWith(
            flag: oldMeta.flag == EntryFlag.import
                ? EntryFlag.none
                : oldMeta.flag,
          ),
          entryText: entryText,
        );

        await updateDbEntity(newJournalImage, enqueueSync: true);
      }

      if (journalEntity is MeasurementEntry) {
        final newEntry = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newEntry, enqueueSync: true);
      }

      if (journalEntity is HabitCompletionEntry) {
        final newEntry = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newEntry, enqueueSync: true);
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateJournalEntityText',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<bool> updateTask({
    required String journalEntityId,
    required TaskData taskData,
    String? categoryId,
    EntryText? entryText,
  }) async {
    try {
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        task: (Task task) async {
          final vc = await _vectorClockService.getNextVectorClock(
            previous: journalEntity.meta.vectorClock,
          );

          final oldMeta = journalEntity.meta;
          final newMeta = oldMeta.copyWith(
            updatedAt: now,
            vectorClock: vc,
          );

          final newTask = task.copyWith(
            meta: newMeta,
            entryText: entryText,
            data: taskData,
          );

          await updateDbEntity(newTask, enqueueSync: true);
        },
        orElse: () async => _loggingDb.captureException(
          'not a task',
          domain: 'persistence_logic',
          subDomain: 'updateTask',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateTask',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<bool> updateEvent({
    required String journalEntityId,
    required EventData data,
    EntryText? entryText,
  }) async {
    try {
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        event: (JournalEvent event) async {
          final vc = await _vectorClockService.getNextVectorClock(
            previous: journalEntity.meta.vectorClock,
          );

          final oldMeta = journalEntity.meta;
          final newMeta = oldMeta.copyWith(
            updatedAt: now,
            vectorClock: vc,
          );

          final newEvent = event.copyWith(
            meta: newMeta,
            entryText: entryText,
            data: data,
          );

          await updateDbEntity(newEvent, enqueueSync: true);
        },
        orElse: () async => _loggingDb.captureException(
          'not an event',
          domain: 'persistence_logic',
          subDomain: 'updateEvent',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateTask',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<bool> addAudioTranscript({
    required String journalEntityId,
    required AudioTranscript transcript,
  }) async {
    try {
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        journalAudio: (JournalAudio journalAudio) async {
          final vc = await _vectorClockService.getNextVectorClock(
            previous: journalEntity.meta.vectorClock,
          );

          final oldMeta = journalEntity.meta;
          final newMeta = oldMeta.copyWith(
            updatedAt: now,
            vectorClock: vc,
          );

          final data = journalAudio.data;
          final updatedData = journalAudio.data.copyWith(
            transcripts: [
              ...?data.transcripts,
              transcript,
            ],
          );

          final entryText = journalAudio.entryText;

          final newEntryText = EntryText(
            plainText: transcript.transcript,
            markdown: transcript.transcript,
          );

          final replaceEntryText = entryText == null ||
              entryText.plainText.isEmpty ||
              '${entryText.markdown}'.trim().isEmpty;

          final updated = journalAudio.copyWith(
            meta: newMeta,
            entryText: replaceEntryText ? newEntryText : entryText,
            data: updatedData,
          );

          await updateDbEntity(updated, enqueueSync: true);
        },
        orElse: () async => _loggingDb.captureException(
          'not an audio entry',
          domain: 'persistence_logic',
          subDomain: 'addAudioTranscript',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addAudioTranscript',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<bool> removeAudioTranscript({
    required String journalEntityId,
    required AudioTranscript transcript,
  }) async {
    try {
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        journalAudio: (JournalAudio journalAudio) async {
          final vc = await _vectorClockService.getNextVectorClock(
            previous: journalEntity.meta.vectorClock,
          );

          final oldMeta = journalEntity.meta;
          final newMeta = oldMeta.copyWith(
            updatedAt: now,
            vectorClock: vc,
          );

          final data = journalAudio.data;
          final updatedData = journalAudio.data.copyWith(
            transcripts: data.transcripts
                ?.where((element) => element.created != transcript.created)
                .toList(),
          );

          final updated = journalAudio.copyWith(
            meta: newMeta,
            data: updatedData,
          );

          await updateDbEntity(updated, enqueueSync: true);
        },
        orElse: () async => _loggingDb.captureException(
          'not an audio entry',
          domain: 'persistence_logic',
          subDomain: 'removeAudioTranscript',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'removeAudioTranscript',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<void> addGeolocationAsync(String journalEntityId) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);
      final geolocation = await location?.getCurrentGeoLocation().timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      if (journalEntity != null && geolocation != null) {
        final metadata = journalEntity.meta;
        final now = DateTime.now();
        final vc = await _vectorClockService.getNextVectorClock(
          previous: metadata.vectorClock,
        );

        final newMeta = metadata.copyWith(
          updatedAt: now,
          vectorClock: vc,
        );

        final newJournalEntity = journalEntity.copyWith(
          meta: newMeta,
          geolocation: geolocation,
        );

        await updateDbEntity(newJournalEntity, enqueueSync: true);
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addGeolocation',
        stackTrace: stackTrace,
      );
    }
  }

  void addGeolocation(String journalEntityId) {
    unawaited(addGeolocationAsync(journalEntityId));
  }

  Future<bool> updateJournalEntityDate(
    String journalEntityId, {
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock(
        previous: journalEntity.meta.vectorClock,
      );

      final newMeta = journalEntity.meta.copyWith(
        updatedAt: now,
        vectorClock: vc,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      final newJournalEntity = journalEntity.copyWith(
        meta: newMeta,
      );

      await updateDbEntity(newJournalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateJournalEntityDate',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<bool> updateCategoryId(
    String journalEntityId, {
    required String? categoryId,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock(
        previous: journalEntity.meta.vectorClock,
      );

      final newMeta = journalEntity.meta.copyWith(
        updatedAt: now,
        vectorClock: vc,
        categoryId: categoryId,
      );

      final newJournalEntity = journalEntity.copyWith(
        meta: newMeta,
      );

      await updateDbEntity(newJournalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateCategoryId',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<bool> updateJournalEntity(
    JournalEntity journalEntity,
    Metadata metadata,
  ) async {
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock(
        previous: metadata.vectorClock,
      );

      final newMeta = metadata.copyWith(
        updatedAt: now,
        vectorClock: vc,
      );

      final newJournalEntity = journalEntity.copyWith(
        meta: newMeta,
      );

      await updateDbEntity(newJournalEntity, enqueueSync: true);
      await _journalDb.addTagged(newJournalEntity);
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateJournalEntity',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  Future<bool?> addTags({
    required String journalEntityId,
    required List<String> addedTagIds,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final meta = addTagsToMeta(journalEntity.meta, addedTagIds);

      final vc = await _vectorClockService.getNextVectorClock(
        previous: meta.vectorClock,
      );

      final newJournalEntity = journalEntity.copyWith(
        meta: meta.copyWith(
          updatedAt: DateTime.now(),
          vectorClock: vc,
        ),
      );

      return await updateDbEntity(newJournalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addTags',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  Future<bool?> addTagsWithLinked({
    required String journalEntityId,
    required List<String> addedTagIds,
  }) async {
    try {
      await addTags(
        journalEntityId: journalEntityId,
        addedTagIds: addedTagIds,
      );

      final tagsService = getIt<TagsService>();
      final storyTags = tagsService.getFilteredStoryTagIds(addedTagIds);

      final linkedEntities = await _journalDb.getLinkedEntities(
        journalEntityId,
      );

      for (final linked in linkedEntities) {
        await addTags(
          journalEntityId: linked.meta.id,
          addedTagIds: storyTags,
        );
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addTagsWithLinked',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  Future<bool?> removeTag({
    required String journalEntityId,
    required String tagId,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final meta = removeTagFromMeta(journalEntity.meta, tagId);

      final vc = await _vectorClockService.getNextVectorClock(
        previous: meta.vectorClock,
      );

      final newJournalEntity = journalEntity.copyWith(
        meta: meta.copyWith(
          updatedAt: DateTime.now(),
          vectorClock: vc,
        ),
      );

      return await updateDbEntity(newJournalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'removeTag',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  Future<bool> deleteJournalEntity(
    String journalEntityId,
  ) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock(
        previous: journalEntity.meta.vectorClock,
      );

      final newMeta = journalEntity.meta.copyWith(
        updatedAt: now,
        vectorClock: vc,
        deletedAt: now,
      );

      final newEntity = journalEntity.copyWith(meta: newMeta);
      await updateDbEntity(newEntity, enqueueSync: true);

      await getIt<NotificationService>().updateBadge();
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'deleteJournalEntity',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    bool enqueueSync = false,
  }) async {
    try {
      unawaited(
        getIt<AiLogic>().embed(
          journalEntity,
        ),
      );

      await _journalDb.updateJournalEntity(journalEntity);

      _updateNotifications.notify(journalEntity.affectedIds);

      await getIt<Fts5Db>().insertText(
        journalEntity,
        removePrevious: true,
      );

      if (enqueueSync) {
        await _outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            journalEntity: journalEntity,
            status: SyncEntryStatus.update,
          ),
        );
      }

      await getIt<NotificationService>().updateBadge();

      return true;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateDbEntity',
        stackTrace: stackTrace,
      );
      debugPrint('Exception $exception');
    }
    return null;
  }

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) async {
    final linesAffected =
        await _journalDb.upsertEntityDefinition(entityDefinition);
    _updateNotifications.notify({entityDefinition.id});
    await _outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: entityDefinition,
        status: SyncEntryStatus.update,
      ),
    );
    return linesAffected;
  }

  Future<int> upsertTagEntity(TagEntity tagEntity) async {
    final linesAffected = await _journalDb.upsertTagEntity(tagEntity);
    await _outboxService.enqueueMessage(
      SyncMessage.tagEntity(
        tagEntity: tagEntity,
        status: SyncEntryStatus.update,
      ),
    );
    return linesAffected;
  }

  Future<int> upsertDashboardDefinition(DashboardDefinition dashboard) async {
    final linesAffected = await _journalDb.upsertDashboardDefinition(dashboard);
    await _outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: dashboard,
        status: SyncEntryStatus.update,
      ),
    );

    if (dashboard.deletedAt != null) {
      await getIt<NotificationService>().cancelNotification(
        dashboard.id.hashCode,
      );
    }

    if (dashboard.reviewAt != null && dashboard.deletedAt == null) {
      await getIt<NotificationService>().scheduleNotification(
        title: 'Time for a Dashboard Review!',
        body: dashboard.name,
        notifyAt: dashboard.reviewAt!,
        notificationId: dashboard.id.hashCode,
        deepLink: '/dashboards/${dashboard.id}',
      );
    }

    return linesAffected;
  }

  Future<int> deleteDashboardDefinition(DashboardDefinition dashboard) async {
    final linesAffected = await upsertDashboardDefinition(
      dashboard.copyWith(
        deletedAt: DateTime.now(),
      ),
    );

    await getIt<NotificationService>()
        .cancelNotification(dashboard.id.hashCode);

    return linesAffected;
  }

  Future<String> addTagDefinition(String tagString) async {
    final now = DateTime.now();
    final id = uuid.v1();
    await upsertTagEntity(
      TagEntity.genericTag(
        id: id,
        tag: tagString.trim(),
        private: false,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );
    return id;
  }
}

Metadata addTagsToMeta(Metadata meta, List<String> addedTagIds) {
  final existingTagIds = meta.tagIds ?? [];
  final tagIds = [...existingTagIds];

  for (final tagId in addedTagIds) {
    if (!tagIds.contains(tagId)) {
      tagIds.add(tagId);
    }
  }

  return meta.copyWith(
    tagIds: tagIds,
  );
}

Metadata removeTagFromMeta(Metadata meta, String tagId) {
  return meta.copyWith(
    tagIds: meta.tagIds?.where((String id) => id != tagId).toList(),
  );
}
