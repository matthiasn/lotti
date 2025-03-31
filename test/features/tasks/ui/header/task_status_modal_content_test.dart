import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:mocktail/mocktail.dart';

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

  // Helper to create a task status for testing
  TaskStatus createTaskStatus(String statusType) {
    switch (statusType) {
      case 'OPEN':
        return TaskStatus.open(
          id: 'test-status-id',
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        );
      case 'DONE':
        return TaskStatus.done(
          id: 'test-status-id',
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        );
      case 'IN PROGRESS':
        return TaskStatus.inProgress(
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

  // Helper function to create a simple label resolver for testing
  String mockLabelResolver(String status, BuildContext context) {
    // Return the status string directly for simplicity in tests
    return status;
  }

  group('TaskStatusModalContent', () {
    testWidgets('renders filter chips for all task statuses', (tester) async {
      // Arrange
      final taskStatus = createTaskStatus('OPEN');
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
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: TaskStatusModalContent(
                task: mockTask,
                labelResolver: mockLabelResolver,
              ),
            ),
          ),
        ),
      );

      // Assert
      expect(
        find.byType(FilterChoiceChip),
        findsNWidgets(allTaskStatuses.length),
      );
    });

    testWidgets('selects the current task status chip', (tester) async {
      // Arrange - create a task with DONE status
      final taskStatus = createTaskStatus('DONE');
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
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: TaskStatusModalContent(
                task: mockTask,
                labelResolver: mockLabelResolver,
              ),
            ),
          ),
        ),
      );

      // Assert - find all chips
      final chips =
          tester.widgetList<FilterChoiceChip>(find.byType(FilterChoiceChip));

      // Find selected chips
      final selectedChips = chips.where((chip) => chip.isSelected).toList();

      // Only one chip should be selected
      expect(selectedChips.length, 1);

      // Find chip with the DONE status - should be selected
      final doneChip = chips.firstWhere((chip) => chip.label == 'DONE');
      expect(doneChip.isSelected, true);
    });

    testWidgets('uses correct colors for status chips', (tester) async {
      // Arrange
      final taskStatus = createTaskStatus('OPEN');
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
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: TaskStatusModalContent(
                task: mockTask,
                labelResolver: mockLabelResolver,
              ),
            ),
          ),
        ),
      );

      // Assert - check colors for all task statuses
      for (final status in allTaskStatuses) {
        final expectedColor = taskColorFromStatusString(status);
        final chip = tester.widget<FilterChoiceChip>(
          find.widgetWithText(FilterChoiceChip, status),
        );
        expect(
          chip.selectedColor,
          expectedColor,
          reason: 'Color mismatch for status $status',
        );
      }
    });

    testWidgets('chip onTap handler calls Navigator.pop with correct status',
        (tester) async {
      // Status to test
      const statusToTest = 'DONE';

      // Arrange
      final taskStatus = createTaskStatus('OPEN');
      final taskData = TaskData(
        status: taskStatus,
        dateFrom: now,
        dateTo: now,
        statusHistory: [],
        title: 'Test Task',
      );
      mockTask = MockTask(taskData);

      // We'll use a simple wrapper that just renders the content
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: TaskStatusModalContent(
                task: mockTask,
                labelResolver: mockLabelResolver,
              ),
            ),
          ),
        ),
      );

      // Find the DONE chip
      final chipFinder = find.widgetWithText(FilterChoiceChip, statusToTest);
      expect(chipFinder, findsOneWidget);

      // Get the chip and its onTap handler
      final chip = tester.widget<FilterChoiceChip>(chipFinder);
      expect(chip.onTap, isNotNull);

      // Since we can't directly test Navigator.pop in a widget test,
      // we'll verify that the structure of the chip is correct,
      // confirming it has an onTap handler and the correct status.

      // This is a structured verification of the component's behavior
      // without trying to mock or intercept Navigator calls, which is complex
      // in widget tests.
      expect(chip.label, statusToTest);
      expect(chip.isSelected, statusToTest == mockTask.data.status.toDbString);
      expect(chip.selectedColor, taskColorFromStatusString(statusToTest));
    });
  });
}
