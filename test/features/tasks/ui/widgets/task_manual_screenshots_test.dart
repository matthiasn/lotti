/// Deterministic manual screenshots for the production Tasks surfaces.
///
/// Opt in with `LOTTI_SCREENSHOT_DIR=<external-dir>`; generated PNGs are
/// staging inputs for the manual media manifest and are never committed here.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/manual_demo_world.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';
import '../pages/task_details_page_test_helpers.dart';

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'task manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  late ManualDemoWorld world;
  late Directory documentsDirectory;
  late PagingController<int, JournalEntity> pagingController;
  late FakeJournalPageController pageController;
  late ValueNotifier<String?> selectedTaskId;
  late ValueNotifier<List<String>> detailStack;

  setUpAll(() async {
    registerAllFallbackValues();
    await loadScreenshotFonts();
  });

  setUp(() async {
    world = ManualDemoWorld.penguinLogistics();
    documentsDirectory = Directory.systemTemp.createTempSync(
      'lotti-manual-tasks-',
    );
    await world.installMedia(documentsDirectory);

    final entitiesCache = MockEntitiesCacheService();
    final navService = MockNavService();
    final timeService = MockTimeService();
    final persistenceLogic = MockPersistenceLogic();
    final userActivityService = MockUserActivityService();
    final editorStateService = MockEditorStateService();

    selectedTaskId = ValueNotifier<String?>(world.orbitalHabitatTask.meta.id);
    detailStack = ValueNotifier<List<String>>(<String>[
      world.orbitalHabitatTask.meta.id,
    ]);

    when(userActivityService.updateActivity).thenReturn(null);
    when(
      () => navService.beamToNamed(any(), data: any(named: 'data')),
    ).thenReturn(null);
    when(() => navService.desktopSelectedTaskId).thenReturn(selectedTaskId);
    when(() => navService.desktopTaskDetailStack).thenReturn(detailStack);
    when(() => navService.isDesktopMode).thenReturn(true);
    when(timeService.getStream).thenAnswer((_) => const Stream.empty());
    when(() => timeService.linkedFrom).thenReturn(null);
    when(
      () => editorStateService.getUnsavedStream(any(), any()),
    ).thenAnswer((_) => const Stream.empty());

    when(() => entitiesCache.sortedCategories).thenReturn([world.category]);
    when(() => entitiesCache.sortedLabels).thenReturn(world.labels);
    when(() => entitiesCache.showPrivateEntries).thenReturn(true);
    when(
      () => entitiesCache.getCategoryById(manualDemoCategoryId),
    ).thenReturn(world.category);
    for (final label in world.labels) {
      when(() => entitiesCache.getLabelById(label.id)).thenReturn(label);
    }

    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(documentsDirectory)
          ..registerSingleton<EntitiesCacheService>(entitiesCache)
          ..registerSingleton<NavService>(navService)
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<PersistenceLogic>(persistenceLogic)
          ..registerSingleton<UserActivityService>(userActivityService)
          ..registerSingleton<EditorStateService>(editorStateService)
          ..registerSingleton<LinkService>(MockLinkService())
          ..registerSingleton<HealthImport>(MockHealthImport());
      },
    );

    when(
      () => mocks.journalDb.journalEntityById(any()),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      return world.entityById(id);
    });
    when(
      () => mocks.journalDb.getCategoryById(manualDemoCategoryId),
    ).thenAnswer((_) async => world.category);
    when(
      () => mocks.journalDb.getProjectsForCategory(any()),
    ).thenAnswer((_) async => <ProjectEntry>[]);
    when(mocks.journalDb.getVisibleProjects).thenAnswer(
      (_) async => <ProjectEntry>[],
    );
    when(
      () => mocks.journalDb.getTaskEstimatesByIds(any()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as Set<String>;
      return {
        for (final id in ids)
          id: world.entityById(id) is Task
              ? (world.entityById(id)! as Task).data.estimate
              : null,
      };
    });
    when(
      () => mocks.journalDb.getBulkLinkedTimeSpans(any()),
    ).thenAnswer((_) async => <String, List<LinkedEntityTimeSpan>>{});
    when(
      () => mocks.journalDb.getLinkedEntities(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);
    when(mocks.journalDb.watchConfigFlags).thenAnswer(
      (_) => const Stream.empty(),
    );

    pagingController =
        PagingController<int, JournalEntity>(
            getNextPageKey: (_) => null,
            fetchPage: (_) async => const <JournalEntity>[],
          )
          ..value = PagingState<int, JournalEntity>(
            pages: [world.tasks],
            keys: const [0],
            hasNextPage: false,
          );
    pageController = FakeJournalPageController(
      JournalPageState(
        showTasks: true,
        pagingController: pagingController,
        taskStatuses: const ['OPEN', 'IN PROGRESS', 'GROOMED'],
        selectedTaskStatuses: const {'OPEN', 'IN PROGRESS', 'GROOMED'},
        selectedEntryTypes: const ['Task'],
        sortOption: TaskSortOption.byDueDate,
      ),
    );
  });

  tearDown(() async {
    pagingController.dispose();
    selectedTaskId.dispose();
    detailStack.dispose();
    await tearDownTestGetIt();
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
  });

  for (final device in [proDevice, desktopDevice]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final viewport = device.isPhone ? 'mobile' : 'desktop';
      final theme = brightness.name;

      testWidgets('$viewport task workspace — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          surface: const TasksRootPage(),
        );

        expect(find.byType(TasksTabPage), findsOneWidget);
        expect(
          find.text('Inspect orbital penguin habitat'),
          findsAtLeastNWidgets(1),
        );
        expect(find.byType(CoverArtThumbnail), findsAtLeastNWidgets(3));
        expect(
          tester
              .widgetList<CoverArtThumbnail>(find.byType(CoverArtThumbnail))
              .map((thumbnail) => thumbnail.imageId)
              .toSet(),
          containsAll(<String>{
            manualHabitatCoverImageId,
            manualFishFeederCoverImageId,
            manualSardineCargoCoverImageId,
          }),
        );
        expect(
          find.descendant(
            of: find.byType(CoverArtThumbnail),
            matching: find.byType(Image),
          ),
          findsAtLeastNWidgets(3),
        );
        if (!device.isPhone) {
          expect(find.byType(TaskDetailsPage), findsOneWidget);
        }
        await captureScreenshot(
          tester,
          'task_workspace_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task detail — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          surface: TaskDetailsPage(taskId: world.orbitalHabitatTask.meta.id),
        );

        expect(find.byType(TaskDetailsPage), findsOneWidget);
        expect(find.text('Inspect orbital penguin habitat'), findsWidgets);
        await captureScreenshot(
          tester,
          'task_detail_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport task filters — $theme', (tester) async {
        await _pumpTaskSurface(
          tester,
          device: device,
          brightness: brightness,
          world: world,
          pageController: pageController,
          surface: const TasksRootPage(),
        );

        await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
        await settleFrames(tester, 6);
        expect(find.text('Filter tasks'), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey('design-system-task-filter-priority-p1'),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'task_filters_${viewport}_$theme',
          subdir: 'manual',
        );
      });
    }
  }
}

