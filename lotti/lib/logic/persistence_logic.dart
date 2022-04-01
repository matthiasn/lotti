import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/location.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:uuid/uuid.dart';

class PersistenceLogic {
  final JournalDb _journalDb = getIt<JournalDb>();
  final VectorClockService _vectorClockService = getIt<VectorClockService>();
  final InsightsDb _insightsDb = getIt<InsightsDb>();
  final OutboxService _outboxService = getIt<OutboxService>();

  final uuid = const Uuid();
  DeviceLocation? location;

  PersistenceLogic() {
    init();
  }

  Future<void> init() async {
    if (!Platform.isLinux && !Platform.isWindows) {
      location = DeviceLocation();
    }
  }

  Future<bool> createQuantitativeEntry(QuantitativeData data) async {
    final transaction =
        _insightsDb.startTransaction('createQuantitativeEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      DateTime dateFrom = data.dateFrom;
      DateTime dateTo = data.dateTo;

      JournalEntity journalEntity = JournalEntity.quantitative(
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
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createWorkoutEntry(WorkoutData data) async {
    final transaction =
        _insightsDb.startTransaction('createQuantitativeEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();

      DateTime dateFrom = data.dateFrom;
      DateTime dateTo = data.dateTo;

      JournalEntity journalEntity = JournalEntity.workout(
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
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createSurveyEntry({
    required SurveyData data,
    String? linkedId,
  }) async {
    final transaction =
        _insightsDb.startTransaction('createSurveyEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      Geolocation? geolocation =
          await location?.getCurrentGeoLocation().timeout(
                const Duration(seconds: 5),
                onTimeout: () => null, // TODO: report timeout in Insights
              );

      JournalEntity journalEntity = JournalEntity.survey(
        data: data,
        geolocation: geolocation,
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
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createMeasurementEntry({
    required MeasurementData data,
    String? linkedId,
  }) async {
    final transaction =
        _insightsDb.startTransaction('createMeasurementEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      Geolocation? geolocation;

      if (data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
          data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1) {
        geolocation = await location?.getCurrentGeoLocation().timeout(
              const Duration(seconds: 5),
              onTimeout: () => null, // TODO: report timeout in Insights
            );
      }

      JournalEntity journalEntity = JournalEntity.measurement(
        data: data,
        geolocation: geolocation,
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
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
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
        _insightsDb.startTransaction('createMeasurementEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      Geolocation? geolocation;

      if (data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
          data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1) {
        geolocation = await location?.getCurrentGeoLocation().timeout(
              const Duration(seconds: 5),
              onTimeout: () => null, // TODO: report timeout in Insights
            );
      }

      JournalEntity journalEntity = JournalEntity.task(
        data: data,
        geolocation: geolocation,
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
        ),
      );

      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linkedId,
      );
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createImageEntry(
    ImageData imageData, {
    JournalEntity? linked,
  }) async {
    final transaction =
        _insightsDb.startTransaction('createImageEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(imageData));

      DateTime dateFrom = imageData.capturedAt;
      DateTime dateTo = imageData.capturedAt;
      JournalEntity journalEntity = JournalEntity.journalImage(
        data: imageData,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
          flag: EntryFlag.import,
        ),
        // TODO: should this be geolocation at capture or insertion?
        geolocation: imageData.geolocation,
      );
      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linked?.meta.id,
      );
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createAudioEntry(
    AudioNote audioNote, {
    String? linkedId,
  }) async {
    final transaction =
        _insightsDb.startTransaction('createImageEntry()', 'task');
    try {
      AudioData audioData = AudioData(
        audioDirectory: audioNote.audioDirectory,
        duration: audioNote.duration,
        audioFile: audioNote.audioFile,
        dateTo: audioNote.createdAt.add(audioNote.duration),
        dateFrom: audioNote.createdAt,
      );

      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(audioData));

      DateTime dateFrom = audioData.dateFrom;
      DateTime dateTo = audioData.dateTo;
      JournalEntity journalEntity = JournalEntity.journalAudio(
        data: audioData,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
          flag: EntryFlag.import,
        ),
        // TODO: should this be geolocation at capture or insertion?
        geolocation: audioNote.geolocation,
      );
      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linkedId,
      );
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createTextEntry(
    EntryText entryText, {
    required DateTime started,
    String? linkedId,
  }) async {
    final transaction =
        _insightsDb.startTransaction('createTextEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();
      String id = uuid.v1();
      Geolocation? geolocation =
          await location?.getCurrentGeoLocation().timeout(
                const Duration(seconds: 5),
                onTimeout: () => null,
              );

      JournalEntity journalEntity = JournalEntity.journalEntry(
        entryText: entryText,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: started,
          dateTo: now,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        geolocation: geolocation,
      );
      await createDbEntity(
        journalEntity,
        enqueueSync: true,
        linkedId: linkedId,
      );
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createLink({
    required String fromId,
    required String toId,
  }) async {
    DateTime now = DateTime.now();
    EntryLink link = EntryLink.basic(
      id: uuid.v1(),
      fromId: fromId,
      toId: toId,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
    );

    int res = await _journalDb.upsertEntryLink(link);
    await _outboxService.enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      ),
    );
    return (res != 0);
  }

  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool enqueueSync = false,
    String? linkedId,
  }) async {
    final TagsService tagsService = getIt<TagsService>();

    JournalEntity? linked;

    if (linkedId != null) {
      linked = await _journalDb.journalEntityById(linkedId);
    }

    final transaction =
        _insightsDb.startTransaction('createDbEntity()', 'task');
    try {
      List<String>? linkedTagIds = linked?.meta.tagIds;
      List<String> storyTags = tagsService.getFilteredStoryTagIds(linkedTagIds);

      JournalEntity withTags = journalEntity.copyWith(
        meta: journalEntity.meta.copyWith(
          tagIds: <String>{
            ...?journalEntity.meta.tagIds,
            ...storyTags,
          }.toList(),
        ),
      );

      int? res = await _journalDb.addJournalEntity(withTags);
      bool saved = (res != 0);
      await saveJournalEntityJson(withTags);
      await _journalDb.addTagged(withTags);

      if (saved && enqueueSync) {
        await _outboxService.enqueueMessage(SyncMessage.journalEntity(
          journalEntity: withTags,
          status: SyncEntryStatus.initial,
        ));
      }

      if (linked != null) {
        createLink(
          fromId: linked.meta.id,
          toId: withTags.meta.id,
        );
      }

      await transaction.finish();

      getIt<NotificationService>().updateBadge();

      return saved;
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
      debugPrint('Exception $exception');
    }
    return null;
  }

  Future<bool> updateJournalEntityText(
    String journalEntityId,
    EntryText entryText,
  ) async {
    final transaction =
        _insightsDb.startTransaction('updateJournalEntity()', 'task');
    try {
      DateTime now = DateTime.now();
      JournalEntity? journalEntity =
          await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      VectorClock vc = await _vectorClockService.getNextVectorClock(
          previous: journalEntity.meta.vectorClock);

      Metadata oldMeta = journalEntity.meta;
      Metadata newMeta = oldMeta.copyWith(
        updatedAt: now,
        vectorClock: vc,
      );

      if (journalEntity is JournalEntry) {
        JournalEntry newJournalEntry = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newJournalEntry, enqueueSync: true);
      }

      if (journalEntity is JournalAudio) {
        JournalAudio newJournalAudio = journalEntity.copyWith(
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
        JournalImage newJournalImage = journalEntity.copyWith(
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
        MeasurementEntry newEntry = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newEntry, enqueueSync: true);
      }
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
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
        _insightsDb.startTransaction('updateJournalEntity()', 'task');
    try {
      DateTime now = DateTime.now();
      JournalEntity? journalEntity =
          await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      journalEntity.maybeMap(
        task: (Task task) async {
          VectorClock vc = await _vectorClockService.getNextVectorClock(
              previous: journalEntity.meta.vectorClock);

          Metadata oldMeta = journalEntity.meta;
          Metadata newMeta = oldMeta.copyWith(
            updatedAt: now,
            vectorClock: vc,
          );

          Task newJournalEntry = task.copyWith(
            meta: newMeta,
            entryText: entryText,
            data: taskData,
          );

          await updateDbEntity(newJournalEntry, enqueueSync: true);
        },
        orElse: () => _insightsDb.captureException('not a task'),
      );
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> updateJournalEntityDate(
    JournalEntity journalEntity, {
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final transaction =
        _insightsDb.startTransaction('updateJournalEntityDate()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock(
          previous: journalEntity.meta.vectorClock);

      Metadata newMeta = journalEntity.meta.copyWith(
        updatedAt: now,
        vectorClock: vc,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      JournalEntity newJournalEntity = journalEntity.copyWith(
        meta: newMeta,
      );

      await updateDbEntity(newJournalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> updateJournalEntity(
    JournalEntity journalEntity,
    Metadata metadata,
  ) async {
    final transaction =
        _insightsDb.startTransaction('updateJournalEntity()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock(
          previous: metadata.vectorClock);

      Metadata newMeta = metadata.copyWith(
        updatedAt: now,
        vectorClock: vc,
      );

      JournalEntity newJournalEntity = journalEntity.copyWith(
        meta: newMeta,
      );

      await updateDbEntity(newJournalEntity, enqueueSync: true);
      await _journalDb.addTagged(newJournalEntity);
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool?> addTags({
    required String journalEntityId,
    required List<String> addedTagIds,
  }) async {
    final transaction = _insightsDb.startTransaction('addTag()', 'task');
    try {
      JournalEntity? journalEntity =
          await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      Metadata meta = addTagsToMeta(journalEntity.meta, addedTagIds);

      VectorClock vc = await _vectorClockService.getNextVectorClock(
        previous: meta.vectorClock,
      );

      JournalEntity newJournalEntity = journalEntity.copyWith(
        meta: meta.copyWith(
          updatedAt: DateTime.now(),
          vectorClock: vc,
        ),
      );

      return await updateDbEntity(newJournalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool?> removeTag({
    required String journalEntityId,
    required String tagId,
  }) async {
    final transaction = _insightsDb.startTransaction('addTag()', 'task');
    try {
      JournalEntity? journalEntity =
          await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      Metadata meta = removeTagFromMeta(journalEntity.meta, tagId);

      VectorClock vc = await _vectorClockService.getNextVectorClock(
          previous: meta.vectorClock);

      JournalEntity newJournalEntity = journalEntity.copyWith(
        meta: meta.copyWith(
          updatedAt: DateTime.now(),
          vectorClock: vc,
        ),
      );

      return await updateDbEntity(newJournalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> deleteJournalEntity(
    JournalEntity journalEntity,
  ) async {
    final transaction =
        _insightsDb.startTransaction('updateJournalEntity()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock(
          previous: journalEntity.meta.vectorClock);

      Metadata newMeta = journalEntity.meta.copyWith(
        updatedAt: now,
        vectorClock: vc,
        deletedAt: now,
      );

      JournalEntity newEntity = journalEntity.copyWith(meta: newMeta);
      await updateDbEntity(newEntity, enqueueSync: true);

      getIt<NotificationService>().updateBadge();
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    bool enqueueSync = false,
  }) async {
    final transaction =
        _insightsDb.startTransaction('updateDbEntity()', 'task');
    try {
      int res = await _journalDb.updateJournalEntity(journalEntity);
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

      getIt<NotificationService>().updateBadge();

      return true;
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
      debugPrint('Exception $exception');
    }
    return null;
  }

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) async {
    int linesAffected =
        await _journalDb.upsertEntityDefinition(entityDefinition);
    await _outboxService.enqueueMessage(SyncMessage.entityDefinition(
      entityDefinition: entityDefinition,
      status: SyncEntryStatus.update,
    ));
    return linesAffected;
  }

  Future<int> upsertTagEntity(TagEntity tagEntity) async {
    int linesAffected = await _journalDb.upsertTagEntity(tagEntity);
    await _outboxService.enqueueMessage(SyncMessage.tagEntity(
      tagEntity: tagEntity,
      status: SyncEntryStatus.update,
    ));
    return linesAffected;
  }

  Future<int> upsertDashboardDefinition(DashboardDefinition dashboard) async {
    int linesAffected = await _journalDb.upsertDashboardDefinition(dashboard);
    await _outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: dashboard,
        status: SyncEntryStatus.update,
      ),
    );

    if (dashboard.reviewAt != null) {
      getIt<NotificationService>().scheduleNotification(
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
    DateTime now = DateTime.now();
    String id = uuid.v1();
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
  List<String> existingTagIds = meta.tagIds ?? [];
  List<String> tagIds = [...existingTagIds];

  for (String tagId in addedTagIds) {
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
    tagIds: meta.tagIds?.where((String id) => (id != tagId)).toList(),
  );
}
