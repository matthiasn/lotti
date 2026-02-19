import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_with_suggestion_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

class MockChecklistItemController extends ChecklistItemController {
  MockChecklistItemController(
    super.params, {
    required ChecklistItem? item,
    this.shouldDelete = false,
  }) {
    _itemsMap = {if (item != null) item.meta.id: item};
    _currentId = item?.meta.id;
    _initialItem = item;
  }

  late final Map<String, ChecklistItem?> _itemsMap;
  String? _currentId;
  ChecklistItem? _initialItem;
  final bool shouldDelete;
  bool deleteWasCalled = false;
  bool archiveWasCalled = false;
  bool unarchiveWasCalled = false;

  @override
  Future<ChecklistItem?> build() async => _initialItem;

  @override
  Future<bool> delete() async {
    deleteWasCalled = true;
    if (shouldDelete) {
      state = const AsyncValue.data(null);
    }
    return true;
  }

  @override
  void archive() {
    archiveWasCalled = true;
    // Don't update state — avoids notifier reuse error in widget tests.
    // State behavior is tested in controller unit tests.
  }

  @override
  void unarchive() {
    unarchiveWasCalled = true;
  }

  @override
  void updateChecked({required bool checked}) {
    final currentId = _currentId;
    if (currentId == null) return;
    final current = _itemsMap[currentId];
    if (current == null) return;

    final data = current.data;
    final updated = current.copyWith(
      data: data.copyWith(isChecked: checked),
    );

    _itemsMap[currentId] = updated;
    state = AsyncValue.data(updated);
  }

  @override
  void updateTitle(String? title) {
    // Mock implementation
  }
}

class MockChecklistController extends ChecklistController {
  MockChecklistController(super.params);

  bool unlinkItemWasCalled = false;
  String? unlinkedItemId;
  bool relinkItemWasCalled = false;
  String? relinkedItemId;

  @override
  Future<Checklist?> build() async => null;

  @override
  Future<void> unlinkItem(String itemId) async {
    unlinkItemWasCalled = true;
    unlinkedItemId = itemId;
  }

  @override
  Future<void> relinkItem(String itemId) async {
    relinkItemWasCalled = true;
    relinkedItemId = itemId;
  }
}

// Helper to create item controller override using overrideWithBuild
Override checklistItemOverrideWithBuild(ChecklistItem? item) {
  return checklistItemControllerProvider.overrideWithBuild(
    (ref, params) async => item,
  );
}

// Helper to create checklist controller override using overrideWithBuild
Override checklistOverrideWithBuild(Checklist? checklist) {
  return checklistControllerProvider.overrideWithBuild(
    (ref, params) async => checklist,
  );
}

