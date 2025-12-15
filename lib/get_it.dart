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
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/health_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
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
      _safeLog('Failed to register lazy $serviceName: already registered',
          isError: true);
      return;
    }
    getIt.registerLazySingleton<T>(() {
      try {
        final instance = factory();
        _safeLog('Successfully created lazy instance of $serviceName',
            isError: false);
        return instance;
      } catch (e) {
        _safeLog('Failed to create lazy instance of $serviceName: $e',
            isError: true);
        rethrow; // Let GetIt handle the failure appropriately
      }
    });
    _safeLog('Successfully registered lazy $serviceName', isError: false);
  } catch (e) {
    _safeLog('Failed to register lazy $serviceName: $e', isError: true);
  }
}

/// Safe logging helper that falls back to print if LoggingService is unavailable
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
      // Fallback to print if LoggingService not available
      // ignore: avoid_print
      print('SERVICE_REGISTRATION: $message');
    }
  } catch (e) {
    // Ultimate fallback if even the safe check fails
    // ignore: avoid_print
    print('SERVICE_REGISTRATION: $message (logging failed: $e)');
  }
}

@visibleForTesting
void registerLazyServiceForTesting<T extends Object>(
  T Function() factory,
  String serviceName,
) =>
    _registerLazyServiceSafely(factory, serviceName);

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
    ..registerSingleton<EditorDb>(EditorDb())
    ..registerSingleton<TagsService>(TagsService())
    ..registerSingleton<EntitiesCacheService>(EntitiesCacheService())
    ..registerSingleton<SyncDatabase>(SyncDatabase())
    ..registerSingleton<VectorClockService>(VectorClockService())
    ..registerSingleton<TimeService>(TimeService());

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
  );
  // Shared in-memory index of latest attachment events keyed by relativePath.
  final attachmentIndex = AttachmentIndex(logging: loggingService);
  final readMarkerService = SyncReadMarkerService(
    settingsDb: settingsDb,
    loggingService: loggingService,
  );

  // Self-healing sync: sequence log service for gap detection
  final syncSequenceLogService = SyncSequenceLogService(
    syncDatabase: syncDatabase,
    vectorClockService: vectorClockService,
    loggingService: loggingService,
  );

  // Note: SyncEventProcessor is created here but BackfillResponseHandler
  // needs OutboxService which depends on MatrixService. We'll create
  // the handler later and inject it after OutboxService is available.
  final syncEventProcessor = SyncEventProcessor(
    loggingService: loggingService,
    updateNotifications: getIt<UpdateNotifications>(),
    aiConfigRepository: aiConfigRepository,
    settingsDb: settingsDb,
    journalEntityLoader: SmartJournalEntityLoader(
      attachmentIndex: attachmentIndex,
      loggingService: loggingService,
    ),
    sequenceLogService: syncSequenceLogService,
    // backfillResponseHandler will be injected later to avoid circular dependency
  );
  // Initialize config flags before constructing services that depend on them.
  await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: false);

  final collectSyncMetrics = await journalDb.getConfigFlag(enableLoggingFlag);

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
  );
  final backfillRequestService = BackfillRequestService(
    sequenceLogService: syncSequenceLogService,
    syncDatabase: syncDatabase,
    outboxService: outboxService,
    vectorClockService: vectorClockService,
    loggingService: loggingService,
  );

  // Inject backfill handler into SyncEventProcessor (resolves circular dependency)
  syncEventProcessor.backfillResponseHandler = backfillResponseHandler;

  // Start the backfill request service
  backfillRequestService.start();

  getIt
    ..registerSingleton<BackfillResponseHandler>(backfillResponseHandler)
    ..registerSingleton<BackfillRequestService>(backfillRequestService)
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

  // Register AudioPlayerCubit with MediaKit error handling
  _registerLazyServiceSafely<AudioPlayerCubit>(
    AudioPlayerCubit.new,
    'AudioPlayerCubit',
  );

  _registerLazyServiceSafely<AudioWaveformService>(
    AudioWaveformService.new,
    'AudioWaveformService',
  );

  unawaited(getIt<MatrixService>().init());
  getIt<LoggingService>().listenToConfigFlag();

  // Shared rate limiter for AI label assignment
  getIt.registerSingleton<LabelAssignmentRateLimiter>(
    LabelAssignmentRateLimiter(),
  );

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

  // Check and run maintenance task to remove deprecated action item suggestions
  unawaited(_checkAndRemoveActionItemSuggestions());

  // Automatically populate sequence log if empty (one-time migration)
  unawaited(_checkAndPopulateSequenceLog());
}

Future<void> _checkAndRemoveActionItemSuggestions() async {
  const settingsKey = 'maintenance_actionItemSuggestionsRemoved';
  final settingsDb = getIt<SettingsDb>();
  final maintenance = getIt<Maintenance>();

  // Check if we've already run this maintenance task
  final hasRun = await settingsDb.itemByKey(settingsKey);

  // TODO(matthiasn): remove after some time
  if (hasRun == null || hasRun != 'true') {
    try {
      // Run the maintenance task
      await maintenance.removeActionItemSuggestions(triggeredAtAppStart: true);

      // Mark as completed
      await settingsDb.saveSettingsItem(settingsKey, 'true');

      getIt<LoggingService>().captureEvent(
        'Automatic removal of action item suggestions completed',
        domain: 'MAINTENANCE',
        subDomain: 'startup',
      );
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'MAINTENANCE',
        subDomain: 'startup_removeActionItemSuggestions',
        stackTrace: stackTrace,
      );
    }
  }
}

@visibleForTesting
Future<void> checkAndRemoveActionItemSuggestionsForTesting() =>
    _checkAndRemoveActionItemSuggestions();

/// Automatically populate the sequence log if it's empty and the journal has
/// entries. This is a one-time migration for existing installations that
/// predates the sequence log feature.
///
/// This enables proper backfill responses - without the sequence log populated,
/// a device can't respond to backfill requests from other devices for historical
/// entries.
Future<void> _checkAndPopulateSequenceLog() async {
  const settingsKey = 'maintenance_sequenceLogPopulated';
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

    // Check current sequence log count
    final sequenceLogCount = await syncDatabase.getSequenceLogCount();

    // If already has significant entries, mark as done
    if (sequenceLogCount > kSequenceLogPopulationThreshold) {
      await settingsDb.saveSettingsItem(settingsKey, 'true');
      loggingService.captureEvent(
        'Sequence log already has $sequenceLogCount entries, skipping population',
        domain: 'MAINTENANCE',
        subDomain: 'sequenceLogPopulation',
      );
      return;
    }

    // Check if journal has entries that need populating
    final journalCount = await journalDb.countAllJournalEntries();
    final linksCount = await journalDb.countAllEntryLinks();

    if (journalCount == 0 && linksCount == 0) {
      // Empty database, nothing to populate
      await settingsDb.saveSettingsItem(settingsKey, 'true');
      return;
    }

    loggingService.captureEvent(
      'Starting automatic sequence log population: journal=$journalCount links=$linksCount sequenceLog=$sequenceLogCount',
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

    // Mark as completed
    await settingsDb.saveSettingsItem(settingsKey, 'true');

    loggingService.captureEvent(
      'Automatic sequence log population completed: journal=$populatedJournal links=$populatedLinks',
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
