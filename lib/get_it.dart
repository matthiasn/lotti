import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/ai_consumption/service/transcript_attribution_coordinator.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_startup.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/state/onboarding_rollout.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
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
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/media/media_repair_service.dart';
import 'package:lotti/features/sync/media/media_request_handler.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/onboarding/onboarding_sync_service.dart';
import 'package:lotti/features/sync/outbox/inert_outbox_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/services/sync_node_capability_probe.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/features/sync/state/conflict_notification_observer.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_repository.dart';
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
import 'package:lotti/services/startup_tasks.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/location.dart';
import 'package:meta/meta.dart';

part 'get_it_helpers.dart';
part 'get_it_maintenance.dart';
part 'get_it_sync.dart';

final GetIt getIt = GetIt.instance;

/// Registers the full per-generation service graph for [profile]'s world.
/// Called by the bootstrap after the profile-scoped primitives (Directory,
/// SettingsDb, SecureStorage, ProfileContext) are in place.
Future<void> registerSingletons({
  required ProfileContext profile,
  // Test seam: registration tests exercise the full graph without starting
  // late/optional runtime work (MatrixService.init, embedding pipeline).
  // Production callers must leave this true.
  bool registerLateAndOptional = true,
}) async {
  getIt
    ..registerSingleton<Fts5Db>(Fts5Db())
    ..registerSingleton<UserActivityService>(
      UserActivityService(),
      dispose: (service) => service.dispose(),
    )
    ..registerSingleton<UserActivityGate>(
      UserActivityGate(
        activityService: getIt<UserActivityService>(),
        idleThreshold: SyncTuning.outboxIdleThreshold,
      ),
    )
    ..registerSingleton<UpdateNotifications>(
      UpdateNotifications(),
      dispose: (notifications) => notifications.dispose(),
    )
    ..registerSingleton<JournalDb>(JournalDb())
    ..registerSingleton<AgentDatabase>(AgentDatabase())
    ..registerSingleton<ConsumptionDatabase>(ConsumptionDatabase())
    ..registerSingleton<NotificationsDb>(NotificationsDb())
    ..registerSingleton<EditorDb>(EditorDb())
    ..registerSingleton<OnboardingMetricsDb>(OnboardingMetricsDb())
    ..registerSingleton<SyncDatabase>(SyncDatabase())
    ..registerSingleton<StartupTasks>(StartupTasks())
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
    dispose: (observer) => observer.dispose(),
  );

  final entitiesCacheService = EntitiesCacheService(
    journalDb: getIt<JournalDb>(),
    updateNotifications: getIt<UpdateNotifications>(),
  );
  await entitiesCacheService.init();
  getIt.registerSingleton<EntitiesCacheService>(
    entitiesCacheService,
    dispose: (service) => service.dispose(),
  );

  final aiConfigRepository = AiConfigRepository(AiConfigDb());
  getIt.registerSingleton<AiConfigRepository>(aiConfigRepository);

  final documentsDirectory = getIt<Directory>();
  final dayProcessingDb = DayProcessingDb();
  getIt
    ..registerSingleton<DayProcessingDb>(dayProcessingDb)
    ..registerSingleton<DayProcessingOutboxRepository>(
      // Runs the ADR 0044 cutover before the processing runtime exists.
      await initializeDayProcessingOutbox(
        db: dayProcessingDb,
        documentsDirectory: documentsDirectory,
      ),
    );
  final loggingService = getIt<LoggingService>();
  final userActivityService = getIt<UserActivityService>();
  final userActivityGate = getIt<UserActivityGate>();
  final journalDb = getIt<JournalDb>();
  final notificationsDb = getIt<NotificationsDb>();
  final settingsDb = getIt<SettingsDb>();
  // Per-item saved-task-filter persistence + sync. Resolves OutboxService
  // lazily (mirrors AiConfigRepository), so it can be constructed here — ahead
  // of the OutboxService registration below — and injected into the
  // SyncEventProcessor.
  final savedTaskFiltersRepository = SavedTaskFiltersRepository(
    SavedTaskFiltersPersistence(settingsDb),
    getIt<UpdateNotifications>(),
  );
  getIt.registerSingleton<SavedTaskFiltersRepository>(
    savedTaskFiltersRepository,
  );
  final syncNodeProfileRepository = SyncNodeProfileRepository(
    settingsDb: settingsDb,
  );
  getIt.registerSingleton<SyncNodeProfileRepository>(
    syncNodeProfileRepository,
    dispose: (repository) => repository.dispose(),
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

  // Prepared Daily OS rollout migration. The lever in
  // `onboarding_rollout.dart` is false during production testing, making this
  // a read/write-free no-op. Once armed, awaiting it before `runApp` prevents
  // the Daily OS gate from racing the one-time flag overwrite.
  await applyOnboardingRolloutFlags(
    journalDb: journalDb,
    settingsDb: settingsDb,
    logger: domainLogger,
  );

  // Self-healing sync: sequence log service for gap detection. Shared
  // across modes — consumption sync and maintenance consult it, and in a
  // guest world it only ever touches that world's own sync.sqlite.
  final syncSequenceLogService = SyncSequenceLogService(
    syncDatabase: syncDatabase,
    vectorClockService: vectorClockService,
    loggingService: domainLogger,
    domainLogger: domainLogger,
  );
  getIt.registerSingleton<SyncSequenceLogService>(syncSequenceLogService);

  // NotificationService is lazily registered above so it doesn't have to
  // initialise the platform plugin at startup. Pass a thunk instead of
  // resolving here so sandboxed builds (e.g. flatpak) don't trip the lazy
  // service before anything actually needs it.
  final notificationScheduler = NotificationScheduler(
    // ignore: unnecessary_lambdas
    notificationServiceProvider: () => getIt<NotificationService>(),
  );
  getIt.registerSingleton<NotificationScheduler>(notificationScheduler);

  // Consumption repository has no circular dependency (only ConsumptionDatabase),
  // so — unlike the agent repository, which is wired via Riverpod — it can be
  // constructed here and injected directly onto the inbound sync collaborators.
  final consumptionRepository = ConsumptionRepository(
    getIt<ConsumptionDatabase>(),
  );

  // The sync boundary. Real profiles construct the full Matrix stack; guest
  // worlds register an inert outbox and nothing else, so the stack — and its
  // keychain credential reads, timers and startup broadcasts — is
  // structurally absent rather than merely disabled.
  var matrixUserId = _noMatrixUserId;
  if (profile.capabilities.syncEnabled) {
    matrixUserId = await _registerMatrixSyncStack(
      documentsDirectory: documentsDirectory,
      domainLogger: domainLogger,
      userActivityService: userActivityService,
      userActivityGate: userActivityGate,
      journalDb: journalDb,
      notificationsDb: notificationsDb,
      settingsDb: settingsDb,
      syncDatabase: syncDatabase,
      vectorClockService: vectorClockService,
      secureStorage: secureStorage,
      aiConfigRepository: aiConfigRepository,
      savedTaskFiltersRepository: savedTaskFiltersRepository,
      syncNodeProfileRepository: syncNodeProfileRepository,
      syncSequenceLogService: syncSequenceLogService,
      notificationScheduler: notificationScheduler,
      consumptionRepository: consumptionRepository,
    );
  } else {
    _registerInertSyncStack();
  }

  final outboxService = getIt<OutboxService>();

  // Sync-aware consumption and attribution services, now that OutboxService
  // is available. In guest worlds these bind to the inert outbox and a null
  // Matrix identity.
  final consumptionSyncService = ConsumptionSyncService(
    repository: consumptionRepository,
    outboxService: outboxService,
    vectorClockService: vectorClockService,
    sequenceLogService: syncSequenceLogService,
  );
  getIt
    ..registerSingleton<ConsumptionRepository>(consumptionRepository)
    ..registerSingleton<ConsumptionSyncService>(consumptionSyncService)
    ..registerSingleton<AiAttributionIdentityResolver>(
      AiAttributionIdentityResolver(
        settingsDb,
        matrixUserId: matrixUserId,
      ),
    )
    ..registerSingleton<AiAttributionService>(
      AiAttributionService(consumptionRepository, consumptionSyncService),
    )
    ..registerSingleton<AiInteractionCapture>(
      AiInteractionCapture(
        getIt<AiAttributionService>(),
        getIt<AiAttributionIdentityResolver>(),
      ),
    )
    ..registerSingleton<TranscriptAttributionCoordinator>(
      TranscriptAttributionCoordinator(
        getIt<AiAttributionService>(),
        getIt<AiAttributionIdentityResolver>(),
      ),
    );
  final notificationRepository = NotificationRepository(
    notificationsDb: notificationsDb,
    vectorClockService: vectorClockService,
    outboxService: outboxService,
    updateNotifications: getIt<UpdateNotifications>(),
    scheduler: notificationScheduler,
  );
  getIt
    ..registerSingleton<NotificationRepository>(notificationRepository)
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
    ..registerSingleton<EditorStateService>(EditorStateService());
  // Device health data must not bleed into a play world: like the sync
  // stack, health import is structurally absent in guest profiles, and its
  // UI surfaces gate on the capability.
  if (profile.capabilities.healthImportEnabled) {
    getIt.registerSingleton<HealthImport>(
      HealthImport(
        persistenceLogic: getIt<PersistenceLogic>(),
        db: getIt<JournalDb>(),
        health: HealthService(Health()),
        deviceInfo: DeviceInfoPlugin(),
      ),
    );
  }
  getIt
    ..registerSingleton<LinkService>(LinkService())
    ..registerSingleton<Maintenance>(Maintenance())
    ..registerSingleton<NavService>(
      NavService(),
      dispose: (service) => service.dispose(),
    );

  if (registerLateAndOptional) {
    await _registerLateAndOptionalServices(profile: profile);
  }
}

String? _noMatrixUserId() => null;
