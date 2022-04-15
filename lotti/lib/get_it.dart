import 'package:get_it/get_it.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';

import 'database/database.dart';
import 'database/maintenance.dart';
import 'database/sync_db.dart';
import 'logic/health_import.dart';
import 'logic/persistence_logic.dart';

final getIt = GetIt.instance;

void registerSingletons() {
  getIt.registerSingleton<JournalDb>(JournalDb());
  getIt.registerSingleton<TagsService>(TagsService());
  getIt<JournalDb>().initConfigFlags();
  getIt.registerSingleton<SyncDatabase>(SyncDatabase());
  getIt.registerSingleton<LoggingDb>(LoggingDb());
  getIt.registerSingleton<VectorClockService>(VectorClockService());
  getIt.registerSingleton<SyncConfigService>(SyncConfigService());
  getIt.registerSingleton<TimeService>(TimeService());
  getIt.registerSingleton<OutboxService>(OutboxService());
  getIt.registerSingleton<PersistenceLogic>(PersistenceLogic());
  getIt.registerSingleton<HealthImport>(HealthImport());
  getIt.registerSingleton<SyncInboxService>(SyncInboxService());
  getIt.registerSingleton<LinkService>(LinkService());
  getIt.registerSingleton<NotificationService>(NotificationService());
  getIt.registerSingleton<EditorStateService>(EditorStateService());
  getIt.registerSingleton<Maintenance>(Maintenance());
  getIt.registerSingleton<AppRouter>(AppRouter());
}
