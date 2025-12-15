import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/entry_utils.dart';
import 'package:lotti/utils/file_utils.dart';
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
  LoggingService get _loggingService => getIt<LoggingService>();
  final OutboxService outboxService = getIt<OutboxService>();
  final uuid = const Uuid();
  DeviceLocation? location;

  /// Tracks entity IDs currently having geolocation added to prevent
  /// concurrent additions which could cause race conditions.
  final Set<String> _pendingGeolocationAdds = {};

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
    List<String>? labelIds,
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
      labelIds: labelIds,
      categoryId: categoryId,
      starred: starred,
      timezone: await getLocalTimezone(),
      utcOffset: now.timeZoneOffset.inMinutes,
      flag: flag,
    );
  }

  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
    List<String>? labelIds,
    bool clearLabelIds = false,
  }) async =>
      metadata.copyWith(
        updatedAt: DateTime.now(),
        vectorClock: await _vectorClockService.getNextVectorClock(
          previous: metadata.vectorClock,
        ),
        dateFrom: dateFrom ?? metadata.dateFrom,
        dateTo: dateTo ?? metadata.dateTo,
        categoryId: clearCategoryId ? null : categoryId ?? metadata.categoryId,
        deletedAt: deletedAt ?? metadata.deletedAt,
        labelIds: clearLabelIds ? null : labelIds ?? metadata.labelIds,
      );

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
      await createDbEntity(
        journalEntity,
        shouldAddGeolocation: false,
        addTags: false,
      );
      return journalEntity;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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

      await createDbEntity(
        workout,
        shouldAddGeolocation: false,
        addTags: false,
      );

      return workout;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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

      await createDbEntity(journalEntity, linkedId: linkedId);
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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

      final shouldAddGeolocation =
          data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
              data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1;

      await createDbEntity(
        measurementEntry,
        linkedId: linkedId,
        shouldAddGeolocation: shouldAddGeolocation,
      );

      _updateNotifications.notify({measurementEntry.data.dataTypeId});

      return measurementEntry;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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

      final shouldAddGeolocation =
          data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
              data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1;

      await createDbEntity(
        habitCompletionEntry,
        linkedId: linkedId,
        shouldAddGeolocation: shouldAddGeolocation,
      );

      if (habitDefinition != null) {
        await getIt<NotificationService>().scheduleHabitNotification(
          habitDefinition,
          daysToAdd: 1,
        );
      }

      return habitCompletionEntry;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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
          starred: false,
        ),
      );

      await createDbEntity(task, linkedId: linkedId);

      return task;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createTaskEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<AiResponseEntry?> createAiResponseEntry({
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
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createAiResponseEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<JournalEvent?> createEventEntry({
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
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createEventEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
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
      hidden: false,
      vectorClock: await _vectorClockService.getNextVectorClock(),
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

  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    bool addTags = true,
    String? linkedId,
  }) async {
    try {
      final tagsService = getIt<TagsService>();
      JournalEntity? linked;

      if (linkedId != null) {
        linked = await _journalDb.journalEntityById(linkedId);
      }

      final linkedTagIds = linked?.meta.tagIds;
      final storyTags = tagsService.getFilteredStoryTagIds(linkedTagIds);

      final withTags = journalEntity.copyWith(
        meta: journalEntity.meta.copyWith(
          private: linked?.meta.private,
          categoryId: journalEntity.categoryId ?? linked?.categoryId,
          tagIds: <String>{
            ...?journalEntity.meta.tagIds,
            ...storyTags,
          }.toList(),
        ),
      );

      final res = await _journalDb.updateJournalEntity(
        withTags,
        overwrite: false,
      );

      final saved = res.applied;

      if (addTags && saved) {
        await _journalDb.addTagged(withTags);
      }

      if (saved && enqueueSync) {
        await outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            id: journalEntity.id,
            vectorClock: withTags.meta.vectorClock,
            jsonPath: relativeEntityPath(journalEntity),
            status: SyncEntryStatus.initial,
            originatingHostId: await _vectorClockService.getHost(),
          ),
        );
      }

      if (linked != null) {
        await createLink(
          fromId: linked.meta.id,
          toId: withTags.meta.id,
        );
      }

      final affectedIds = withTags.affectedIds;

      if (linkedId != null) {
        affectedIds.add(linkedId);
      }

      _updateNotifications.notify(affectedIds);

      await getIt<NotificationService>().updateBadge();

      if (shouldAddGeolocation) {
        addGeolocation(journalEntity.id);
      }

      return saved;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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
      _loggingService.captureException(
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
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await journalEntity.maybeMap(
        task: (Task task) async {
          await updateDbEntity(
            task.copyWith(
              meta: await updateMetadata(journalEntity.meta),
              entryText: entryText ?? task.entryText,
              data: taskData,
            ),
          );

          // Ensure denormalized priority columns are updated for reliable UI reads
          try {
            await _journalDb.updateTaskPriorityColumn(
              id: journalEntityId,
              priority: taskData.priority.short,
              rank: taskData.priority.rank,
            );
          } catch (_) {
            // ignore best-effort denormalized update errors
          }
        },
        orElse: () async => _loggingService.captureException(
          'not a task',
          domain: 'persistence_logic',
          subDomain: 'updateTask',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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
        orElse: () async => _loggingService.captureException(
          'not an event',
          domain: 'persistence_logic',
          subDomain: 'updateEvent',
        ),
      );
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateEvent',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  FutureOr<Geolocation?> addGeolocationAsync(String journalEntityId) async {
    // Prevent concurrent geolocation additions for the same entity.
    // This avoids race conditions where multiple async calls could
    // both see geolocation == null and then both try to update.
    if (_pendingGeolocationAdds.contains(journalEntityId)) {
      return null;
    }
    _pendingGeolocationAdds.add(journalEntityId);

    try {
      Geolocation? geolocation;
      try {
        geolocation = await location?.getCurrentGeoLocation();
      } catch (e) {
        _loggingService.captureException(
          e,
          domain: 'persistence_logic',
          subDomain: 'addGeolocation_getCurrentGeoLocation',
        );
      }

      if (geolocation == null) {
        return null;
      }

      final journalEntity = await _journalDb.journalEntityById(journalEntityId);
      // Only add geolocation if the entry doesn't already have one.
      // Geolocation should be set once at creation and never overwritten.
      if (journalEntity != null && journalEntity.geolocation == null) {
        await updateDbEntity(
          journalEntity.copyWith(
            meta: await updateMetadata(journalEntity.meta),
            geolocation: geolocation,
          ),
        );
        return geolocation;
      }

      return journalEntity?.geolocation;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addGeolocation',
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      _pendingGeolocationAdds.remove(journalEntityId);
    }
  }

  void addGeolocation(String journalEntityId) {
    addGeolocationAsync(journalEntityId);
  }

  Future<bool> updateJournalEntity(
    JournalEntity journalEntity,
    Metadata metadata,
  ) async {
    try {
      // Preserve existing labels to avoid races with concurrent label assignments.
      // Label changes should go through LabelsRepository; general updates should
      // not override meta.labelIds based on a stale in-memory entity.
      JournalEntity? current;
      try {
        current = await _journalDb.journalEntityById(journalEntity.id);
      } catch (_) {
        // If we can't fetch current (e.g., in tests without a stub), proceed without preservation.
        current = null;
      }
      final updatedMeta = await updateMetadata(metadata);
      final preservedLabelIds = current?.meta.labelIds;
      final entityWithUpdatedMeta = journalEntity.copyWith(
        meta: updatedMeta.copyWith(labelIds: preservedLabelIds),
      );
      final applied = (await updateDbEntity(entityWithUpdatedMeta)) ?? false;
      if (applied) {
        await _journalDb.addTagged(entityWithUpdatedMeta);
        await _journalDb.addLabeled(entityWithUpdatedMeta);
      }
      return applied;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateJournalEntity',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    bool overrideComparison = false,
  }) async {
    try {
      final updateResult = await _journalDb.updateJournalEntity(
        journalEntity,
        overrideComparison: overrideComparison,
      );
      final applied = updateResult.applied;
      _updateNotifications.notify({
        ...journalEntity.affectedIds,
        if (linkedId != null) linkedId,
      });

      await getIt<Fts5Db>().insertText(
        journalEntity,
        removePrevious: true,
      );

      if (enqueueSync && applied) {
        await outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            id: journalEntity.id,
            vectorClock: journalEntity.meta.vectorClock,
            jsonPath: relativeEntityPath(journalEntity),
            status: SyncEntryStatus.update,
            originatingHostId: await _vectorClockService.getHost(),
          ),
        );
      }

      await getIt<NotificationService>().updateBadge();

      return applied;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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
