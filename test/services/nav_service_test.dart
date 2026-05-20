import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

enum _GeneratedNavPathKind {
  tasksRoot,
  tasksChild,
  projectsRoot,
  projectsChild,
  calendarRoot,
  calendarChild,
  habitsRoot,
  habitsChild,
  dashboardsRoot,
  dashboardsChild,
  journalRoot,
  journalChild,
  settingsRoot,
  settingsChild,
  unknown,
}

class _GeneratedNavPath {
  const _GeneratedNavPath({
    required this.kind,
    required this.seed,
  });

  final _GeneratedNavPathKind kind;
  final int seed;

  String get path {
    final suffix = 'generated-$seed';
    return switch (kind) {
      _GeneratedNavPathKind.tasksRoot => '/tasks',
      _GeneratedNavPathKind.tasksChild => '/tasks/$suffix',
      _GeneratedNavPathKind.projectsRoot => '/projects',
      _GeneratedNavPathKind.projectsChild => '/projects/$suffix',
      _GeneratedNavPathKind.calendarRoot => '/calendar',
      _GeneratedNavPathKind.calendarChild => '/calendar/$suffix',
      _GeneratedNavPathKind.habitsRoot => '/habits',
      _GeneratedNavPathKind.habitsChild => '/habits/$suffix',
      _GeneratedNavPathKind.dashboardsRoot => '/dashboards',
      _GeneratedNavPathKind.dashboardsChild => '/dashboards/$suffix',
      _GeneratedNavPathKind.journalRoot => '/journal',
      _GeneratedNavPathKind.journalChild => '/journal/$suffix',
      _GeneratedNavPathKind.settingsRoot => '/settings',
      _GeneratedNavPathKind.settingsChild => '/settings/$suffix',
      _GeneratedNavPathKind.unknown => '/unknown/$suffix',
    };
  }

  @override
  String toString() {
    return '_GeneratedNavPath(kind: $kind, seed: $seed)';
  }
}

class _GeneratedNavScenario {
  const _GeneratedNavScenario({
    required this.projects,
    required this.dailyOs,
    required this.habits,
    required this.dashboards,
    required this.paths,
  });

  final bool projects;
  final bool dailyOs;
  final bool habits;
  final bool dashboards;
  final List<_GeneratedNavPath> paths;

  List<String> get enabledRoots => [
    '/tasks',
    if (projects) '/projects',
    if (dailyOs) '/calendar',
    if (habits) '/habits',
    if (dashboards) '/dashboards',
    '/journal',
    '/settings',
  ];

  String normalize(String path) {
    return _rootForPath(path) == null ? '/tasks' : path;
  }

  int expectedIndexForPath(String path) {
    final normalizedPath = normalize(path);
    final root = _rootForPath(normalizedPath);
    return enabledRoots.indexOf(root!);
  }

  String? _rootForPath(String path) {
    for (final root in enabledRoots) {
      if (path == root || path.startsWith('$root/')) {
        return root;
      }
    }
    return null;
  }

  @override
  String toString() {
    return '_GeneratedNavScenario(projects: $projects, dailyOs: $dailyOs, '
        'habits: $habits, dashboards: $dashboards, paths: $paths)';
  }
}

extension _AnyGeneratedNavScenario on glados.Any {
  glados.Generator<_GeneratedNavPathKind> get navPathKind =>
      glados.AnyUtils(this).choose(_GeneratedNavPathKind.values);

