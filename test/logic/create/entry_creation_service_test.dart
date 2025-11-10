import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fallbacks.dart';
import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntryCreationService', () {
    late JournalDb journalDb;
    late SettingsDb settingsDb;
    late MockTimeService mockTimeService;
    late MockNavService mockNavService;
    late EntryCreationService service;

    setUpAll(() async {
      await getIt.reset();
      setFakeDocumentsPath();
      registerFallbackValue(fallbackJournalEntity);
      registerFallbackValue(fallbackSyncMessage);

      final mockNotificationService = MockNotificationService();
      final mockUpdateNotifications = MockUpdateNotifications();
      final mockFts5Db = MockFts5Db();
      final mockOutboxService = MockOutboxService();
      mockTimeService = MockTimeService();
      mockNavService = MockNavService();

      settingsDb = SettingsDb(inMemoryDatabase: true);
      journalDb = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(journalDb, inMemoryDatabase: true);

      when(mockNotificationService.updateBadge).thenAnswer((_) async {});
      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
      when(() => mockFts5Db.insertText(any(), removePrevious: true))
          .thenAnswer((_) async {});
      when(() => mockNotificationService.showNotification(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationId: any(named: 'notificationId'),
            deepLink: any(named: 'deepLink'),
          )).thenAnswer((_) async {});
      when(() => mockNotificationService.cancelNotification(any()))
          .thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});
      when(() => mockTimeService.start(any(), any())).thenAnswer((_) async {});
      when(() => mockNavService.beamToNamed(any())).thenReturn(null);

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<Directory>(Directory.systemTemp)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<TagsService>(TagsService())
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<NotificationService>(mockNotificationService)
        ..registerSingleton<VectorClockService>(VectorClockService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(PersistenceLogic());

      final container = ProviderContainer();
      service = container.read(entryCreationServiceProvider);
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    test('createTextEntry creates and stores a text entry', () async {
      final entry = await service.createTextEntry();

      expect(entry, isNotNull);
      expect(entry?.entryText?.plainText, '');

      // Verify it was saved to database
      final retrieved = await journalDb.journalEntityById(entry!.meta.id);
      expect(retrieved, isNotNull);
      expect(retrieved?.meta.id, entry.meta.id);
    });

    test('createTextEntry with linkedId does not navigate', () async {
      final parent = await service.createTextEntry();
      expect(parent, isNotNull);

      // Clear previous interactions
      reset(mockNavService);

      final linked = await service.createTextEntry(linkedId: parent!.meta.id);

      expect(linked, isNotNull);

      // Linked entries should not trigger navigation
      verifyNever(() => mockNavService.beamToNamed(any()));
    });

    test('createTextEntry without linkedId triggers navigation', () async {
      final entry = await service.createTextEntry();

      expect(entry, isNotNull);

      // Should navigate when not linked
      verify(() => mockNavService.beamToNamed('/journal/${entry!.meta.id}'))
          .called(1);
    });

    test('createTimerEntry without linked creates simple timer', () async {
      final timer = await service.createTimerEntry();

      expect(timer, isNotNull);

      // TimeService.start should not be called when no linked entry
      verifyNever(() => mockTimeService.start(any(), any()));
    });

    test('createTimerEntry with linked entry starts timer', () async {
      final parent = await service.createTextEntry();
      expect(parent, isNotNull);

      final timer = await service.createTimerEntry(linked: parent);

      expect(timer, isNotNull);

      // TimeService.start should be called with both entries
      verify(() => mockTimeService.start(timer!, parent)).called(1);
    });
  });
}
