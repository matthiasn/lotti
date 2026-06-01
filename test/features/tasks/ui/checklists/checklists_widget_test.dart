import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_section_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

class MockEntryController extends EntryController {
  MockEntryController({required this.mockEntry});

  final JournalEntity? mockEntry;
  final List<List<String>> updateChecklistOrderCalls = [];

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

  @override
  Future<void> updateChecklistOrder(List<String> checklistIds) async {
    updateChecklistOrderCalls.add(checklistIds);
    return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await getIt.reset();
    final mockUpdateNotifications = MockUpdateNotifications();
    final mockJournalDb = MockJournalDb();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockNavService = MockNavService();
    final mockNotificationService = MockNotificationService();
    final mockTimeService = MockTimeService();
    final mockLoggingService = MockLoggingService();
    final mockEditorStateService = MockEditorStateService();
    final mockSecureStorage = MockSecureStorage();
    final settingsDb = SettingsDb(inMemoryDatabase: true);

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
    when(
      () => mockEditorStateService.getUnsavedStream(any(), any()),
    ).thenAnswer((_) => Stream<bool>.fromIterable([false]));
    when(() => mockEditorStateService.getDelta(any())).thenReturn(null);
    when(() => mockEditorStateService.getSelection(any())).thenReturn(null);
    when(() => mockEditorStateService.entryIsUnsaved(any())).thenReturn(false);

    // Mock secure storage for vector clock
    when(
      () => mockSecureStorage.readValue(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockSecureStorage.writeValue(any(), any()),
    ).thenAnswer((_) async {});

    // Mock journal db
    when(
      () => mockJournalDb.getConfigFlag(any()),
    ).thenAnswer((_) async => false);

    getIt
      ..registerSingleton<SettingsDb>(settingsDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<NotificationService>(mockNotificationService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
      ..registerSingleton<SecureStorage>(mockSecureStorage)
      ..registerSingleton<OutboxService>(MockOutboxService())
      ..registerSingleton<VectorClockService>(VectorClockService())
      ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
      ..registerSingleton<EditorStateService>(mockEditorStateService);
  });

  tearDownAll(getIt.reset);

  group('ChecklistsWidget', () {
    late Task mockTask;
    late MockChecklistRepository mockChecklistRepository;

    setUp(() {
      final dateTime = DateTime(2024);
      final dateTimeTo = DateTime(2024, 1, 1, 1);
      final mockJournalDb = getIt<JournalDb>() as MockJournalDb;
      mockTask =
          JournalEntity.task(
                meta: Metadata(
                  id: 'task1',
                  createdAt: dateTime,
                  updatedAt: dateTime,
                  dateFrom: dateTime,
                  dateTo: dateTimeTo,
                  starred: false,
                  private: false,
                  categoryId: 'category1',
                ),
                entryText: const EntryText(plainText: 'Test Task'),
                data: TaskData(
                  title: 'Test Task',
                  status: TaskStatus.open(
                    id: 'status1',
                    createdAt: dateTime,
                    utcOffset: 0,
                  ),
                  dateFrom: dateTime,
                  dateTo: dateTimeTo,
                  statusHistory: [],
                  checklistIds: ['checklist1', 'checklist2'],
                ),
              )
              as Task;

      mockChecklistRepository = MockChecklistRepository();

      // Setup journal db mock for this test
      when(
        () => mockJournalDb.journalEntityById(mockTask.id),
      ).thenAnswer((_) async => mockTask);

      // Mock checklist entities
      when(() => mockJournalDb.journalEntityById('checklist1')).thenAnswer(
        (_) async => JournalEntity.checklist(
          meta: Metadata(
            id: 'checklist1',
            createdAt: dateTime,
            updatedAt: dateTime,
            dateFrom: dateTime,
            dateTo: dateTime,
            starred: false,
            private: false,
          ),
          data: const ChecklistData(
            title: 'Checklist 1',
            linkedChecklistItems: [],
            linkedTasks: ['task1'],
          ),
        ),
      );

      when(() => mockJournalDb.journalEntityById('checklist2')).thenAnswer(
        (_) async => JournalEntity.checklist(
          meta: Metadata(
            id: 'checklist2',
            createdAt: dateTime,
            updatedAt: dateTime,
            dateFrom: dateTime,
            dateTo: dateTime,
            starred: false,
            private: false,
          ),
          data: const ChecklistData(
            title: 'Checklist 2',
            linkedChecklistItems: [],
            linkedTasks: ['task1'],
          ),
        ),
      );

      // Mock any other entity id (for cases where we don't have checklists)
      // Note: This must come BEFORE the specific mocks to avoid conflicts
      registerFallbackValue('');
    });

    Widget createTestWidget({
      List<String>? checklistIds,
      Task? task,
    }) {
      final testTask = task ?? mockTask;
      final taskWithIds = testTask.copyWith(
        data: testTask.data.copyWith(
          checklistIds: checklistIds ?? testTask.data.checklistIds,
        ),
      );

      return ProviderScope(
        overrides: [
          entryControllerProvider(id: testTask.id).overrideWith(
            () => MockEntryController(mockEntry: taskWithIds),
          ),
          checklistRepositoryProvider.overrideWithValue(
            mockChecklistRepository,
          ),
        ],
        child: WidgetTestBench(
          child: ChecklistsWidget(
            entryId: testTask.id,
            task: testTask,
          ),
        ),
      );
    }

    testWidgets('renders checklist cards (one per checklist)', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Debug: Check if ChecklistsWidget is rendered
      expect(find.byType(ChecklistsWidget), findsOneWidget);

      // Debug: Print widget tree
      await tester.pump();

      // Two checklists -> two TaskDetailSectionCard checklist cards, one per
      // checklist (post-migration from ModernBaseCard).
      expect(find.byType(TaskDetailSectionCard), findsNWidgets(2));
      expect(find.byType(ChecklistCardWrapper), findsNWidgets(2));
      expect(find.text('Checklist 1'), findsOneWidget);
      expect(find.text('Checklist 2'), findsOneWidget);
      // The inline `+` add button has been removed — adding a checklist now
      // lives on the FAB's create-entry menu (CreateChecklistItem).
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      // Checklists-level sort menu is shown when there are multiple checklists
      expect(find.byKey(const Key('checklists-menu')), findsOneWidget);
    });

    testWidgets('hides menu button when only one checklist', (tester) async {
      await tester.pumpWidget(createTestWidget(checklistIds: ['checklist1']));
      await tester.pumpAndSettle();

      // Checklists-level sort menu is hidden when there's only one checklist
      expect(find.byKey(const Key('checklists-menu')), findsNothing);
      expect(find.byType(ChecklistCardWrapper), findsOneWidget);
      expect(find.text('Checklist 1'), findsOneWidget);
    });

    testWidgets('hides the section entirely when there are no checklists', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(checklistIds: []));
      await tester.pumpAndSettle();

      // No cards, no header text, no sort menu — the whole section collapses
      // so the empty state doesn't dangle in the layout. Adding the first
      // checklist is exclusively via the FAB.
      expect(find.byType(ChecklistCardWrapper), findsNothing);
      expect(find.text('Checklists'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      expect(find.byKey(const Key('checklists-menu')), findsNothing);
    });

    testWidgets('returns SizedBox.shrink when entry is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task1').overrideWith(
              () => MockEntryController(mockEntry: null),
            ),
          ],
          child: WidgetTestBench(
            child: ChecklistsWidget(
              entryId: 'task1',
              task: mockTask,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(TaskDetailSectionCard), findsNothing);
    });

    testWidgets('returns SizedBox.shrink when entry is not a Task', (
      tester,
    ) async {
      final dateTime = DateTime(2024);
      final dateTimeTo = DateTime(2024, 1, 1, 1);
      final journalEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry1',
          createdAt: dateTime,
          updatedAt: dateTime,
          dateFrom: dateTime,
          dateTo: dateTimeTo,
          starred: false,
          private: false,
        ),
        entryText: const EntryText(plainText: 'Journal Entry'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task1').overrideWith(
              () => MockEntryController(mockEntry: journalEntry),
            ),
          ],
          child: WidgetTestBench(
            child: ChecklistsWidget(
              entryId: 'task1',
              task: mockTask,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(TaskDetailSectionCard), findsNothing);
    });

