import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_card.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

class _RoutePushObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}

void main() {
  group('LinkedTaskCard', () {
    final now = DateTime(2025, 12, 31, 12);

    Task buildTask({
      String id = 'task-1',
      String title = 'Test Task',
      TaskStatus? status,
    }) {
      return Task(
        meta: Metadata(
          id: id,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          status:
              status ??
              TaskStatus.open(
                id: 'status-1',
                createdAt: now,
                utcOffset: 0,
              ),
          dateFrom: now,
          dateTo: now,
          statusHistory: const [],
          title: title,
        ),
      );
    }

    testWidgets('renders task title', (tester) async {
      final task = buildTask(title: 'My Task Title');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      expect(find.text('My Task Title'), findsOneWidget);
    });

    testWidgets('card is tappable with GestureDetector', (tester) async {
      final task = buildTask(id: 'task-123', title: 'Tappable Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      // Verify GestureDetector is present for tap handling
      expect(find.byType(GestureDetector), findsOneWidget);

      // Verify the gesture detector has opaque hit test behavior
      final gestureDetector = tester.widget<GestureDetector>(
        find.byType(GestureDetector),
      );
      expect(gestureDetector.behavior, HitTestBehavior.opaque);
    });

    testWidgets('does not show unlink button by default', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('shows unlink button when showUnlinkButton is true', (
      tester,
    ) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(
              task: task,
              showUnlinkButton: true,
              onUnlink: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('calls onUnlink when unlink button is pressed', (tester) async {
      var unlinkCalled = false;
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(
              task: task,
              showUnlinkButton: true,
              onUnlink: () {
                unlinkCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(unlinkCalled, isTrue);
    });

    testWidgets('title has no underline decoration', (tester) async {
      final task = buildTask(title: 'Plain Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Plain Task'));
      // No underline - chevron provides tap affordance instead
      expect(textWidget.style?.decoration, isNot(TextDecoration.underline));
    });

    testWidgets('shows chevron for tap affordance', (tester) async {
      final task = buildTask(title: 'Task with Chevron');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      // Chevron indicates tappable row
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('hides chevron when showUnlinkButton is true', (tester) async {
      final task = buildTask(title: 'Task in Manage Mode');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(
              task: task,
              showUnlinkButton: true,
              onUnlink: () {},
            ),
          ),
        ),
      );

      // In manage mode, unlink button replaces chevron
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('chevron uses status color', (tester) async {
      final task = buildTask(
        title: 'Task with colored chevron',
        status: TaskStatus.inProgress(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      // Chevron should use the same color as the status circle
      final chevron = tester.widget<Icon>(
        find.byIcon(Icons.chevron_right_rounded),
      );
      expect(chevron.color, isNotNull);
    });

    testWidgets('long title truncates with ellipsis', (tester) async {
      const longTitle =
          'This is a very long task title that should be '
          'truncated when it exceeds the available width in the card';
      final task = buildTask(title: longTitle);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(300, 600)),
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text(longTitle));
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('renders status circle for open task', (tester) async {
      final task = buildTask(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      // Should have a container with circular border (the status circle)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('completed task shows check icon in circle', (tester) async {
      final task = buildTask(
        status: TaskStatus.done(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('renders within a Row with Expanded for title', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      expect(find.byType(Row), findsWidgets);
      expect(find.byType(Expanded), findsOneWidget);
    });

    group('navigation on tap', () {
      late MockNavService mockNavService;

      setUp(() {
        mockNavService = MockNavService();
        when(
          () => mockNavService.pushDesktopTaskDetail(any()),
        ).thenAnswer((_) {});
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
        getIt
          ..allowReassignment = true
          ..registerSingleton<NavService>(mockNavService);
      });

      tearDown(() {
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
      });

      testWidgets(
        'desktop tap pushes onto NavService desktop detail stack',
        (tester) async {
          final task = buildTask(id: 'task-target');

          await tester.pumpWidget(
            ProviderScope(
              child: WidgetTestBench(
                mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
                child: LinkedTaskCard(task: task),
              ),
            ),
          );

          await tester.tap(find.byType(GestureDetector));
          await tester.pump();

          verify(
            () => mockNavService.pushDesktopTaskDetail('task-target'),
          ).called(1);
          // Desktop must NOT push a MaterialPageRoute that would cover both
          // panes — verify no TaskDetailsPage was pushed onto the navigator.
          expect(find.byType(TaskDetailsPage), findsNothing);
        },
      );

      testWidgets(
        'mobile tap pushes a MaterialPageRoute onto the navigator',
        (tester) async {
          final task = buildTask(id: 'task-mobile');
          final observer = _RoutePushObserver();

          await tester.pumpWidget(
            ProviderScope(
              child: MediaQuery(
                data: const MediaQueryData(size: Size(400, 800)),
                child: MaterialApp(
                  theme: resolveTestTheme(),
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  navigatorObservers: [observer],
                  home: Scaffold(
                    body: LinkedTaskCard(task: task),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.byType(GestureDetector));
          // Don't pumpAndSettle — TaskDetailsPage tries to read services
          // from getIt that are intentionally not wired up here.

          verifyNever(
            () => mockNavService.pushDesktopTaskDetail(any()),
          );
          // Initial push of the home route + the linked task push.
          expect(observer.pushedRoutes.length, 2);
          final pushed = observer.pushedRoutes.last;
          expect(pushed, isA<MaterialPageRoute<void>>());
          final builder = (pushed as MaterialPageRoute<void>).builder;
          expect(
            builder(tester.element(find.byType(Scaffold))),
            isA<TaskDetailsPage>(),
          );
        },
      );
    });
  });
}
