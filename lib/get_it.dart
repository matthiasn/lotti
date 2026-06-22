import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:get_it/get_it.dart';
import 'package:health/health.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_store_loader.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/agent_vc_dominance_check.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/services/sync_node_capability_probe.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/features/sync/state/conflict_notification_observer.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/health_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/location.dart';
import 'package:meta/meta.dart';

part 'get_it_helpers.dart';
part 'get_it_maintenance.dart';

final GetIt getIt = GetIt.instance;

Future<void> registerSingletons() async {
  getIt
    ..registerSingleton<Fts5Db>(Fts5Db())
    ..registerSingleton<UserActivityService>(UserActivityService())
    ..registerSingleton<UserActivityGate>(
      UserActivityGate(
        activityService: getIt<UserActivityService>(),
        idleThreshold: SyncTuning.outboxIdleThreshold,
      ),
    )
    ..registerSingleton<UpdateNotifications>(UpdateNotifications())
    ..registerSingleton<SyncActivitySignaler>(SyncActivitySignaler())
    ..registerSingleton<JournalDb>(JournalDb())
    ..registerSingleton<AgentDatabase>(AgentDatabase())
    ..registerSingleton<NotificationsDb>(NotificationsDb())
    ..registerSingleton<EditorDb>(EditorDb())
    ..registerSingleton<OnboardingMetricsDb>(OnboardingMetricsDb())
    ..registerSingleton<SyncDatabase>(SyncDatabase())
    ..registerSingleton<VectorClockService>(VectorClockService())
    ..registerSingleton<TimeService>(
      // When a new timer replaces a still-running one, persist the outgoing
      // entry's real stop time so it is not left with the stale dateTo it
      // was created with (≈ its start time). Existing entry text is
      // preserved — only the end time is written.
      TimeService(
        (entry) => getIt<PersistenceLogic>().updateJournalEntry(
          journalEntityId: entry.meta.id,
          dateTo: DateTime.now(),
        ),
      ),
    );

  // Initialize config flags before constructing services that depend on them.
  await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: false);
  await getIt<LoggingService>().listenToConfigFlag();

  _registerLazyServiceSafely<NotificationService>(
    NotificationService.new,
    'NotificationService',
  );

  // Proactively surface newly detected sync conflicts via an OS banner so the
  // user doesn't have to discover them by browsing settings.
  getIt.registerSingleton<ConflictNotificationObserver>(
    ConflictNotificationObserver()..start(),
  );

  final entitiesCacheService = EntitiesCacheService(
    journalDb: getIt<JournalDb>(),
    updateNotifications: getIt<UpdateNotifications>(),
  );
  await entitiesCacheService.init();
  getIt.registerSingleton<EntitiesCacheService>(entitiesCacheService);

  final aiConfigRepository = AiConfigRepository(AiConfigDb());
  getIt.registerSingleton<AiConfigRepository>(aiConfigRepository);

  await vod.init();
  final documentsDirectory = getIt<Directory>();
  final client = await createMatrixClient(
    documentsDirectory: documentsDirectory,
  );
  final loggingService = getIt<LoggingService>();
  final userActivityService = getIt<UserActivityService>();
  final userActivityGate = getIt<UserActivityGate>();
  final journalDb = getIt<JournalDb>();
  final notificationsDb = getIt<NotificationsDb>();
  final settingsDb = getIt<SettingsDb>();
  final syncNodeProfileRepository = SyncNodeProfileRepository(
    settingsDb: settingsDb,
  );
  getIt.registerSingleton<SyncNodeProfileRepository>(
    syncNodeProfileRepository,
  );
  final syncDatabase = getIt<SyncDatabase>();
  final vectorClockService = getIt<VectorClockService>();
  final secureStorage = getIt<SecureStorage>();
  // main() registers DomainLogger early (before this runs) so startup
  // diagnostics can resolve it; only register here when an entry point hasn't
  // already done so (e.g. a future caller of registerSingletons()).
  if (!getIt.isRegistered<DomainLogger>()) {
    getIt.registerSingleton<DomainLogger>(
      DomainLogger(loggingService: loggingService),
    );
  }
  final domainLogger = getIt<DomainLogger>();

  // FTUE measurement substrate. Recording the first-launch signal here (rather
  // than when the welcome UI shows) ensures pre-FTUE users upgrading into this
  // build are tagged as the baseline cohort even if they never trigger the
  // welcome, which is essential for clean before/after retention comparison.
  final onboardingMetricsRepository = OnboardingMetricsRepository(
    db: getIt<OnboardingMetricsDb>(),
    logger: domainLogger,
    hasExistingUserData: () async =>
        await journalDb.countAllJournalEntries() > 0,
  );
  getIt.registerSingleton<OnboardingMetricsRepository>(
    onboardingMetricsRepository,
  );
  // Fire-and-forget startup write — guard it so a metrics-DB failure can't
  // surface as an uncaught async error during startup.
  unawaited(() async {
    try {
      await onboardingMetricsRepository.recordAppFirstSeenIfAbsent();
    } catch (error, stackTrace) {
      domainLogger.error(
        LogDomain.onboarding,
        error,
        stackTrace: stackTrace,
        subDomain: 'recordAppFirstSeen',
      );
    }
  }());

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
  final readMarkerService = SyncReadMarkerService(
    settingsDb: settingsDb,
    loggingService: domainLogger,
  );

  // Self-healing sync: sequence log service for gap detection
  final syncSequenceLogService = SyncSequenceLogService(
    syncDatabase: syncDatabase,
    vectorClockService: vectorClockService,
    loggingService: domainLogger,
    domainLogger: domainLogger,
  );

  // NotificationService is lazily registered above so it doesn't have to
  // initialise the platform plugin at startup. Pass a thunk instead of
  // resolving here so sandboxed builds (e.g. flatpak) don't trip the lazy
  // service before anything actually needs it.
  final notificationScheduler = NotificationScheduler(
    notificationsDb: notificationsDb,
    // ignore: unnecessary_lambdas
    notificationServiceProvider: () => getIt<NotificationService>(),
    journalDb: journalDb,
  );
  getIt.registerSingleton<NotificationScheduler>(notificationScheduler);

  // SyncEventProcessor is constructed first; its `backfillResponseHandler`
  // (a `late final`) is assigned below once BackfillResponseHandler exists.
  // The chain BackfillResponseHandler → OutboxService → MatrixService →
  // SyncEventProcessor prevents constructor-time injection.
  final syncEventProcessor = SyncEventProcessor(
    loggingService: domainLogger,
    domainLogger: domainLogger,
    updateNotifications: getIt<UpdateNotifications>(),
    aiConfigRepository: aiConfigRepository,
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
  );
  final collectSyncMetrics = await journalDb.getConfigFlag(enableLoggingFlag);

  // Room discovery service for single-user multi-device flow
  final discoveryService = SyncRoomDiscoveryService(
    loggingService: domainLogger,
  );

  // Room manager with discovery capability
  final roomManager = SyncRoomManager(
    gateway: matrixGateway,
    settingsDb: settingsDb,
    loggingService: domainLogger,
    discoveryService: discoveryService,
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
    ..registerSingleton<AttachmentIndex>(attachmentIndex)
    ..registerSingleton<SyncReadMarkerService>(readMarkerService)
    ..registerSingleton<SyncEventProcessor>(syncEventProcessor)
    ..registerSingleton<MatrixService>(matrixService)
    ..registerSingleton<SyncSequenceLogService>(syncSequenceLogService)
    ..registerSingleton<OutboxService>(
      OutboxService(
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
  final notificationRepository = NotificationRepository(
    notificationsDb: notificationsDb,
    journalDb: journalDb,
    vectorClockService: vectorClockService,
    outboxService: outboxService,
    updateNotifications: getIt<UpdateNotifications>(),
    scheduler: notificationScheduler,
  );
  getIt.registerSingleton<NotificationRepository>(notificationRepository);

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
  unawaited(() async {
    try {
      await syncNodeProfileBroadcaster.broadcast();
    } catch (error, stackTrace) {
      domainLogger.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'startupBroadcast',
      );
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
      domainLogger.log(
        LogDomain.sync,
        'vc.burn.broadcast.skipBound host=$hostId counter=$counter '
        'status=$existingStatus',
        subDomain: 'vc.burn.broadcast',
      );
      return;
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
      domainLogger.error(
        LogDomain.sync,
        error,
        message:
            'vc burn broadcast failed; counter $counter will fall back to '
            'reactive backfill resolution',
        stackTrace: stackTrace,
        subDomain: 'vc.burn.broadcast',
      );
    }
  });

  // Crash recovery for counters explicitly released in a previous process but
  // not yet broadcast as unresolvable. Plain `reserved` rows are not retried
  // here: a crash after the payload DB write but before outbox/sequence
  // logging can leave a real payload behind, so only `burnPending` rows are
  // authoritative burns.
  unawaited(
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
            domainLogger.error(
              LogDomain.sync,
              error,
              message:
                  'vc burn reconciliation failed for host=$hostId '
                  'counter=$counter; continuing',
              stackTrace: stackTrace,
              subDomain: 'vc.burn.reconcile',
            );
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
        domainLogger.error(
          LogDomain.sync,
          error,
          message:
              'vc burn reconciliation failed; burn-pending counters will retry '
              'on the next startup or reactive backfill',
          stackTrace: stackTrace,
          subDomain: 'vc.burn.reconcile',
        );
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
  );
  final backfillRequestService = BackfillRequestService(
    sequenceLogService: syncSequenceLogService,
    syncDatabase: syncDatabase,
    outboxService: outboxService,
    vectorClockService: vectorClockService,
    loggingService: domainLogger,
    documentsDirectory: documentsDirectory,
    queueCoordinator: queuePipelineCoordinator,
    domainLogger: domainLogger,
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

  // Set-once assignment of the late-final `backfillResponseHandler`. Must
  // run before MatrixService consumes any inbound timeline events.
  syncEventProcessor.backfillResponseHandler = backfillResponseHandler;

  // Start the backfill request service
  backfillRequestService.start();

  getIt
    ..registerSingleton<BackfillResponseHandler>(backfillResponseHandler)
    ..registerSingleton<BackfillRequestService>(backfillRequestService)
    ..registerSingleton<MetadataService>(
      MetadataService(vectorClockService: vectorClockService),
    )
    ..registerSingleton<GeolocationService>(
      GeolocationService(
        journalDb: journalDb,
        loggingService: domainLogger,
        metadataService: getIt<MetadataService>(),
        deviceLocation: Platform.isWindows ? null : DeviceLocation(),
      ),
    )
    ..registerSingleton<PersistenceLogic>(PersistenceLogic())
    ..registerSingleton<EditorStateService>(EditorStateService())
    ..registerSingleton<HealthImport>(
      HealthImport(
        persistenceLogic: getIt<PersistenceLogic>(),
        db: getIt<JournalDb>(),
        health: HealthService(Health()),
        deviceInfo: DeviceInfoPlugin(),
      ),
    )
    ..registerSingleton<LinkService>(LinkService())
    ..registerSingleton<Maintenance>(Maintenance())
    ..registerSingleton<NavService>(NavService());

  await _registerLateAndOptionalServices();
}
