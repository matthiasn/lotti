import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
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
  goalsRoot,
  goalsChild,
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
      _GeneratedNavPathKind.goalsRoot => '/goals',
      _GeneratedNavPathKind.goalsChild => '/goals/$suffix',
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
    required this.dailyOs,
    required this.projects,
    required this.unifiedGoals,
    required this.habits,
    required this.dashboards,
    required this.paths,
  });

  final bool dailyOs;
  final bool projects;
  final bool unifiedGoals;
  final bool habits;
  final bool dashboards;
  final List<_GeneratedNavPath> paths;

  // Mirrors `NavService._tabSpecs`: Daily OS sits right after Tasks when its
  // rollout flag is enabled, then Projects and the remaining flag-gated tabs.
  List<String> get enabledRoots => [
    '/tasks',
    if (dailyOs) '/calendar',
    if (projects) '/projects',
    if (unifiedGoals) '/goals',
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
    return '_GeneratedNavScenario(dailyOs: $dailyOs, projects: $projects, '
        'unifiedGoals: $unifiedGoals, habits: $habits, '
        'dashboards: $dashboards, paths: $paths)';
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
      glados.CombinableAny(this).combine6(
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        glados.ListAnys(this).listWithLengthInRange(0, 35, navPath),
        (
          bool dailyOs,
          bool projects,
          bool unifiedGoals,
          bool habits,
          bool dashboards,
          List<_GeneratedNavPath> paths,
        ) => _GeneratedNavScenario(
          dailyOs: dailyOs,
          projects: projects,
          unifiedGoals: unifiedGoals,
          habits: habits,
          dashboards: dashboards,
          paths: paths,
        ),
      );
}

/// Bench for the flag-driven NavService tests: wires the optional-tab flag
/// stream controllers (one per flag-gated destination) into a fresh
/// NavService and registers teardown.
class _NavFlagBench {
  _NavFlagBench({bool registerTeardown = true, SettingsDb? settingsDb}) {
    this.settingsDb = settingsDb ?? SettingsDb(inMemoryDatabase: true);
    final journalDb = mockJournalDbWithMeasurableTypes([]);

    when(() => journalDb.watchConfigFlag(any())).thenAnswer((invocation) {
      final flagName = invocation.positionalArguments.first as String;
      return switch (flagName) {
        enableDailyOsPageFlag => dailyOs.stream,
        enableProjectsFlag => projects.stream,
        enableHabitsPageFlag => habits.stream,
        enableDashboardsPageFlag => dashboards.stream,
        enableEventsFlag => events.stream,
        enableUnifiedGoalsFlag => unifiedGoals.stream,
        enableRelationshipsFlag => relationships.stream,
        _ => Stream<bool>.value(false),
      };
    });

    navService = NavService(journalDb: journalDb, settingsDb: this.settingsDb);
    if (registerTeardown) {
      addTearDown(dispose);
    }
  }

  /// Shared across benches when a test needs a second service generation to
  /// read what the first one persisted.
  late final SettingsDb settingsDb;

  final dailyOs = StreamController<bool>.broadcast(sync: true);
  final projects = StreamController<bool>.broadcast(sync: true);
  final habits = StreamController<bool>.broadcast(sync: true);
  final dashboards = StreamController<bool>.broadcast(sync: true);
  final events = StreamController<bool>.broadcast(sync: true);
  final unifiedGoals = StreamController<bool>.broadcast(sync: true);
  final relationships = StreamController<bool>.broadcast(sync: true);
  late final NavService navService;

  /// Emits all optional-tab flags at once. Only [dailyOs], [projects],
  /// [habits] and [dashboards] take `enabled`; [events], [unifiedGoals] and
  /// [relationships] stay off so existing tab indices/delegates are
  /// unaffected (toggle those three directly to exercise their
  /// destinations).
  void emitAll({required bool enabled}) {
    dailyOs.add(enabled);
    projects.add(enabled);
    habits.add(enabled);
    dashboards.add(enabled);
    events.add(false);
    unifiedGoals.add(false);
    relationships.add(false);
  }

