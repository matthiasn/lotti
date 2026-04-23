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
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
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

final GetIt getIt = GetIt.instance;

/// Minimum number of sequence log entries that indicate the log is already
/// sufficiently populated, making the one-time migration unnecessary.
const int kSequenceLogPopulationThreshold = 100;

/// Helper function to lazily register services that might fail in sandboxed environments
/// Services are only created on first access, with safe error handling
void _registerLazyServiceSafely<T extends Object>(
  T Function() factory,
  String serviceName,
) {
  try {
    // Proactively prevent duplicate registration regardless of
    // GetIt's global allowReassignment flag, to keep semantics strict
    // and predictable across optimized test runners.
    if (getIt.isRegistered<T>()) {
      _safeLog(
        'Failed to register lazy $serviceName: already registered',
        isError: true,
      );
      return;
    }
    getIt.registerLazySingleton<T>(() {
      try {
        final instance = factory();
        _safeLog(
          'Successfully created lazy instance of $serviceName',
          isError: false,
        );
        return instance;
      } catch (e) {
        _safeLog(
          'Failed to create lazy instance of $serviceName: $e',
          isError: true,
        );
        rethrow; // Let GetIt handle the failure appropriately
      }
    });
    _safeLog('Successfully registered lazy $serviceName', isError: false);
  } catch (e) {
    _safeLog('Failed to register lazy $serviceName: $e', isError: true);
  }
}

/// Safe logging helper that falls back to DevLogger if LoggingService is unavailable
void _safeLog(String message, {required bool isError}) {
  try {
    if (getIt.isRegistered<LoggingService>()) {
      final loggingService = getIt<LoggingService>();
      if (isError) {
        loggingService.captureEvent(
          message,
          domain: 'SERVICE_REGISTRATION',
          subDomain: 'error',
        );
      } else {
        loggingService.captureEvent(
          message,
          domain: 'SERVICE_REGISTRATION',
        );
      }
    } else {
      // Fallback to DevLogger if LoggingService not available
      if (isError) {
        DevLogger.error(
          name: 'SERVICE_REGISTRATION',
          message: message,
        );
      } else {
        DevLogger.log(
          name: 'SERVICE_REGISTRATION',
          message: message,
        );
      }
    }
  } catch (e) {
    // Ultimate fallback if even the safe check fails
    DevLogger.error(
      name: 'SERVICE_REGISTRATION',
      message: '$message (logging failed: $e)',
    );
  }
}

@visibleForTesting
void registerLazyServiceForTesting<T extends Object>(
  T Function() factory,
  String serviceName,
) => _registerLazyServiceSafely(factory, serviceName);

