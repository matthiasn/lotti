import 'dart:async';

import 'package:drift/isolate.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/logic/ai/ai_logic.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/asr_service.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/inbox/inbox_service.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/outbox/outbox_service.dart';

final getIt = GetIt.instance;

Future<void> registerSingletons() async {
  await getIt.registerSingleton<Future<DriftIsolate>>(
    createDriftIsolate(journalDbFileName),
    instanceName: journalDbFileName,
  );

  await getIt.registerSingleton<Future<DriftIsolate>>(
    createDriftIsolate(loggingDbFileName),
    instanceName: loggingDbFileName,
  );

  await getIt.registerSingleton<Future<DriftIsolate>>(
    createDriftIsolate(syncDbFileName),
    instanceName: syncDbFileName,
  );

  getIt
    ..registerSingleton<Fts5Db>(Fts5Db())
    ..registerSingleton<LoggingDb>(getLoggingDb())
    ..registerSingleton<JournalDb>(getJournalDb())
    ..registerSingleton<ConnectivityService>(ConnectivityService())
    ..registerSingleton<FgBgService>(FgBgService())
    ..registerSingleton<EditorDb>(EditorDb())
    ..registerSingleton<TagsService>(TagsService())
    ..registerSingleton<EntitiesCacheService>(EntitiesCacheService())
    ..registerSingleton<SyncDatabase>(getSyncDatabase())
    ..registerSingleton<ImapClientManager>(ImapClientManager())
    ..registerSingleton<AsrService>(AsrService())
    ..registerSingleton<VectorClockService>(VectorClockService())
    ..registerSingleton<SyncConfigService>(SyncConfigService())
    ..registerSingleton<TimeService>(TimeService())
    ..registerSingleton<OutboxService>(OutboxService())
    ..registerSingleton<MatrixService>(MatrixService())
    ..registerSingleton<AiLogic>(AiLogic())
    ..registerSingleton<PersistenceLogic>(PersistenceLogic())
    ..registerSingleton<EditorStateService>(EditorStateService())
    ..registerSingleton<HealthImport>(HealthImport())
    ..registerSingleton<InboxService>(InboxService())
    ..registerSingleton<LinkService>(LinkService())
    ..registerSingleton<NotificationService>(NotificationService())
    ..registerSingleton<Maintenance>(Maintenance())
    ..registerSingleton<NavService>(NavService());

  unawaited(getIt<MatrixService>().loginAndListen());

  await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: false);
}
