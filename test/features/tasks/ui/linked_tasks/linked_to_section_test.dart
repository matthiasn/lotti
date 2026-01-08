import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_card.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_to_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockJournalDb extends Mock implements JournalDb {}

class MockEditorStateService extends Mock implements EditorStateService {}

class MockLinkedEntriesController extends LinkedEntriesController {
  @override
  Future<List<EntryLink>> build({required String id}) async => [];

  @override
  Future<void> removeLink({required String toId}) async {}
}

class TrackingLinkedEntriesController extends LinkedEntriesController {
  bool removeLinkCalled = false;
  String? removeLinkToId;

  @override
  Future<List<EntryLink>> build({required String id}) async => [];

  @override
  Future<void> removeLink({required String toId}) async {
    removeLinkCalled = true;
    removeLinkToId = toId;
  }
}

class MockEntryController extends EntryController {
  MockEntryController({required this.mockEntry});

  final JournalEntity? mockEntry;

  @override
  Future<EntryState?> build({required String id}) async {
    if (mockEntry == null) {
      return null;
    }
    return EntryState.saved(
      entryId: id,
      entry: mockEntry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

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

  setUpAll(() async {
    await getIt.reset();

    final mockUpdateNotifications = MockUpdateNotifications();
    final mockJournalDb = MockJournalDb();
    final mockEditorStateService = MockEditorStateService();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockJournalDb.journalEntityById(any()))
        .thenAnswer((_) async => null);

    getIt
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<EditorStateService>(mockEditorStateService);
  });

  tearDownAll(getIt.reset);

  group('LinkedToSection', () {
    testWidgets('returns SizedBox.shrink when outgoingLinks is empty',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [],
              manageMode: false,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('LINKED TO'), findsNothing);
    });

    testWidgets('renders directional label when links exist', (tester) async {
      final task = buildTask(id: 'linked-task-1', title: 'Linked Task');
      final link = buildLink(toId: 'linked-task-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'linked-task-1')
                .overrideWith(() => MockEntryController(mockEntry: task)),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link],
              manageMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('↗ '), findsOneWidget);
      expect(find.text('LINKED TO'), findsOneWidget);
    });

    testWidgets('renders LinkedTaskCard for each task link', (tester) async {
      final task1 = buildTask(title: 'First Task');
      final task2 = buildTask(id: 'task-2', title: 'Second Task');
      final link1 = buildLink(toId: 'task-1');
      final link2 = buildLink(toId: 'task-2');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task-1')
                .overrideWith(() => MockEntryController(mockEntry: task1)),
            entryControllerProvider(id: 'task-2')
                .overrideWith(() => MockEntryController(mockEntry: task2)),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link1, link2],
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

    testWidgets('hides non-task entries', (tester) async {
      final textEntry = JournalEntry(
        meta: Metadata(
          id: 'text-entry-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        entryText: const EntryText(plainText: 'Some text'),
      );
      final link = buildLink(toId: 'text-entry-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'text-entry-1')
                .overrideWith(() => MockEntryController(mockEntry: textEntry)),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link],
              manageMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show the section label but the entry itself should be hidden
      expect(find.text('LINKED TO'), findsOneWidget);
      expect(find.byType(LinkedTaskCard), findsNothing);
    });

    testWidgets('shows unlink buttons in manage mode', (tester) async {
      final task = buildTask(title: 'Linked Task');
      final link = buildLink(toId: 'task-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task-1')
                .overrideWith(() => MockEntryController(mockEntry: task)),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link],
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
      final link = buildLink(toId: 'task-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task-1')
                .overrideWith(() => MockEntryController(mockEntry: task)),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link],
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
      final link = buildLink(toId: 'task-1');
      final mockController = MockLinkedEntriesController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task-1')
                .overrideWith(() => MockEntryController(mockEntry: task)),
            linkedEntriesControllerProvider(id: 'task-main')
                .overrideWith(() => mockController),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link],
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
      final link = buildLink(toId: 'task-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task-1')
                .overrideWith(() => MockEntryController(mockEntry: task)),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link],
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

    testWidgets('confirm unlink calls removeLink on controller',
        (tester) async {
      final task = buildTask(title: 'Linked Task');
      final link = buildLink(toId: 'task-1');
      final trackingController = TrackingLinkedEntriesController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task-1')
                .overrideWith(() => MockEntryController(mockEntry: task)),
            linkedEntriesControllerProvider(id: 'task-main')
                .overrideWith(() => trackingController),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link],
              manageMode: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap Unlink to confirm
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      // Verify removeLink was called with the correct toId
      expect(trackingController.removeLinkCalled, isTrue);
      expect(trackingController.removeLinkToId, 'task-1');

      // Dialog should be dismissed
      expect(find.text('Unlink Task'), findsNothing);
    });

    testWidgets('renders section inside a Column', (tester) async {
      final task = buildTask();
      final link = buildLink(toId: 'task-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task-1')
                .overrideWith(() => MockEntryController(mockEntry: task)),
          ],
          child: WidgetTestBench(
            child: LinkedToSection(
              taskId: 'task-main',
              outgoingLinks: [link],
              manageMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Column), findsWidgets);
    });
  });
}
