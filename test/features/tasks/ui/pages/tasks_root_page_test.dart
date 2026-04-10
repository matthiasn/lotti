import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
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
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
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

    // Dispose the widget tree and flush pending timers from
    // flutter_animate inside the detail page.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
