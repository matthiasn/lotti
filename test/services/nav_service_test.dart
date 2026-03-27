import 'dart:async';

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

    setUpAll(() async {
      await getIt.reset();
      final secureStorageMock = MockSecureStorage();
      settingsDb = SettingsDb(inMemoryDatabase: true);
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);

      when(
        () => secureStorageMock.readValue(lastRouteKey),
      ).thenAnswer((_) async => '/settings');

      when(
        () => secureStorageMock.writeValue(lastRouteKey, any()),
      ).thenAnswer((_) async {});

      when(() => mockJournalDb.watchConfigFlag(any())).thenAnswer((invocation) {
        final flagName = invocation.positionalArguments.first as String;
        final enabledFlags = {
          enableProjectsFlag,
          enableDailyOsPageFlag,
          enableHabitsPageFlag,
          enableDashboardsPageFlag,
        };
        return Stream<bool>.value(enabledFlags.contains(flagName));
      });

      final navService = NavService(
        journalDb: mockJournalDb,
        settingsDb: settingsDb,
      );

      getIt
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<NavService>(navService);
    });

    tearDownAll(() async {
      await getIt<NavService>().dispose();
      await getIt.reset();
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

      navService.tapIndex(6);
      expect(navService.index, 6);

      navService.tapIndex(0);
      expect(navService.index, 0);

      beamToNamed('/settings');
      expect(navService.index, navService.settingsIndex);
      expect(navService.currentPath, '/settings');

      beamToNamed('/settings/advanced');
      expect(navService.index, navService.settingsIndex);
      expect(navService.currentPath, '/settings/advanced');
      navService.tapIndex(navService.settingsIndex);
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

      beamToNamed('/projects');
      expect(navService.index, navService.projectsIndex);
      expect(navService.currentPath, '/projects');
      navService.tapIndex(navService.projectsIndex);
      expect(navService.currentPath, '/projects');

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

    test('orders Projects directly after Tasks when enabled', () {
      final navService = getIt<NavService>();

      expect(
        navService.beamerDelegates,
        [
          navService.tasksDelegate,
          navService.projectsDelegate,
          navService.calendarDelegate,
          navService.habitsDelegate,
          navService.dashboardsDelegate,
          navService.journalDelegate,
          navService.settingsDelegate,
        ],
      );
    });

    test('hides Projects when the projects flag is disabled', () async {
      final settingsDb = SettingsDb(inMemoryDatabase: true);
      final projectsDisabledDb = mockJournalDbWithMeasurableTypes([]);
      when(
        () => projectsDisabledDb.watchConfigFlag(any()),
      ).thenAnswer((invocation) {
        final flagName = invocation.positionalArguments.first as String;
        final enabledFlags = {
          enableDailyOsPageFlag,
          enableHabitsPageFlag,
          enableDashboardsPageFlag,
        };
        return Stream<bool>.value(enabledFlags.contains(flagName));
      });

      final navService = NavService(
        journalDb: projectsDisabledDb,
        settingsDb: settingsDb,
      );
      addTearDown(navService.dispose);

      expect(
        navService.beamerDelegates,
        isNot(contains(navService.projectsDelegate)),
      );
      expect(navService.projectsIndex, -1);
    });

    test('starts with optional tabs hidden until config flags emit', () async {
      final settingsDb = SettingsDb(inMemoryDatabase: true);
      final journalDb = mockJournalDbWithMeasurableTypes([]);
      final projectsController = StreamController<bool>.broadcast(sync: true);
      final dailyOsController = StreamController<bool>.broadcast(sync: true);
      final habitsController = StreamController<bool>.broadcast(sync: true);
      final dashboardsController = StreamController<bool>.broadcast(sync: true);

      when(() => journalDb.watchConfigFlag(any())).thenAnswer((invocation) {
        final flagName = invocation.positionalArguments.first as String;
        return switch (flagName) {
          enableProjectsFlag => projectsController.stream,
          enableDailyOsPageFlag => dailyOsController.stream,
          enableHabitsPageFlag => habitsController.stream,
          enableDashboardsPageFlag => dashboardsController.stream,
          _ => Stream<bool>.value(false),
        };
      });

      final navService = NavService(
        journalDb: journalDb,
        settingsDb: settingsDb,
      );
      addTearDown(() async {
        await navService.dispose();
        await Future.wait([
          projectsController.close(),
          dailyOsController.close(),
          habitsController.close(),
          dashboardsController.close(),
        ]);
      });

      expect(
        navService.beamerDelegates,
        [
          navService.tasksDelegate,
          navService.journalDelegate,
          navService.settingsDelegate,
        ],
      );
      expect(navService.projectsIndex, -1);

      projectsController.add(true);
      dailyOsController.add(true);
      habitsController.add(true);
      dashboardsController.add(true);

      expect(
        navService.beamerDelegates,
        [
          navService.tasksDelegate,
          navService.projectsDelegate,
          navService.calendarDelegate,
          navService.habitsDelegate,
          navService.dashboardsDelegate,
          navService.journalDelegate,
          navService.settingsDelegate,
        ],
      );
      expect(navService.projectsIndex, 1);
    });

    test(
      'falls back to Tasks when Projects is disabled while selected',
      () async {
        final settingsDb = SettingsDb(inMemoryDatabase: true);
        final journalDb = mockJournalDbWithMeasurableTypes([]);
        final projectsController = StreamController<bool>.broadcast(sync: true);
        final dailyOsController = StreamController<bool>.broadcast(sync: true);
        final habitsController = StreamController<bool>.broadcast(sync: true);
        final dashboardsController = StreamController<bool>.broadcast(
          sync: true,
        );

        when(() => journalDb.watchConfigFlag(any())).thenAnswer((invocation) {
          final flagName = invocation.positionalArguments.first as String;
          return switch (flagName) {
            enableProjectsFlag => projectsController.stream,
            enableDailyOsPageFlag => dailyOsController.stream,
            enableHabitsPageFlag => habitsController.stream,
            enableDashboardsPageFlag => dashboardsController.stream,
            _ => Stream<bool>.value(false),
          };
        });

        final navService = NavService(
          journalDb: journalDb,
          settingsDb: settingsDb,
        );
        addTearDown(() async {
          await navService.dispose();
          await Future.wait([
            projectsController.close(),
            dailyOsController.close(),
            habitsController.close(),
            dashboardsController.close(),
          ]);
        });

        projectsController.add(true);
        dailyOsController.add(true);
        habitsController.add(true);
        dashboardsController.add(true);

        navService.beamToNamed('/projects');
        expect(navService.index, navService.projectsIndex);
        expect(navService.currentPath, '/projects');

        projectsController.add(false);

        expect(navService.index, navService.tasksIndex);
        expect(navService.currentPath, '/tasks');
        expect(navService.projectsIndex, -1);
      },
    );

    test('navigating to an unrecognized path falls back to tasks', () {
      final navService = getIt<NavService>()..beamToNamed('/nonexistent');
      expect(navService.currentPath, '/tasks');
      expect(navService.index, 0);
    });

    test('restoreRoute', () async {
      final navService = getIt<NavService>();
      await settingsDb.saveSettingsItem(lastRouteKey, '/settings');
      await navService.restoreRoute();
      expect(navService.currentPath, '/settings');
    });

    test('getIdFromSavedRoute', () async {
      await settingsDb.saveSettingsItem(
        lastRouteKey,
        '/journal/123e4567-e89b-12d3-a456-426614174000',
      );
      final id = await getIdFromSavedRoute();
      expect(id, '123e4567-e89b-12d3-a456-426614174000');
    });

    group('global beamToNamed', () {
      test('uses override when set', () {
        String? calledPath;
        beamToNamedOverride = (path) => calledPath = path;
        addTearDown(() => beamToNamedOverride = null);

        beamToNamed('/test-path');

        expect(calledPath, '/test-path');
      });

      test('falls back to NavService when override is null', () {
        beamToNamedOverride = null;
        final navService = getIt<NavService>();

        beamToNamed('/settings');

        expect(navService.currentPath, '/settings');
      });
    });
  });
}
