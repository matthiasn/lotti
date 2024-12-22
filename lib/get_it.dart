import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/logic/ai/ai_logic.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

final getIt = GetIt.instance;

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
    ..registerSingleton<AsrService>(AsrService())
    ..registerSingleton<VectorClockService>(VectorClockService())
    ..registerSingleton<TimeService>(TimeService())
    ..registerSingleton<OutboxService>(OutboxService())
    ..registerSingleton<MatrixService>(MatrixService())
    ..registerSingleton<AiLogic>(AiLogic())
    ..registerSingleton<PersistenceLogic>(PersistenceLogic())
    ..registerSingleton<EditorStateService>(EditorStateService())
    ..registerSingleton<HealthImport>(HealthImport())
    ..registerSingleton<LinkService>(LinkService())
    ..registerSingleton<NotificationService>(NotificationService())
    ..registerSingleton<Maintenance>(Maintenance())
    ..registerSingleton<NavService>(NavService());

  unawaited(getIt<MatrixService>().init());

  await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: false);
}
