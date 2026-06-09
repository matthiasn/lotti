part of 'persistence_logic.dart';

mixin _PersistenceUpdates on _PersistenceLogicBase {
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
  @override
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

  @override
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

  @override
  Future<int> upsertDashboardDefinition(DashboardDefinition dashboard) =>
      upsertDashboardDefinitionImpl(dashboard);

  Future<void> setConfigFlag(ConfigFlag configFlag) =>
      setConfigFlagImpl(configFlag);

  Future<int> deleteDashboardDefinition(DashboardDefinition dashboard) =>
      deleteDashboardDefinitionImpl(dashboard);
}
