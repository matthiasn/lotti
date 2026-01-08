import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_from_section.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_header.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_to_section.dart';

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

  EntryLink buildLink({
    required String toId,
    String fromId = 'task-main',
  }) {
    return EntryLink.basic(
      id: 'link-$toId',
      fromId: fromId,
      toId: toId,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
    );
  }

  group('LinkedTasksWidget', () {
    setUp(() async {
      await setUpTestGetIt();
    });

    tearDown(() async {
      await tearDownTestGetIt();
    });

    testWidgets('returns SizedBox.shrink when no linked tasks', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedFromEntriesController([]),
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-main'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LinkedTasksHeader), findsNothing);
      expect(find.byType(LinkedFromSection), findsNothing);
      expect(find.byType(LinkedToSection), findsNothing);
    });

    testWidgets('renders header when there are linked tasks', (tester) async {
      final task = buildTask(id: 'linked-task', title: 'Linked Task');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedFromEntriesController([task]),
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-main'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LinkedTasksHeader), findsOneWidget);
      expect(find.text('Linked Tasks'), findsOneWidget);
    });

    testWidgets('renders LinkedFromSection when there are incoming tasks',
        (tester) async {
      final task = buildTask(id: 'incoming-task', title: 'Incoming Task');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedFromEntriesController([task]),
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-main'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LinkedFromSection), findsOneWidget);
      expect(find.text('LINKED FROM'), findsOneWidget);
      expect(find.text('Incoming Task'), findsOneWidget);
    });

    testWidgets('renders LinkedToSection when there are outgoing links',
        (tester) async {
      final link = buildLink(toId: 'outgoing-task');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedEntriesController([link]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedFromEntriesController([]),
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-main'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LinkedToSection), findsOneWidget);
      expect(find.text('LINKED TO'), findsOneWidget);
    });

    testWidgets(
        'renders both sections when there are both incoming and outgoing',
        (tester) async {
      final incomingTask = buildTask(id: 'incoming-task', title: 'Incoming');
      final outgoingLink = buildLink(toId: 'outgoing-task');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedEntriesController([outgoingLink]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedFromEntriesController([incomingTask]),
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-main'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LinkedFromSection), findsOneWidget);
      expect(find.byType(LinkedToSection), findsOneWidget);
      expect(find.text('LINKED FROM'), findsOneWidget);
      expect(find.text('LINKED TO'), findsOneWidget);
    });

    testWidgets('filters incoming entries to only tasks', (tester) async {
      final task = buildTask(id: 'task-1', title: 'Real Task');
      final textEntry = JournalEntry(
        meta: Metadata(
          id: 'text-entry',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        entryText: EntryText(plainText: 'Some text'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedFromEntriesController([task, textEntry]),
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-main'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should only show the task, not the text entry
      expect(find.text('Real Task'), findsOneWidget);
      expect(find.text('Some text'), findsNothing);
    });

    testWidgets('passes manageMode to sections', (tester) async {
      final task = buildTask(id: 'task-1', title: 'Linked Task');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
              _MockLinkedTasksControllerManageMode.new,
            ),
            linkedEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedFromEntriesController([task]),
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-main'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show unlink button since manageMode is true
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('renders inside a Column', (tester) async {
      final task = buildTask(id: 'task-1', title: 'Test Task');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
              LinkedTasksController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
              () => _MockLinkedFromEntriesController([task]),
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-main'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Column), findsWidgets);
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

class _MockLinkedTasksControllerManageMode extends LinkedTasksController {
  @override
  LinkedTasksState build({required String taskId}) {
    return const LinkedTasksState(manageMode: true);
  }
}
