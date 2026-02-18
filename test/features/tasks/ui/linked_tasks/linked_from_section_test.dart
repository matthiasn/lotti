import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_from_section.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

void main() {
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

  group('LinkedFromSection', () {
    setUp(() async {
      await setUpTestGetIt();
    });

    tearDown(() async {
      await tearDownTestGetIt();
    });

    testWidgets('returns SizedBox.shrink when incomingTasks is empty',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [],
              manageMode: false,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('LINKED FROM'), findsNothing);
    });

    testWidgets('renders directional label when tasks exist', (tester) async {
      final task = buildTask(id: 'linked-task-1', title: 'Linked Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task],
              manageMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('↳ '), findsOneWidget);
      expect(find.text('LINKED FROM'), findsOneWidget);
    });

    testWidgets('renders LinkedTaskCard for each task', (tester) async {
      final task1 = buildTask(title: 'First Task');
      final task2 = buildTask(id: 'task-2', title: 'Second Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task1, task2],
              manageMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('First Task'), findsOneWidget);
      expect(find.text('Second Task'), findsOneWidget);
      expect(find.byType(LinkedTaskCard), findsNWidgets(2));
    });

    testWidgets('shows unlink buttons in manage mode', (tester) async {
      final task = buildTask(title: 'Linked Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task],
              manageMode: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('hides unlink buttons when not in manage mode', (tester) async {
      final task = buildTask(title: 'Linked Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task],
              manageMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('tapping unlink shows confirmation dialog', (tester) async {
      final task = buildTask(title: 'Linked Task');
      final mockRepo = MockJournalRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task],
              manageMode: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Unlink Task'), findsOneWidget);
      expect(find.text('Are you sure you want to unlink this task?'),
          findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Unlink'), findsOneWidget);
    });

    testWidgets('cancel button dismisses confirmation dialog', (tester) async {
      final task = buildTask(title: 'Linked Task');

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task],
              manageMode: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Unlink Task'), findsNothing);
    });

    testWidgets('confirm unlink calls repository removeLink', (tester) async {
      final task = buildTask(id: 'linking-task', title: 'Linked Task');
      final mockRepo = MockJournalRepository();

      when(() => mockRepo.removeLink(
            fromId: 'linking-task',
            toId: 'task-main',
          )).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task],
              manageMode: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap Unlink
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.removeLink(
            fromId: 'linking-task',
            toId: 'task-main',
          )).called(1);
    });

    testWidgets('renders section inside a Column', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task],
              manageMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Section should render in a Column with CrossAxisAlignment.start
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('renders label with correct styling', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: LinkedFromSection(
              taskId: 'task-main',
              incomingTasks: [task],
              manageMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the label text and verify it renders
      expect(find.text('↳ '), findsOneWidget);
      expect(find.text('LINKED FROM'), findsOneWidget);

      // Both should be in a Row
      expect(find.byType(Row), findsWidgets);
    });
  });
}
