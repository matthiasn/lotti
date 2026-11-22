import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../mocks/mocks.dart';
import 'path_provider.dart';
import 'test_get_it.dart';

/// A real in-memory [JournalDb] behind a real [PersistenceLogic], with the
/// services around a write (outbox, notifications, search index, location)
/// mocked out.
///
/// For a repository test that must see what is actually stored, linked and
/// merged — a mocked repository cannot keep a link or refuse a stale write.
/// Call [setUp] from the test's `setUp` and [tearDown] from its `tearDown`;
/// both own GetIt for the test.
class RealJournalPersistence {
  late JournalDb journalDb;
  late SettingsDb settingsDb;

  final outboxService = MockOutboxService();
  final updateNotifications = MockUpdateNotifications();

  /// The [PersistenceLogic] registered in GetIt, which [JournalRepository]
  /// writes through too.
  PersistenceLogic get persistenceLogic => getIt<PersistenceLogic>();

  /// Registers everything a write needs and opens the databases.
  /// [persistenceLogic] replaces the default [buildPersistenceLogic], for a
  /// test that needs a seam inside a write.
  Future<void> setUp({PersistenceLogic Function()? persistenceLogic}) async {
    // Per test: the global teardown resets platform channel mocks, so a fake
    // set once for the file is gone by the time a bundled run reaches it.
    setFakeDocumentsPath();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    journalDb = JournalDb(inMemoryDatabase: true);
    await initConfigFlags(journalDb, inMemoryDatabase: true);

    final notificationService = MockNotificationService();
    when(notificationService.updateBadge).thenAnswer((_) async {});
    when(
      () => updateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});

    final documentsDirectory = await getApplicationDocumentsDirectory();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(updateNotifications)
          ..registerSingleton<Directory>(documentsDirectory)
          ..unregister<SettingsDb>()
          ..registerSingleton<SettingsDb>(settingsDb)
          ..registerSingleton<Fts5Db>(MockFts5Db())
          ..registerSingleton<UserActivityService>(UserActivityService())
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(journalDb)
          ..registerSingleton<OutboxService>(outboxService)
          ..registerSingleton<NotificationService>(notificationService)
          ..registerSingleton<VectorClockService>(buildVectorClockService())
          ..registerSingleton<MetadataService>(
            MetadataService(vectorClockService: getIt<VectorClockService>()),
          )
          ..registerSingleton<GeolocationService>(MockGeolocationService())
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<NavService>(MockNavService())
          ..registerSingleton<EntitiesCacheService>(MockEntitiesCacheService())
          ..registerSingleton<PersistenceLogic>(
            (persistenceLogic ?? buildPersistenceLogic)(),
          );
      },
    );
  }

  /// A [JournalRepository] over the registered services.
  JournalRepository journalRepository() => buildJournalRepository();

  /// Releases GetIt and closes the databases.
  Future<void> tearDown() async {
    await tearDownTestGetIt();
    await journalDb.close();
    await settingsDb.close();
  }
}
