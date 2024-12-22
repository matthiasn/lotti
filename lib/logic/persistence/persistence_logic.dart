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
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/ai/ai_logic.dart';
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

  JournalDb get _journalDb => getIt<JournalDb>();
  VectorClockService get _vectorClockService => getIt<VectorClockService>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  LoggingDb get _loggingDb => getIt<LoggingDb>();
  final OutboxService outboxService = getIt<OutboxService>();
  final uuid = const Uuid();
  DeviceLocation? location;

  Future<void> init() async {
    if (!Platform.isWindows) {
      location = DeviceLocation();
    }
  }

  /// Creates a [Metadata] object with either a random UUID v1 ID or a
  /// deterministic UUID v5 ID. If [uuidV5Input] is provided, it will be used
  /// as the basis for the UUID v5 ID.
  /// The [dateFrom] and [dateTo] parameters are optional and will default to
  /// the current date and time if not provided. The [dateFrom] and [dateTo] can
  /// for example differ when importing photos from the camera roll.
  Future<Metadata> createMetadata({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? uuidV5Input,
    bool? private,
    List<String>? tagIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
  }) async {
    final now = DateTime.now();
    final vc = await _vectorClockService.getNextVectorClock();

    // avoid inserting the same external entity multiple times
    final id = uuidV5Input != null
        ? uuid.v5(Namespace.nil.value, uuidV5Input)
        : uuid.v1();

    return Metadata(
      createdAt: now,
      updatedAt: now,
      dateFrom: dateFrom ?? now,
      dateTo: dateTo ?? now,
      id: id,
      vectorClock: vc,
      private: private,
      tagIds: tagIds,
      categoryId: categoryId,
      starred: starred,
      timezone: await getLocalTimezone(),
      utcOffset: now.timeZoneOffset.inMinutes,
      flag: flag,
    );
  }

  Future<QuantitativeEntry?> createQuantitativeEntry(
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
      final workout = WorkoutEntry(
        data: data,
        meta: await createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: data.id,
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
      final journalEntity = JournalEntity.survey(
        data: data,
        meta: await createMetadata(
          dateFrom: data.taskResult.startDate,
          dateTo: data.taskResult.endDate,
          uuidV5Input: json.encode(data),
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
      final defaultStoryId = habitDefinition?.defaultStoryId;
      final tagIds = defaultStoryId != null ? [defaultStoryId] : <String>[];

      final habitCompletionEntry = HabitCompletionEntry(
        data: data,
        meta: await createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: json.encode(data),
          private: habitDefinition?.private,
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
      final task = Task(
        data: data,
        entryText: entryText,
        meta: await createMetadata(
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          uuidV5Input: json.encode(data),
          categoryId: categoryId,
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
      final journalEvent = JournalEvent(
        data: data,
        entryText: entryText,
        meta: await createMetadata(
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
      final journalEntity = JournalEntity.journalImage(
        data: imageData,
        meta: await createMetadata(
          dateFrom: imageData.capturedAt,
          dateTo: imageData.capturedAt,
          uuidV5Input: json.encode(imageData),
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

      final dateFrom = audioData.dateFrom;
      final dateTo = audioData.dateTo;

      final journalEntity = JournalAudio(
        data: audioData,
        meta: await createMetadata(
          dateFrom: dateFrom,
          dateTo: dateTo,
          uuidV5Input: json.encode(audioData),
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
      final journalEntity = JournalEntity.journalEntry(
        entryText: entryText,
        meta: await createMetadata(
          dateFrom: started,
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

    await outboxService.enqueueMessage(
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
        await outboxService.enqueueMessage(
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
        subDomain: 'updateEvent',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<void> updateLanguage({
    required String journalEntityId,
    required String language,
  }) async {
    try {
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      await journalEntity?.maybeMap(
        journalAudio: (JournalAudio item) async {
          final vc = await _vectorClockService.getNextVectorClock(
            previous: journalEntity.meta.vectorClock,
          );

          final newEvent = item.copyWith(
            meta: item.meta.copyWith(
              updatedAt: now,
              vectorClock: vc,
            ),
            data: item.data.copyWith(language: language),
          );

          await updateDbEntity(newEvent, enqueueSync: true);
        },
        orElse: () async => _loggingDb.captureException(
          'not an audio entry',
          domain: 'persistence_logic',
          subDomain: 'updateLanguage',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateLanguage',
        stackTrace: stackTrace,
      );
    }
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
      final geolocation = await location?.getCurrentGeoLocation().timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

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
        await outboxService.enqueueMessage(
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
    await outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: entityDefinition,
        status: SyncEntryStatus.update,
      ),
    );
    return linesAffected;
  }

  Future<int> upsertDashboardDefinition(DashboardDefinition dashboard) async {
    final linesAffected = await _journalDb.upsertDashboardDefinition(dashboard);
    await outboxService.enqueueMessage(
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
}
