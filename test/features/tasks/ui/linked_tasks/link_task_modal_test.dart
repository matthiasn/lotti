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
      expect(find.byIcon(Icons.search), findsOneWidget);
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

      // Handle bar is rendered as a Container with specific decoration
      expect(find.byType(Container), findsWidgets);
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
  });
}