@visibleForTesting
void safeLogForTesting(String message, {required bool isError}) =>
    _safeLog(message, isError: isError);

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
    ..registerSingleton<JournalDb>(JournalDb())
    ..registerSingleton<AgentDatabase>(AgentDatabase())
    ..registerSingleton<EditorDb>(EditorDb())
    ..registerSingleton<SyncDatabase>(SyncDatabase())
    ..registerSingleton<VectorClockService>(VectorClockService())
    ..registerSingleton<TimeService>(TimeService());

  // Initialize config flags before constructing services that depend on them.
  await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: false);

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
  final settingsDb = getIt<SettingsDb>();
  final syncDatabase = getIt<SyncDatabase>();
  final vectorClockService = getIt<VectorClockService>();
  final secureStorage = getIt<SecureStorage>();
  final domainLogger = DomainLogger(loggingService: loggingService);
  getIt.registerSingleton<DomainLogger>(domainLogger);
  final sentEventRegistry = SentEventRegistry();
  final matrixGateway = MatrixSdkGateway(
    client: client,
    sentEventRegistry: sentEventRegistry,
  );
  final matrixMessageSender = MatrixMessageSender(
    loggingService: loggingService,
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
    logging: loggingService,
    verboseLogging: false,
  );
  final readMarkerService = SyncReadMarkerService(
    settingsDb: settingsDb,
    loggingService: loggingService,
  );

  // Self-healing sync: sequence log service for gap detection
  final syncSequenceLogService = SyncSequenceLogService(
    syncDatabase: syncDatabase,
    vectorClockService: vectorClockService,
    loggingService: loggingService,
    domainLogger: domainLogger,
  );

  // Note: SyncEventProcessor is created here but BackfillResponseHandler
  // needs OutboxService which depends on MatrixService. We'll create
  // the handler later and inject it after OutboxService is available.
  final syncEventProcessor = SyncEventProcessor(
    loggingService: loggingService,
    domainLogger: domainLogger,
    updateNotifications: getIt<UpdateNotifications>(),
    aiConfigRepository: aiConfigRepository,
    settingsDb: settingsDb,
    journalEntityLoader: SmartJournalEntityLoader(
      attachmentIndex: attachmentIndex,
      loggingService: loggingService,
    ),
    attachmentIndex: attachmentIndex,
    sequenceLogService: syncSequenceLogService,
    // backfillResponseHandler will be injected later to avoid circular dependency
  );
  final collectSyncMetrics = await journalDb.getConfigFlag(enableLoggingFlag);

  // Room discovery service for single-user multi-device flow
  final discoveryService = SyncRoomDiscoveryService(
    loggingService: loggingService,
  );

  // Room manager with discovery capability
  final roomManager = SyncRoomManager(
    gateway: matrixGateway,
    settingsDb: settingsDb,
    loggingService: loggingService,
    discoveryService: discoveryService,
  );

  // Session manager is ordinarily created inside MatrixService, but
  // Phase 2 needs it at hand to build the QueuePipelineCoordinator
  // before MatrixService so both end up sharing the same instance.
  final sessionManager = MatrixSessionManager(
    gateway: matrixGateway,
    roomManager: roomManager,
    loggingService: loggingService,
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
    logging: loggingService,
    attachmentIndex: attachmentIndex,
    updateNotifications: getIt<UpdateNotifications>(),
    attachmentIngestor: queueAttachmentIngestor,
    sentEventRegistry: sentEventRegistry,
  );

  final matrixService = MatrixService(
    gateway: matrixGateway,
    loggingService: loggingService,
    activityGate: userActivityGate,
    messageSender: matrixMessageSender,
    journalDb: journalDb,
    settingsDb: settingsDb,
    readMarkerService: readMarkerService,
    eventProcessor: syncEventProcessor,
    secureStorage: secureStorage,
    collectSyncMetrics: collectSyncMetrics,
    attachmentIndex: attachmentIndex,
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
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        activityGate: userActivityGate,
        matrixService: matrixService,
        sequenceLogService: syncSequenceLogService,
        domainLogger: domainLogger,
      ),
    );

  // Self-healing sync: create backfill services after OutboxService is available
  final outboxService = getIt<OutboxService>();
  final backfillResponseHandler = BackfillResponseHandler(
    journalDb: journalDb,
    sequenceLogService: syncSequenceLogService,
    outboxService: outboxService,
    loggingService: loggingService,
    vectorClockService: vectorClockService,
    domainLogger: domainLogger,
  );
  final backfillRequestService = BackfillRequestService(
    sequenceLogService: syncSequenceLogService,
    syncDatabase: syncDatabase,
    outboxService: outboxService,
    vectorClockService: vectorClockService,
    loggingService: loggingService,
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

  // Inject backfill handler into SyncEventProcessor (resolves circular dependency)
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
        loggingService: loggingService,
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

  // Register services that might fail in sandboxed environments using lazy loading
  _registerLazyServiceSafely<NotificationService>(
    NotificationService.new,
    'NotificationService',
  );

  _registerLazyServiceSafely<AudioWaveformService>(
    AudioWaveformService.new,
    'AudioWaveformService',
  );

  unawaited(getIt<MatrixService>().init());
  getIt<LoggingService>().listenToConfigFlag();

  // Label validator used by the assignment processor
  _registerLazyServiceSafely<LabelValidator>(
    LabelValidator.new,
    'LabelValidator',
  );

  // Label assignment processor
  _registerLazyServiceSafely<LabelAssignmentProcessor>(
    LabelAssignmentProcessor.new,
    'LabelAssignmentProcessor',
  );

  // Label assignment event service for UI notifications
  _registerLazyServiceSafely<LabelAssignmentEventService>(
    LabelAssignmentEventService.new,
    'LabelAssignmentEventService',
  );

  // Embedding generation pipeline (Ollama-based, local).
  // If the backend fails to initialize, the pipeline is non-essential
  // and the app should still start.
  // coverage:ignore-start
  try {
    final embeddingStore = await openShardedEmbeddingStore(
      documentsPath: getIt<Directory>().path,
    );
    getIt
      ..registerSingleton<EmbeddingStore>(
        embeddingStore,
        dispose: (store) => store.close(),
      )
      ..registerSingleton<OllamaEmbeddingRepository>(
        OllamaEmbeddingRepository(),
        dispose: (repo) => repo.close(),
      )
      ..registerSingleton<EmbeddingService>(
        EmbeddingService(
          embeddingStore: embeddingStore,
          embeddingRepository: getIt<OllamaEmbeddingRepository>(),
          journalDb: getIt<JournalDb>(),
          updateNotifications: getIt<UpdateNotifications>(),
          aiConfigRepository: getIt<AiConfigRepository>(),
        ),
        dispose: (svc) async => svc.stop(),
      )
      ..registerSingleton<VectorSearchRepository>(
        VectorSearchRepository(
          embeddingStore: embeddingStore,
          embeddingRepository: getIt<OllamaEmbeddingRepository>(),
          journalDb: getIt<JournalDb>(),
          aiConfigRepository: getIt<AiConfigRepository>(),
        ),
      );

    getIt<EmbeddingService>().start();
    _safeLog('Embedding pipeline initialized successfully', isError: false);
  } catch (e, stackTrace) {
    if (getIt.isRegistered<LoggingService>()) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'AI',
        subDomain: 'embedding_pipeline_init',
        stackTrace: stackTrace,
      );
    }
    _safeLog(
      'Embedding pipeline unavailable: $e',
      isError: true,
    );
  }
  // coverage:ignore-end

  // Automatically populate sequence log if empty (one-time migration)
  unawaited(_checkAndPopulateSequenceLog());
}

