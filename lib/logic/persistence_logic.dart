import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/location.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:uuid/uuid.dart';

class PersistenceLogic {
  PersistenceLogic() {
    init();
  }

  final JournalDb _journalDb = getIt<JournalDb>();
  final VectorClockService _vectorClockService = getIt<VectorClockService>();
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final OutboxService _outboxService = getIt<OutboxService>();
  final uuid = const Uuid();
  DeviceLocation? location;

  Future<void> init() async {
    if (!Platform.isWindows) {
      location = DeviceLocation();
    }
  }

  Future<bool> createQuantitativeEntry(QuantitativeData data) async {
    final transaction =
        _loggingDb.startTransaction('createQuantitativeEntry()', 'task');
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      final dateFrom = data.dateFrom;
      final dateTo = data.dateTo;

      final journalEntity = JournalEntity.quantitative(
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
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createQuantitativeEntry',
        stackTrace: stackTrace,
      );
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createWorkoutEntry(WorkoutData data) async {
    final transaction =
        _loggingDb.startTransaction('createQuantitativeEntry()', 'task');
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();
      final dateFrom = data.dateFrom;
      final dateTo = data.dateTo;

      final journalEntity = JournalEntity.workout(
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
      await createDbEntity(journalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createWorkoutEntry',
        stackTrace: stackTrace,
      );
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createSurveyEntry({
    required SurveyData data,
    String? linkedId,
  }) async {
    final transaction =
        _loggingDb.startTransaction('createSurveyEntry()', 'task');
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

    await transaction.finish();
    return true;
  }

  Future<bool> createMeasurementEntry({
    required MeasurementData data,
    String? linkedId,
  }) async {
    final transaction =
        _loggingDb.startTransaction('createMeasurementEntry()', 'task');
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      final journalEntity = JournalEntity.measurement(
        data: data,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
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

      if (data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
          data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1) {
        addGeolocation(journalEntity.meta.id);
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createMeasurementEntry',
        stackTrace: stackTrace,
      );
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createTaskEntry({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
  }) async {
    final transaction =
        _loggingDb.startTransaction('createMeasurementEntry()', 'task');
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      final journalEntity = JournalEntity.task(
        data: data,
        entryText: entryText,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          id: id,
          vectorClock: vc,
          timezone: await getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
          starred: true,
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
        subDomain: 'createTaskEntry',
        stackTrace: stackTrace,
      );
    }

    await transaction.finish();
    return true;
  }

  Future<JournalEntity?> createImageEntry(
    ImageData imageData, {
    String? linkedId,
  }) async {
    final transaction =
        _loggingDb.startTransaction('createImageEntry()', 'task');
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
        // ignore: flutter_style_todos
        // TODO: should this be geolocation at capture or insertion?
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

    await transaction.finish();
    return null;
  }

  Future<bool> createAudioEntry(
    AudioNote audioNote, {
    String? linkedId,
  }) async {
    final transaction =
        _loggingDb.startTransaction('createImageEntry()', 'task');
    try {
      final audioData = AudioData(
        audioDirectory: audioNote.audioDirectory,
        duration: audioNote.duration,
        audioFile: audioNote.audioFile,
        dateTo: audioNote.createdAt.add(audioNote.duration),
        dateFrom: audioNote.createdAt,
      );

      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      final id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(audioData));

      final dateFrom = audioData.dateFrom;
      final dateTo = audioData.dateTo;
      final journalEntity = JournalEntity.journalAudio(
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
        geolocation: audioNote.geolocation,
      );
      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linkedId,
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createAudioEntry',
        stackTrace: stackTrace,
      );
    }

    await transaction.finish();
    return true;
  }

  Future<JournalEntity?> createTextEntry(
    EntryText entryText, {
    required DateTime started,
    String? linkedId,
  }) async {
    final transaction =
        _loggingDb.startTransaction('createTextEntry()', 'task');
    try {
      final now = DateTime.now();
      final vc = await _vectorClockService.getNextVectorClock();
      final id = uuid.v1();

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
      await transaction.finish();
      return journalEntity;
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createTextEntry',
        stackTrace: stackTrace,
      );
      await transaction.error();
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
    await _outboxService.enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      ),
    );
    return res != 0;
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

    final transaction = _loggingDb.startTransaction('createDbEntity()', 'task');
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

      final res = await _journalDb.addJournalEntity(withTags);
      final saved = res != 0;
      await saveJournalEntityJson(withTags);
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

      await transaction.finish();

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
  ) async {
    final transaction =
        _loggingDb.startTransaction('updateJournalEntity()', 'task');
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
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateJournalEntityText',
        stackTrace: stackTrace,
      );
    }

    await transaction.finish();
    return true;
  }

  Future<bool> updateTask({
    required String journalEntityId,
    required EntryText entryText,
    required TaskData taskData,
  }) async {
    final transaction =
        _loggingDb.startTransaction('updateJournalEntity()', 'task');
    try {
      final now = DateTime.now();
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      journalEntity.maybeMap(
        task: (Task task) async {
          final vc = await _vectorClockService.getNextVectorClock(
            previous: journalEntity.meta.vectorClock,
          );

          final oldMeta = journalEntity.meta;
          final newMeta = oldMeta.copyWith(
            updatedAt: now,
            vectorClock: vc,
          );

          final newJournalEntry = task.copyWith(
            meta: newMeta,
            entryText: entryText,
            data: taskData,
          );

          await updateDbEntity(newJournalEntry, enqueueSync: true);
        },
        orElse: () => _loggingDb.captureException(
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

    await transaction.finish();
    return true;
  }

  Future<void> addGeolocationAsync(String journalEntityId) async {
    final transaction =
        _loggingDb.startTransaction('createTextEntry()', 'task');
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
      await transaction.error();
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
    final transaction =
        _loggingDb.startTransaction('updateJournalEntityDate()', 'task');
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

    await transaction.finish();
    return true;
  }

  Future<bool> updateJournalEntity(
    JournalEntity journalEntity,
    Metadata metadata,
  ) async {
    final transaction =
        _loggingDb.startTransaction('updateJournalEntity()', 'task');
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

    await transaction.finish();
    return true;
  }

  Future<bool?> addTags({
    required String journalEntityId,
    required List<String> addedTagIds,
  }) async {
    final transaction = _loggingDb.startTransaction('addTag()', 'task');
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

    await transaction.finish();
    return true;
  }

  Future<bool?> removeTag({
    required String journalEntityId,
    required String tagId,
  }) async {
    final transaction = _loggingDb.startTransaction('addTag()', 'task');
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

    await transaction.finish();
    return true;
  }

  Future<bool> deleteJournalEntity(
    String journalEntityId,
  ) async {
    final transaction =
        _loggingDb.startTransaction('updateJournalEntity()', 'task');
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

    await transaction.finish();
    return true;
  }

  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    bool enqueueSync = false,
  }) async {
    final transaction = _loggingDb.startTransaction('updateDbEntity()', 'task');
    try {
      final res = await _journalDb.updateJournalEntity(journalEntity);
      debugPrint('updateDbEntity res $res');
      await saveJournalEntityJson(journalEntity);
      await _journalDb.addTagged(journalEntity);

      if (enqueueSync) {
        await _outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            journalEntity: journalEntity,
            status: SyncEntryStatus.update,
          ),
        );
      }
      await transaction.finish();

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

    if (dashboard.reviewAt != null) {
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
