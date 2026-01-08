import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_header.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

// Larger size to avoid overflow in popup menus
const _largeMediaQuery = MediaQueryData(size: Size(800, 600));

void main() {
  group('LinkedTasksHeader', () {
    late MockJournalDb mockJournalDb;
    late MockFts5Db mockFts5Db;
    late MockUpdateNotifications mockUpdateNotifications;

    setUp(() async {
      await getIt.reset();

      mockJournalDb = MockJournalDb();
      mockFts5Db = MockFts5Db();
      mockUpdateNotifications = MockUpdateNotifications();

      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockJournalDb.journalEntityById(any()))
          .thenAnswer((_) async => null);
      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <JournalEntity>[]);
      when(() => mockFts5Db.watchFullTextMatches(any()))
          .thenAnswer((_) => Stream.value(<String>[]));

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<Fts5Db>(mockFts5Db);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('renders title "Linked Tasks"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      expect(find.text('Linked Tasks'), findsOneWidget);
    });

    testWidgets('renders menu button with more_vert icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('opens popup menu when menu button is tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Menu items should be visible
      expect(find.text('Link existing task...'), findsOneWidget);
      expect(find.text('Create new linked task...'), findsOneWidget);
    });

    testWidgets('shows Manage links menu item when hasLinkedTasks is true',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Manage links...'), findsOneWidget);
    });

    testWidgets(
        'does not show Manage links menu item when hasLinkedTasks is false',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Manage links...'), findsNothing);
    });

    testWidgets('menu has link icon for Link existing task', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('menu has add icon for Create new linked task', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('manage mode toggle changes icon and text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: true,
            ),
          ),
        ),
      );

      // Open menu and verify initial state
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Initially shows "Manage links..." with edit icon
      expect(find.text('Manage links...'), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

      // Tap to enter manage mode
      await tester.tap(find.text('Manage links...'));
      await tester.pumpAndSettle();

      // Open menu again
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Now shows "Done" with check icon
      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('header is laid out in a Row with Spacer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      // The header uses Row with Spacer
      expect(find.byType(Row), findsWidgets);
      expect(find.byType(Spacer), findsOneWidget);
    });

    testWidgets('PopupMenuButton has correct tooltip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      final popupMenuButton = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(popupMenuButton.tooltip, 'Linked tasks options');
    });

    testWidgets('tapping Link existing task opens modal', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-1').overrideWith(
              () => _MockLinkedEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-1').overrideWith(
              () => _MockLinkedFromEntriesController([]),
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Link existing task
      await tester.tap(find.text('Link existing task...'));
      await tester.pumpAndSettle();

      // Modal should open (shows bottom sheet)
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('link modal excludes already linked task IDs', (tester) async {
      final now = DateTime(2025, 12, 31, 12);
      // This task is linked FROM another task (incoming)
      final linkedFromTask = Task(
        meta: Metadata(
          id: 'linked-from-task',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          status: TaskStatus.open(id: 's1', createdAt: now, utcOffset: 0),
          dateFrom: now,
          dateTo: now,
          statusHistory: const [],
          title: 'Linked From Task',
        ),
      );
      // This is the outgoing link (task-1 links TO outgoing-task)
      final outgoingLink = EntryLink.basic(
        id: 'link-1',
        fromId: 'task-1',
        toId: 'outgoing-task',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      );
      // Task that should appear in modal (not linked)
      final availableTask = Task(
        meta: Metadata(
          id: 'available-task',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          status: TaskStatus.open(id: 's2', createdAt: now, utcOffset: 0),
          dateFrom: now,
          dateTo: now,
          statusHistory: const [],
          title: 'Available Task',
        ),
      );
      // Task that should be excluded (it's the outgoing link target)
      final outgoingTask = Task(
        meta: Metadata(
          id: 'outgoing-task',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          status: TaskStatus.open(id: 's3', createdAt: now, utcOffset: 0),
          dateFrom: now,
          dateTo: now,
          statusHistory: const [],
          title: 'Outgoing Task',
        ),
      );

      // Mock getTasks to return all tasks (the modal filters them)
      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [linkedFromTask, availableTask, outgoingTask],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-1').overrideWith(
              () => _MockLinkedEntriesController([outgoingLink]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-1').overrideWith(
              () => _MockLinkedFromEntriesController([linkedFromTask]),
            ),
          ],
          child: WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: Consumer(
              // Pre-load the providers so they're ready when the modal opens
              builder: (context, ref, child) {
                ref
                  ..watch(linkedEntriesControllerProvider(id: 'task-1'))
                  ..watch(linkedFromEntriesControllerProvider(id: 'task-1'));
                return child!;
              },
              child: const LinkedTasksHeader(
                taskId: 'task-1',
                hasLinkedTasks: true,
              ),
            ),
          ),
        ),
      );

      // Wait for providers to load
      await tester.pumpAndSettle();

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Link existing task
      await tester.tap(find.text('Link existing task...'));
      await tester.pumpAndSettle();

      // Modal should open
      expect(find.byType(BottomSheet), findsOneWidget);

      // Available task should be visible (not linked)
      expect(find.text('Available Task'), findsOneWidget);

      // Linked tasks should be excluded from the modal
      expect(find.text('Linked From Task'), findsNothing);
      expect(find.text('Outgoing Task'), findsNothing);
    });
  });
}

class _MockLinkedEntriesController extends LinkedEntriesController {
  _MockLinkedEntriesController(this._links);
  final List<EntryLink> _links;

  @override
  Future<List<EntryLink>> build({required String id}) async => _links;
}

class _MockLinkedFromEntriesController extends LinkedFromEntriesController {
  _MockLinkedFromEntriesController(this._entities);
  final List<JournalEntity> _entities;

  @override
  Future<List<JournalEntity>> build({required String id}) async => _entities;
}
