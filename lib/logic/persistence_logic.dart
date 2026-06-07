import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
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
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/entry_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:uuid/uuid.dart';

part 'persistence_create.dart';
part 'persistence_definitions.dart';
part 'persistence_update.dart';

class PersistenceLogic {
  JournalDb get _journalDb => getIt<JournalDb>();
  MetadataService get _metadataService => getIt<MetadataService>();
  VectorClockService get _vectorClockService => getIt<VectorClockService>();
  GeolocationService get _geolocationService => getIt<GeolocationService>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  DomainLogger get _loggingService => getIt<DomainLogger>();
  SyncSequenceLogService? get _sequenceLogService =>
      getIt.isRegistered<SyncSequenceLogService>()
      ? getIt<SyncSequenceLogService>()
      : null;
  final OutboxService outboxService = getIt<OutboxService>();
  final uuid = const Uuid();

  Future<void> _recordJournalSequence(
    JournalEntity entity, {
    required String subDomain,
  }) async {
    final vectorClock = entity.meta.vectorClock;
    final service = _sequenceLogService;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntry(
        entryId: entity.meta.id,
        vectorClock: vectorClock,
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        exception,
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }

  Future<void> _recordEntryLinkSequence(
    EntryLink link, {
    required String subDomain,
  }) async {
    final vectorClock = link.vectorClock;
    final service = _sequenceLogService;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntryLink(
        linkId: link.id,
        vectorClock: vectorClock,
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        exception,
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }

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

  Future<QuantitativeEntry?> createQuantitativeEntry(QuantitativeData data) =>
      createQuantitativeEntryImpl(data);

  Future<WorkoutEntry?> createWorkoutEntry(WorkoutData data) =>
      createWorkoutEntryImpl(data);

  Future<bool> createSurveyEntry({
    required SurveyData data,
    String? linkedId,
  }) => createSurveyEntryImpl(data: data, linkedId: linkedId);

  Future<MeasurementEntry?> createMeasurementEntry({
    required MeasurementData data,
    required bool private,
    String? linkedId,
    String? comment,
  }) => createMeasurementEntryImpl(
    data: data,
    private: private,
    linkedId: linkedId,
    comment: comment,
  );

  Future<HabitCompletionEntry?> createHabitCompletionEntry({
    required HabitCompletionData data,
    required HabitDefinition? habitDefinition,
    String? linkedId,
    String? comment,
  }) => createHabitCompletionEntryImpl(
    data: data,
    habitDefinition: habitDefinition,
    linkedId: linkedId,
    comment: comment,
  );

  Future<Task?> createTaskEntry({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) => createTaskEntryImpl(
    data: data,
    entryText: entryText,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  Future<AiResponseEntry?> createAiResponseEntry({
    required AiResponseData data,
    DateTime? dateFrom,
    String? linkedId,
    String? categoryId,
  }) => createAiResponseEntryImpl(
    data: data,
    dateFrom: dateFrom,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  Future<JournalEvent?> createEventEntry({
    required EventData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) => createEventEntryImpl(
    data: data,
    entryText: entryText,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  Future<bool> createLink({
    required String fromId,
    required String toId,
  }) async {
    // Invariant: once the link upsert hits disk, the VC counter is claimed on
    // disk and MUST commit. If the upsert reports "no row changed", the
    // counter has no payload and must be burnt instead.
    return _vectorClockService.withVcScope<bool>(
      () async {
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
        if (res == 0) return false;
        await _recordEntryLinkSequence(
          link,
          subDomain: 'createLink.recordSent',
        );
        _updateNotifications.notify({
          link.fromId,
          link.toId,
          linkNotification,
        });

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
            LogDomain.sync,
            exception,
            message:
                'outbox enqueue failed after createLink; VC already committed',
            stackTrace: stackTrace,
            subDomain: 'createLink.enqueue',
          );
        }
        return true;
      },
      commitWhen: (created) => created,
    );
  }

  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    String? linkedId,
  }) async {
    try {
      JournalEntity? linked;
      Set<String>? affectedIds;

      final saved = await _vectorClockService.withVcScope<bool?>(
        () async {
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

          if (!saved) {
            await _vectorClockService.burnUnboundVectorClock(
              withContext.meta.vectorClock,
              reason: 'createDbEntity write rejected id=${withContext.id}',
            );
          }

          if (saved) {
            await _recordJournalSequence(
              withContext,
              subDomain: 'createDbEntity.recordSent',
            );
          }

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
                LogDomain.sync,
                exception,
                message:
                    'outbox enqueue failed after createDbEntity; '
                    'VC already committed',
                stackTrace: stackTrace,
                subDomain: 'createDbEntity.enqueue',
              );
            }
          }

          affectedIds = withContext.affectedIds;

          if (linkedId != null) {
            affectedIds!.add(linkedId);
          }

          return saved;
        },
        // Commit iff the local entity write succeeded. A rejected write never
        // bound the input VC to this payload; that counter is burnt explicitly
        // above and any scoped reservations are released by commitWhen=false.
        // enqueueSync intentionally does not gate the commit: if the DB
        // accepted the row, the VC is baked into persisted state.
        commitWhen: (saved) => saved ?? false,
      );

      // Keep link creation outside the entity VC scope. A link write claims a
      // separate counter and must be finalized by createLink's own scope even
      // when the entity write above was skipped.
      final linkedEntity = linked;
      if (linkedEntity != null) {
        await createLink(
          fromId: linkedEntity.meta.id,
          toId: journalEntity.meta.id,
        );
      }

      _updateNotifications.notify({
        ...?affectedIds,
        labelUsageNotification,
      });

      await getIt<NotificationService>().updateBadge();

      if (shouldAddGeolocation) {
        addGeolocation(journalEntity.id);
      }

      return saved;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createDbEntity',
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
  ) => updateJournalEntityTextImpl(journalEntityId, entryText, dateTo);

  Future<bool> updateJournalEntry({
    required String journalEntityId,
    EntryText? entryText,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => updateJournalEntryImpl(
    journalEntityId: journalEntityId,
    entryText: entryText,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );

  Future<bool> updateTask({
    required String journalEntityId,
    required TaskData taskData,
    String? categoryId,
    EntryText? entryText,
  }) => updateTaskImpl(
    journalEntityId: journalEntityId,
    taskData: taskData,
    categoryId: categoryId,
    entryText: entryText,
  );

  Future<bool> updateEvent({
    required String journalEntityId,
    required EventData data,
    EntryText? entryText,
  }) => updateEventImpl(
    journalEntityId: journalEntityId,
    data: data,
    entryText: entryText,
  );

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
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateJournalEntity',
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

          if (!applied) {
            // The incoming entity carries a VC counter that was reserved by
            // the caller (typically via [updateMetadata]) BEFORE entering
            // this scope, so the scope itself has nothing to release on
            // rejection. Burn it explicitly so the counter does not linger
            // as plain `reserved`, outside the startup recovery path.
            await _vectorClockService.burnUnboundVectorClock(
              journalEntity.meta.vectorClock,
              reason: 'updateDbEntity write rejected id=${journalEntity.id}',
            );
          }

          if (applied) {
            await _recordJournalSequence(
              journalEntity,
              subDomain: 'updateDbEntity.recordSent',
            );
          }

          if (applied && beforeNotify != null) {
            try {
              await beforeNotify();
            } catch (exception, stackTrace) {
              _loggingService.error(
                LogDomain.persistence,
                exception,
                stackTrace: stackTrace,
                subDomain: 'updateDbEntity.beforeNotify',
              );
            }
          }

          // Include parent linked entry IDs so that agents subscribed to a
          // parent (e.g. a task) are notified when a child entry is edited.
          // Parent IDs are wrapped with [propagatedNotification] so the
          // wake orchestrator can distinguish "the parent itself was
          // edited" (direct match → 120 s throttle) from "a child of the
          // parent was edited" (propagated match → defer to next 06:00).
          // UI providers continue to react to either form via the parent
          // ID matching helpers.
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
            for (final id in parentIds) propagatedNotification(id),
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
                LogDomain.sync,
                exception,
                message:
                    'outbox enqueue failed after updateDbEntity; '
                    'VC already committed',
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
      _loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateDbEntity',
      );
      DevLogger.error(
        name: 'PersistenceLogic',
        message: 'Exception: $exception',
      );
    }
    return null;
  }

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) =>
      upsertEntityDefinitionImpl(entityDefinition);

  Future<int> upsertDashboardDefinition(DashboardDefinition dashboard) =>
      upsertDashboardDefinitionImpl(dashboard);

  Future<void> setConfigFlag(ConfigFlag configFlag) =>
      setConfigFlagImpl(configFlag);

  Future<int> deleteDashboardDefinition(DashboardDefinition dashboard) =>
      deleteDashboardDefinitionImpl(dashboard);
}
