import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_card.dart';

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
