part of 'get_it.dart';

/// Registers the complete Matrix sync stack for a real profile: client,
/// gateway, inbound queue pipeline, MatrixService, the Matrix-backed outbox,
/// onboarding sync, node-profile broadcasting, VC-burn handling, backfill and
/// media self-healing.
///
/// Guest profiles never call this — see [_registerInertSyncStack]. Returns
/// the Matrix user-id thunk consumed by the AI attribution identity
/// resolver.
Future<String? Function()> _registerMatrixSyncStack({
  required Directory documentsDirectory,
  required DomainLogger domainLogger,
  required UserActivityService userActivityService,
  required UserActivityGate userActivityGate,
  required JournalDb journalDb,
  required NotificationsDb notificationsDb,
  required SettingsDb settingsDb,
  required SyncDatabase syncDatabase,
  required VectorClockService vectorClockService,
  required SecureStorage secureStorage,
  required AiConfigRepository aiConfigRepository,
  required SavedTaskFiltersRepository savedTaskFiltersRepository,
  required SyncNodeProfileRepository syncNodeProfileRepository,
  required SyncSequenceLogService syncSequenceLogService,
  required NotificationScheduler notificationScheduler,
  required ConsumptionRepository consumptionRepository,
}) async {
  final client = await createMatrixClient(
    documentsDirectory: documentsDirectory,
  );

  final sentEventRegistry = SentEventRegistry();
  final matrixGateway = MatrixSdkGateway(
    client: client,
    sentEventRegistry: sentEventRegistry,
  );
  final matrixMessageSender = MatrixMessageSender(
    loggingService: domainLogger,
    journalDb: journalDb,
    documentsDirectory: documentsDirectory,
    sentEventRegistry: sentEventRegistry,
    vectorClockService: vectorClockService,
    domainLogger: domainLogger,
  );
  // Shared in-memory index of latest attachment events keyed by relativePath.
  // Verbose per-event logging is off in production; SDK pagination bursts
  // would otherwise produce thousands of `attachmentIndex.*` lines in a
  // single second. The wrapping `batch.summary` carries the aggregate.
  final attachmentIndex = AttachmentIndex(
    logging: domainLogger,
    verboseLogging: false,
  );

  // SyncEventProcessor is constructed first; its `backfillResponseHandler`
  // (a `late final`) is assigned below once BackfillResponseHandler exists.
  // The chain BackfillResponseHandler → OutboxService → MatrixService →
  // SyncEventProcessor prevents constructor-time injection.
  final syncEventProcessor = SyncEventProcessor(
    loggingService: domainLogger,
    domainLogger: domainLogger,
    updateNotifications: getIt<UpdateNotifications>(),
    aiConfigRepository: aiConfigRepository,
    savedTaskFiltersRepository: savedTaskFiltersRepository,
    settingsDb: settingsDb,
    journalEntityLoader: SmartJournalEntityLoader(
      attachmentIndex: attachmentIndex,
      loggingService: domainLogger,
    ),
    attachmentIndex: attachmentIndex,
    sequenceLogService: syncSequenceLogService,
    journalDb: journalDb,
    vectorClockService: vectorClockService,
    notificationsDb: notificationsDb,
    notificationScheduler: notificationScheduler,
    syncNodeProfileRepository: syncNodeProfileRepository,
  )..consumptionRepository = consumptionRepository;

  final collectSyncMetrics = await journalDb.getConfigFlag(enableLoggingFlag);

  final roomManager = SyncRoomManager(
    gateway: matrixGateway,
    settingsDb: settingsDb,
    loggingService: domainLogger,
  );

  // Session manager is ordinarily created inside MatrixService, but
  // Phase 2 needs it at hand to build the QueuePipelineCoordinator
  // before MatrixService so both end up sharing the same instance.
  final sessionManager = MatrixSessionManager(
    gateway: matrixGateway,
    roomManager: roomManager,
    loggingService: domainLogger,
  );

  // Phase-2 queue pipeline owns inbound ingestion unconditionally. The
  // dedicated ingestor below drives attachment recording + downloads on
  // the queue's live + bootstrap paths so descriptor JSONs land on disk
  // before the worker tries to apply their companion sync events.
  // `verboseLogging: false` matches the `attachmentIndex` setting above
  // — steady-state per-event logging would flood the general log on
  // large catch-ups.
  final localVcDominanceCheck = AgentVcDominanceCheck(
    agentDb: getIt<AgentDatabase>(),
  );
  final queueAttachmentIngestor = AttachmentIngestor(
    documentsDirectory: documentsDirectory,
    verboseLogging: false,
    localVcDominates: localVcDominanceCheck.check,
  );
  final queuePipelineCoordinator = QueuePipelineCoordinator(
    syncDb: syncDatabase,
    settingsDb: settingsDb,
    journalDb: journalDb,
    sessionManager: sessionManager,
    roomManager: roomManager,
    eventProcessor: syncEventProcessor,
    sequenceLogService: syncSequenceLogService,
    activityGate: userActivityGate,
    logging: domainLogger,
    attachmentIndex: attachmentIndex,
    updateNotifications: getIt<UpdateNotifications>(),
    attachmentIngestor: queueAttachmentIngestor,
    sentEventRegistry: sentEventRegistry,
    activitySignaler: getIt<SyncActivitySignaler>(),
  );

  final matrixService = MatrixService(
    gateway: matrixGateway,
    loggingService: domainLogger,
    activityGate: userActivityGate,
    messageSender: matrixMessageSender,
    settingsDb: settingsDb,
    eventProcessor: syncEventProcessor,
    secureStorage: secureStorage,
    collectSyncMetrics: collectSyncMetrics,
    roomManager: roomManager,
    sessionManager: sessionManager,
    queueCoordinator: queuePipelineCoordinator,
  );

  getIt
    ..registerSingleton<MatrixSyncGateway>(matrixGateway)
    ..registerSingleton<MatrixMessageSender>(matrixMessageSender)
    ..registerSingleton<SentEventRegistry>(sentEventRegistry)
    ..registerSingleton<AttachmentIndex>(
      attachmentIndex,
      dispose: (index) => index.dispose(),
    )
    ..registerSingleton<SyncEventProcessor>(syncEventProcessor)
    ..registerSingleton<MatrixService>(matrixService)
    ..registerSingleton<OutboxService>(
      MatrixOutboxService(
        syncDatabase: syncDatabase,
        loggingService: domainLogger,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        activityGate: userActivityGate,
        matrixService: matrixService,
        sequenceLogService: syncSequenceLogService,
        domainLogger: domainLogger,
        activitySignaler: getIt<SyncActivitySignaler>(),
      ),
    );

  // Self-healing sync: create backfill services after OutboxService is available
  final outboxService = getIt<OutboxService>();
  final onboardingSyncService = OnboardingSyncService(
    syncDatabase: syncDatabase,
    enqueueMessage: outboxService.enqueueMessageOrThrow,
    getHostId: vectorClockService.getHost,
    getSnapshotCoverage: syncDatabase.resolvedSequenceUpperBounds,
    // trivial accessor thunks, consumed only during
    // coverage:ignore-start
    // live onboarding-sync rounds against a logged-in client.
    getLocalUserId: () => client.userID,
    getLocalDeviceId: () => client.deviceID,
    // coverage:ignore-end
    logging: domainLogger,
  );
  syncEventProcessor.onboardingSyncService = onboardingSyncService;
  matrixService.onSyncMessageSent = onboardingSyncService.handleMessageSent;

  // Sync-node profile broadcaster: probes the local node's capabilities and
  // broadcasts (over the outbox) whenever the snapshot changes. Registered
  // here because it depends on both the repository (created earlier) and the
  // outbox service. The initial broadcast is fire-and-forget — boot must
  // never await it — and we wrap the future in a try/catch right here so an
  // unexpected probe / enqueue failure is captured under SYNC_NODE_PROFILE
  // instead of escaping to the zone error handler.
  final syncNodeProfileBroadcaster = SyncNodeProfileBroadcaster(
    repository: syncNodeProfileRepository,
    probe: defaultSyncNodeCapabilityProbe,
    vectorClockService: vectorClockService,
    outboxService: outboxService,
    domainLogger: domainLogger,
  );
  getIt.registerSingleton<SyncNodeProfileBroadcaster>(
    syncNodeProfileBroadcaster,
  );
  // Unconditional broadcast on every startup so late-joining peers and peers
  // that wiped settings always converge on the current snapshot within a
  // session — the receiver's directory upsert is last-write-wins by
  // updatedAt, so redundant re-broadcasts of unchanged content are cheap.
  getIt<StartupTasks>().track(() async {
    try {
      await syncNodeProfileBroadcaster.broadcast();
    } catch (error, stackTrace) {
      // defensive: only reachable when the probe or
      // coverage:ignore-start
      // the outbox write infrastructure itself fails.
      domainLogger.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'startupBroadcast',
      );
      // coverage:ignore-end
    }
  }());

  Future<void> enqueueOwnUnresolvableMarker({
    required String hostId,
    required int counter,
  }) async {
    final existing = await syncSequenceLogService.getEntryByHostAndCounter(
      hostId,
      counter,
    );
    final existingStatus = existing?.status;
    if (existingStatus == SyncSequenceStatus.received.index ||
        existingStatus == SyncSequenceStatus.backfilled.index ||
        existingStatus == SyncSequenceStatus.deleted.index) {
      // guards a live-sync race: a peer's response
      // coverage:ignore-start
      // about this very counter landing between reserve and release. The
      // receive path ignores own-host entries, so the state cannot be
      // constructed in-process.
      domainLogger.log(
        LogDomain.sync,
        'vc.burn.broadcast.skipBound host=$hostId counter=$counter '
        'status=$existingStatus',
        subDomain: 'vc.burn.broadcast',
      );
      return;
      // coverage:ignore-end
    }

    await outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: false,
        unresolvable: true,
      ),
    );
    await syncSequenceLogService.markOwnCounterUnresolvable(
      hostId: hostId,
      counter: counter,
    );
  }

  // Proactive VC burn broadcast: when a reservation releases (write rejected,
  // scope threw, commitWhen=false), enqueue a SyncBackfillResponse with
  // unresolvable=true so peers close the gap on arrival instead of having to
  // issue a backfill request first. Registered here because the handler has
  // to fire into OutboxService, which is only now available. The handler is
  // awaited by VectorClockService so the durable enqueue attempt finishes
  // before `release()` returns; failures are still swallowed here because the
  // VC counter is already persisted and cannot be rewound.
  vectorClockService.setBurnHandler((hostId, counter) async {
    // [hostId] is the host captured at reservation time, not whatever
    // [VectorClockService.getHost] returns now — if setNewHost ran between
    // reserve and release the broadcast would otherwise be attributed to
    // the new host, producing a phantom unresolvable on the new host's
    // counter space and leaving the actual burnt counter on the old host
    // unannounced.
    try {
      // Enqueue first. If the outbox write fails, the row remains
      // `burnPending` and startup/backfill can retry; terminalizing first
      // would make a transient outbox failure silently drop the proactive
      // repair signal.
      await enqueueOwnUnresolvableMarker(
        hostId: hostId,
        counter: counter,
      );
      domainLogger.log(
        LogDomain.sync,
        'vc.burn.broadcast host=$hostId counter=$counter',
        subDomain: 'vc.burn.broadcast',
      );
    } catch (error, stackTrace) {
      // defensive: reachable only when the outbox or
      // coverage:ignore-start
      // sequence-log write infrastructure itself fails mid-broadcast.
      domainLogger.error(
        LogDomain.sync,
        error,
        message:
            'vc burn broadcast failed; counter $counter will fall back to '
            'reactive backfill resolution',
        stackTrace: stackTrace,
        subDomain: 'vc.burn.broadcast',
      );
      // coverage:ignore-end
    }
  });

  // Crash recovery for counters explicitly released in a previous process but
  // not yet broadcast as unresolvable. Plain `reserved` rows are not retried
  // here: a crash after the payload DB write but before outbox/sequence
  // logging can leave a real payload behind, so only `burnPending` rows are
  // authoritative burns.
  getIt<StartupTasks>().track(
    Future<void>(() async {
      try {
        final hostId = await vectorClockService.getHost();
        if (hostId == null) return;
        final counters = await syncSequenceLogService
            .burnPendingCountersForHost(
              hostId: hostId,
            );
        var reconciled = 0;
        for (final counter in counters) {
          try {
            await enqueueOwnUnresolvableMarker(
              hostId: hostId,
              counter: counter,
            );
            reconciled++;
          } catch (error, stackTrace) {
            // defensive per-counter containment for
            // coverage:ignore-start
            // infrastructure write failures.
            domainLogger.error(
              LogDomain.sync,
              error,
              message:
                  'vc burn reconciliation failed for host=$hostId '
                  'counter=$counter; continuing',
              stackTrace: stackTrace,
              subDomain: 'vc.burn.reconcile',
            );
            // coverage:ignore-end
          }
        }
        if (counters.isNotEmpty) {
          domainLogger.log(
            LogDomain.sync,
            'vc.burn.reconcile host=$hostId count=$reconciled '
            'attempted=${counters.length} '
            'counters=$counters',
            subDomain: 'vc.burn.reconcile',
          );
        }
        final reservedCounters = await syncSequenceLogService
            .reservedCountersForHost(hostId: hostId);
        if (reservedCounters.isNotEmpty) {
          domainLogger.error(
            LogDomain.sync,
            'vc.reserved.audit host=$hostId '
            'count=${reservedCounters.length} '
            'counters=$reservedCounters',
            subDomain: 'vc.reserved.audit',
          );
        }
      } catch (error, stackTrace) {
        // defensive: whole-pass containment when the
        // coverage:ignore-start
        // sequence log itself cannot be read.
        domainLogger.error(
          LogDomain.sync,
          error,
          message:
              'vc burn reconciliation failed; burn-pending counters will retry '
              'on the next startup or reactive backfill',
          stackTrace: stackTrace,
          subDomain: 'vc.burn.reconcile',
        );
        // coverage:ignore-end
      }
    }),
  );
  final backfillResponseHandler = BackfillResponseHandler(
    journalDb: journalDb,
    sequenceLogService: syncSequenceLogService,
    outboxService: outboxService,
    loggingService: domainLogger,
    vectorClockService: vectorClockService,
    domainLogger: domainLogger,
    notificationsDb: notificationsDb,
    onboardingSyncService: onboardingSyncService,
  )..consumptionRepository = consumptionRepository;
  final backfillRequestService = BackfillRequestService(
    sequenceLogService: syncSequenceLogService,
    syncDatabase: syncDatabase,
    outboxService: outboxService,
    vectorClockService: vectorClockService,
    loggingService: domainLogger,
    documentsDirectory: documentsDirectory,
    queueCoordinator: queuePipelineCoordinator,
    domainLogger: domainLogger,
    onboardingSyncService: onboardingSyncService,
  );
  syncSequenceLogService.onMissingEntriesDetected = () {
    backfillRequestService.nudge();
    // Barren-bridge recovery: when the most recent reconnect bridge
    // finished without accepting anything and a live event now reveals
    // a missing counter, run an unbounded history walk to close the
    // hole immediately instead of waiting for the normal backfill
    // cadence. No-op when no barren bridge was recorded.
    queuePipelineCoordinator.maybeStartGapRecovery();
  };

  // After a bridge walk settles, re-analyse the sequence log and
  // dispatch a backfill request for anything still missing — nudges
  // during the walk are dropped by the `isBridgeInFlight` gate, so
  // this hook is how the service learns the walk finished.
  queuePipelineCoordinator.onBridgeCompleted = backfillRequestService.nudge;
  onboardingSyncService.onInboundSuppressionEnded =
      backfillRequestService.nudgeAfterDrain;

  // Set-once assignment of the late-final `backfillResponseHandler`. Must
  // run before MatrixService consumes any inbound timeline events.
  syncEventProcessor.backfillResponseHandler = backfillResponseHandler;

  // Media self-healing, both halves. The requester turns the loader's
  // "blob missing locally" signal into a broadcast request; the responder
  // answers peers' requests with the blob. Wiring the listener is what makes
  // the signal actionable — unsubscribed, a missing image or recording is
  // observed on every load and silently dropped.
  final mediaRepairService = MediaRepairService(
    outboxService: outboxService,
    vectorClockService: vectorClockService,
    loggingService: domainLogger,
  );
  syncEventProcessor
    ..missingMediaListener = mediaRepairService.reportMissing
    ..mediaRequestHandler = MediaRequestHandler(
      journalDb: journalDb,
      outboxService: outboxService,
      vectorClockService: vectorClockService,
      documentsDirectory: documentsDirectory,
      loggingService: domainLogger,
    );

  // Start the backfill request service
  backfillRequestService.start();

  getIt
    ..registerSingleton<BackfillResponseHandler>(backfillResponseHandler)
    ..registerSingleton<BackfillRequestService>(backfillRequestService)
    ..registerSingleton<OnboardingSyncService>(onboardingSyncService)
    ..registerSingleton<MediaRepairService>(
      mediaRepairService,
      dispose: (service) => service.dispose(),
    );

  return () => client.userID;
}

/// Registers the sync boundary for guest/demo worlds: an inert outbox and
/// nothing else. No Matrix client (so the device-global keychain credentials
/// are never read), no inbound queue, no backfill timers, no node-profile
/// broadcast, no VC-burn handler — the sync stack is structurally absent,
/// which is the demo-mode isolation guarantee.
void _registerInertSyncStack() {
  getIt.registerSingleton<OutboxService>(InertOutboxService());
}
