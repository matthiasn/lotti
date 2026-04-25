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
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/entry_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:uuid/uuid.dart';

class PersistenceLogic {
  JournalDb get _journalDb => getIt<JournalDb>();
  MetadataService get _metadataService => getIt<MetadataService>();
  VectorClockService get _vectorClockService => getIt<VectorClockService>();
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
    List<String>? labelIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
  }) => _metadataService.createMetadata(
    dateFrom: dateFrom,
    dateTo: dateTo,
    uuidV5Input: uuidV5Input,
    private: private,
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
  }) => _metadataService.updateMetadata(
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
    // Invariant: once the link upsert hits disk, the VC counter is claimed on
    // disk and MUST commit — otherwise a subsequent reservation could hand
    // out the same counter to a different entity, producing a cross-entity
    // collision. Only a pre-write exception (DB throws before we reach
    // [upsertEntryLink]) releases the reservation.
    return _vectorClockService.withVcScope<bool>(() async {
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

      try {
        await outboxService.enqueueMessage(
          SyncMessage.entryLink(
            entryLink: link,
            status: SyncEntryStatus.initial,
          ),
        );
      } catch (exception, stackTrace) {
        // Swallow to preserve the commit-on-write invariant: the VC is
        // already baked into the persisted link row and must not be
        // rewound just because the outbox write failed transiently.
        getIt<DomainLogger>().error(
          LogDomains.sync,
          'outbox enqueue failed after createLink; VC already committed',
          error: exception,
          stackTrace: stackTrace,
          subDomain: 'createLink.enqueue',
        );
      }
      return res != 0;
    });
  }

  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    String? linkedId,
  }) async {
    try {
      return await _vectorClockService.withVcScope<bool?>(
        () async {
          JournalEntity? linked;

          if (linkedId != null) {
            linked = await _journalDb.journalEntityById(linkedId);
          }

          final withContext = journalEntity.copyWith(
            meta: journalEntity.meta.copyWith(
              private: linked?.meta.private,
              categoryId: journalEntity.categoryId ?? linked?.categoryId,
            ),
          );

          final res = await _journalDb.updateJournalEntity(
            withContext,
            overwrite: false,
          );

          final saved = res.applied;

          if (saved && enqueueSync) {
            try {
              await outboxService.enqueueMessage(
                SyncMessage.journalEntity(
                  id: journalEntity.id,
                  vectorClock: withContext.meta.vectorClock,
                  jsonPath: relativeEntityPath(journalEntity),
                  status: SyncEntryStatus.initial,
                  originatingHostId: await _vectorClockService.getHost(),
                ),
              );
            } catch (exception, stackTrace) {
              // Local write already committed the counter to disk — do not
              // let an outbox failure trigger a release that would re-hand
              // the counter to a different entity. Log and move on; the
              // receiver will observe a transient gap that backfill fills.
              getIt<DomainLogger>().error(
                LogDomains.sync,
                'outbox enqueue failed after createDbEntity; '
                'VC already committed',
                error: exception,
                stackTrace: stackTrace,
                subDomain: 'createDbEntity.enqueue',
              );
            }
          }

          if (linked != null) {
            await createLink(
              fromId: linked.meta.id,
              toId: withContext.meta.id,
            );
          }

          final affectedIds = withContext.affectedIds;

          if (linkedId != null) {
            affectedIds.add(linkedId);
          }

          _updateNotifications.notify({
            ...affectedIds,
            labelUsageNotification,
          });

          await getIt<NotificationService>().updateBadge();

          if (shouldAddGeolocation) {
            addGeolocation(journalEntity.id);
          }

          return saved;
        },
        // Commit iff the LOCAL WRITE succeeded. A rejected write
        // (applied=false) never touched disk, so releasing the reserved
        // counter is safe and lets the next reservation reuse the slot.
        // enqueueSync intentionally does NOT gate the commit — if the DB
        // accepted the row, the VC is baked into persisted state and must
        // advance regardless of whether sync was wired.
        commitWhen: (saved) => saved ?? false,
      );
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
      // Mirror updateJournalEntity's contract: a caught exception means the
      // write did not commit, so callers must see a failure return rather
      // than a silently-true result with a logged exception.
      return false;
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
          final priorityChanged = task.data.priority != taskData.priority;
          await updateDbEntity(
            task.copyWith(
              meta: await updateMetadata(journalEntity.meta),
              entryText: entryText ?? task.entryText,
              data: taskData,
            ),
            beforeNotify: priorityChanged
                ? () => _journalDb.updateTaskPriorityColumn(
                    id: journalEntityId,
                    priority: taskData.priority.short,
                    rank: taskData.priority.rank,
                  )
                : null,
          );
        },
        orElse: () async {
          _loggingService.captureException(
            'not a task',
            domain: 'persistence_logic',
            subDomain: 'updateTask',
          );
        },
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
        orElse: () async {
          _loggingService.captureException(
            'not an event',
            domain: 'persistence_logic',
            subDomain: 'updateEvent',
          );
        },
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
      // Wrap the whole update chain in a VC scope so the counter reserved
      // inside [updateMetadata] rolls back whenever the downstream write is
      // rejected (applied=false) or throws. Nested [withVcScope] calls from
      // [updateDbEntity] participate in this outer scope.
      return await _vectorClockService.withVcScope<bool>(
        () async {
          // Preserve existing labels to avoid races with concurrent label
          // assignments. Label changes should go through LabelsRepository;
          // general updates should not override meta.labelIds based on a
          // stale in-memory entity.
          JournalEntity? current;
          try {
            current = await _journalDb.journalEntityById(journalEntity.id);
          } catch (_) {
            // If we can't fetch current (e.g., in tests without a stub),
            // proceed without preservation.
            current = null;
          }
          final updatedMeta = await updateMetadata(metadata);
          final preservedLabelIds = current?.meta.labelIds;
          final entityWithUpdatedMeta = journalEntity.copyWith(
            meta: updatedMeta.copyWith(labelIds: preservedLabelIds),
          );
          Future<void> Function()? beforeNotify;
          if (entityWithUpdatedMeta is Task) {
            final task = entityWithUpdatedMeta;
            final priorityChanged =
                current is! Task || current.data.priority != task.data.priority;
            if (priorityChanged) {
              beforeNotify = () => _journalDb.updateTaskPriorityColumn(
                id: task.id,
                priority: task.data.priority.short,
                rank: task.data.priority.rank,
              );
            }
          }
          final applied =
              (await updateDbEntity(
                entityWithUpdatedMeta,
                beforeNotify: beforeNotify,
              )) ??
              false;
          if (applied) {
            await _journalDb.addLabeled(entityWithUpdatedMeta);
          }
          return applied;
        },
        commitWhen: (applied) => applied,
      );
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
    Future<void> Function()? beforeNotify,
  }) async {
    try {
      return await _vectorClockService.withVcScope<bool?>(
        () async {
          final updateResult = await _journalDb.updateJournalEntity(
            journalEntity,
            overrideComparison: overrideComparison,
          );
          final applied = updateResult.applied;

          if (applied && beforeNotify != null) {
            try {
              await beforeNotify();
            } catch (exception, stackTrace) {
              _loggingService.captureException(
                exception,
                domain: 'persistence_logic',
                subDomain: 'updateDbEntity.beforeNotify',
                stackTrace: stackTrace,
              );
            }
          }

          // Include parent linked entry IDs so that agents subscribed to a
          // parent (e.g. a task) are notified when a child entry is edited.
          final parentIds = await _journalDb
              .parentLinkedEntityIds(journalEntity.id)
              .get();

          // When running inside an agent execution zone, route the
          // notification through notifyUiOnly so the wake orchestrator
          // does not re-trigger the agent on its own writes.
          final ids = {
            ...journalEntity.affectedIds,
            ?linkedId,
            ...parentIds,
            labelUsageNotification,
          };
          if (isAgentExecution) {
            _updateNotifications.notifyUiOnly(ids);
          } else {
            _updateNotifications.notify(ids);
          }

          await getIt<Fts5Db>().insertText(
            journalEntity,
            removePrevious: true,
          );

          if (enqueueSync && applied) {
            try {
              await outboxService.enqueueMessage(
                SyncMessage.journalEntity(
                  id: journalEntity.id,
                  vectorClock: journalEntity.meta.vectorClock,
                  jsonPath: relativeEntityPath(journalEntity),
                  status: SyncEntryStatus.update,
                  originatingHostId: await _vectorClockService.getHost(),
                ),
              );
            } catch (exception, stackTrace) {
              // See [createDbEntity]: once the DB accepted the row, the VC
              // is claimed on disk. An outbox failure here must NOT release
              // the counter (that would let a subsequent reservation reuse
              // the same counter for a different entity).
              getIt<DomainLogger>().error(
                LogDomains.sync,
                'outbox enqueue failed after updateDbEntity; '
                'VC already committed',
                error: exception,
                stackTrace: stackTrace,
                subDomain: 'updateDbEntity.enqueue',
              );
            }
          }

          await getIt<NotificationService>().updateBadge();

          return applied;
        },
        // Commit iff the local write actually landed. applied=false is the
        // VC comparison rejecting a stale/concurrent update (e.g. an
        // incoming sync already advanced this entity) — the row on disk
        // never took the reserved counter, so a rewind is safe. When
        // applied=true the VC is baked into the persisted row and MUST
        // commit, even if enqueueSync=false or the outbox enqueue above
        // threw.
        commitWhen: (applied) => applied ?? false,
      );
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
    final linesAffected = await _journalDb.upsertEntityDefinition(
      entityDefinition,
    );
    final typeNotification = switch (entityDefinition) {
      CategoryDefinition() => categoriesNotification,
      HabitDefinition() => habitsNotification,
      DashboardDefinition() => dashboardsNotification,
      MeasurableDataType() => measurablesNotification,
      LabelDefinition() => labelsNotification,
    };
    _updateNotifications.notify({entityDefinition.id, typeNotification});
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
    _updateNotifications.notify({dashboard.id, dashboardsNotification});
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

  Future<void> setConfigFlag(ConfigFlag configFlag) async {
    await _journalDb.upsertConfigFlag(configFlag);
    if (configFlag.name == 'private') {
      _updateNotifications.notify({privateToggleNotification});
    }
  }

  Future<int> deleteDashboardDefinition(DashboardDefinition dashboard) async {
    final linesAffected = await upsertDashboardDefinition(
      dashboard.copyWith(
        deletedAt: DateTime.now(),
      ),
    );

    await getIt<NotificationService>().cancelNotification(
      dashboard.id.hashCode,
    );

    return linesAffected;
  }
}