/// Automatically populate the sequence log if it's empty and the journal has
/// entries. This is a one-time migration for existing installations that
/// predates the sequence log feature.
///
/// This enables proper backfill responses - without the sequence log populated,
/// a device can't respond to backfill requests from other devices for historical
/// entries.
///
/// V2 adds agent entities and links to the population, which were missing in V1.
/// Devices that already ran V1 will re-run with the full set of data sources.
Future<void> _checkAndPopulateSequenceLog() async {
  // Bumped from 'maintenance_sequenceLogPopulated' to V2 so devices that
  // ran V1 (journal + links only) will re-run with agent data included.
  const settingsKey = 'maintenance_sequenceLogPopulatedV2';
  final settingsDb = getIt<SettingsDb>();
  final loggingService = getIt<LoggingService>();

  try {
    // Check if we've already run this migration
    final hasRun = await settingsDb.itemByKey(settingsKey);
    if (hasRun == 'true') {
      return;
    }

    final syncDatabase = getIt<SyncDatabase>();
    final journalDb = getIt<JournalDb>();
    final agentDb = getIt<AgentDatabase>();

    // Check current sequence log count
    final sequenceLogCount = await syncDatabase.getSequenceLogCount();

    // If already has significant entries, skip the threshold check — we still
    // need to populate agent data even if journal data is already present.
    // Only skip entirely if this V2 key has been set.

    // Check if there's any data that needs populating
    final journalCount = await journalDb.countAllJournalEntries();
    final linksCount = await journalDb.countAllEntryLinks();
    final agentEntityCount = await agentDb.countAllAgentEntities();
    final agentLinkCount = await agentDb.countAllAgentLinks();

    if (journalCount == 0 &&
        linksCount == 0 &&
        agentEntityCount == 0 &&
        agentLinkCount == 0) {
      // Empty database, nothing to populate
      await settingsDb.saveSettingsItem(settingsKey, 'true');
      return;
    }

    loggingService.captureEvent(
      'Starting automatic sequence log population (V2): '
      'journal=$journalCount links=$linksCount '
      'agentEntities=$agentEntityCount agentLinks=$agentLinkCount '
      'sequenceLog=$sequenceLogCount',
      domain: 'MAINTENANCE',
      subDomain: 'sequenceLogPopulation',
    );

    final sequenceLogService = getIt<SyncSequenceLogService>();

    // Populate from journal entries
    final populatedJournal = await sequenceLogService.populateFromJournal(
      entryStream: journalDb.streamEntriesWithVectorClock(),
      getTotalCount: journalDb.countAllJournalEntries,
    );

    // Populate from entry links
    final populatedLinks = await sequenceLogService.populateFromEntryLinks(
      linkStream: journalDb.streamEntryLinksWithVectorClock(),
      getTotalCount: journalDb.countAllEntryLinks,
    );

    // Populate from agent entities
    final populatedAgentEntities = await sequenceLogService
        .populateFromAgentEntities(
          entityStream: agentDb.streamAgentEntitiesWithVectorClock(),
          getTotalCount: agentDb.countAllAgentEntities,
        );

    // Populate from agent links
    final populatedAgentLinks = await sequenceLogService.populateFromAgentLinks(
      linkStream: agentDb.streamAgentLinksWithVectorClock(),
      getTotalCount: agentDb.countAllAgentLinks,
    );

    // Mark as completed
    await settingsDb.saveSettingsItem(settingsKey, 'true');

    loggingService.captureEvent(
      'Automatic sequence log population (V2) completed: '
      'journal=$populatedJournal links=$populatedLinks '
      'agentEntities=$populatedAgentEntities agentLinks=$populatedAgentLinks',
      domain: 'MAINTENANCE',
      subDomain: 'sequenceLogPopulation',
    );
  } catch (e, stackTrace) {
    loggingService.captureException(
      e,
      domain: 'MAINTENANCE',
      subDomain: 'sequenceLogPopulation',
      stackTrace: stackTrace,
    );
    // Don't mark as completed on error - will retry on next startup
  }
}

@visibleForTesting
Future<void> checkAndPopulateSequenceLogForTesting() =>
    _checkAndPopulateSequenceLog();
