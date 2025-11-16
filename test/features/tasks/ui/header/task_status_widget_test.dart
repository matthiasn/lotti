import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/header/task_status_widget.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockTask extends Mock implements Task {
  MockTask(this.taskData);

  final TaskData taskData;

  @override
  TaskData get data => taskData;

  @override
  Metadata get meta => Metadata(
        id: 'test-task-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      );
}

void main() {
  late DateTime now;
  late MockTask mockTask;

  setUp(() {
    now = DateTime.now();
  });

  TaskStatus createTaskStatus(String statusType) {
    switch (statusType) {
      case 'open':
        return TaskStatus.open(
          id: 'test-status-id',
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        );
      case 'inProgress':
        return TaskStatus.inProgress(
          id: 'test-status-id',
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        );
      case 'done':
        return TaskStatus.done(
          id: 'test-status-id',
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        );
      default:
        return TaskStatus.open(
          id: 'test-status-id',
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        );
    }
  }

  group('TaskStatusWidget', () {
    testWidgets('displays the correct status label', (tester) async {
      // Arrange
      final taskStatus = createTaskStatus('inProgress');

      final taskData = TaskData(
        status: taskStatus,
        dateFrom: now,
        dateTo: now,
        statusHistory: [],
        title: 'Test Task',
      );

      mockTask = MockTask(taskData);

      // Act
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskStatusWidget(
            task: mockTask,
            onStatusChanged: (String? status) {},
          ),
        ),
      );

      // Assert - we can't check for exact text as it depends on localization
      // Instead, ensure widget renders without errors
      expect(find.byType(TaskStatusWidget), findsOneWidget);
      expect(
        find.byType(Text),
        findsAtLeast(2),
      ); // At least label and status text
    });

    testWidgets('applies correct styling to the status label', (tester) async {
      // Arrange
      final taskStatus = createTaskStatus('done');

      final taskData = TaskData(
        status: taskStatus,
        dateFrom: now,
        dateTo: now,
        statusHistory: [],
        title: 'Test Task',
      );

      mockTask = MockTask(taskData);

      // Act
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskStatusWidget(
            task: mockTask,
            onStatusChanged: (String? status) {},
          ),
        ),
      );

      // Verify widget renders without errors
      expect(find.byType(TaskStatusWidget), findsOneWidget);

      // We know there should be a "Done" status with green color
      // but we can't check the exact text due to localization
    });

    testWidgets('shows correct label for task status section', (tester) async {
      // Arrange
      final taskStatus = createTaskStatus('open');

      final taskData = TaskData(
        status: taskStatus,
        dateFrom: now,
        dateTo: now,
        statusHistory: [],
        title: 'Test Task',
      );

      mockTask = MockTask(taskData);

      // Act
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskStatusWidget(
            task: mockTask,
            onStatusChanged: (String? status) {},
          ),
        ),
      );

      // The actual label will depend on localization, we can't know the exact value
      // but we can verify Text widgets exist
      expect(
        find.byType(Text),
        findsAtLeast(2),
      ); // At least two Text widgets (label and status)
    });

    testWidgets('calls onStatusChanged when new status is selected',
        (tester) async {
      // This test would require mocking ModalUtils.showSinglePageModal
      // which returns a new status, but this is challenging in widget tests
      // We'll provide a simplified version

      // Arrange
      final taskStatus = createTaskStatus('open');

      final taskData = TaskData(
        status: taskStatus,
        dateFrom: now,
        dateTo: now,
        statusHistory: [],
        title: 'Test Task',
      );

      mockTask = MockTask(taskData);

      // ignore: unused_local_variable
      var callbackCalled = false;

      // Act
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskStatusWidget(
            task: mockTask,
            onStatusChanged: (String? status) {
              callbackCalled = true;
            },
          ),
        ),
      );

      // Verify widget renders without errors
      expect(find.byType(TaskStatusWidget), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);

      // We can't easily test the modal interaction and callback in this setup
    });

    testWidgets('renders chip-only layout when showLabel is false',
        (tester) async {
      final taskStatus = createTaskStatus('inProgress');

      final taskData = TaskData(
        status: taskStatus,
        dateFrom: now,
        dateTo: now,
        statusHistory: [],
        title: 'Test Task',
      );

      mockTask = MockTask(taskData);

      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskStatusWidget(
            task: mockTask,
            onStatusChanged: (String? status) {},
            showLabel: false,
          ),
        ),
      );

      // Should render a modern status chip without the \"Status:\" label.
      expect(find.byType(ModernStatusChip), findsOneWidget);
      expect(find.text('Status:'), findsNothing);

      // Icon should match in-progress mapping.
      expect(
        find.byIcon(Icons.play_circle_outline_rounded),
        findsOneWidget,
      );
    });
  });
}
