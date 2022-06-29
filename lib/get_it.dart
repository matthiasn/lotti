import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:lotti/theme.dart';

final getIt = GetIt.instance;

void registerSingletons() {
  getIt
    ..registerSingleton<JournalDb>(JournalDb())
    ..registerSingleton<ThemeService>(ThemeService())
    ..registerSingleton<EditorDb>(EditorDb())
    ..registerSingleton<TagsService>(TagsService())
    ..registerSingleton<SyncDatabase>(SyncDatabase())
    ..registerSingleton<LoggingDb>(LoggingDb())
    ..registerSingleton<VectorClockService>(VectorClockService())
    ..registerSingleton<SyncConfigService>(SyncConfigService())
    ..registerSingleton<TimeService>(TimeService())
    ..registerSingleton<OutboxService>(OutboxService())
    ..registerSingleton<PersistenceLogic>(PersistenceLogic())
    ..registerSingleton<EditorStateService>(EditorStateService())
    ..registerSingleton<HealthImport>(HealthImport())
    ..registerSingleton<SyncInboxService>(SyncInboxService())
    ..registerSingleton<LinkService>(LinkService())
    ..registerSingleton<NotificationService>(NotificationService())
    ..registerSingleton<Maintenance>(Maintenance())
    ..registerSingleton<AppRouter>(AppRouter())
    ..registerSingleton<NavService>(NavService());

  getIt<JournalDb>().initConfigFlags();
}
