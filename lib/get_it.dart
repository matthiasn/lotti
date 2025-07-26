import 'dart:async';

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
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
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

final GetIt getIt = GetIt.instance;

Future<void> registerSingletons() async {
  getIt
    ..registerSingleton<Fts5Db>(Fts5Db())
    ..registerSingleton<UserActivityService>(UserActivityService())
    ..registerSingleton<UpdateNotifications>(UpdateNotifications())
    ..registerSingleton<JournalDb>(JournalDb())
    ..registerSingleton<EditorDb>(EditorDb())
    ..registerSingleton<TagsService>(TagsService())
    ..registerSingleton<EntitiesCacheService>(EntitiesCacheService())
    ..registerSingleton<SyncDatabase>(SyncDatabase())
    ..registerSingleton<VectorClockService>(VectorClockService())
    ..registerSingleton<TimeService>(TimeService())
    ..registerSingleton<OutboxService>(OutboxService());

  await vod.init();
  final client = await createMatrixClient();

  getIt
    ..registerSingleton<MatrixService>(MatrixService(client: client))
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
    ..registerSingleton<NotificationService>(NotificationService())
    ..registerSingleton<Maintenance>(Maintenance())
    ..registerSingleton<AiConfigRepository>(AiConfigRepository(AiConfigDb()))
    ..registerSingleton<NavService>(NavService())
    ..registerSingleton<AudioPlayerCubit>(AudioPlayerCubit());

  unawaited(getIt<MatrixService>().init());
  getIt<LoggingService>().listenToConfigFlag();

  await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: false);

  // Check and run maintenance task to remove deprecated action item suggestions
  await _checkAndRemoveActionItemSuggestions();
}

Future<void> _checkAndRemoveActionItemSuggestions() async {
  const settingsKey = 'maintenance_actionItemSuggestionsRemoved';
  final settingsDb = getIt<SettingsDb>();
  final maintenance = getIt<Maintenance>();

  // Check if we've already run this maintenance task
  final hasRun = await settingsDb.itemByKey(settingsKey);

  if (hasRun == null || hasRun != 'true') {
    try {
      // Run the maintenance task
      await maintenance.removeActionItemSuggestions();

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