  glados.Generator<_GeneratedNavPath> get navPath =>
      glados.CombinableAny(this).combine2(
        navPathKind,
        glados.IntAnys(this).intInRange(0, 10000),
        (_GeneratedNavPathKind kind, int seed) => _GeneratedNavPath(
          kind: kind,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedNavScenario> get navScenario =>
      glados.CombinableAny(this).combine5(
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        glados.ListAnys(this).listWithLengthInRange(0, 35, navPath),
        (
          bool projects,
          bool dailyOs,
          bool habits,
          bool dashboards,
          List<_GeneratedNavPath> paths,
        ) => _GeneratedNavScenario(
          projects: projects,
          dailyOs: dailyOs,
          habits: habits,
          dashboards: dashboards,
          paths: paths,
        ),
      );
}

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

    glados.Glados(
      glados.any.navScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('matches generated enabled-tab navigation invariants', (
      scenario,
    ) async {
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

      try {
        projectsController.add(scenario.projects);
        dailyOsController.add(scenario.dailyOs);
        habitsController.add(scenario.habits);
        dashboardsController.add(scenario.dashboards);
        await pumpEventQueue();

        final expectedDelegates = [
          navService.tasksDelegate,
          if (scenario.projects) navService.projectsDelegate,
          if (scenario.dailyOs) navService.calendarDelegate,
          if (scenario.habits) navService.habitsDelegate,
          if (scenario.dashboards) navService.dashboardsDelegate,
          navService.journalDelegate,
          navService.settingsDelegate,
        ];
        expect(
          navService.beamerDelegates,
          expectedDelegates,
          reason: scenario.toString(),
        );

        for (final generatedPath in scenario.paths) {
          final path = generatedPath.path;
          navService.setPath(path);

          expect(
            navService.currentPath,
            scenario.normalize(path),
            reason: '$scenario for $generatedPath',
          );
          expect(
            navService.index,
            scenario.expectedIndexForPath(path),
            reason: '$scenario for $generatedPath',
          );
        }
      } finally {
        await navService.dispose();
        await Future.wait([
          projectsController.close(),
          dailyOsController.close(),
          habitsController.close(),
          dashboardsController.close(),
        ]);
      }
    }, tags: 'glados');

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

    test('getIdFromSavedRoute', () async {
      await settingsDb.saveSettingsItem(
        lastRouteKey,
        '/journal/123e4567-e89b-12d3-a456-426614174000',
      );
      final id = await getIdFromSavedRoute();
      expect(id, '123e4567-e89b-12d3-a456-426614174000');
    });

    group('desktop task detail stack', () {
      setUp(() {
        // The NavService singleton is shared across tests. Clear the
        // stack first so each test starts from a clean state and the
        // idempotency guard in `resetDesktopTaskDetail` does not pick
        // up state from a sibling test.
        getIt<NavService>().resetDesktopTaskDetail(null);
      });

      test('resetDesktopTaskDetail seeds the stack with one entry', () {
        final navService = getIt<NavService>()
          ..resetDesktopTaskDetail('task-a');
        expect(navService.desktopTaskDetailStack.value, ['task-a']);
        expect(navService.desktopSelectedTaskId.value, 'task-a');

        navService.resetDesktopTaskDetail(null);
        expect(navService.desktopTaskDetailStack.value, isEmpty);
        expect(navService.desktopSelectedTaskId.value, isNull);
      });

      test('pushDesktopTaskDetail appends and updates selected id', () {
        final navService = getIt<NavService>()
          ..resetDesktopTaskDetail('base')
          ..pushDesktopTaskDetail('linked');

        expect(navService.desktopTaskDetailStack.value, ['base', 'linked']);
        expect(navService.desktopSelectedTaskId.value, 'linked');
      });

      test('pushDesktopTaskDetail ignores the already visible task', () {
        final navService = getIt<NavService>()
          ..resetDesktopTaskDetail('base')
          ..pushDesktopTaskDetail('base');

        expect(navService.desktopTaskDetailStack.value, ['base']);
        expect(navService.desktopSelectedTaskId.value, 'base');
      });

      test('popDesktopTaskDetail removes the top and restores selected id', () {
        final navService = getIt<NavService>()
          ..resetDesktopTaskDetail('base')
          ..pushDesktopTaskDetail('linked-1')
          ..pushDesktopTaskDetail('linked-2')
          ..popDesktopTaskDetail();

        expect(navService.desktopTaskDetailStack.value, ['base', 'linked-1']);
        expect(navService.desktopSelectedTaskId.value, 'linked-1');
      });

      test(
        'popDesktopTaskDetail is a no-op when only one entry remains',
        () {
          final navService = getIt<NavService>()
            ..resetDesktopTaskDetail('only')
            ..popDesktopTaskDetail();

          expect(navService.desktopTaskDetailStack.value, ['only']);
          expect(navService.desktopSelectedTaskId.value, 'only');
        },
      );

      test(
        'resetDesktopTaskDetail preserves a pushed linked-task stack '
        'when the base task id is unchanged',
        () {
          // Simulates Beamer rebuilding `buildPages` for the same URL
          // (theme change, provider change). The trailing reset must not
          // clobber the linked-task layered on top of the base.
          final navService = getIt<NavService>()
            ..resetDesktopTaskDetail('base')
            ..pushDesktopTaskDetail('linked')
            ..resetDesktopTaskDetail('base');

          expect(navService.desktopTaskDetailStack.value, ['base', 'linked']);
          expect(navService.desktopSelectedTaskId.value, 'linked');
        },
      );
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
