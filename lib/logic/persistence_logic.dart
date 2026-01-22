import 'dart:async';
import 'dart:convert';

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
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/utils/entry_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:uuid/uuid.dart';

class PersistenceLogic {
  JournalDb get _journalDb => getIt<JournalDb>();
  MetadataService get _metadataService => getIt<MetadataService>();
  GeolocationService get _geolocationService => getIt<GeolocationService>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  LoggingService get _loggingService => getIt<LoggingService>();
  final OutboxService outboxService = getIt<OutboxService>();
  final uuid = const Uuid();

  /// Creates a [Metadata] object with either a random UUID v1 ID or a
  /// deterministic UUID v5 ID.
  ///
  /// Delegates to [MetadataService.createMetadata].
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
  }) =>
      _metadataService.createMetadata(
        dateFrom: dateFrom,
        dateTo: dateTo,
        uuidV5Input: uuidV5Input,
        private: private,
        tagIds: tagIds,
        labelIds: labelIds,
        categoryId: categoryId,
        starred: starred,
        flag: flag,
      );

  /// Updates existing [Metadata] with a new vector clock and optional field changes.
  ///
  /// Delegates to [MetadataService.updateMetadata].
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
    List<String>? labelIds,
    bool clearLabelIds = false,
  }) =>
      _metadataService.updateMetadata(
        metadata,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
        clearCategoryId: clearCategoryId,
        deletedAt: deletedAt,
        labelIds: labelIds,
        clearLabelIds: clearLabelIds,
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
      vectorClock: await _metadataService.getNextVectorClock(),
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
            originatingHostId: await _metadataService.getHost(),
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
      DevLogger.error(
        name: 'PersistenceLogic',
        message: 'Exception: $exception',
      );
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

  /// Adds geolocation to a journal entry asynchronously.
  ///
  /// Delegates to [GeolocationService.addGeolocationAsync].
  FutureOr<Geolocation?> addGeolocationAsync(String journalEntityId) =>
      _geolocationService.addGeolocationAsync(journalEntityId, updateDbEntity);

  /// Fire-and-forget: add geolocation to entry.
  ///
  /// Delegates to [GeolocationService.addGeolocation].
  void addGeolocation(String journalEntityId) {
    _geolocationService.addGeolocation(journalEntityId, updateDbEntity);
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
            originatingHostId: await _metadataService.getHost(),
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
      DevLogger.error(
        name: 'PersistenceLogic',
        message: 'Exception: $exception',
      );
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
