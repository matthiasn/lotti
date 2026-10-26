part of 'get_it.dart';

/// The composition with `use_isolate_sync` on (ADR 0142, step 4b): the sync
/// isolate hosts the Matrix client, admission, the bridge, ingestion and the
/// sender; this isolate keeps the apply step, its own read connection to the
/// queue, a mirror of the attachment index, and talks to sync through
/// [IsolateSyncService]. Nothing here constructs a client — the SDK database
/// is opened by one isolate only.
Future<_SyncCore> _composeIsolateSyncCore({
  required Directory documentsDirectory,
  required DomainLogger domainLogger,
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
  required bool collectSyncMetrics,
}) async {
  // What the worker cannot reach itself: the keychain and device info are
  // plugins, so the credentials and the display name a fresh login
  // registers travel in its boot config; the UI-owned reads it makes while
  // running are answered by the host services.
  final matrixConfig = await readStoredMatrixConfig(secureStorage);
  final deviceDisplayName = await createMatrixDeviceName();
  final localVcDominanceCheck = AgentVcDominanceCheck(
    agentDb: getIt<AgentDatabase>(),
  );
  final host = (await registerSyncIsolateIfEnabled(
    getIt: getIt,
    journalDb: journalDb,
    syncDatabase: syncDatabase,
    documentsDirectory: documentsDirectory,
    temporaryDirectory: getTemporaryDirectory,
    logger: domainLogger,
    services: DatabaseSyncIsolateHostServices(
      settings: settingsDb,
      journal: journalDb,
      vectorClock: vectorClockService,
      localVcDominance: localVcDominanceCheck.check,
    ),
    hostMatrixStack: true,
    matrixConfig: matrixConfig,
    deviceDisplayName: deviceDisplayName,
    collectSyncMetrics: collectSyncMetrics,
  ))!;

  // The UI isolate's cost meter measures the apply step and the recovery
  // pass; the worker has its own for the SDK and admission.
  final syncCostMeter = SyncCostMeter(logger: domainLogger)..start();
  getIt.registerSingleton<SyncCostMeter>(
    syncCostMeter,
    dispose: (meter) => meter.dispose(),
  );

  // The mirror: fed with every descriptor the worker's ingestion records,
  // so the apply step's synchronous lookups and the media answers' observed
  // attachments see what the worker saw.
  final attachmentIndex = AttachmentIndex(
    logging: domainLogger,
    verboseLogging: false,
  );
  // This isolate's own connection to the queue: reads for the pages and
  // the apply loop's lease/settle through the host. The worker is the
  // queue's writer.
  final inboundQueue = InboundQueue(
    db: syncDatabase,
    logging: domainLogger,
    trust: SyncEventTrust(syncDb: syncDatabase, logging: domainLogger),
  );
  final syncService = IsolateSyncService(
    host: host,
    secureStorage: secureStorage,
    inboundQueue: inboundQueue,
    attachmentIndex: attachmentIndex,
    logger: domainLogger,
  );

  final syncEventProcessor = _buildSyncEventProcessor(
    domainLogger: domainLogger,
    journalDb: journalDb,
    notificationsDb: notificationsDb,
    settingsDb: settingsDb,
    vectorClockService: vectorClockService,
    secureStorage: secureStorage,
    aiConfigRepository: aiConfigRepository,
    savedTaskFiltersRepository: savedTaskFiltersRepository,
    syncNodeProfileRepository: syncNodeProfileRepository,
    syncSequenceLogService: syncSequenceLogService,
    notificationScheduler: notificationScheduler,
    consumptionRepository: consumptionRepository,
    attachmentIndex: attachmentIndex,
    descriptorRecovery: IsolateDescriptorRecovery(syncService),
    attachmentFetcher: IsolateAttachmentFetcher(syncService),
  );

  final applyLoop = IsolateApplyLoop(
    host: host,
    queue: inboundQueue,
    processor: syncEventProcessor,
    journalDb: journalDb,
    sequenceLogService: syncSequenceLogService,
    logging: domainLogger,
    service: syncService,
    updateNotifications: getIt<UpdateNotifications>(),
    activityGate: userActivityGate,
    costMeter: syncCostMeter,
  );
  // Registered after the host, so a reset stops the loop before the worker.
  getIt
    ..registerSingleton<AttachmentIndex>(
      attachmentIndex,
      dispose: (index) => index.dispose(),
    )
    ..registerSingleton<SyncEventProcessor>(syncEventProcessor)
    ..registerSingleton<IsolateApplyLoop>(
      applyLoop,
      dispose: (loop) async {
        await loop.dispose();
        await inboundQueue.dispose();
      },
    );
  // The loop leases nothing until the worker is up, and nothing applies
  // before the sync service's init has started the stack; starting it now
  // keeps startup from waiting on either.
  getIt<StartupTasks>().track(applyLoop.start());

  return (
    service: syncService,
    queueControl: syncService.queueControl,
    inboundQueue: inboundQueue,
    attachmentIndex: attachmentIndex,
    processor: syncEventProcessor,
    costMeter: syncCostMeter,
    ownUserId: () => syncService.ownUserId,
    ownDeviceId: () => syncService.ownDeviceId,
  );
}
