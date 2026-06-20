import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
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

  group('TaskDetailPage Widget Tests - ', () {
    setUpAll(registerTaskDetailsFallbacks);

    // This group stubs journalEntityById per test, so leave it unstubbed here.
    setUp(() => registerTaskDetailsServices(stubTaskEntity: false));
    tearDown(getIt.reset);

    testWidgets('Task Entry is rendered', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskDetailsPage(taskId: testTask.id),
          overrides: hTaskDetailsPageOverrides(),
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // test task displays progress bar (now in Labels row)
      final progressBarFinder = find.byType(LinearProgressIndicator);
      if (progressBarFinder.evaluate().isNotEmpty) {
        final progressBar =
            tester.firstWidget(progressBarFinder) as LinearProgressIndicator;
        expect(progressBar, isNotNull);
        expect(progressBar.value, 0.25);
      }

      // test task title is displayed once (inside the new desktop header).
      expect(find.text(testTask.data.title), findsOneWidget);

      // The legacy FAB has been replaced by the sticky TaskActionBar
      // pinned at the bottom of the page.
      expect(find.byType(TaskActionBar), findsOneWidget);
      expect(find.byType(AiRunningDecoderBars), findsOneWidget);

      // Background matches sidebar / Figma background/01.
      final scaffold = tester.widget<Scaffold>(
        find
            .descendant(
              of: find.byType(TaskDetailsPage),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      final context = tester.element(find.byType(TaskDetailsPage));
      expect(
        scaffold.backgroundColor,
        context.designTokens.colors.background.level01,
      );
      // Scaffold no longer hosts a FAB; the action bar sits in the body
      // Stack so it stacks correctly with the AI overlay above it.
      expect(scaffold.floatingActionButton, isNull);
    });

    testWidgets(
      'wraps task scaffold in a nested ScaffoldMessenger on every platform '
      'so toasts float above the sticky action bar instead of the screen '
      'bottom edge',
      (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => testTask);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: hTaskDetailsPageOverrides(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The nested messenger is mounted inside the TaskDetailsPage
        // subtree, so a context resolving via ScaffoldMessenger.of from
        // within the page (e.g. from TaskActionBar) hits the nested one
        // and SnackBars float above the sticky action bar — not at the
        // screen / window bottom owned by the outer/root messenger.
        final nestedFinder = find.descendant(
          of: find.byType(TaskDetailsPage),
          matching: find.byType(ScaffoldMessenger),
        );
        expect(nestedFinder, findsOneWidget);

        final nestedMessengerState = tester.state<ScaffoldMessengerState>(
          nestedFinder,
        );
        final innerContext = tester.element(find.byType(TaskActionBar));
        expect(
          ScaffoldMessenger.of(innerContext),
          same(nestedMessengerState),
        );
      },
    );
  });

  group('TaskDetailsPage Auto-Scroll Tests - ', () {
    setUpAll(registerTaskDetailsFallbacks);

    setUp(registerTaskDetailsServices);
    tearDown(getIt.reset);

    testWidgets('focus intent triggers scroll to entry', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskDetailsPage(taskId: testTask.id),
          overrides: hTaskDetailsPageOverrides(),
        ),
      );

      // Allow scroll retry/backoff to complete and clear intent over multiple frames
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Publish focus intent
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskDetailsPage)),
      );

      container
          .read(taskFocusControllerProvider(id: testTask.id).notifier)
          .publishTaskFocus(
            entryId: testTextEntry.meta.id,
          );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
      for (
        var i = 0;
        i < 20 &&
            container.read(taskFocusControllerProvider(id: testTask.id)) !=
                null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify intent was cleared after consumption
      final intent = container.read(
        taskFocusControllerProvider(id: testTask.id),
      );
      expect(intent, isNull);
    });

    testWidgets('pre-existing intent handled on page build', (tester) async {
      // Create a container and publish intent before building the page
      final container = ProviderContainer(
        overrides: hTaskDetailsPageOverrides(),
      );

      container
          .read(taskFocusControllerProvider(id: testTask.id).notifier)
          .publishTaskFocus(
            entryId: testTextEntry.meta.id,
          );

      // Verify intent exists
      final intentBefore = container.read(
        taskFocusControllerProvider(id: testTask.id),
      );
      expect(intentBefore, isNotNull);
      expect(intentBefore!.entryId, equals(testTextEntry.meta.id));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(
            TaskDetailsPage(taskId: testTask.id),
          ),
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
      for (
        var i = 0;
        i < 20 &&
            container.read(taskFocusControllerProvider(id: testTask.id)) !=
                null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify intent was cleared after handling
      final intentAfter = container.read(
        taskFocusControllerProvider(id: testTask.id),
      );
      expect(intentAfter, isNull);

      container.dispose();
    });

    testWidgets('suggestions focus intent scrolls to proposals section', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskDetailsPage(taskId: testTask.id),
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hTaskDetailsPageAgentOverrides(),
          ],
        ),
      );
      // Full settle: the page-load chain (async providers + entrance
      // animations) must finish before the focus intent is published.
      await tester.pumpAndSettle();

      expect(find.text('Set estimate to 30 minutes'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskDetailsPage)),
      );
      container
          .read(taskFocusControllerProvider(id: testTask.id).notifier)
          .publishSuggestionFocus(alignment: 0.2);

      for (
        var i = 0;
        i < 10 &&
            container.read(taskFocusControllerProvider(id: testTask.id)) !=
                null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        container.read(taskFocusControllerProvider(id: testTask.id)),
        isNull,
      );
    });

    testWidgets(
      'suggestions focus clears when proposals section never mounts',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            taskAgentProvider.overrideWith((ref, id) async => null),
          ],
        );

        container
            .read(taskFocusControllerProvider(id: testTask.id).notifier)
            .publishSuggestionFocus();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidget2(
              TaskDetailsPage(taskId: testTask.id),
            ),
          ),
        );

        for (
          var i = 0;
          i < 10 &&
              container.read(taskFocusControllerProvider(id: testTask.id)) !=
                  null;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(
          container.read(taskFocusControllerProvider(id: testTask.id)),
          isNull,
        );

        container.dispose();
      },
    );
  });

  group('TaskDetailsPage Suggestions Anchor - ', () {
    setUpAll(registerTaskDetailsFallbacks);
    setUp(registerTaskDetailsServices);
    tearDown(getIt.reset);

    testWidgets(
      'confirming a proposal (open count drops) engages the scroll anchor and '
      'updates the list without crashing',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hControllableSuggestionOverrides(),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidget2(
              TaskDetailsPage(taskId: testTask.id),
            ),
          ),
        );
        // Explicit pumps (not pumpAndSettle, which would hang on the AI
        // card's long-lived wake timers) to let the async providers resolve.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // The proposals section is up with the (first) open proposal showing.
        expect(find.text('Set estimate to 30 minutes'), findsOneWidget);

        // Simulate confirming one proposal: the open list shrinks 2 -> 1,
        // which fires the page's suggestion listener and engages the scroll
        // anchor (capturing the proposals' position to hold it across the
        // relayout a confirm can trigger above the card).
        container.read(controllableOpenSuggestionCountProvider.notifier).set(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The page absorbed the shrink cleanly (the anchor ran, no exception)
        // and the surviving proposal is still shown.
        expect(tester.takeException(), isNull);
        expect(find.text('Set estimate to 30 minutes'), findsOneWidget);

        // Dispose the container (cancels the entry-controller cache timer)
        // before the framework's pending-timer check.
        container.dispose();
      },
    );
  });
}