Future<void> _pumpTaskSurface(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
  required ManualDemoWorld world,
  required FakeJournalPageController pageController,
  required Widget surface,
}) async {
  applyScreenshotDevice(tester, device);
  final tasksById = {for (final task in world.tasks) task.meta.id: task};

  await withClock(Clock.fixed(manualDemoNow), () async {
    await primeManualDemoCoverArt(
      tester,
      documentsDirectory: getIt<Directory>(),
      world: world,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotBoundaryKey,
        child: ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => pageController),
            taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
            taskLiveDataProvider.overrideWith(
              (ref, taskId) async => tasksById[taskId],
            ),
            taskOneLinerProvider.overrideWith(
              (ref, taskId) async => switch (taskId) {
                manualOrbitalHabitatTaskId =>
                  'Pressure stable · 37 penguins accounted for',
                manualFishFeederTaskId =>
                  'Feeder calibration blocks the habitat demo',
                manualSardineCargoTaskId =>
                  'Europa cold-chain manifest ready to reconcile',
                _ => 'Awaiting an answer from orbital transport counsel',
              },
            ),
            agentUpdateStreamProvider.overrideWith(
              (ref, agentId) => const Stream<Set<String>>.empty(),
            ),
            taskAgentProvider.overrideWith((ref, taskId) async => null),
            for (final coverImage in world.coverImages)
              createEntryControllerOverride(coverImage),
            for (final task in world.tasks) createEntryControllerOverride(task),
            ...hTaskDetailsPageOverrides(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: brightness == Brightness.dark
                ? DesignSystemTheme.dark()
                : DesignSystemTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: surface,
          ),
        ),
      ),
    );
    await settleFrames(tester, 8);
  });
}
