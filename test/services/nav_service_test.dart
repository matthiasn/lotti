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

  // Mirrors `NavService._tabSpecs`: Daily OS right after Tasks, then
  // Projects and the remaining flag-gated tabs.
  List<String> get enabledRoots => [
    '/tasks',
    if (dailyOs) '/calendar',
    if (projects) '/projects',
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

/// Bench for the flag-driven NavService tests: wires the four optional-tab
/// flag stream controllers into a fresh NavService and registers teardown.
class _NavFlagBench {
  _NavFlagBench({bool registerTeardown = true}) {
    final settingsDb = SettingsDb(inMemoryDatabase: true);
    final journalDb = mockJournalDbWithMeasurableTypes([]);

    when(() => journalDb.watchConfigFlag(any())).thenAnswer((invocation) {
      final flagName = invocation.positionalArguments.first as String;
      return switch (flagName) {
        enableProjectsFlag => projects.stream,
        enableDailyOsPageFlag => dailyOs.stream,
        enableHabitsPageFlag => habits.stream,
        enableDashboardsPageFlag => dashboards.stream,
        enableEventsFlag => events.stream,
        _ => Stream<bool>.value(false),
      };
    });

    navService = NavService(journalDb: journalDb, settingsDb: settingsDb);
    if (registerTeardown) {
      addTearDown(dispose);
    }
  }

  final projects = StreamController<bool>.broadcast(sync: true);
  final dailyOs = StreamController<bool>.broadcast(sync: true);
  final habits = StreamController<bool>.broadcast(sync: true);
  final dashboards = StreamController<bool>.broadcast(sync: true);
  final events = StreamController<bool>.broadcast(sync: true);
  late final NavService navService;

  /// Emits the four optional-tab flags at once; the Events flag stays off so
  /// existing tab indices/delegates are unaffected (toggle [events] directly to
  /// exercise the Events destination).
  void emitAll({required bool enabled}) {
    projects.add(enabled);
    dailyOs.add(enabled);
    habits.add(enabled);
    dashboards.add(enabled);
    events.add(false);
  }

  Future<void> dispose() async {
    await navService.dispose();
    await Future.wait([
      projects.close(),
      dailyOs.close(),
      habits.close(),
      dashboards.close(),
      events.close(),
    ]);
  }
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

    test('orders Daily OS directly after Tasks when enabled', () {
      final navService = getIt<NavService>();

      expect(
        navService.beamerDelegates,
        [
          navService.tasksDelegate,
          navService.calendarDelegate,
          navService.projectsDelegate,
          navService.habitsDelegate,
          navService.dashboardsDelegate,
          navService.journalDelegate,
          navService.settingsDelegate,
        ],
      );
    });

    glados.Glados(
      glados.any.navScenario,
      // 80 runs cover the bounded path/index input space; each run spins up
      // four StreamControllers and a real in-memory SettingsDb, so the count
      // dominates this test's wall-clock (review speed item).
      glados.ExploreConfig(numRuns: 80),
    ).test('matches generated enabled-tab navigation invariants', (
      scenario,
    ) async {
      // Glados runs many iterations inside one test: dispose explicitly in
      // the finally block instead of stacking addTearDown callbacks.
      final bench = _NavFlagBench(registerTeardown: false);
      final navService = bench.navService;

      try {
        bench.projects.add(scenario.projects);
        bench.dailyOs.add(scenario.dailyOs);
        bench.habits.add(scenario.habits);
        bench.dashboards.add(scenario.dashboards);
        bench.events.add(false);
        await pumpEventQueue();

        final expectedDelegates = [
          navService.tasksDelegate,
          if (scenario.dailyOs) navService.calendarDelegate,
          if (scenario.projects) navService.projectsDelegate,
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
        await bench.dispose();
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
      final bench = _NavFlagBench();
      final navService = bench.navService;

      expect(
        navService.beamerDelegates,
        [
          navService.tasksDelegate,
          navService.journalDelegate,
          navService.settingsDelegate,
        ],
      );
      expect(navService.projectsIndex, -1);

      bench.emitAll(enabled: true);

      expect(
        navService.beamerDelegates,
        [
          navService.tasksDelegate,
          navService.calendarDelegate,
          navService.projectsDelegate,
          navService.habitsDelegate,
          navService.dashboardsDelegate,
          navService.journalDelegate,
          navService.settingsDelegate,
        ],
      );
      expect(navService.projectsIndex, 2);
    });

    test(
      'falls back to Tasks when Projects is disabled while selected',
      () async {
        final bench = _NavFlagBench();
        final navService = bench.navService;

        bench.emitAll(enabled: true);

        navService.beamToNamed('/projects');
        expect(navService.index, navService.projectsIndex);
        expect(navService.currentPath, '/projects');

        bench.projects.add(false);

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

    group('page-enabled flag getters', () {
      test(
        'reports correct flag states when all optional tabs are enabled',
        () {
          // The shared NavService was set up with all four optional flags ON.
          final navService = getIt<NavService>();

          expect(navService.isHabitsPageEnabled, isTrue);
          expect(navService.isDashboardsPageEnabled, isTrue);
          expect(navService.isDailyOsPageEnabled, isTrue);
          expect(navService.isProjectsPageEnabled, isTrue);
        },
      );

      test(
        'reports false for all optional flags when none are enabled',
        () async {
          final localSettingsDb = SettingsDb(inMemoryDatabase: true);
          final localJournalDb = mockJournalDbWithMeasurableTypes([]);
          when(
            () => localJournalDb.watchConfigFlag(any()),
          ).thenAnswer((_) => Stream<bool>.value(false));

          final navService = NavService(
            journalDb: localJournalDb,
            settingsDb: localSettingsDb,
          );
          addTearDown(navService.dispose);
          await pumpEventQueue();

          expect(navService.isHabitsPageEnabled, isFalse);
          expect(navService.isDashboardsPageEnabled, isFalse);
          expect(navService.isDailyOsPageEnabled, isFalse);
          expect(navService.isProjectsPageEnabled, isFalse);
        },
      );
    });

    group('setPath with unknown path falls back to tasks', () {
      test('setPath with unknown path resets index to 0 and path to tasks', () {
        final localSettingsDb = SettingsDb(inMemoryDatabase: true);
        final localJournalDb = mockJournalDbWithMeasurableTypes([]);
        when(
          () => localJournalDb.watchConfigFlag(any()),
        ).thenAnswer((invocation) {
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
          journalDb: localJournalDb,
          settingsDb: localSettingsDb,
        );
        addTearDown(navService.dispose);

        // First navigate somewhere valid.
        navService.setPath('/journal');
        expect(navService.index, navService.journalIndex);
        expect(navService.currentPath, '/journal');

        // Now call setPath with a path that has no matching enabled spec.
        navService.setPath('/completely/unknown/path');
        expect(navService.currentPath, '/tasks');
        expect(navService.index, 0);
      });
    });

    group('getIndexStream', () {
      // getIndexStream() returns the indexStreamController.stream.
      // We verify the return type and that it is in fact a broadcast stream
      // (i.e. supports multiple simultaneous subscribers).
      test('returns a broadcast Stream<int>', () {
        final navService = getIt<NavService>();
        final stream = navService.getIndexStream();
        expect(stream, isA<Stream<int>>());
        expect(stream.isBroadcast, isTrue);
      });

      test('emits the new index after tapIndex switches tab', () async {
        // Use the shared, fully-initialised NavService.
        final navService = getIt<NavService>();

        // Ensure we are on a known tab (tasks = 0) before we subscribe.
        navService.beamToNamed('/tasks'); // ignore: cascade_invocations
        expect(navService.index, 0);

        // Subscribe first, then trigger the navigation so the emission
        // happens after the listener is attached.
        final nextIndex = navService.getIndexStream().first;

        // tapIndex to journal fires setIndex → emitState.
        navService.tapIndex(navService.journalIndex);

        // Await the first emitted value.
        expect(await nextIndex, navService.journalIndex);
      });
    });

    group('beamBack', () {
      test('calls beamBack on the current delegate without throwing', () {
        // beamBack delegates to the active BeamerDelegate. Since Beamer
        // delegates in tests are real (not mocked) we just verify that the
        // call does not throw — the delegate handles its own no-history case.
        final navService = getIt<NavService>()..beamToNamed('/journal');

        // Should not throw even if there is no history to go back to.
        expect(navService.beamBack, returnsNormally);
      });
    });

    group('resetDesktopTaskDetail selectedTaskId sync', () {
      setUp(() {
        getIt<NavService>().resetDesktopTaskDetail(null);
      });

      test(
        'resetDesktopTaskDetail re-syncs desktopSelectedTaskId to stack.last '
        'when it had drifted',
        () {
          final navService = getIt<NavService>()
            ..resetDesktopTaskDetail('base')
            ..pushDesktopTaskDetail('linked');

          expect(navService.desktopSelectedTaskId.value, 'linked');

          // Manually drift desktopSelectedTaskId away from current.last to
          // simulate a state where the notifier is out of sync.
          navService.desktopSelectedTaskId.value = 'something-else';

          // A second reset with the same base task must re-sync the
          // selectedTaskId to current.last ('linked') — line 290 path.
          navService.resetDesktopTaskDetail('base');

          expect(navService.desktopTaskDetailStack.value, ['base', 'linked']);
          expect(navService.desktopSelectedTaskId.value, 'linked');
        },
      );
    });

    group('_handleNavigationFlagsUpdated fallback', () {
      test(
        'falls back to tasks when current path becomes unreachable after '
        'flag update',
        () async {
          final localSettingsDb = SettingsDb(inMemoryDatabase: true);
          final localJournalDb = mockJournalDbWithMeasurableTypes([]);
          final projectsController = StreamController<bool>.broadcast(
            sync: true,
          );
          final dailyOsController = StreamController<bool>.broadcast(
            sync: true,
          );
          final habitsController = StreamController<bool>.broadcast(sync: true);
          final dashboardsController = StreamController<bool>.broadcast(
            sync: true,
          );
          final eventsController = StreamController<bool>.broadcast(sync: true);

          when(
            () => localJournalDb.watchConfigFlag(any()),
          ).thenAnswer((invocation) {
            final flagName = invocation.positionalArguments.first as String;
            return switch (flagName) {
              enableProjectsFlag => projectsController.stream,
              enableDailyOsPageFlag => dailyOsController.stream,
              enableHabitsPageFlag => habitsController.stream,
              enableDashboardsPageFlag => dashboardsController.stream,
              enableEventsFlag => eventsController.stream,
              _ => Stream<bool>.value(false),
            };
          });

          final navService = NavService(
            journalDb: localJournalDb,
            settingsDb: localSettingsDb,
          );
          addTearDown(() async {
            await navService.dispose();
            await Future.wait([
              projectsController.close(),
              dailyOsController.close(),
              habitsController.close(),
              dashboardsController.close(),
              eventsController.close(),
            ]);
          });

          // Enable all optional tabs and navigate to habits.
          projectsController.add(true);
          dailyOsController.add(true);
          habitsController.add(true);
          dashboardsController.add(true);
          eventsController.add(false);

          navService.beamToNamed('/habits');
          expect(navService.currentPath, '/habits');
          expect(navService.index, navService.habitsIndex);

          // Disable habits — the current path is now unreachable, triggering
          // the matchingSpec == null branch in _handleNavigationFlagsUpdated.
          habitsController.add(false);

          expect(navService.currentPath, '/tasks');
          expect(navService.index, 0);
        },
      );
    });
  });
}