void main() {
  late MockLoggingService mockLoggingService;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockJournalDb mockJournalDb;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  setUp(() async {
    await getIt.reset();
    mockLoggingService = MockLoggingService();
    mockUpdateNotifications = MockUpdateNotifications();
    mockJournalDb = MockJournalDb();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockJournalDb.journalEntityById(any()))
        .thenAnswer((_) async => null);

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<JournalDb>(mockJournalDb);

    // Setup mock behaviors
    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) {});
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('ChecklistItemWrapper', () {
    const testItemId = 'item-1';
    const testTaskId = 'task-1';
    const testChecklistId = 'checklist-1';
    late ChecklistItem testItem;

    setUp(() {
      final now = DateTime(2024);
      testItem = ChecklistItem(
        meta: Metadata(
          id: testItemId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: const ChecklistItemData(
          title: 'Test Item',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      // Update the JournalDb mock to return testItem for testItemId
      final journalDb = getIt<JournalDb>();
      reset(journalDb);
      when(() => journalDb.journalEntityById(testItemId))
          .thenAnswer((_) async => testItem);
      when(() => journalDb.journalEntityById(any(that: isNot(testItemId))))
          .thenAnswer((_) async => null);
    });

    testWidgets('renders ChecklistItemWithSuggestionWidget when item exists',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify the item is rendered
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsOneWidget);
      // There might be multiple text widgets (one in EditableText, one in Text)
      expect(find.text('Test Item'), findsWidgets);
    });

    testWidgets('renders empty when item is null', (tester) async {
      // Make JournalDb return null for this test
      final journalDb = getIt<JournalDb>();
      reset(journalDb);
      when(() => journalDb.journalEntityById(any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(null),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify nothing is rendered
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders empty when item is deleted', (tester) async {
      // Make JournalDb return the deleted item for this test
      final journalDb = getIt<JournalDb>();

      final deletedAt = DateTime(2024);
      final deletedItem = ChecklistItem(
        meta: Metadata(
          id: testItemId,
          createdAt: deletedAt,
          updatedAt: deletedAt,
          dateFrom: deletedAt,
          dateTo: deletedAt,
          deletedAt: deletedAt, // Marked as deleted
        ),
        data: const ChecklistItemData(
          title: 'Deleted Item',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      reset(journalDb);
      when(() => journalDb.journalEntityById(testItemId))
          .thenAnswer((_) async => deletedItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(deletedItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify nothing is rendered for deleted item
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('has dismissible widget with bidirectional configuration',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the Dismissible widget
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));

      // Verify bidirectional dismissible settings
      expect(dismissible.dismissThresholds, {
        DismissDirection.endToStart: 0.25,
        DismissDirection.startToEnd: 0.25,
      });
      expect(dismissible.confirmDismiss, isNotNull);
      expect(dismissible.onDismissed, isNotNull);
      // Verify both backgrounds are set (archive + delete)
      expect(dismissible.background, isNotNull);
      expect(dismissible.secondaryBackground, isNotNull);

      // Verify the widget is properly configured
      expect(find.byType(ChecklistItemWrapper), findsOneWidget);
    });

    testWidgets('onDismissed unlinks immediately and delays delete',
        (tester) async {
      // This test verifies the delayed-deletion pattern:
      // 1. Unlink immediately (visual removal)
      // 2. Start Timer for actual delete (5s)
      // 3. Show countdown SnackBar with undo

      final mockItemController = MockChecklistItemController(
        (id: testItemId, taskId: testTaskId),
        item: testItem,
        shouldDelete: true,
      );
      final mockChecklistController = MockChecklistController(
        (id: testChecklistId, taskId: testTaskId),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider.overrideWith(
              () => mockItemController,
            ),
            checklistControllerProvider.overrideWith(
              () => mockChecklistController,
            ),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.onDismissed, isNotNull);

      // Invoke onDismissed and let async work + SnackBar entry complete
      dismissible.onDismissed?.call(DismissDirection.endToStart);
      await tester.pump(); // process microtasks from async callback
      await tester.pump(); // render SnackBar frame

      // Unlink should be called immediately
      expect(mockChecklistController.unlinkItemWasCalled, isTrue);
      expect(mockChecklistController.unlinkedItemId, testItemId);

      // Delete should NOT be called yet (delayed by Timer)
      expect(mockItemController.deleteWasCalled, isFalse);

      // Verify floating SnackBar is shown for delete with undo
      expect(find.byType(SnackBar), findsOneWidget);

      // Advance past the delete duration to trigger the Timer
      await tester.pump(kChecklistDeleteDuration);

      // Now delete should have been called
      expect(mockItemController.deleteWasCalled, isTrue);
    });

    testWidgets('delete undo cancels timer and relinks item', (tester) async {
      final mockItemController = MockChecklistItemController(
        (id: testItemId, taskId: testTaskId),
        item: testItem,
        shouldDelete: true,
      );
      final mockChecklistController = MockChecklistController(
        (id: testChecklistId, taskId: testTaskId),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider.overrideWith(
              () => mockItemController,
            ),
            checklistControllerProvider.overrideWith(
              () => mockChecklistController,
            ),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Trigger delete dismiss — use pump() to avoid advancing past Timer
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      dismissible.onDismissed?.call(DismissDirection.endToStart);
      await tester.pump(); // process microtasks
      await tester.pump(); // render SnackBar

      // SnackBar should be visible with undo button
      expect(find.byType(SnackBar), findsOneWidget);

      // Find the undo TextButton inside the SnackBar and invoke directly
      // (floating SnackBar overlays can be obscured in test hit-testing)
      final snackBarFinder = find.byType(SnackBar);
      final undoButton = find.descendant(
        of: snackBarFinder,
        matching: find.byType(TextButton),
      );
      expect(undoButton, findsOneWidget);

      // Invoke onPressed directly to bypass hit-test overlay issues
      tester.widget<TextButton>(undoButton).onPressed?.call();
      await tester.pump();

      // Relink should have been called
      expect(mockChecklistController.relinkItemWasCalled, isTrue);
      expect(mockChecklistController.relinkedItemId, testItemId);

      // Advance past the delete duration — delete should NOT fire (timer cancelled)
      await tester.pump(kChecklistDeleteDuration);
      expect(mockItemController.deleteWasCalled, isFalse);
    });

    testWidgets('properly captures notifiers before disposal', (tester) async {
      // This test ensures that the notifiers are captured before the widget is disposed
      // which is the main fix we made to prevent the disposal error

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // The widget should be rendered without errors
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsOneWidget);

      // The key insight of our fix is that notifiers are read and stored
      // during the build method, not in the onDismissed callback
      // This test passes if no disposal errors occur during widget lifecycle
    });

    testWidgets('dragBuilder applies correct visual styling', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the DragItemWidget and test its dragBuilder directly
      final dragItemWidget =
          tester.widget<DragItemWidget>(find.byType(DragItemWidget));
      expect(dragItemWidget.dragBuilder, isNotNull);

      // Test the dragBuilder by calling it directly
      final testChild = Container(key: const ValueKey('test-child'));
      final context = tester.element(find.byType(ChecklistItemWrapper));
      final decoratedWidget = dragItemWidget.dragBuilder!(context, testChild);

      // Verify the decorated widget is a Container with the correct styling
      expect(decoratedWidget, isA<Container>());
      final container = decoratedWidget! as Container;
      final decoration = container.decoration! as BoxDecoration;
      final theme = Theme.of(context);

      expect(decoration.color, theme.colorScheme.surface);
      expect(decoration.border, isA<Border>());
      final border = decoration.border! as Border;
      expect(border.top.color, theme.colorScheme.primary);
      expect(border.top.width, 2);
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('renders with drag and drop capabilities', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify widget renders correctly
      expect(find.byType(ChecklistItemWrapper), findsOneWidget);
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsOneWidget);
      expect(find.text('Test Item'), findsWidgets);

      // Verify DragItemWidget is configured with dragItemProvider
      final dragItemWidget =
          tester.widget<DragItemWidget>(find.byType(DragItemWidget));
      expect(dragItemWidget.dragItemProvider, isNotNull);

      // Note: Testing the actual dragItemProvider invocation requires mocking
      // DragSession which is complex. The provider's logic is tested through
      // integration tests where actual drag operations occur.
    });

    testWidgets('dragItemProvider creates DragItem with correct data',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify DragItemWidget is configured with dragItemProvider
      final dragItemWidget =
          tester.widget<DragItemWidget>(find.byType(DragItemWidget));
      expect(dragItemWidget.dragItemProvider, isNotNull);

      // Note: Directly invoking dragItemProvider requires creating a proper
      // DragItemRequest which depends on the drag-and-drop framework.
      // The provider's existence and configuration is verified above.
      // The actual behavior is tested through integration tests.
    });

    testWidgets('allowedOperations returns move operation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the DragItemWidget and check allowedOperations
      final dragItemWidget =
          tester.widget<DragItemWidget>(find.byType(DragItemWidget));
      expect(dragItemWidget.allowedOperations, isNotNull);

      // Call allowedOperations to verify it returns move
      final operations = dragItemWidget.allowedOperations();
      expect(operations, [DropOperation.move]);
    });

    testWidgets('confirmDismiss returns true immediately for delete direction',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the Dismissible widget
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));

      // Delete direction returns true immediately (no dialog)
      final result =
          await dismissible.confirmDismiss!(DismissDirection.endToStart);
      expect(result, isTrue);

      // No dialog should be shown
      expect(find.byType(AlertDialog), findsNothing);
    });

    // TODO(riverpod3): These animation tests require stateful mock controllers
    // that update their state when updateChecked() is called. In Riverpod 3,
    // overrideWith() doesn't allow pre-constructed notifier reuse.
    // These tests should be revisited with proper integration test setup
    // that uses real controllers with mocked repositories.
    //
    // testWidgets(
    //     'fades out and hides newly checked item when hideIfChecked is true',
    // testWidgets(
    //     'cancels fade-out when item is unchecked again before completion',

    testWidgets('wraps item in DropRegion for cross-checklist drag support',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify DropRegion is present in widget tree
      expect(find.byType(DropRegion), findsOneWidget);
    });

    testWidgets('DropRegion onDropOver returns move operation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the DropRegion and verify its configuration
      final dropRegion = tester.widget<DropRegion>(find.byType(DropRegion));
      expect(dropRegion.onDropOver, isNotNull);

      // The onDropOver callback should return DropOperation.move
      // Note: We can't easily invoke onDropOver without mocking DropOverEvent,
      // but we verify the callback exists and is configured.
    });

    testWidgets('passes correct index to DropRegion for position-aware drops',
        (tester) async {
      const testIndex = 5;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
              index: testIndex,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify the widget renders with the correct index
      final wrapper = tester.widget<ChecklistItemWrapper>(
        find.byType(ChecklistItemWrapper),
      );
      expect(wrapper.index, testIndex);

      // The DropRegion's onPerformDrop will use this index
      // when calling dropChecklistItem
      expect(find.byType(DropRegion), findsOneWidget);
    });

    testWidgets('DropRegion has standardFormats configured', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      final dropRegion = tester.widget<DropRegion>(find.byType(DropRegion));
      expect(dropRegion.formats, Formats.standardFormats);
    });

    testWidgets('archive swipe (startToEnd) calls archive and shows snackbar',
        (tester) async {
      final mockItemController = MockChecklistItemController(
        (id: testItemId, taskId: testTaskId),
        item: testItem,
      );
      final mockChecklistController = MockChecklistController(
        (id: testChecklistId, taskId: testTaskId),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider.overrideWith(
              () => mockItemController,
            ),
            checklistControllerProvider.overrideWith(
              () => mockChecklistController,
            ),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Get the confirmDismiss callback
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      final result = await dismissible.confirmDismiss!(
        DismissDirection.startToEnd,
      );

      // Single pump to show the SnackBar without triggering a full rebuild
      // cycle that would reuse the mock notifier instance.
      await tester.pump();

      // confirmDismiss should return false (item stays in place)
      expect(result, isFalse);
      // archive should have been called
      expect(mockItemController.archiveWasCalled, isTrue);
      // delete should NOT have been called
      expect(mockItemController.deleteWasCalled, isFalse);

      // Verify SnackBar is shown with undo action
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('archive swipe on already-archived item calls unarchive',
        (tester) async {
      final archivedItem = ChecklistItem(
        meta: Metadata(
          id: testItemId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'Archived Item',
          isChecked: false,
          isArchived: true,
          linkedChecklists: [],
        ),
      );

      final mockItemController = MockChecklistItemController(
        (id: testItemId, taskId: testTaskId),
        item: archivedItem,
      );
      final mockChecklistController = MockChecklistController(
        (id: testChecklistId, taskId: testTaskId),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider.overrideWith(
              () => mockItemController,
            ),
            checklistControllerProvider.overrideWith(
              () => mockChecklistController,
            ),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Get the confirmDismiss callback
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      final result = await dismissible.confirmDismiss!(
        DismissDirection.startToEnd,
      );

      // Single pump — avoid full settle which triggers notifier reuse error
      await tester.pump();

      // confirmDismiss should return false
      expect(result, isFalse);
      // unarchive should have been called (not archive)
      expect(mockItemController.unarchiveWasCalled, isTrue);
      expect(mockItemController.archiveWasCalled, isFalse);
    });

    testWidgets('delete swipe (endToStart) returns true without showing dialog',
        (tester) async {
      final mockItemController = MockChecklistItemController(
        (id: testItemId, taskId: testTaskId),
        item: testItem,
      );
      final mockChecklistController = MockChecklistController(
        (id: testChecklistId, taskId: testTaskId),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider.overrideWith(
              () => mockItemController,
            ),
            checklistControllerProvider.overrideWith(
              () => mockChecklistController,
            ),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Get the confirmDismiss callback for delete direction
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      final result = await dismissible.confirmDismiss!(
        DismissDirection.endToStart,
      );

      // Returns true immediately — no dialog
      expect(result, isTrue);

      // archive/unarchive should NOT have been called
      expect(mockItemController.archiveWasCalled, isFalse);
      expect(mockItemController.unarchiveWasCalled, isFalse);
    });

    testWidgets(
        'Dismissible has both background and secondaryBackground configured',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(testItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify both backgrounds are set on the Dismissible widget
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.background, isNotNull);
      expect(dismissible.secondaryBackground, isNotNull);
    });

    testWidgets('passes isArchived to ChecklistItemWithSuggestionWidget',
        (tester) async {
      final archivedItem = ChecklistItem(
        meta: Metadata(
          id: testItemId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'Archived Item',
          isChecked: false,
          isArchived: true,
          linkedChecklists: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemOverrideWithBuild(archivedItem),
            checklistOverrideWithBuild(null),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify isArchived is passed through
      final suggestionWidget = tester.widget<ChecklistItemWithSuggestionWidget>(
        find.byType(ChecklistItemWithSuggestionWidget),
      );
      expect(suggestionWidget.isArchived, isTrue);
    });
  });
}
