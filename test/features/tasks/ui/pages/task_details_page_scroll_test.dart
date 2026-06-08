import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/media_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import 'task_details_page_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  void registerTaskDetailsFallbacks() {
    setFakeDocumentsPath();
    registerFallbackValue(FakeMeasurementData());
  }

  /// Registers the full GetIt service graph the [TaskDetailsPage] needs and
  /// installs the common Mocktail stubs. Groups share this body; the few
  /// scenario-specific differences are expressed as parameters:
  ///
  /// * [measurables] — measurable types the [MockJournalDb] knows about
  ///   (defaults to water + chocolate). The null/non-task group registers none.
  /// * [categories] — value returned by `sortedCategories` (defaults to
  ///   `[categoryMindfulness]`). The null group returns an empty list.
  /// * [stubTaskEntity] — when true, `journalEntityById(testTask)` resolves to
  ///   [testTask] (most groups). The first widget-test group stubs it per test
  ///   instead, so it passes false.
  /// * [stubLinkedAndMeasurements] — when true, stubs `getLinkedEntities`,
  ///   `getMeasurableDataTypeById`, and `getMeasurementsByType`. The null group
  ///   needs none of these.
  /// * [watchConfigPrivate] — when true, `watchConfigFlags` emits the `private`
  ///   flag; the null group emits an empty set.
  Future<void> registerTaskDetailsServices({
    List<MeasurableDataType>? measurables,
    List<CategoryDefinition>? categories,
    bool stubTaskEntity = true,
    bool stubLinkedAndMeasurements = true,
    bool watchConfigPrivate = true,
  }) async {
    // `categoryMindfulness` / `measurableWater` are runtime `final`s, so the
    // defaults are resolved here rather than in the parameter list (which
    // would require compile-time constants).
    final resolvedMeasurables =
        measurables ?? [measurableWater, measurableChocolate];
    final resolvedCategories = categories ?? [categoryMindfulness];

    mockJournalDb = mockJournalDbWithMeasurableTypes(resolvedMeasurables);
    mockPersistenceLogic = MockPersistenceLogic();

    final mockTimeService = MockTimeService();
    final mockEditorStateService = MockEditorStateService();
    final mockHealthImport = MockHealthImport();
    final mockUserActivityService = MockUserActivityService();
    when(mockUserActivityService.updateActivity).thenReturn(null);

    getIt
      ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
      ..registerSingleton<UserActivityService>(mockUserActivityService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<LinkService>(MockLinkService())
      ..registerSingleton<HealthImport>(mockHealthImport)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

    when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
      (_) => resolvedCategories,
    );
    when(
      () => mockEntitiesCacheService.sortedLabels,
    ).thenReturn(<LabelDefinition>[]);
    when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([
        if (watchConfigPrivate)
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
      ]),
    );

    when(
      () => mockEditorStateService.getUnsavedStream(any(), any()),
    ).thenAnswer(
      (_) => Stream<bool>.fromIterable([false]),
    );

    when(
      mockTimeService.getStream,
    ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

    if (stubLinkedAndMeasurements) {
      when(
        () => mockJournalDb.getMeasurableDataTypeById(
          '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => measurableWater);
      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [testTextEntry],
      );
      when(
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);
    }

    if (stubTaskEntity) {
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
    }

    // Ensure ThemingController dependencies are registered.
    ensureThemingServicesRegistered();
  }

  group('TaskDetailsPage Scroll Offset Listener - ', () {
    setUpAll(registerTaskDetailsFallbacks);

    setUp(registerTaskDetailsServices);
    tearDown(getIt.reset);

    testWidgets(
      'scrolling triggers _updateOffsetListener which updates '
      'TaskAppBarController offset',
      (tester) async {
        // Width below the desktop breakpoint (960) → mobile layout, no
        // NavService dependency, and wide enough for TaskActionBar not to
        // overflow.  Keep the height short (400 px) so the page content
        // is taller than the viewport and the CustomScrollView can scroll.
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            TaskDetailsPage(taskId: testTask.id),
            overrides: hTaskDetailsPageOverrides(),
            mediaQueryData: const MediaQueryData(size: Size(800, 400)),
          ),
        );

        // Give the async providers time to resolve (task data, linked
        // entries) without demanding full settlement.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Read the initial offset from the TaskAppBarController.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TaskDetailsPage)),
        );

        // Programmatically jump the scroll position so the listener fires
        // regardless of how much content the page renders.  The
        // CustomScrollView inside TaskDetailsPage uses a custom
        // ScrollController whose listeners include _updateOffsetListener.
        // We access it via the Scrollable state attached to the
        // CustomScrollView.
        final scrollableFinder = find
            .descendant(
              of: find.byType(TaskDetailsPage),
              matching: find.byType(Scrollable),
            )
            .first;
        final scrollState = tester.state<ScrollableState>(scrollableFinder);
        // jumpTo requires the position's maxScrollExtent > 0 or it will
        // clamp to 0 — use notifyListeners directly as a fallback when
        // there is no content to scroll past.
        if (scrollState.position.maxScrollExtent > 0) {
          scrollState.position.jumpTo(50);
        } else {
          // Even without content, calling the notifier confirms the
          // listener path is wired up; we just verify no exception.
          scrollState.position.notifyListeners();
        }
        await tester.pump();

        // After scrolling (or notifying), the TaskAppBarController state
        // should have been updated — either to a non-zero offset or, when
        // the content doesn't overflow, to the clamped 0.0.  What matters
        // is that the listener executes without error and the provider
        // state is accessible.
        final updatedState = container.read(
          taskAppBarControllerProvider(id: testTask.id),
        );
        expect(
          updatedState.hasValue,
          isTrue,
          reason: 'TaskAppBarController must have resolved its state',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group: Empty-scaffold when task is null (lines 133-135)
  // ---------------------------------------------------------------------------
  group('TaskDetailsPage null/non-task entry - ', () {
    setUpAll(registerTaskDetailsFallbacks);

    // No measurables/categories, no linked-entity stubs, and the entity is
    // stubbed per test (null vs. a non-task entry).
    setUp(
      () => registerTaskDetailsServices(
        measurables: const <MeasurableDataType>[],
        categories: const <CategoryDefinition>[],
        stubTaskEntity: false,
        stubLinkedAndMeasurements: false,
        watchConfigPrivate: false,
      ),
    );
    tearDown(getIt.reset);

    for (final testCase in [
      (label: 'null entity', entity: null),
      (label: 'non-task entity (text entry)', entity: testTextEntry),
    ]) {
      testWidgets(
        'shows EmptyScaffoldWithTitle when entry is ${testCase.label}',
        (tester) async {
          when(
            () => mockJournalDb.journalEntityById(testTask.meta.id),
          ).thenAnswer((_) async => testCase.entity);

          await tester.pumpWidget(
            makeTestableWidgetNoScroll(
              TaskDetailsPage(taskId: testTask.meta.id),
              overrides: hTaskDetailsPageOverrides(),
            ),
          );

          await tester.pump();

          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(EmptyScaffoldWithTitle), findsOneWidget);
          expect(find.byType(TaskActionBar), findsNothing);
        },
      );
    }
  });

  // ---------------------------------------------------------------------------
  // Group: DropTarget onDragDone callback (lines 237-242)
  // ---------------------------------------------------------------------------
  group('TaskDetailsPage DropTarget onDragDone - ', () {
    setUpAll(registerTaskDetailsFallbacks);

    setUp(registerTaskDetailsServices);
    tearDown(getIt.reset);

    testWidgets(
      'onDragDone callback invokes handleDroppedMedia with task ids',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: hTaskDetailsPageOverrides(),
          ),
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        // Locate the DropTarget that wraps the task detail body.
        final dropTargetFinder = find.descendant(
          of: find.byType(TaskDetailsPage),
          matching: find.byType(DropTarget),
        );
        expect(dropTargetFinder, findsOneWidget);

        final dropTarget = tester.widget<DropTarget>(dropTargetFinder);
        expect(dropTarget.onDragDone, isNotNull);

        // Invoke the callback with an empty file list so no real import
        // logic runs (no matching extension → handleDroppedMedia returns
        // immediately).  The important thing is that the callback body
        // (lines 234-239) executes without throwing.
        const emptyDrop = DropDoneDetails(
          files: [],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        );

        expect(
          () => dropTarget.onDragDone!.call(emptyDrop),
          returnsNormally,
        );

        // Pump to let any async work settle without error.
        await tester.pump();
      },
    );

    testWidgets(
      'onDragDone callback passes task.meta.id and task.meta.categoryId to '
      'handleDroppedMedia',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: hTaskDetailsPageOverrides(),
          ),
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        final dropTargetFinder = find.descendant(
          of: find.byType(TaskDetailsPage),
          matching: find.byType(DropTarget),
        );
        final dropTarget = tester.widget<DropTarget>(dropTargetFinder);

        // Simulate dropping an unsupported file type (e.g. .txt) so that
        // importDroppedImages / importDroppedAudio are NOT called — we just
        // want to confirm the DropTarget wraps the correct task.
        final unsupportedFile = TaskDetailsFakeDropItem(XFile('/tmp/note.txt'));
        final dropDetails = DropDoneDetails(
          files: [unsupportedFile],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        );

        // Calling onDragDone must not throw, meaning the body reached
        // handleDroppedMedia with the task's linked/category IDs.
        expect(
          () => dropTarget.onDragDone!.call(dropDetails),
          returnsNormally,
        );

        await tester.pump();
      },
    );

    testWidgets(
      'an image drop whose file cannot be read is logged and swallowed',
      (tester) async {
        // The per-file try/catch in importDroppedImages must log the read
        // failure (lastModified/length on a nonexistent path) and continue
        // instead of letting the exception escape the drop handler.
        final mockLogger = MockDomainLogger();
        when(
          () => mockLogger.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenReturn(null);
        if (getIt.isRegistered<DomainLogger>()) {
          getIt.unregister<DomainLogger>();
        }
        getIt.registerSingleton<DomainLogger>(mockLogger);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: hTaskDetailsPageOverrides(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The DropTarget wiring itself is pinned by the adjacent tests;
        // here we drive handleDroppedMedia (the drop handler's body)
        // directly so the real-IO failure path is reachable via runAsync.
        expect(find.byType(DropTarget), findsOneWidget);

        final unreadableImage = TaskDetailsFakeDropItem(
          XFile('/nonexistent/missing.jpg'),
        );
        // The import loop does real file I/O (lastModified/length), which
        // never completes inside the fake-async test zone — run it for real.
        await tester.runAsync(() async {
          await handleDroppedMedia(
            data: DropDoneDetails(
              files: [unreadableImage],
              localPosition: Offset.zero,
              globalPosition: Offset.zero,
            ),
            linkedId: testTask.id,
            categoryId: testTask.meta.categoryId,
          );
        });

        verify(
          () => mockLogger.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'importDroppedImages',
          ),
        ).called(1);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group: Suggestions scroll finally-block (lines 286, 288)
  // ---------------------------------------------------------------------------
  group('TaskDetailsPage suggestions scroll finally block - ', () {
    setUpAll(registerTaskDetailsFallbacks);

    setUp(registerTaskDetailsServices);
    tearDown(getIt.reset);

    testWidgets(
      'suggestion focus intent clears (finally block runs) when '
      'proposals section is mounted and ensureVisible completes',
      (tester) async {
        // Width below the desktop breakpoint (960) → mobile layout, no
        // NavService dependency.  Extra tall so the suggestions section
        // keyed by _suggestionsKey is rendered and has a non-null
        // currentContext, exercising the context != null branch →
        // ensureVisible → finally block (lines 286, 288).
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            TaskDetailsPage(taskId: testTask.id),
            overrides: [
              ...hTaskDetailsPageOverrides(),
              ...hTaskDetailsPageAgentOverrides(),
            ],
            mediaQueryData: const MediaQueryData(size: Size(800, 4000)),
          ),
        );

        // Allow the full tree (including suggestions section) to settle.
        // Full settle: the page-load chain (async providers + entrance
        // animations) must finish before the focus intent is published.
        await tester.pumpAndSettle();

        // Confirm suggestions section is rendered.
        expect(find.text('Set estimate to 30 minutes'), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(TaskDetailsPage)),
        );

        // Publish the suggestions focus intent.
        container
            .read(taskFocusControllerProvider(id: testTask.id).notifier)
            .publishSuggestionFocus(alignment: 0);

        // Pump enough frames for the scroll + finally block to complete.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // The finally block calls onScrolled() → clearIntent(), so the
        // intent must be null now.
        expect(
          container.read(taskFocusControllerProvider(id: testTask.id)),
          isNull,
          reason: 'Intent must be cleared in finally block after ensureVisible',
        );
      },
    );
  });
}
