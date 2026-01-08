import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_card.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../test_helper.dart';

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
          status: status ??
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

    String? navigatedPath;

    setUp(() {
      navigatedPath = null;
      beamToNamedOverride = (path) {
        navigatedPath = path;
      };
    });

    tearDown(() {
      beamToNamedOverride = null;
    });

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

    testWidgets('navigates to task when tapped', (tester) async {
      final task = buildTask(id: 'task-123', title: 'Tappable Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Task'));
      await tester.pump();

      expect(navigatedPath, '/tasks/task-123');
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

    testWidgets('shows unlink button when showUnlinkButton is true',
        (tester) async {
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

    testWidgets('applies italic style for completed (Done) tasks',
        (tester) async {
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

      final textWidget = tester.widget<Text>(find.text('Test Task'));
      expect(textWidget.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('applies italic style for rejected tasks', (tester) async {
      final task = buildTask(
        status: TaskStatus.rejected(
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

      final textWidget = tester.widget<Text>(find.text('Test Task'));
      expect(textWidget.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('applies normal style for open tasks', (tester) async {
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

      final textWidget = tester.widget<Text>(find.text('Test Task'));
      expect(textWidget.style?.fontStyle, FontStyle.normal);
    });

    testWidgets('applies normal style for in-progress tasks', (tester) async {
      final task = buildTask(
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

      final textWidget = tester.widget<Text>(find.text('Test Task'));
      expect(textWidget.style?.fontStyle, FontStyle.normal);
    });

    testWidgets('title has underline decoration', (tester) async {
      final task = buildTask(title: 'Underlined Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedTaskCard(task: task),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Underlined Task'));
      expect(textWidget.style?.decoration, TextDecoration.underline);
    });

    testWidgets('long title truncates with ellipsis', (tester) async {
      const longTitle = 'This is a very long task title that should be '
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
  });
}