  Future<void> dispose() async {
    await navService.dispose();
    await Future.wait([
      dailyOs.close(),
      projects.close(),
      habits.close(),
      dashboards.close(),
      events.close(),
      unifiedGoals.close(),
      relationships.close(),
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
          enableDailyOsPageFlag,
          enableProjectsFlag,
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

    test('orders Daily OS directly after Tasks', () {
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
      // five StreamControllers and a real in-memory SettingsDb, so the count
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
        bench.dailyOs.add(scenario.dailyOs);
        bench.projects.add(scenario.projects);
        bench.unifiedGoals.add(scenario.unifiedGoals);
        bench.habits.add(scenario.habits);
        bench.dashboards.add(scenario.dashboards);
        bench.events.add(false);
        bench.relationships.add(false);
        await pumpEventQueue();

        final expectedDelegates = [
          navService.tasksDelegate,
          if (scenario.dailyOs) navService.calendarDelegate,
          if (scenario.projects) navService.projectsDelegate,
          if (scenario.unifiedGoals) navService.goalsDelegate,
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
      'falls back to Tasks when Daily OS is disabled while selected',
      () async {
        final bench = _NavFlagBench();
        final navService = bench.navService;

        bench.emitAll(enabled: true);

        navService.beamToNamed('/calendar');
        expect(navService.index, navService.calendarIndex);
        expect(navService.currentPath, '/calendar');

        bench.dailyOs.add(false);

        expect(navService.index, navService.tasksIndex);
        expect(navService.currentPath, '/tasks');
        expect(navService.calendarIndex, -1);
      },
    );

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

    test('getIdFromSavedRoute resolves the ACTIVE tab, not the persisted '
        'route', () async {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      final navService = getIt<NavService>();
      addTearDown(() => navService.beamToNamed('/tasks'));

      // A stale persisted route must not leak into creation context…
      await settingsDb.saveSettingsItem(lastRouteKey, '/journal/$uuid');
      navService.beamToNamed('/tasks');
      expect(await getIdFromSavedRoute(), isNull);

      // …while the active tab's live entity route does provide it.
      navService.beamToNamed('/journal/$uuid');
      expect(await getIdFromSavedRoute(), uuid);

      // Switching tabs by INDEX (a nav-bar tap persists nothing) drops the
      // context: the user already left the entity.
      navService.setIndex(navService.beamerDelegates.length - 1);
      expect(await getIdFromSavedRoute(), isNull);
    });

    test('creationContextIdForRoute yields NO context on unified Goals '
        'routes — the UUID there is an agent, not a journal parent', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(creationContextIdForRoute('/journal/$uuid'), uuid);
      expect(creationContextIdForRoute('/goals/details/$uuid'), isNull);
      expect(creationContextIdForRoute('/tasks'), isNull);
      expect(creationContextIdForRoute(null), isNull);
    });

    test('People routes yield no global creation context because BasicLink '
        'does not represent relationship ownership', () {
      expect(
        creationContextIdForRoute(
          '/people/123e4567-e89b-12d3-a456-426614174000',
        ),
        isNull,
      );
    });

    group('desktop selected entry id', () {
      test('starts unselected and notifies logbook listeners on change', () {
        final navService = getIt<NavService>();
        addTearDown(() => navService.desktopSelectedEntryId.value = null);
        expect(navService.desktopSelectedEntryId.value, isNull);

        final seen = <String?>[];
        void listener() => seen.add(navService.desktopSelectedEntryId.value);
        navService.desktopSelectedEntryId.addListener(listener);
        addTearDown(
          () => navService.desktopSelectedEntryId.removeListener(listener),
        );

        navService.desktopSelectedEntryId.value = 'entry-1';
        navService.desktopSelectedEntryId.value = null;
        expect(seen, ['entry-1', null]);
      });

      test('is independent of the task detail selection', () {
        final navService = getIt<NavService>()
          ..resetDesktopTaskDetail('task-a');
        addTearDown(() {
          navService
            ..resetDesktopTaskDetail(null)
            ..desktopSelectedEntryId.value = null;
        });

        navService.desktopSelectedEntryId.value = 'entry-1';
        expect(navService.desktopSelectedTaskId.value, 'task-a');

        navService.resetDesktopTaskDetail(null);
        expect(navService.desktopSelectedEntryId.value, 'entry-1');
      });
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
          // The shared NavService was set up with every optional flag ON.
          final navService = getIt<NavService>();

          expect(navService.isHabitsPageEnabled, isTrue);
          expect(navService.isDashboardsPageEnabled, isTrue);
          expect(navService.isDailyOsPageEnabled, isTrue);
          expect(navService.isProjectsPageEnabled, isTrue);
        },
      );

      test('events index resolves to the enabled Events delegate', () async {
        final bench = _NavFlagBench();
        bench.dailyOs.add(false);
        bench.projects.add(false);
        bench.habits.add(false);
        bench.dashboards.add(false);
        bench.events.add(true);
        bench.unifiedGoals.add(false);
        bench.relationships.add(false);
        await pumpEventQueue();

        expect(bench.navService.isEventsPageEnabled, isTrue);
        expect(
          bench.navService.delegateByIndex(bench.navService.eventsIndex),
          same(bench.navService.eventsDelegate),
        );
      });

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
          expect(navService.isEventsPageEnabled, isFalse);
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

        // The stream replays the current index to every new subscriber, so
        // skip that and wait for the emission the navigation causes.
        final nextIndex = navService.getIndexStream().skip(1).first;

        // tapIndex to journal fires setIndex → emitState.
        navService.tapIndex(navService.journalIndex);

        // Await the first emitted value after the replay.
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

      test('falls back to the tab root when there is no history to pop', () {
        final bench = _NavFlagBench()..emitAll(enabled: true);
        final navService = bench.navService;

        // A caller outside this service can replace the tab's only history
        // entry with a detail route — restore used to do exactly that. The
        // delegate then cannot beam back, and on mobile the detail route
        // hides the bottom bar: without a fallback the user is locked in.
        navService.tasksDelegate.beamToReplacementNamed('/tasks/task-3');
        expect(navService.tasksDelegate.canBeamBack, isFalse);

        navService.beamBack();

        expect(navService.routeForTab('/tasks'), '/tasks');
        // The fallback REPLACES the dead route instead of stacking the root on
        // top of it: leaving the detail underneath would make the very next
        // back drop the user straight back into the page they just escaped.
        expect(navService.tasksDelegate.canBeamBack, isFalse);
        navService.beamBack();
        expect(navService.routeForTab('/tasks'), '/tasks');
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

    group('goals tab flag', () {
      test('enable_unified_goals shows the Goals tab between projects and '
          'habits, and disabling it falls back to tasks', () async {
        final bench = _NavFlagBench();
        final navService = bench.navService;
        bench.emitAll(enabled: true);

        // Off (the emitAll default): the delegate is absent and the index
        // getter reports -1 — the value the habits controller relies on to
        // treat a disabled Goals tab as never-active.
        expect(navService.isUnifiedGoalsPageEnabled, isFalse);
        expect(navService.goalsIndex, -1);

        bench.unifiedGoals.add(true);

        expect(navService.isUnifiedGoalsPageEnabled, isTrue);
        // The Goals tab occupies the slot directly before Habits (the design
        // handover's cutover position).
        expect(
          navService.goalsIndex,
          navService.beamerDelegates.indexOf(navService.projectsDelegate) + 1,
        );
        expect(navService.habitsIndex, navService.goalsIndex + 1);

        navService.beamToNamed('/goals');
        expect(navService.currentPath, '/goals');
        expect(navService.index, navService.goalsIndex);

        bench.unifiedGoals.add(false);
        expect(navService.isUnifiedGoalsPageEnabled, isFalse);
        expect(
          navService.beamerDelegates.contains(navService.goalsDelegate),
          isFalse,
        );
        expect(navService.currentPath, '/tasks');
      });
    });

    group('relationships tab flag', () {
      test('enable_relationships shows the People tab right before journal, '
          'and disabling it falls back to tasks', () async {
        final bench = _NavFlagBench();
        final navService = bench.navService;
        bench.emitAll(enabled: true);
        bench.relationships.add(true);

        expect(navService.isRelationshipsPageEnabled, isTrue);
        expect(
          navService.beamerDelegates.indexOf(
            navService.relationshipsDelegate,
          ),
          navService.beamerDelegates.indexOf(navService.journalDelegate) - 1,
        );

        navService.setPath('/people/rel-1');
        expect(navService.currentPath, '/people/rel-1');

        bench.relationships.add(false);
        expect(navService.isRelationshipsPageEnabled, isFalse);
        expect(
          navService.beamerDelegates.contains(
            navService.relationshipsDelegate,
          ),
          isFalse,
        );
        expect(navService.currentPath, '/tasks');
      });
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
          final habitsController = StreamController<bool>.broadcast(sync: true);
          final dashboardsController = StreamController<bool>.broadcast(
            sync: true,
          );
          final dailyOsController = StreamController<bool>.broadcast(
            sync: true,
          );
          final eventsController = StreamController<bool>.broadcast(sync: true);
          final unifiedGoalsController = StreamController<bool>.broadcast(
            sync: true,
          );
          final relationshipsController = StreamController<bool>.broadcast(
            sync: true,
          );

          when(
            () => localJournalDb.watchConfigFlag(any()),
          ).thenAnswer((invocation) {
            final flagName = invocation.positionalArguments.first as String;
            return switch (flagName) {
              enableProjectsFlag => projectsController.stream,
              enableHabitsPageFlag => habitsController.stream,
              enableDashboardsPageFlag => dashboardsController.stream,
              enableDailyOsPageFlag => dailyOsController.stream,
              enableEventsFlag => eventsController.stream,
              enableUnifiedGoalsFlag => unifiedGoalsController.stream,
              enableRelationshipsFlag => relationshipsController.stream,
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
              habitsController.close(),
              dashboardsController.close(),
              dailyOsController.close(),
              eventsController.close(),
              unifiedGoalsController.close(),
              relationshipsController.close(),
            ]);
          });

          // Enable all optional tabs and navigate to habits.
          projectsController.add(true);
          habitsController.add(true);
          dashboardsController.add(true);
          dailyOsController.add(true);
          eventsController.add(false);
          unifiedGoalsController.add(false);
          relationshipsController.add(false);

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

    group('restoring a flag-gated tab', () {
      /// Persists [route] as the active tab's position through one service
      /// generation, then returns a fresh generation sharing its SettingsDb —
      /// still before its flag streams have emitted, exactly as at boot.
      Future<_NavFlagBench> restoredBenchFor(String route) async {
        final first = _NavFlagBench(registerTeardown: false)
          ..emitAll(enabled: true);
        first.navService.beamToNamed(route);
        await pumpEventQueue();
        await first.dispose();

        final second = _NavFlagBench(settingsDb: first.settingsDb);
        await second.navService.restoreNavigationState();
        return second;
      }

      test('lands on it once the config flags say it exists', () async {
        final bench = await restoredBenchFor('/projects/project-3');

        // Before the flags emit, Projects is not even in the enabled tab
        // list — the tab cannot be selected yet, but its route is already
        // restored.
        expect(bench.navService.index, 0);
        expect(
          bench.navService.projectsDelegate.configuration.uri.path,
          '/projects/project-3',
        );

        bench.emitAll(enabled: true);

        expect(bench.navService.index, bench.navService.projectsIndex);
        expect(bench.navService.currentPath, '/projects/project-3');
      });

      test(
        'falls back to Tasks when that tab is now behind a disabled flag',
        () async {
          final bench = await restoredBenchFor('/projects/project-3');

          bench.emitAll(enabled: false);

          expect(bench.navService.index, 0);
          expect(bench.navService.currentPath, '/tasks');
        },
      );

      test('the pending tab is consumed once, not re-applied on later flag '
          'changes', () async {
        final bench = await restoredBenchFor('/projects/project-3');
        bench.emitAll(enabled: true);
        expect(bench.navService.index, bench.navService.projectsIndex);

        // The user moves on; a later flag change must not yank them back to
        // where they happened to be at boot.
        bench.navService.beamToNamed('/journal');
        expect(bench.navService.index, bench.navService.journalIndex);

        bench.emitAll(enabled: true);

        expect(bench.navService.index, bench.navService.journalIndex);
        expect(bench.navService.currentPath, '/journal');
      });

      test(
        'nothing is written while the restore read is still in flight',
        () async {
          // A slow settings read, so the config flags can land in the middle
          // of one — the window in which a write would target the very row
          // being read, with the not-yet-restored default.
          final settingsDb = MockSettingsDb();
          final readGate = Completer<String?>();
          when(
            () => settingsDb.itemByKey(navStateKey),
          ).thenAnswer((_) => readGate.future);
          when(
            () => settingsDb.itemByKey(lastRouteKey),
          ).thenAnswer((_) async => null);
          final writes = <String>[];
          when(() => settingsDb.saveSettingsItem(any(), any())).thenAnswer((
            invocation,
          ) async {
            writes.add(invocation.positionalArguments[1] as String);
            return 1;
          });

          final bench = _NavFlagBench(settingsDb: settingsDb);
          final restoring = bench.navService.restoreNavigationState();

          bench.emitAll(enabled: true);
          await pumpEventQueue();
          expect(
            writes,
            isEmpty,
            reason: 'the flag handler must not persist over the pending read',
          );

          readGate.complete(
            const NavStateSnapshot(
              activeRootPath: '/projects',
              routes: {'/projects': '/projects/project-3'},
            ).encode(),
          );
          await restoring;
          await pumpEventQueue();

          expect(bench.navService.index, bench.navService.projectsIndex);
          expect(bench.navService.currentPath, '/projects/project-3');
          expect(writes, isNotEmpty, reason: 'restore persists once it lands');
        },
      );

      test('a corrupt saved state degrades to the Tasks landing', () async {
        final settingsDb = SettingsDb(inMemoryDatabase: true);
        await settingsDb.saveSettingsItem(navStateKey, '{not json');

        final bench = _NavFlagBench(settingsDb: settingsDb);
        await bench.navService.restoreNavigationState();
        bench.emitAll(enabled: true);

        expect(bench.navService.index, 0);
        expect(bench.navService.currentPath, '/tasks');
      });

      test(
        'a restored detail route can be backed out of',
        () async {
          final settingsDb = SettingsDb(inMemoryDatabase: true);
          await settingsDb.saveSettingsItem(
            navStateKey,
            const NavStateSnapshot(
              activeRootPath: '/tasks',
              routes: {'/tasks': '/tasks/task-7'},
            ).encode(),
          );

          final bench = _NavFlagBench(settingsDb: settingsDb);
          await bench.navService.restoreNavigationState();
          bench.emitAll(enabled: true);
          expect(bench.navService.routeForTab('/tasks'), '/tasks/task-7');

          // Restoring must leave the tab root UNDER the detail route. The
          // mobile shell hides the bottom bar on `/tasks/<id>`, so if the
          // restored history were one entry long the back button would be
          // dead and the user locked into the detail page — with nothing on
          // it at all when the task has since been deleted.
          expect(bench.navService.tasksDelegate.canBeamBack, isTrue);
          bench.navService.beamBack();
          await pumpEventQueue();

          expect(bench.navService.routeForTab('/tasks'), '/tasks');
        },
      );

      test('a pre-JSON NAV_LAST_ROUTE row still restores its tab', () async {
        final settingsDb = SettingsDb(inMemoryDatabase: true);
        await settingsDb.saveSettingsItem(lastRouteKey, '/habits/habit-9');

        final bench = _NavFlagBench(settingsDb: settingsDb);
        await bench.navService.restoreNavigationState();
        bench.emitAll(enabled: true);

        expect(bench.navService.index, bench.navService.habitsIndex);
        expect(
          bench.navService.habitsDelegate.configuration.uri.path,
          '/habits/habit-9',
        );
      });
    });

    group('routes that bypass NavService', () {
      test('backing out of a detail page is what gets persisted', () async {
        final bench = _NavFlagBench()..emitAll(enabled: true);
        final navService = bench.navService..beamToNamed('/tasks/task-9');
        await pumpEventQueue();
        expect(navService.routeForTab('/tasks'), '/tasks/task-9');

        // `beamBack` moves the delegate without going through any of this
        // service's navigation methods. A route map maintained on the side
        // would still be pointing at the detail, and the next launch would
        // reopen the page the user just backed out of.
        navService.beamBack();
        await pumpEventQueue();

        expect(navService.routeForTab('/tasks'), '/tasks');
        expect(
          await navService.getSavedRoute(),
          '/tasks',
          reason: 'the persisted row must agree with the live stack',
        );
      });

      test('a delegate beamed directly is still persisted', () async {
        final bench = _NavFlagBench()..emitAll(enabled: true);
        final navService = bench.navService;

        // What `settings_tree_url_sync` does via
        // `Beamer.of(context).beamToReplacementNamed`, and what
        // `linked_tasks_widget` does straight on the delegate.
        navService.settingsDelegate.beamToReplacementNamed(
          '/settings/advanced',
        );
        await pumpEventQueue();

        expect(navService.routeForTab('/settings'), '/settings/advanced');
        expect(
          NavStateSnapshot.decode(
            await bench.settingsDb.itemByKey(navStateKey),
          )?.routes['/settings'],
          '/settings/advanced',
        );
      });
    });

    group('background navigation', () {
      test('beamWithinTab moves the tab without activating it', () async {
        final bench = _NavFlagBench()..emitAll(enabled: true);
        final navService = bench.navService;

        expect(navService.index, 0, reason: 'the user is on Tasks');
        // Skip the replayed current index; only a CHANGE matters here.
        final emitted = <int>[];
        final sub = navService.getIndexStream().skip(1).listen(emitted.add);
        addTearDown(sub.cancel);

        // What the logbook's newest-entry auto-selection does from the
        // background Logbook tab. Through `beamToNamed` this yanked the user
        // off Tasks onto Logbook on every crossing of the desktop breakpoint.
        navService.beamWithinTab('/journal/entry-42');
        await pumpEventQueue();

        expect(navService.index, 0);
        expect(navService.currentPath, '/tasks');
        expect(emitted, isEmpty);
        expect(
          navService.journalDelegate.configuration.uri.path,
          '/journal/entry-42',
        );
        expect(navService.routeForTab('/journal'), '/journal/entry-42');

        // It is still where the user will find it on returning to that tab —
        // and after a restart.
        navService.tapIndex(navService.journalIndex);
        expect(navService.currentPath, '/journal/entry-42');

        // Once Logbook IS the active tab, the same call does move the
        // service's notion of where the user is — auto-select re-runs there
        // whenever the selection is cleared.
        navService.beamWithinTab('/journal/entry-43');
        await pumpEventQueue();

        expect(navService.currentPath, '/journal/entry-43');
        expect(navService.index, navService.journalIndex);
      });

      test('beamWithinTab ignores a path no tab owns', () async {
        final bench = _NavFlagBench()..emitAll(enabled: true);

        bench.navService.beamWithinTab('/nowhere/at-all');

        expect(bench.navService.index, 0);
        expect(bench.navService.currentPath, '/tasks');
      });
    });

    group('storage failures are non-fatal', () {
      test('an unreadable settings row does not abort bootstrap', () async {
        final settingsDb = MockSettingsDb();
        when(() => settingsDb.itemByKey(any())).thenThrow(
          Exception('settings db unavailable'),
        );
        when(
          () => settingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);

        final bench = _NavFlagBench(settingsDb: settingsDb);

        // `registerSingletons` awaits this before `runApp`; letting the read
        // throw would take the whole app down instead of landing on Tasks.
        await expectLater(
          bench.navService.restoreNavigationState(),
          completes,
        );
        bench.emitAll(enabled: true);

        expect(bench.navService.index, 0);
        expect(bench.navService.currentPath, '/tasks');
      });

      test(
        'a failing write does not escape as an unhandled async error',
        () async {
          final settingsDb = MockSettingsDb();
          when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
          when(
            () => settingsDb.saveSettingsItem(any(), any()),
          ).thenThrow(Exception('disk full'));

          // Swallowed, but not silently — a storage problem the user can do
          // nothing about still has to be diagnosable.
          final logger = MockDomainLogger();
          when(
            () => logger.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).thenReturn(null);
          getIt.registerSingleton<DomainLogger>(logger);
          addTearDown(() => getIt.unregister<DomainLogger>());

          final bench = _NavFlagBench(settingsDb: settingsDb)
            ..emitAll(enabled: true);

          // Every persist is fire-and-forget, so an uncaught failure would
          // surface as an unhandled async error on EVERY navigation for as long
          // as the storage problem lasts.
          final errors = <Object>[];
          await runZonedGuarded(() async {
            bench.navService.beamToNamed('/journal');
            await pumpEventQueue();
          }, (error, stack) => errors.add(error));

          expect(errors, isEmpty);
          expect(
            bench.navService.index,
            bench.navService.journalIndex,
            reason: 'navigation itself still succeeds',
          );
          verify(
            () => logger.error(
              LogDomain.navigation,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'persistState',
            ),
          ).called(greaterThan(0));
        },
      );
    });

    group('stale index', () {
      test(
        'persists the first enabled tab when the index is out of range',
        () async {
          final bench = _NavFlagBench()..emitAll(enabled: true);
          final navService = bench.navService..beamToNamed('/habits');
          await pumpEventQueue();

          // Turning flags off shrinks the tab list under a larger index — the
          // same staleness the shell guards with `clampNavigationIndex`. A save
          // landing in that window must not index past the end of the list.
          navService.index = 99;
          await navService.persistNamedRoute('/habits');

          expect(
            NavStateSnapshot.decode(
              await bench.settingsDb.itemByKey(navStateKey),
            )?.activeRootPath,
            '/tasks',
          );
        },
      );
    });

    group('index stream', () {
      test('replays the current index to a late subscriber', () async {
        final bench = _NavFlagBench()..emitAll(enabled: true);
        final navService = bench.navService..beamToNamed('/journal');
        expect(navService.index, navService.journalIndex);

        // The shell and the per-tab controllers all subscribe AFTER restore
        // has already selected the tab — restore runs before `runApp`. A
        // non-replaying broadcast stream drops that emission and leaves every
        // one of them believing the app is on Tasks.
        final seen = await navService.getIndexStream().first;

        expect(seen, navService.journalIndex);
      });
    });

    group('form-factor changes', () {
      testWidgets('crossing the breakpoint re-renders every tab for the new '
          'layout', (tester) async {
        // A frame has to actually run for the deferred rebuild to land.
        await tester.pumpWidget(const SizedBox.shrink());
        final bench = _NavFlagBench()..emitAll(enabled: true);
        final navService = bench.navService;

        var tasksRebuilds = 0;
        void countTasks() => tasksRebuilds++;
        navService.tasksDelegate.addListener(countTasks);
        addTearDown(() => navService.tasksDelegate.removeListener(countTasks));

        // The shell keeps the nav subtree alive across the breakpoint, so
        // nothing rebuilds the delegates by accident — but the locations
        // branch on this flag to decide whether a detail is a pushed page or
        // a right-hand pane, so the change has to reach them.
        navService.isDesktopMode = true;
        expect(
          tasksRebuilds,
          0,
          reason: 'assigned during build — must not notify synchronously',
        );

        // Production assigns this from `AppScreen.build`, so a frame is
        // always in flight; drive one here the same way.
        await tester.pumpWidget(const SizedBox(width: 1));

        expect(tasksRebuilds, 1);

        // An unchanged assignment is not a layout change.
        navService.isDesktopMode = true;
        await tester.pumpWidget(const SizedBox(width: 2));
        expect(tasksRebuilds, 1);
      });
    });

    group('landing tab per service generation', () {
      // Every tab's BeamerDelegate is a top-level final, so it survives
      // `getIt.reset()` — a profile switch replaces this service, the
      // databases and the widget tree, but not them.
      NavService buildGeneration() => NavService(
        journalDb: mockJournalDb,
        settingsDb: settingsDb,
      );

      test(
        "a new generation lands on Tasks and forgets the previous world's "
        'routes',
        () async {
          // The user walks into the Logbook and opens an entry, then leaves
          // the app sitting there — e.g. inside the demo world.
          final previousWorld = buildGeneration()
            ..beamToNamed('/journal/demo-entry-id');
          expect(
            previousWorld.currentPath,
            '/journal/demo-entry-id',
          );
          expect(
            previousWorld.index,
            previousWorld.journalIndex,
          );
          await previousWorld.dispose();

          // Switching profiles bootstraps a fresh service generation.
          final nextWorld = buildGeneration();
          addTearDown(nextWorld.dispose);

          expect(
            nextWorld.index,
            0,
            reason: 'a new world must land on the Tasks tab',
          );
          expect(nextWorld.currentPath, '/tasks');
          expect(
            nextWorld.journalDelegate.configuration.uri.path,
            '/journal',
            reason:
                'the Logbook tab still pointed at an entry id from the world '
                'the user just left',
          );
          expect(nextWorld.tasksDelegate.configuration.uri.path, '/tasks');
        },
      );

      test('cold start returns to the tab and route it was left on', () async {
        final previousSession = buildGeneration()
          // Another tab was visited earlier in that session and must come
          // back where it stood too, not at its root.
          ..beamToNamed('/settings/advanced')
          ..beamToNamed('/journal/entry-7');
        // The writes are fire-and-forget; let them land.
        await pumpEventQueue();
        await previousSession.dispose();

        // The delegates are top-level finals, so a fresh generation would
        // inherit them regardless — reset them the way a cold process would.
        final restored = buildGeneration();
        addTearDown(restored.dispose);
        expect(restored.currentPath, '/tasks', reason: 'before restore');

        await restored.restoreNavigationState();

        expect(restored.currentPath, '/journal/entry-7');
        expect(
          restored.journalDelegate.configuration.uri.path,
          '/journal/entry-7',
        );
        expect(
          restored.settingsDelegate.configuration.uri.path,
          '/settings/advanced',
          reason: 'each tab keeps its own place, not just the active one',
        );
        // The active tab itself only lands once the flag streams have said
        // which tabs exist — this harness emits them synchronously at
        // construction, so it is already applied.
        expect(restored.index, restored.journalIndex);
      });

      test('every tab root is restored, including disabled ones', () async {
        final previousWorld = buildGeneration();
        // Events is disabled in this harness; its delegate can still be
        // carrying a route from a world where the flag was on.
        previousWorld.eventsDelegate.beamToReplacementNamed('/events/stale-id');
        await previousWorld.dispose();

        final nextWorld = buildGeneration();
        addTearDown(nextWorld.dispose);

        expect(
          nextWorld.eventsDelegate.configuration.uri.path,
          '/events',
          reason: 'a disabled tab kept a stale route behind its flag',
        );
      });
    });
  });
}
