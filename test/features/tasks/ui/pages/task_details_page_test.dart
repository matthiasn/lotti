import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposals_section_part.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_with_timer.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_connector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/features/tasks/ui/widgets/task_first_run_actions.dart';
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

import '../../../../helpers/fake_linked_entries_controller.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import 'task_details_page_test_helpers.dart';

/// Serves a fixed entry so a link target resolves without a database.
class _FixedEntryController extends EntryController {
  _FixedEntryController(this._entry);

  final JournalEntity _entry;

  @override
  Future<EntryState?> build() async {
    return EntryState.saved(
      entryId: id,
      entry: _entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

/// A [FakeLinkedEntriesController] whose links can change mid-test, the way
/// "Write a note" changes them mid-session.
class _MutableLinkedEntries extends FakeLinkedEntriesController {
  void emit(List<EntryLink> next) => state = AsyncData(next);
}

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
  /// * [linkedEntities] — entities `getLinkedEntities` resolves to (defaults to
  ///   one text entry). The off-screen-card tests pass several so the sliver
  ///   below the AI card is tall enough to scroll the card past the viewport
  ///   top.
  Future<void> registerTaskDetailsServices({
    List<MeasurableDataType>? measurables,
    List<CategoryDefinition>? categories,
    List<JournalEntity>? linkedEntities,
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
        (_) async => linkedEntities ?? [testTextEntry],
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

    testWidgets(
      'a first-run task fills the remaining viewport and narrows the column, '
      'so the group is composed rather than stacked at the top of a blank page',
      (tester) async {
        final blank = testTask.copyWith(
          data: testTask.data.copyWith(title: '', checklistIds: const []),
          entryText: null,
        );
        when(
          () => mockJournalDb.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => blank);
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: [
              ...hTaskDetailsPageOverrides(),
              // Blank task *data* is not enough. `watchTaskIsFirstRun` also
              // needs "no linked entries", and it treats an unresolved
              // provider as unknown — the real controller reads through
              // `JournalDb.linksFromId`, a Drift selectable this harness does
              // not answer, so it lands in AsyncError and nothing first-run
              // renders. Without this the test asserted the ordinary layout
              // and passed.
              linkedEntriesControllerProvider(
                testTask.meta.id,
              ).overrideWith(FakeLinkedEntriesController.new),
              taskAgentProvider.overrideWith((ref, id) async => null),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(TaskFirstRunActions),
          findsOneWidget,
          reason: 'the layout under test only applies in the first-run state',
        );

        // The first content sliver claims the rest of the viewport instead of
        // taking its child's height, which is what turns the leftover space
        // into margin above and below.
        expect(find.byType(SliverLayoutBuilder), findsWidgets);

        final constraints = tester
            .widgetList<ConstrainedBox>(
              find.descendant(
                of: find.byType(SliverLayoutBuilder),
                matching: find.byType(ConstrainedBox),
              ),
            )
            .map((box) => box.constraints)
            .toList();
        expect(
          constraints.any((c) => c.minHeight > 0),
          isTrue,
          reason:
              'a minHeight floor, not a fixed height — a long title or a '
              'large text scale must still grow and scroll',
        );
        expect(
          constraints.any((c) => c.maxWidth == TaskFirstRunActions.maxWidth),
          isTrue,
          reason:
              'the column adopts the block measure so the field, the chip '
              'lane and the card share one right edge',
        );
      },
    );

    testWidgets(
      'a first-run task drops the History header but keeps the entry-stream '
      'widgets, so reverse-linked entries stay reachable',
      (tester) async {
        // `watchTaskIsFirstRun` examines only OUTGOING links, so a blank task
        // can still carry entries that link TO it. Hiding the whole history
        // subtree on first-run would disappear those with no way to expand —
        // the bare stream (which renders nothing when truly empty) must stay.
        final blank = testTask.copyWith(
          data: testTask.data.copyWith(title: '', checklistIds: const []),
          entryText: null,
        );
        when(
          () => mockJournalDb.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => blank);
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: [
              ...hTaskDetailsPageOverrides(),
              linkedEntriesControllerProvider(
                testTask.meta.id,
              ).overrideWith(FakeLinkedEntriesController.new),
              taskAgentProvider.overrideWith((ref, id) async => null),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TaskFirstRunActions), findsOneWidget);
        expect(find.text('History'), findsNothing);
        expect(
          find.byType(LinkedEntriesWithTimer, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.byType(LinkedFromEntriesWidget, skipOffstage: false),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'first content releases the composed fill through the animated exit — '
      'the measuring branch unmounts after the transition instead of the '
      'page snapping in one frame',
      (tester) async {
        final blank = testTask.copyWith(
          data: testTask.data.copyWith(title: '', checklistIds: const []),
          entryText: null,
        );
        when(
          () => mockJournalDb.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => blank);
        final links = _MutableLinkedEntries();
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: [
              ...hTaskDetailsPageOverrides(),
              linkedEntriesControllerProvider(
                testTask.meta.id,
              ).overrideWith(() => links),
              taskAgentProvider.overrideWith((ref, id) async => null),
              // The link target must RESOLVE for first-run to end: an
              // unresolved target reads as unknown, not as content.
              entryControllerProvider(
                testTextEntry.meta.id,
              ).overrideWith(() => _FixedEntryController(testTextEntry)),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SliverLayoutBuilder), findsWidgets);

        // The first note lands: the page leaves first-run, the measure and
        // the optical-centre anchoring animate out, and — this is the line
        // under test — the AnimatedContainer's onEnd swaps the sliver to the
        // plain adapter so ordinary scrolling stops paying the
        // layout-builder's rebuild-on-scroll cost.
        links.emit([
          EntryLink.basic(
            id: 'link-1',
            fromId: blank.meta.id,
            toId: testTextEntry.meta.id,
            createdAt: DateTime(2026, 8, 4),
            updatedAt: DateTime(2026, 8, 4),
            vectorClock: null,
          ),
        ]);
        await tester.pumpAndSettle();

        expect(find.byType(TaskFirstRunActions), findsNothing);
        expect(
          find.byType(SliverLayoutBuilder),
          findsNothing,
          reason:
              'after the release animation completes the measuring branch '
              'must be gone — it rebuilds on every scroll tick',
        );
      },
    );

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
          .read(taskFocusControllerProvider(testTask.id).notifier)
          .publishTaskFocus(
            entryId: testTextEntry.meta.id,
          );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
      for (
        var i = 0;
        i < 20 &&
            container.read(taskFocusControllerProvider(testTask.id)) != null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify intent was cleared after consumption
      final intent = container.read(
        taskFocusControllerProvider(testTask.id),
      );
      expect(intent, isNull);
    });

    testWidgets('pre-existing intent handled on page build', (tester) async {
      // Create a container and publish intent before building the page
      final container = ProviderContainer(
        overrides: hTaskDetailsPageOverrides(),
      );

      container
          .read(taskFocusControllerProvider(testTask.id).notifier)
          .publishTaskFocus(
            entryId: testTextEntry.meta.id,
          );

      // Verify intent exists
      final intentBefore = container.read(
        taskFocusControllerProvider(testTask.id),
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
            container.read(taskFocusControllerProvider(testTask.id)) != null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify intent was cleared after handling
      final intentAfter = container.read(
        taskFocusControllerProvider(testTask.id),
      );
      expect(intentAfter, isNull);

      container.dispose();
    });

    testWidgets(
      'the history section is collapsed by default and expands from its '
      'header',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: [
              ...hTaskDetailsPageOverrides(),
              ...hLinkedEntriesOverrides(),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Collapsed by default: the header is there, the entry stream is not
        // in the tree at all.
        expect(find.text('History'), findsOneWidget);
        expect(
          find.byType(LinkedEntriesWithTimer, skipOffstage: false),
          findsNothing,
        );

        await tester.tap(find.text('History'), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byType(LinkedEntriesWithTimer, skipOffstage: false),
          findsOneWidget,
        );

        // And it collapses again from the same header.
        await tester.tap(find.text('History'), warnIfMissed: false);
        await tester.pump();
        expect(
          find.byType(LinkedEntriesWithTimer, skipOffstage: false),
          findsNothing,
        );
      },
    );

    testWidgets(
      'an entry focus intent force-expands the collapsed history',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: [
              ...hTaskDetailsPageOverrides(),
              ...hLinkedEntriesOverrides(),
            ],
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.byType(LinkedEntriesWithTimer, skipOffstage: false),
          findsNothing,
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(TaskDetailsPage)),
        );
        container
            .read(taskFocusControllerProvider(testTask.id).notifier)
            .publishTaskFocus(entryId: testTextEntry.meta.id);

        await tester.pump();
        for (
          var i = 0;
          i < 20 &&
              container.read(taskFocusControllerProvider(testTask.id)) != null;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // A collapsed section has no mounted entry keys to scroll to, so the
        // intent must have opened it.
        expect(
          find.byType(LinkedEntriesWithTimer, skipOffstage: false),
          findsOneWidget,
        );
      },
    );

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

      expect(find.textContaining('Set estimate to 30 minutes'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskDetailsPage)),
      );
      container
          .read(taskFocusControllerProvider(testTask.id).notifier)
          .publishSuggestionFocus(alignment: 0.2);

      for (
        var i = 0;
        i < 10 &&
            container.read(taskFocusControllerProvider(testTask.id)) != null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        container.read(taskFocusControllerProvider(testTask.id)),
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
            .read(taskFocusControllerProvider(testTask.id).notifier)
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
              container.read(taskFocusControllerProvider(testTask.id)) != null;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(
          container.read(taskFocusControllerProvider(testTask.id)),
          isNull,
        );

        container.dispose();
      },
    );
  });

  group('TaskDetailsPage Suggestions Anchor - ', () {
    setUpAll(() {
      registerTaskDetailsFallbacks();
      registerAllFallbackValues();
    });
    setUp(registerTaskDetailsServices);
    tearDown(getIt.reset);

    testWidgets(
      'Accept all keeps the proposals position stable at a nonzero scroll '
      'offset while its rows collapse',
      (tester) async {
        tester.view.physicalSize = const Size(800, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final confirmationService = MockChangeSetConfirmationService();
        late final ProviderContainer container;
        when(() => confirmationService.confirmAll(any())).thenAnswer((_) async {
          container
              .read(controllableOpenSuggestionCountProvider.notifier)
              .set(0);
          return const [ToolExecutionResult(success: true, output: 'ok')];
        });

        container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hControllableSuggestionOverrides(),
            changeSetConfirmationServiceProvider.overrideWith(
              (ref) => confirmationService,
            ),
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

        final proposals = find.byType(ProposalsSection);
        final confirmAll = find.text('Confirm all');
        expect(proposals, findsOneWidget);
        expect(confirmAll, findsOneWidget);

        await tester.ensureVisible(confirmAll);
        await tester.pump();
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        expect(position.pixels, greaterThan(0));
        final proposalsTop = tester.getTopLeft(proposals).dy;

        await tester.tap(confirmAll);
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            tester.getTopLeft(proposals).dy,
            closeTo(proposalsTop, 1),
            reason: 'proposals moved during Accept-all frame $frame',
          );
        }

        verify(() => confirmationService.confirmAll(any())).called(1);
        expect(
          container.read(controllableOpenSuggestionCountProvider),
          isZero,
        );
        expect(tester.takeException(), isNull);

        // Dispose the container (cancels the entry-controller cache timer)
        // before the framework's pending-timer check.
        container.dispose();
      },
    );

    testWidgets(
      'a new proposal (open count rises) while the card is visible does not '
      'jump the scroll',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hControllableSuggestionOverrides(),
          ],
        );
        // Start with a single open proposal so we can grow it mid-run.
        container.read(controllableOpenSuggestionCountProvider.notifier).set(1);

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
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.textContaining('Set estimate to 30 minutes'),
          findsOneWidget,
        );
        expect(find.byType(ProposalRow), findsOneWidget);

        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        final offsetBefore = position.pixels;

        // A new proposal lands (1 -> 2). The card is visible, so the growth
        // anchor must NOT engage — the card's own EnterTransition reveals the
        // growth in place rather than the page scrolling under the user.
        container.read(controllableOpenSuggestionCountProvider.notifier).set(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        // The new proposal is shown (1 -> 2 rows) and the scroll position was
        // left untouched.
        expect(find.byType(ProposalRow), findsNWidgets(2));
        expect(position.pixels, offsetBefore);

        container.dispose();
      },
    );
  });

  group('TaskDetailsPage Off-screen Card Anchor - ', () {
    // Every accepted proposal collapses its row and shrinks the AI card. While
    // the card is visible that collapse is the reflow the user is watching;
    // once the card has scrolled above the viewport it instead drags the
    // linked entries the user *is* reading upwards. The proposals anchor is
    // structurally blind to it — a row collapsing inside the proposals section
    // does not move the section's top — so the card band reports its own
    // shrink and the below-card anchor replaces the proposals anchor.
    setUpAll(() {
      registerTaskDetailsFallbacks();
      registerAllFallbackValues();
    });
    setUp(
      () => registerTaskDetailsServices(
        // Enough below the card that it can scroll fully past the viewport top.
        linkedEntities: [
          for (var i = 0; i < 8; i++)
            testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(id: 'linked-entry-$i'),
            ),
        ],
      ),
    );
    tearDown(getIt.reset);

    ScrollPosition scrollPositionOf(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    /// Pumps the page, scrolls until the AI card sits fully above the viewport
    /// top, and returns the scroll position. Fails loudly when the scenario
    /// cannot be reached, so the test can never silently assert nothing.
    Future<ScrollPosition> scrollCardOffScreen(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // These scenarios have the user reading the entries below the card, so
      // the collapsed-by-default history section must be open — it is also
      // what gives the page enough scroll extent to put the card past the
      // viewport top. The header can start below the fold (unbuilt), so
      // scroll it into view before tapping, then return to the top.
      await tester.scrollUntilVisible(
        find.text('History'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // A further nudge: scrollUntilVisible stops the moment the header is
      // technically visible, which can leave it under the glass action bar
      // where a tap never lands.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pump();
      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      scrollPositionOf(tester).jumpTo(0);
      await tester.pump();

      final position = scrollPositionOf(tester);
      final viewportTop = tester.getRect(find.byType(CustomScrollView)).top;
      // skipOffstage: false — a sliver scrolled past the viewport is offstage,
      // and the default finder would report it as absent rather than measuring
      // it. It is still laid out, which is exactly why its height changes still
      // move the content below it.
      final card = find.byType(AiSummaryCard, skipOffstage: false);
      // Past the top by more than the band's trailing padding: the page
      // measures the whole reported band (card plus its bottom padding), not
      // just the card, so clearing the card alone leaves the predicate false.
      position.jumpTo(
        position.pixels + (tester.getRect(card).bottom - viewportTop) + 40,
      );
      await tester.pump();

      expect(
        tester.getRect(card).bottom,
        lessThan(viewportTop),
        reason: 'the card never scrolled above the viewport top',
      );
      return position;
    }

    for (final scenario in [
      (
        // The pure card-collapse case: nothing above the card changes, so the
        // proposals anchor provably is not what keeps this stable.
        tool: 'set_task_language',
      ),
      (
        // A header delta and the card shrink compose into one correction.
        tool: 'update_task_estimate',
      ),
      (
        // Opposite-sign deltas: the checklist grows above while the card
        // shrinks below.
        tool: 'add_checklist_item',
      ),
    ]) {
      testWidgets(
        '${scenario.tool}: resolving with the card above the viewport keeps '
        'the below-card entries fixed',
        (tester) async {
          tester.view.physicalSize = const Size(800, 500);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final confirmationService = MockChangeSetConfirmationService();
          late final ProviderContainer container;
          when(
            () => confirmationService.confirmItem(any(), any()),
          ).thenAnswer((_) async {
            container
                .read(controllableOpenSuggestionCountProvider.notifier)
                .set(0);
            return const ToolExecutionResult(success: true, output: 'ok');
          });

          container = ProviderContainer(
            overrides: [
              ...hTaskDetailsPageOverrides(),
              ...hLinkedEntriesOverrides(),
              ...hControllableSuggestionOverrides(
                items: hSingleSuggestion(scenario.tool),
              ),
              changeSetConfirmationServiceProvider.overrideWith(
                (ref) => confirmationService,
              ),
            ],
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: makeTestableWidget2(TaskDetailsPage(taskId: testTask.id)),
            ),
          );

          // Confirm the row while the card is still visible, then scroll it
          // away before the collapse lands — the same shape as tapping and
          // scrolling on to read the entries below.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(ProposalRow), findsOneWidget);

          final position = await scrollCardOffScreen(tester);
          final entriesTop = tester
              .getTopLeft(find.byType(LinkedEntriesWithTimer))
              .dy;

          container
              .read(controllableOpenSuggestionCountProvider.notifier)
              .set(
                0,
              );
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 50));
            expect(
              tester.getTopLeft(find.byType(LinkedEntriesWithTimer)).dy,
              closeTo(entriesTop, 1),
              reason: 'below-card entries moved on frame $frame',
            );
          }

          expect(tester.takeException(), isNull);
          expect(position.pixels, isNot(isNaN));
          container.dispose();
        },
      );
    }

    testWidgets(
      'a new proposal arriving while the card is above the viewport keeps the '
      'below-card entries fixed',
      (tester) async {
        tester.view.physicalSize = const Size(800, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hLinkedEntriesOverrides(),
            ...hControllableSuggestionOverrides(),
          ],
        );
        container.read(controllableOpenSuggestionCountProvider.notifier).set(1);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidget2(TaskDetailsPage(taskId: testTask.id)),
          ),
        );

        await scrollCardOffScreen(tester);
        final entriesTop = tester
            .getTopLeft(find.byType(LinkedEntriesWithTimer))
            .dy;

        // The growth-side dual: the card grows off-screen, so the visible
        // content below it must not be pushed down.
        container.read(controllableOpenSuggestionCountProvider.notifier).set(2);
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            tester.getTopLeft(find.byType(LinkedEntriesWithTimer)).dy,
            closeTo(entriesTop, 1),
            reason: 'below-card entries moved on frame $frame',
          );
        }

        expect(tester.takeException(), isNull);
        container.dispose();
      },
    );

    testWidgets('a user scroll during the resolve window releases the hold', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          ...hTaskDetailsPageOverrides(),
          ...hLinkedEntriesOverrides(),
          ...hControllableSuggestionOverrides(),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(TaskDetailsPage(taskId: testTask.id)),
        ),
      );

      final position = await scrollCardOffScreen(tester);

      // Arm the hold, then scroll deliberately: stabilization must never fight
      // input, however long its window still had to run.
      container.read(controllableOpenSuggestionCountProvider.notifier).set(1);
      await tester.pump();
      final offsetBefore = position.pixels;

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -120),
      );
      await tester.pump();

      expect(position.pixels, greaterThan(offsetBefore));
      expect(tester.takeException(), isNull);
      container.dispose();
    });

    testWidgets(
      'a linked task appearing long after the resolve window leaves the '
      'proposals and the offset untouched',
      (tester) async {
        // `create_follow_up_task` links its new task only after awaiting agent
        // content generation, so the linked-tasks band can grow seconds after
        // the tap. The band sits BELOW the proposals now: its growth is the
        // visible reflow underneath them, so the armed hold must ignore the
        // delta — the proposals stay put because nothing above them moved,
        // not because the offset was corrected.
        tester.view.physicalSize = const Size(800, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hLinkedEntriesOverrides(),
            ...hControllableLinkedTasksOverrides(),
            ...hControllableSuggestionOverrides(),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidget2(TaskDetailsPage(taskId: testTask.id)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final proposals = find.byType(ProposalsSection);
        expect(proposals, findsOneWidget);
        final position = scrollPositionOf(tester);
        await tester.ensureVisible(proposals);
        await tester.pump();

        // Well past _suggestionResolveHold, so nothing armed earlier can be
        // what keeps this stable.
        await tester.pump(const Duration(seconds: 2));
        final proposalsTop = tester.getTopLeft(proposals).dy;
        final offsetBefore = position.pixels;
        final bandHeightBefore = tester
            .getSize(find.byType(LinkedTasksWidget, skipOffstage: false))
            .height;

        container.read(controllableLinkedTaskCountProvider.notifier).set(1);
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            tester.getTopLeft(proposals).dy,
            closeTo(proposalsTop, 1),
            reason: 'proposals moved on frame $frame',
          );
        }

        // The band really did change height below the proposals — otherwise
        // the assertion above would hold trivially.
        expect(
          tester
              .getSize(find.byType(LinkedTasksWidget, skipOffstage: false))
              .height,
          isNot(closeTo(bandHeightBefore, 1)),
        );
        // And the offset was left alone: nothing above the proposals moved.
        expect(position.pixels, closeTo(offsetBefore, 1));
        expect(tester.takeException(), isNull);
        container.dispose();
      },
    );

    testWidgets(
      'a link changing relationship type resizes the band without moving the '
      'proposals or the offset, even though the count is unchanged',
      (tester) async {
        // TaskLinkGroupsController re-emits whenever the resolved entries
        // differ, not only when links are added or removed. totalCount is
        // flat + typed, so a link moving between those buckets — a synced
        // link-type change — resizes the band (typed links render with their
        // own section headers) while the count stays identical. The band sits
        // below the proposals, so that resize must reflow underneath them
        // with no offset correction.
        tester.view.physicalSize = const Size(800, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hLinkedEntriesOverrides(),
            ...hControllableLinkedTasksOverrides(),
            ...hControllableSuggestionOverrides(),
          ],
        );
        container.read(controllableLinkedTaskCountProvider.notifier).set(1);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidget2(TaskDetailsPage(taskId: testTask.id)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final proposals = find.byType(ProposalsSection);
        expect(proposals, findsOneWidget);
        final position = scrollPositionOf(tester);
        await tester.ensureVisible(proposals);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        final proposalsTop = tester.getTopLeft(proposals).dy;
        final offsetBefore = position.pixels;
        final bandHeightBefore = tester
            .getSize(find.byType(LinkedTasksWidget, skipOffstage: false))
            .height;

        container.read(controllableLinkedTaskTypedProvider.notifier).set(true);
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            tester.getTopLeft(proposals).dy,
            closeTo(proposalsTop, 1),
            reason: 'proposals moved on frame $frame',
          );
        }

        // The type change really did resize the band — otherwise the
        // assertion above would hold trivially.
        expect(
          tester
              .getSize(find.byType(LinkedTasksWidget, skipOffstage: false))
              .height,
          isNot(closeTo(bandHeightBefore, 1)),
        );
        // And the offset was left alone: nothing above the proposals moved.
        expect(position.pixels, closeTo(offsetBefore, 1));
        expect(tester.takeException(), isNull);
        container.dispose();
      },
    );

    testWidgets(
      'the first link change after mounting onto an already-resolved provider '
      'still reflows only below the proposals',
      (tester) async {
        // taskLinkGroupsControllerProvider is cached for entryCacheDuration, so
        // a page can mount onto an AsyncData provider and get no emission for
        // the value already there. Without seeding the baseline from the
        // listener's own previous value, the first real change would only
        // establish the baseline and arm nothing.
        tester.view.physicalSize = const Size(800, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hLinkedEntriesOverrides(),
            ...hControllableLinkedTasksOverrides(),
            ...hControllableSuggestionOverrides(),
          ],
        );
        container.read(controllableLinkedTaskCountProvider.notifier).set(1);

        // Warm the provider to AsyncData *before* the page mounts, and keep the
        // subscription alive so it is not auto-disposed in between.
        final warmup = container.listen(
          taskLinkGroupsControllerProvider(testTask.meta.id),
          (_, _) {},
        );
        await container.read(
          taskLinkGroupsControllerProvider(testTask.meta.id).future,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidget2(TaskDetailsPage(taskId: testTask.id)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final proposals = find.byType(ProposalsSection);
        expect(proposals, findsOneWidget);
        final position = scrollPositionOf(tester);
        await tester.ensureVisible(proposals);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        final proposalsTop = tester.getTopLeft(proposals).dy;
        final offsetBefore = position.pixels;
        final bandHeightBefore = tester
            .getSize(find.byType(LinkedTasksWidget, skipOffstage: false))
            .height;

        // The very first change this page ever sees for the provider, pushed as
        // a single AsyncData the way the real controller's update-stream
        // listener does — no AsyncLoading in between to seed the baseline.
        (container.read(
                  taskLinkGroupsControllerProvider(testTask.meta.id).notifier,
                )
                as ControllableTaskLinkGroupsController)
            .push(hLinkGroups(count: 2));
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            tester.getTopLeft(proposals).dy,
            closeTo(proposalsTop, 1),
            reason: 'proposals moved on frame $frame',
          );
        }

        // The band really did resize below the proposals, and the offset was
        // left alone: nothing above them moved.
        expect(
          tester
              .getSize(find.byType(LinkedTasksWidget, skipOffstage: false))
              .height,
          isNot(closeTo(bandHeightBefore, 1)),
        );
        expect(position.pixels, closeTo(offsetBefore, 1));
        expect(tester.takeException(), isNull);
        warmup.close();
        container.dispose();
      },
    );

    testWidgets(
      'a linked task appearing below the viewport leaves the content the user '
      'is reading alone',
      (tester) async {
        // The linked-tasks listener fires without the user having touched
        // anything — a sync can change the link set at any scroll position.
        // Down there the growth moves nothing on screen, so compensating it
        // would drag the header and checklist upwards for no reason.
        //
        // Short viewport so the band is genuinely past the fold at offset 0;
        // the width is unchanged, so the layout above it is identical.
        tester.view.physicalSize = const Size(800, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            ...hTaskDetailsPageOverrides(),
            ...hLinkedEntriesOverrides(),
            ...hControllableLinkedTasksOverrides(),
            ...hControllableSuggestionOverrides(),
          ],
        );

        // Start populated and then *grow* the band. A shrink at offset zero is
        // clamped by minScrollExtent and would pass whether or not the gate
        // exists; growth is what actually pushes the offset forward.
        container.read(controllableLinkedTaskCountProvider.notifier).set(1);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidget2(TaskDetailsPage(taskId: testTask.id)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Stay at the top, where the header is what the user is reading and
        // the linked-tasks band is far below the fold.
        final position = scrollPositionOf(tester);
        expect(position.pixels, isZero);
        final viewportBottom = tester
            .getRect(find.byType(CustomScrollView))
            .bottom;
        expect(
          tester
              .getTopLeft(find.byType(LinkedTasksWidget, skipOffstage: false))
              .dy,
          greaterThanOrEqualTo(viewportBottom),
          reason: 'the linked-tasks band was not below the viewport',
        );

        final header = find.byType(DesktopTaskHeaderConnector);
        final headerTop = tester.getTopLeft(header).dy;

        container.read(controllableLinkedTaskCountProvider.notifier).set(2);
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            tester.getTopLeft(header).dy,
            closeTo(headerTop, 1),
            reason: 'the header moved on frame $frame',
          );
        }

        expect(position.pixels, isZero);
        expect(tester.takeException(), isNull);
        container.dispose();
      },
    );
  });
}