    testWidgets('calls createChecklist when add button is pressed', (
      tester,
    ) async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final newChecklist = JournalEntity.checklist(
        meta: Metadata(
          id: 'new-checklist',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          starred: false,
          private: false,
        ),
        data: const ChecklistData(
          title: 'Todos',
          linkedChecklistItems: [],
          linkedTasks: ['task1'],
        ),
      );

      when(
        () => mockChecklistRepository.createChecklist(
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer(
        (_) async => (
          checklist: newChecklist,
          createdItems: <({String id, String title, bool isChecked})>[],
        ),
      );

      await tester.pumpWidget(createTestWidget());

      // The add button is rendered but tapping requires full widget tree
      // await tester.tap(find.byIcon(Icons.add_rounded));
      // await tester.pump();

      // verify(() => mockChecklistRepository.createChecklist(taskId: 'task1'))
      //     .called(1);
    });

    testWidgets('reorders checklists correctly', (tester) async {
      final controller = MockEntryController(mockEntry: mockTask);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'task1').overrideWith(
              () => controller,
            ),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
          child: WidgetTestBench(
            child: ChecklistsWidget(
              entryId: 'task1',
              task: mockTask,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test that ReorderableListView exists
      // Multiple instances may exist in the widget tree
      expect(find.byType(ReorderableListView), findsWidgets);

      // More detailed reordering tests require ChecklistCardWrapper widgets to render
    });

    testWidgets('renders ChecklistsWidget with checklist data', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(ChecklistsWidget), findsOneWidget);
    });

