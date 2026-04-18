import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJournalPageController fakeController;

  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<UserActivityService>(UserActivityService());
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(false);
        when(
          () => mockNavService.desktopSelectedTaskId,
        ).thenReturn(ValueNotifier<String?>(null));
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
    expect(find.byType(DesktopDetailEmptyState), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 540,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders desktop split layout with selected task detail', (
    tester,
  ) async {
    fakeController = FakeJournalPageController(state());

    final navService = getIt<NavService>() as MockNavService;
    final selectedNotifier = ValueNotifier<String?>('task-42');
    when(
      () => navService.desktopSelectedTaskId,
    ).thenReturn(selectedNotifier);

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
      tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).key,
      const ValueKey('task-42'),
    );

    // Dispose the widget tree and flush pending timers from
    // flutter_animate inside the detail page.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'wraps detail pane in AnimatedSwitcher and crossfades between tasks',
    (tester) async {
      fakeController = FakeJournalPageController(state());

      final navService = getIt<NavService>() as MockNavService;
      final selectedNotifier = ValueNotifier<String?>('task-a');
      when(
        () => navService.desktopSelectedTaskId,
      ).thenReturn(selectedNotifier);

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

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(TaskDetailsPage), findsOneWidget);
      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).key,
        const ValueKey('task-a'),
      );

      // Switch to a different task id — mid-transition both pages coexist.
      selectedNotifier.value = 'task-b';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TaskDetailsPage), findsNWidgets(2));

      // After the 480ms fade, only the new task remains.
      await tester.pump(const Duration(milliseconds: 360));
      expect(find.byType(TaskDetailsPage), findsOneWidget);
      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).key,
        const ValueKey('task-b'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'does not animate when the selected task id stays the same',
    (tester) async {
      fakeController = FakeJournalPageController(state());

      final navService = getIt<NavService>() as MockNavService;
      final selectedNotifier = ValueNotifier<String?>('task-stable');
      when(
        () => navService.desktopSelectedTaskId,
      ).thenReturn(selectedNotifier);

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

      // Re-emit the same id — simulates a data-reload code path that
      // happens to rebuild the outer ValueListenableBuilder.
      selectedNotifier.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Still exactly one TaskDetailsPage — no crossfade in flight.
      expect(find.byType(TaskDetailsPage), findsOneWidget);
      expect(
        tester.widget<TaskDetailsPage>(find.byType(TaskDetailsPage)).key,
        const ValueKey('task-stable'),
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
}
