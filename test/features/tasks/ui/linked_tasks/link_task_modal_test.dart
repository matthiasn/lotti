import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  group('LinkTaskModal', () {
    late MockJournalDb mockJournalDb;
    late MockFts5Db mockFts5Db;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;

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

    setUp(() async {
      await getIt.reset();

      mockJournalDb = MockJournalDb();
      mockFts5Db = MockFts5Db();
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();

      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => const Stream.empty());

      // Default: return empty task list
      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <JournalEntity>[]);

      // Default: FTS returns empty
      when(() => mockFts5Db.watchFullTextMatches(any()))
          .thenAnswer((_) => Stream.value(<String>[]));

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('renders title "Link existing task..."', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      // Tap to open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Link existing task...'), findsOneWidget);
    });

    testWidgets('renders search field with hint', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Search tasks...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('modal uses DraggableScrollableSheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('displays tasks from database', (tester) async {
      final testTasks = [
        buildTask(title: 'First Task'),
        buildTask(id: 'task-2', title: 'Second Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('First Task'), findsOneWidget);
      expect(find.text('Second Task'), findsOneWidget);
    });

    testWidgets('excludes current task from results', (tester) async {
      final testTasks = [
        buildTask(id: 'current-task', title: 'Current Task'),
        buildTask(id: 'other-task', title: 'Other Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Current task should be filtered out
      expect(find.text('Current Task'), findsNothing);
      expect(find.text('Other Task'), findsOneWidget);
    });

    testWidgets('excludes already linked tasks from results', (tester) async {
      final testTasks = [
        buildTask(id: 'linked-task', title: 'Already Linked'),
        buildTask(id: 'available-task', title: 'Available Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {'linked-task'},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Already linked task should be filtered out
      expect(find.text('Already Linked'), findsNothing);
      expect(find.text('Available Task'), findsOneWidget);
    });

    testWidgets('has a handle bar for dragging', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Handle bar is rendered with a specific key
      expect(find.byKey(const Key('link_task_modal_handle')), findsOneWidget);
    });

    testWidgets('shows status icons for tasks', (tester) async {
      final testTasks = [
        buildTask(
          title: 'Open Task',
          status: TaskStatus.open(id: 's1', createdAt: now, utcOffset: 0),
        ),
        buildTask(
          id: 'task-2',
          title: 'In Progress Task',
          status: TaskStatus.inProgress(id: 's2', createdAt: now, utcOffset: 0),
        ),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Status icons should be present
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('shows link icon for each task item', (tester) async {
      final testTasks = [buildTask(title: 'Some Task')];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Each task shows add_link icon as trailing
      expect(find.byIcon(Icons.add_link_rounded), findsOneWidget);
    });

    testWidgets('modal opens as bottom sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify modal is open as a BottomSheet
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('shows no tasks message when no tasks available',
        (tester) async {
      // Default mock returns empty list
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('No tasks available to link'), findsOneWidget);
    });

    testWidgets('filters tasks by search query', (tester) async {
      final testTasks = [
        buildTask(title: 'Apple Task'),
        buildTask(id: 'task-2', title: 'Banana Task'),
        buildTask(id: 'task-3', title: 'Cherry Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // All tasks should be visible initially
      expect(find.text('Apple Task'), findsOneWidget);
      expect(find.text('Banana Task'), findsOneWidget);
      expect(find.text('Cherry Task'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'banana');
      await tester.pumpAndSettle();

      // Only matching task should be visible
      expect(find.text('Apple Task'), findsNothing);
      expect(find.text('Banana Task'), findsOneWidget);
      expect(find.text('Cherry Task'), findsNothing);
    });

    testWidgets('shows no tasks found when search has no matches',
        (tester) async {
      final testTasks = [
        buildTask(title: 'Apple Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Enter search query with no matches
      await tester.enterText(find.byType(TextField), 'xyz123');
      await tester.pumpAndSettle();

      expect(find.text('No tasks found'), findsOneWidget);
    });

    testWidgets('clear button clears search text', (tester) async {
      final testTasks = [
        buildTask(),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'search text');
      await tester.pumpAndSettle();

      // Clear button should appear
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      // Search field should be empty
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('tapping task creates link and closes modal', (tester) async {
      final testTask = buildTask(id: 'task-to-link', title: 'Task to Link');

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [testTask]);

      when(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Tap the task
      await tester.tap(find.text('Task to Link'));
      await tester.pumpAndSettle();

      // Verify link was created
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: 'current-task',
          toId: 'task-to-link',
        ),
      ).called(1);
    });

    testWidgets('shows status labels for blocked tasks', (tester) async {
      final blockedTask = buildTask(
        title: 'Blocked Task',
        status: TaskStatus.blocked(
          id: 's1',
          createdAt: now,
          utcOffset: 0,
          reason: 'Test reason',
        ),
      );

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [blockedTask]);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Blocked'), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    });

    testWidgets('shows status labels for on hold tasks', (tester) async {
      final onHoldTask = buildTask(
        title: 'On Hold Task',
        status: TaskStatus.onHold(
          id: 's1',
          createdAt: now,
          utcOffset: 0,
          reason: 'Test reason',
        ),
      );

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [onHoldTask]);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('On Hold'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('shows status labels for groomed tasks', (tester) async {
      final groomedTask = buildTask(
        title: 'Groomed Task',
        status: TaskStatus.groomed(id: 's1', createdAt: now, utcOffset: 0),
      );

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [groomedTask]);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Groomed'), findsOneWidget);
      expect(find.byIcon(Icons.done_outline_rounded), findsOneWidget);
    });

    testWidgets('FTS5 matches are used for filtering', (tester) async {
      final testTasks = [
        buildTask(title: 'Apple Task'),
        buildTask(id: 'task-2', title: 'Banana Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      // FTS5 returns task-2 as a match
      when(() => mockFts5Db.watchFullTextMatches('special'))
          .thenAnswer((_) => Stream.value(['task-2']));

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Enter search that matches via FTS5
      await tester.enterText(find.byType(TextField), 'special');
      await tester.pumpAndSettle();

      // Task-2 should be visible because FTS5 matched it
      expect(find.text('Banana Task'), findsOneWidget);
    });

    testWidgets('handles FTS5 error gracefully', (tester) async {
      final testTasks = [
        buildTask(),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      // FTS5 throws an error
      when(() => mockFts5Db.watchFullTextMatches(any()))
          .thenAnswer((_) => Stream.error(Exception('FTS5 error')));

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingLinkedIds: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Enter search
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle();

      // Should fallback to title matching
      expect(find.text('Test Task'), findsOneWidget);
    });
  });
}