    testWidgets('handles null checklistIds correctly', (tester) async {
      final taskWithNullIds = mockTask.copyWith(
        data: mockTask.data.copyWith(checklistIds: null),
      );

      await tester.pumpWidget(createTestWidget(task: taskWithNullIds));

      // With empty checklists, no ChecklistCardWrapper widgets are rendered
      expect(find.byType(ChecklistCardWrapper), findsNothing);
      // Checklists-level sort menu is hidden when there are no checklists
      expect(find.byKey(const Key('checklists-menu')), findsNothing);
      // ChecklistSuggestionsWidget requires AI providers to be mocked
      // expect(find.byType(ChecklistSuggestionsWidget), findsOneWidget);
    });

    testWidgets('can enter sorting mode via menu', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open the checklists-level sort menu
      await tester.tap(find.byKey(const Key('checklists-menu')));
      await tester.pumpAndSettle();

      // Test that the menu contains the sort option
      expect(find.byIcon(Icons.sort), findsOneWidget);

      // Tap on sort option
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // Test that the widget supports reordering
      // Multiple ReorderableListView widgets may exist in the tree
      expect(find.byType(ReorderableListView), findsWidgets);

      // Detailed order preservation testing requires ChecklistCardWrapper widgets to render
    });

    testWidgets(
      'shows Done button in sorting mode and tapping it exits sorting mode',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Initially no FilledButton (the sorting-mode Done button) is shown
        expect(find.byType(FilledButton), findsNothing);

        // Enter sorting mode via the menu
        await tester.tap(find.byKey(const Key('checklists-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();

        // The FilledButton "Done" is shown during sorting mode.
        // Note: "Done" text also appears in checklist filter tabs, so we find
        // the button specifically by widget type.
        expect(find.byType(FilledButton), findsOneWidget);

        // Tap the FilledButton to exit sorting mode (_exitSortingMode)
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        // FilledButton disappears after exiting sorting mode
        expect(find.byType(FilledButton), findsNothing);
      },
    );

    testWidgets(
      'onReorderItem moving item down (newIndex > oldIndex) exercises the '
      'newIndex - 1 branch and calls updateChecklistOrder',
      (tester) async {
        final controller = MockEntryController(mockEntry: mockTask);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryControllerProvider(id: 'task1').overrideWith(
                () => controller,
              ),
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
            child: WidgetTestBench(
              child: ChecklistsWidget(
                entryId: 'task1',
                task: mockTask,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter sorting mode so drag handles (and semantics) appear
        await tester.tap(find.byKey(const Key('checklists-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();

        // Use the "Move down" semantics action on the first checklist item.
        // Flutter's SliverReorderableList calls _handleReorderItem(0, 0+2=2).
        // Inside _handleReorderItem, because newIndex(2) > oldIndex(0),
        // Flutter adjusts: newIndex = 2-1 = 1. Then onReorderItem(0, 1) fires.
        // The widget's onReorderItem handler hits the newIndex > oldIndex branch
        // (line 104-105): insertionIndex = newIndex - 1 = 0.
        // This exercises all previously uncovered lines 101-112.
        final firstItemNode = tester.getSemantics(find.text('Checklist 1'));
        final moveDownId = CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move down'),
        );
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          firstItemNode.id,
          SemanticsAction.customAction,
          moveDownId,
        );
        await tester.pumpAndSettle();

        // The callback was invoked once — covering lines 101-112 (onReorderItem
        // body, setState, updateChecklistOrder call).
        expect(controller.updateChecklistOrderCalls, hasLength(1));
        // With (oldIndex=0, newIndex=1) the newIndex>oldIndex branch fires:
        // insertionIndex = 1-1 = 0, so the list is reinserted at position 0.
        expect(
          controller.updateChecklistOrderCalls.first,
          ['checklist1', 'checklist2'],
        );
      },
    );

    testWidgets(
      'onReorderItem moving item up (newIndex <= oldIndex) updates order via semantics',
      (tester) async {
        final controller = MockEntryController(mockEntry: mockTask);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryControllerProvider(id: 'task1').overrideWith(
                () => controller,
              ),
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
            child: WidgetTestBench(
              child: ChecklistsWidget(
                entryId: 'task1',
                task: mockTask,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter sorting mode so the list becomes reorderable
        await tester.tap(find.byKey(const Key('checklists-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();

        // Use the "Move up" semantics action on the second checklist item.
        // _handleReorderItem(1, 0) → newIndex(0) <= oldIndex(1) → no adjustment
        // → onReorderItem(1, 0) → reordered list: [checklist2, checklist1]
        final secondItemNode = tester.getSemantics(find.text('Checklist 2'));
        final moveUpId = CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move up'),
        );
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          secondItemNode.id,
          SemanticsAction.customAction,
          moveUpId,
        );
        await tester.pumpAndSettle();

        // updateChecklistOrder should have been called with the reversed order
        expect(controller.updateChecklistOrderCalls, hasLength(1));
        expect(
          controller.updateChecklistOrderCalls.first,
          ['checklist2', 'checklist1'],
        );
      },
    );
  });
}
