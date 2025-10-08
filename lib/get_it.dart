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
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
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
import 'package:meta/meta.dart';

final GetIt getIt = GetIt.instance;

/// Helper function to lazily register services that might fail in sandboxed environments
/// Services are only created on first access, with safe error handling
void _registerLazyServiceSafely<T extends Object>(
  T Function() factory,
  String serviceName,
) {
  try {
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
  final client = await createMatrixClient();
  final loggingService = getIt<LoggingService>();
  final userActivityService = getIt<UserActivityService>();
  final userActivityGate = getIt<UserActivityGate>();
  final journalDb = getIt<JournalDb>();
  final settingsDb = getIt<SettingsDb>();
  final documentsDirectory = getIt<Directory>();
  final syncDatabase = getIt<SyncDatabase>();
  final vectorClockService = getIt<VectorClockService>();
  final secureStorage = getIt<SecureStorage>();
  final matrixGateway = MatrixSdkGateway(client: client);
  final matrixMessageSender = MatrixMessageSender(
    loggingService: loggingService,
    journalDb: journalDb,
    documentsDirectory: documentsDirectory,
  );
  final readMarkerService = SyncReadMarkerService(
    settingsDb: settingsDb,
    loggingService: loggingService,
  );
  final syncEventProcessor = SyncEventProcessor(
    loggingService: loggingService,
    updateNotifications: getIt<UpdateNotifications>(),
    aiConfigRepository: aiConfigRepository,
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
  );

  getIt
    ..registerSingleton<MatrixSyncGateway>(matrixGateway)
    ..registerSingleton<MatrixMessageSender>(matrixMessageSender)
    ..registerSingleton<SyncReadMarkerService>(readMarkerService)
    ..registerSingleton<SyncEventProcessor>(syncEventProcessor)
    ..registerSingleton<MatrixService>(matrixService)
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

  // Register AudioPlayerCubit with MediaKit error handling
  _registerLazyServiceSafely<AudioPlayerCubit>(
    AudioPlayerCubit.new,
    'AudioPlayerCubit',
  );

  unawaited(getIt<MatrixService>().init());
  getIt<LoggingService>().listenToConfigFlag();

  await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: false);

  // Check and run maintenance task to remove deprecated action item suggestions
  unawaited(_checkAndRemoveActionItemSuggestions());
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
