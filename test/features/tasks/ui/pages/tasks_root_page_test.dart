import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_column.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJournalPageController fakeController;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final mockUserActivityService = MockUserActivityService();
        when(mockUserActivityService.updateActivity).thenReturn(null);
        getIt.registerSingleton<UserActivityService>(mockUserActivityService);
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(false);
        when(
          () => mockNavService.desktopSelectedTaskId,
        ).thenReturn(ValueNotifier<String?>(null));
        when(
          () => mockNavService.desktopTaskDetailStack,
        ).thenReturn(ValueNotifier<List<String>>(const <String>[]));
        getIt
          ..registerSingleton<NavService>(mockNavService)
          ..registerSingleton<EntitiesCacheService>(
            MockEntitiesCacheService(),
          );
      },
    );
    // `_TasksTabActiveFilters` reads `getVisibleProjects` from JournalDb to
    // resolve selected project chips. Stub to an empty list so the
    // FutureProvider resolves cleanly.
    when(
      () => (getIt<JournalDb>() as MockJournalDb).getVisibleProjects(),
    ).thenAnswer((_) async => const []);
  });

  tearDown(tearDownTestGetIt);

  /// Enters focus mode the way the relocated control does: the hide toggle now
  /// lives in the task detail header (see [TaskDetailHideListButton]), which
  /// these tests do not render because their task never resolves. The split
  /// controller's `hideListPane` is what that button calls, and the pane
  /// controller is where it lands.
  Future<void> hideListPane(WidgetTester tester) async {
    final splitController = ListDetailFocusTraversal.maybeOf(
      tester.element(find.byType(TaskDetailsPage)),
    );
    splitController!.hideListPane();
    await tester.pump();
    await tester.pump();
  }

  JournalPageState state() => const JournalPageState(
    showTasks: true,
    taskStatuses: ['OPEN'],
    selectedTaskStatuses: {'OPEN'},
    selectedEntryTypes: ['Task'],
  );

  testWidgets('renders TasksTabPage', (tester) async {
    fakeController = FakeJournalPageController(state());

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const TasksRootPage(),
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(TasksTabPage), findsOneWidget);
    expect(find.byType(InfiniteJournalPage), findsNothing);
    // Content, not just the type: the mobile layout shows the tab page
    // full-bleed — no desktop split chrome.
    expect(find.byType(ResizableDivider), findsNothing);
    expect(find.byType(DesktopDetailEmptyState), findsNothing);
  });

  testWidgets('renders desktop split layout with empty detail pane', (
    tester,
  ) async {
    fakeController = FakeJournalPageController(state());

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const TasksRootPage(),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(TasksTabPage), findsOneWidget);
    expect(find.byType(ListDetailFocusTraversal), findsOneWidget);
    expect(find.byType(DesktopDetailEmptyState), findsOneWidget);
    // Content, not just the type: the empty pane shows the localized
    // "select a task" prompt and its touch glyph.
    final emptyState = tester.widget<DesktopDetailEmptyState>(
      find.byType(DesktopDetailEmptyState),
    );
    expect(emptyState.message, 'Select a task to view details');
    expect(emptyState.icon, LottiIcons.touch);
    expect(find.text('Select a task to view details'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 432,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders desktop split layout with selected task detail', (
    tester,
  ) async {
    fakeController = FakeJournalPageController(state());

    final navService = getIt<NavService>() as MockNavService;
    final stackNotifier = ValueNotifier<List<String>>(<String>['task-42']);
    when(
      () => navService.desktopTaskDetailStack,
    ).thenReturn(stackNotifier);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const TasksRootPage(),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(TasksTabPage), findsOneWidget);
    expect(find.byType(DesktopDetailEmptyState), findsNothing);
    expect(find.byType(TaskDetailsPage), findsOneWidget);
    expect(
      tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).taskId,
      'task-42',
    );

    // Dispose the widget tree and flush pending timers from
    // flutter_animate inside the detail page.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  group('the persistent details column', () {
    Future<void> pumpFocused(
      WidgetTester tester, {
      required double paneWidth,
    }) async {
      fakeController = FakeJournalPageController(state());

      final navService = getIt<NavService>() as MockNavService;
      final stackNotifier = ValueNotifier<List<String>>(<String>['task-42']);
      addTearDown(stackNotifier.dispose);
      when(
        () => navService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);

      // The real surface, not just a MediaQuery value: the column is gated
      // on the pane's layout constraints.
      await tester.binding.setSurfaceSize(Size(paneWidth, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TasksRootPage(),
          // Window stays wide (desktop layout); the *pane* is what
          // narrows — exactly the shape a collapsed navigation sidebar or a
          // small window puts the task page in.
          mediaQueryData: const MediaQueryData(size: Size(1600, 800)),
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();

      // Collapse the list — the column is the focus-mode layout.
      await hideListPane(tester);
    }

    Future<void> disposeTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    testWidgets('mounts beside a focused task on a wide enough pane', (
      tester,
    ) async {
      await pumpFocused(tester, paneWidth: 1400);

      expect(find.byType(TaskMetaColumn), findsOneWidget);
      // The task column pays for it: it keeps the rest of the pane, exactly.
      expect(
        tester.getSize(find.byType(TaskMetaColumn)).width,
        kTaskMetaColumnWidth,
      );
      expect(
        tester.getSize(find.byType(TaskDetailsPage)).width,
        1400 - kTaskMetaColumnWidth,
      );
      await disposeTree(tester);
    });

    testWidgets('falls back to the fly-out below the breakpoint', (
      tester,
    ) async {
      await pumpFocused(tester, paneWidth: kTaskMetaColumnMinHostWidth - 1);

      expect(find.byType(TaskMetaColumn), findsNothing);
      // Nothing else changes: the task still owns the whole pane.
      expect(
        tester.getSize(find.byType(TaskDetailsPage)).width,
        kTaskMetaColumnMinHostWidth - 1,
      );
      await disposeTree(tester);
    });

    testWidgets('stays away while the task list is visible', (tester) async {
      fakeController = FakeJournalPageController(state());

      final navService = getIt<NavService>() as MockNavService;
      final stackNotifier = ValueNotifier<List<String>>(<String>['task-42']);
      addTearDown(stackNotifier.dispose);
      when(
        () => navService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TasksRootPage(),
          mediaQueryData: const MediaQueryData(size: Size(1600, 800)),
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();

      // Browsing: list, divider and task. Three columns, not four.
      expect(find.byType(TasksTabPage), findsOneWidget);
      expect(find.byType(TaskMetaColumn), findsNothing);
      await disposeTree(tester);
    });
  });

  group('day-view column starving the split', () {
    /// Pumps the split with a task open in a content region [regionWidth]
    /// wide, on a desktop-layout window (MediaQuery stays at 1600), and
    /// returns the pane-width controller so a test can bring the day-view
    /// column up or read the persisted flags.
    Future<ProviderContainer> pumpWithTask(
      WidgetTester tester, {
      required double regionWidth,
    }) async {
      fakeController = FakeJournalPageController(state());
      final navService = getIt<NavService>() as MockNavService;
      final stackNotifier = ValueNotifier<List<String>>(<String>['task-42']);
      addTearDown(stackNotifier.dispose);
      when(
        () => navService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);

      await tester.binding.setSurfaceSize(Size(regionWidth, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TasksRootPage(),
          mediaQueryData: const MediaQueryData(size: Size(1600, 800)),
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();
      return ProviderScope.containerOf(
        tester.element(find.byType(TasksRootPage)),
      );
    }

    Future<void> showDayViewColumn(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      container.read(paneWidthControllerProvider.notifier).showDayViewPanel();
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'gives the open task the whole region while the column is up on a '
      'region below the desktop breakpoint, without touching the collapse '
      'flag',
      (tester) async {
        final container = await pumpWithTask(tester, regionWidth: 900);
        expect(find.byType(TasksTabPage), findsOneWidget);

        await showDayViewColumn(tester, container);

        expect(find.byType(TasksTabPage), findsNothing);
        expect(
          find.byType(TasksTabPage, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.byType(ResizableDivider), findsNothing);
        expect(find.byType(TaskDetailsPage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('tasks-show-list-pane')),
          findsOneWidget,
        );
        // Forced by geometry, not chosen: the persisted flag stays clear so
        // the list returns on its own once there is room again.
        expect(
          container.read(paneWidthControllerProvider).listPaneCollapsed,
          isFalse,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'asking for the list back yields the day-view column instead of '
      'flipping a flag that changes nothing',
      (tester) async {
        final container = await pumpWithTask(tester, regionWidth: 900);
        await showDayViewColumn(tester, container);
        expect(find.byType(TasksTabPage), findsNothing);

        await tester.tap(find.byKey(const ValueKey('tasks-show-list-pane')));
        await tester.pump();
        await tester.pump();

        expect(
          container.read(paneWidthControllerProvider).dayViewPanelHidden,
          isTrue,
        );
        expect(find.byType(TasksTabPage), findsOneWidget);
        expect(find.byType(ResizableDivider), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'keeps the list beside the task while the column is hidden, even on a '
      'narrow region',
      (tester) async {
        final container = await pumpWithTask(tester, regionWidth: 900);
        expect(
          container.read(paneWidthControllerProvider).dayViewPanelHidden,
          isTrue,
        );

        expect(find.byType(TasksTabPage), findsOneWidget);
        expect(find.byType(ResizableDivider), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'keeps the list beside the task while the column is up on a region '
      'wide enough for both',
      (tester) async {
        final container = await pumpWithTask(tester, regionWidth: 1400);
        await showDayViewColumn(tester, container);

        expect(find.byType(TasksTabPage), findsOneWidget);
        expect(find.byType(ResizableDivider), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets(
    'focus mode hides and restores the selected task list while preserving it',
    (tester) async {
      fakeController = FakeJournalPageController(state());

      final navService = getIt<NavService>() as MockNavService;
      final stackNotifier = ValueNotifier<List<String>>(<String>['task-42']);
      addTearDown(stackNotifier.dispose);
      when(
        () => navService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TasksRootPage(),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();

      // The list header no longer carries the toggle: it moved to the task
      // detail header, so selecting a task can never shift the list title
      // sideways to make room for it.
      expect(
        find.descendant(
          of: find.byType(TasksTabPage),
          matching: find.byKey(const ValueKey('tasks-hide-list-pane')),
        ),
        findsNothing,
      );
      final detailElement = tester.element(find.byType(TaskDetailsPage));
      await hideListPane(tester);

      expect(find.byType(TasksTabPage), findsNothing);
      expect(
        find.byType(TasksTabPage, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(ResizableDivider), findsNothing);
      expect(find.byType(TaskDetailsPage), findsOneWidget);
      expect(tester.element(find.byType(TaskDetailsPage)), detailElement);
      expect(
        find.byKey(const ValueKey('tasks-show-list-pane')),
        findsOneWidget,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TasksRootPage)),
      );
      expect(
        container.read(paneWidthControllerProvider).listPaneCollapsed,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('tasks-show-list-pane')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TasksTabPage), findsOneWidget);
      expect(find.byType(ResizableDivider), findsOneWidget);
      expect(tester.element(find.byType(TaskDetailsPage)), detailElement);
      expect(
        container.read(paneWidthControllerProvider).listPaneCollapsed,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('focus-search restores a hidden task list before focusing', (
    tester,
  ) async {
    fakeController = FakeJournalPageController(state());

    final navService = getIt<NavService>() as MockNavService;
    final stackNotifier = ValueNotifier<List<String>>(<String>['task-42']);
    addTearDown(stackNotifier.dispose);
    when(
      () => navService.desktopTaskDetailStack,
    ).thenReturn(stackNotifier);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AppCommandHost(
          handlers: {},
          platform: TargetPlatform.windows,
          child: TasksRootPage(),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
        ],
      ),
    );
    await tester.pump();

    await hideListPane(tester);

    final taskSearch = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.focusNode?.debugLabel == 'tasks-search',
      skipOffstage: false,
    );
    expect(taskSearch, findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.focusNode?.debugLabel == 'tasks-search',
      ),
      findsNothing,
    );

    final detailContext = tester.element(find.byType(TaskDetailsPage));
    final commandController = AppCommandControllerProvider.of(detailContext);
    expect(
      await commandController.invoke(detailContext, AppCommandId.focusSearch),
      isTrue,
    );
    await tester.pump();
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TasksRootPage)),
    );
    expect(
      container.read(paneWidthControllerProvider).listPaneCollapsed,
      isFalse,
    );
    expect(tester.widget<TextField>(taskSearch).focusNode?.hasFocus, isTrue);
  });

  testWidgets(
    'wraps detail pane in AnimatedSwitcher and crossfades between tasks',
    (tester) async {
      fakeController = FakeJournalPageController(state());

      final navService = getIt<NavService>() as MockNavService;
      final stackNotifier = ValueNotifier<List<String>>(<String>['task-a']);
      when(
        () => navService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TasksRootPage(),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(TaskDetailsPage), findsOneWidget);
      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).taskId,
        'task-a',
      );

      // Replace base task — mid-transition both pages coexist.
      stackNotifier.value = <String>['task-b'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TaskDetailsPage), findsNWidgets(2));
      final outgoingTask = find.byWidgetPredicate(
        (widget) => widget is TaskDetailsPage && widget.taskId == 'task-a',
      );
      final outgoingFocusGuard = find.ancestor(
        of: outgoingTask,
        matching: find.byType(ExcludeFocus),
      );
      expect(
        tester
            .widgetList<ExcludeFocus>(outgoingFocusGuard)
            .where((guard) => guard.excluding),
        hasLength(1),
      );

      // After the 480ms fade, only the new task remains.
      await tester.pump(const Duration(milliseconds: 360));
      expect(find.byType(TaskDetailsPage), findsOneWidget);
      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).taskId,
        'task-b',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'pushing onto the stack swaps to the linked task and crossfades',
    (tester) async {
      fakeController = FakeJournalPageController(state());

      final navService = getIt<NavService>() as MockNavService;
      final stackNotifier = ValueNotifier<List<String>>(<String>['base-task']);
      when(
        () => navService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TasksRootPage(),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();

      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).taskId,
        'base-task',
      );

      // Simulate pushing a linked task onto the desktop stack.
      stackNotifier.value = <String>['base-task', 'linked-task'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TaskDetailsPage), findsOneWidget);
      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).taskId,
        'linked-task',
      );

      // Pop returns to the base task.
      stackNotifier.value = <String>['base-task'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).taskId,
        'base-task',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'does not animate when the stack stays the same',
    (tester) async {
      fakeController = FakeJournalPageController(state());

      final navService = getIt<NavService>() as MockNavService;
      final stackNotifier = ValueNotifier<List<String>>(
        <String>['task-stable'],
      );
      when(
        () => navService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TasksRootPage(),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(TaskDetailsPage), findsOneWidget);

      // Re-emit the same stack — simulates a data-reload code path that
      // happens to rebuild the outer ValueListenableBuilder.
      stackNotifier.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Still exactly one TaskDetailsPage — no crossfade in flight.
      expect(find.byType(TaskDetailsPage), findsOneWidget);
      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).taskId,
        'task-stable',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('dragging divider updates list pane width', (tester) async {
    fakeController = FakeJournalPageController(state());

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const TasksRootPage(),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(ResizableDivider), findsOneWidget);

    final dividerCenter = tester.getCenter(find.byType(ResizableDivider));
    await tester.dragFrom(dividerCenter, const Offset(50, 0));
    await tester.pump();

    final sizedBox = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == defaultListPaneWidth + 50,
      ),
    );
    expect(sizedBox.width, defaultListPaneWidth + 50);
  });

  testWidgets('dragging the ResizableDivider widens the list pane', (
    tester,
  ) async {
    fakeController = FakeJournalPageController(state());

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const TasksRootPage(),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
        ],
      ),
    );
    await tester.pump();

    double listPaneWidth() => tester
        .widget<SizedBox>(
          find.ancestor(
            of: find.byType(TasksTabPage),
            matching: find.byType(SizedBox),
          ),
        )
        .width!;

    final before = listPaneWidth();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TasksRootPage)),
    );
    container.read(paneWidthControllerProvider.notifier).collapseListPane();
    await tester.pump();

    expect(find.byType(ResizableDivider), findsOneWidget);
    expect(
      container.read(paneWidthControllerProvider).listPaneCollapsed,
      isTrue,
    );

    await tester.drag(
      find.byType(ResizableDivider),
      const Offset(80, 0),
    );
    await tester.pump();

    expect(listPaneWidth(), greaterThan(before));
    // The width delta is forwarded to the pane controller, not just local
    // layout: the divider's onDrag updates paneWidthControllerProvider.
    expect(listPaneWidth(), before + 80);
    expect(
      container.read(paneWidthControllerProvider).listPaneCollapsed,
      isTrue,
    );
    await tester.pump(persistDebounce);
  });
}
