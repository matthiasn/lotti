import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavService Tests', () {
    late SettingsDb settingsDb;
    late JournalDb mockJournalDb;

    setUpAll(() {
      final secureStorageMock = MockSecureStorage();
      settingsDb = SettingsDb(inMemoryDatabase: true);
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);

      when(() => secureStorageMock.readValue(lastRouteKey))
          .thenAnswer((_) async => '/settings');

      when(() => secureStorageMock.writeValue(lastRouteKey, any()))
          .thenAnswer((_) async {});

      when(() => mockJournalDb.watchActiveConfigFlagNames()).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([
          {
            enableCalendarPageFlag,
            enableHabitsPageFlag,
            enableDashboardsPageFlag,
          }
        ]),
      );

      getIt
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<NavService>(
            NavService(journalDb: mockJournalDb, settingsDb: settingsDb));
    });

    test('tap all tabs', () async {
      final navService = getIt<NavService>();

      expect(navService.index, 0);

      navService.tapIndex(1);
      expect(navService.index, 1);

      navService.tapIndex(2);
      expect(navService.index, 2);

      navService.tapIndex(3);
      expect(navService.index, 3);

      navService.tapIndex(4);
      expect(navService.index, 4);

      navService.tapIndex(5);
      expect(navService.index, 5);

      navService.tapIndex(0);
      expect(navService.index, 0);

      beamToNamed('/settings');
      expect(navService.index, navService.settingsIndex);
      expect(navService.currentPath, '/settings');

      beamToNamed('/settings/advanced');
      expect(navService.index, navService.settingsIndex);
      expect(navService.currentPath, '/settings/advanced');
      navService.tapIndex(5);
      expect(navService.currentPath, '/settings');

      beamToNamed('/settings/advanced/maintenance');
      expect(navService.index, navService.settingsIndex);
      expect(navService.currentPath, '/settings/advanced/maintenance');

      beamToNamed('/journal');
      expect(navService.index, navService.journalIndex);
      expect(navService.currentPath, '/journal');
      beamToNamed('/journal/some-id');
      expect(navService.currentPath, '/journal/some-id');
      navService.tapIndex(navService.journalIndex);
      expect(navService.currentPath, '/journal');

      beamToNamed('/tasks');
      expect(navService.index, navService.tasksIndex);
      expect(navService.currentPath, '/tasks');
      beamToNamed('/tasks/some-id');
      expect(navService.currentPath, '/tasks/some-id');
      navService.tapIndex(navService.tasksIndex);
      expect(navService.currentPath, '/tasks');

      beamToNamed('/calendar');
      expect(navService.index, navService.calendarIndex);
      expect(navService.currentPath, '/calendar');

      beamToNamed('/dashboards');
      expect(navService.index, navService.dashboardsIndex);
      expect(navService.currentPath, '/dashboards');
      beamToNamed('/dashboards/some-id');
      expect(navService.currentPath, '/dashboards/some-id');
      navService.tapIndex(navService.dashboardsIndex);
      expect(navService.currentPath, '/dashboards');

      beamToNamed('/habits');
      expect(navService.index, navService.habitsIndex);
      expect(navService.currentPath, '/habits');
    });

    test('restoreRoute', () async {
      final navService = getIt<NavService>();
      await settingsDb.saveSettingsItem(lastRouteKey, '/settings');
      await navService.restoreRoute();
      expect(navService.currentPath, '/settings');
    });

    test('getIdFromSavedRoute', () async {
      await settingsDb.saveSettingsItem(
          lastRouteKey, '/journal/123e4567-e89b-12d3-a456-426614174000');
      final id = await getIdFromSavedRoute();
      expect(id, '123e4567-e89b-12d3-a456-426614174000');
    });
  });
}
