part of 'persistence_logic.dart';

mixin _PersistenceEntries on _PersistenceLogicBase {
  @override
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
  @override
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
  @override
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

  @override
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
}
