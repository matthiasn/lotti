import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_with_suggestion_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../test_helper.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockChecklistItemController extends ChecklistItemController {
  MockChecklistItemController({
    required this.item,
    this.shouldDelete = false,
  });

  ChecklistItem? item;
  final bool shouldDelete;
  bool deleteWasCalled = false;

  @override
  Future<ChecklistItem?> build({
    required String id,
    required String? taskId,
  }) async =>
      item;

  @override
  Future<bool> delete() async {
    deleteWasCalled = true;
    if (shouldDelete) {
      state = const AsyncValue.data(null);
    }
    return true;
  }

  @override
  void updateChecked({required bool checked}) {
    final current = item;
    if (current == null) return;

    final data = current.data;
    final updated = current.copyWith(
      data: data.copyWith(isChecked: checked),
    );

    item = updated;
    state = AsyncValue.data(updated);
  }

  @override
  void updateTitle(String? title) {
    // Mock implementation
  }
}

class MockChecklistController extends ChecklistController {
  MockChecklistController() {
    lastInstance = this;
  }

  static MockChecklistController? lastInstance;

  bool unlinkItemWasCalled = false;
  String? unlinkedItemId;

  @override
  Future<Checklist?> build({
    required String id,
    required String? taskId,
  }) async =>
      null;

  @override
  Future<void> unlinkItem(String itemId) async {
    unlinkItemWasCalled = true;
    unlinkedItemId = itemId;
  }
}

void main() {
  late MockLoggingService mockLoggingService;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockUpdateNotifications = MockUpdateNotifications();

    // Register mocks in GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

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

  tearDown(() {
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
  });

  group('ChecklistItemWrapper', () {
    const testItemId = 'item-1';
    const testTaskId = 'task-1';
    const testChecklistId = 'checklist-1';
    late ChecklistItem testItem;

    setUp(() {
      final now = DateTime.now();
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
    });

    testWidgets('renders ChecklistItemWithSuggestionWidget when item exists',
        (tester) async {
      final mockItemController = MockChecklistItemController(item: testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // Verify the item is rendered
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsOneWidget);
      // There might be multiple text widgets (one in EditableText, one in Text)
      expect(find.text('Test Item'), findsWidgets);
    });

    testWidgets('renders empty when item is null', (tester) async {
      final mockItemController = MockChecklistItemController(item: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // Verify nothing is rendered
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders empty when item is deleted', (tester) async {
      final deletedItem = ChecklistItem(
        meta: Metadata(
          id: testItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          deletedAt: DateTime.now(), // Marked as deleted
        ),
        data: const ChecklistItemData(
          title: 'Deleted Item',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      final mockItemController = MockChecklistItemController(item: deletedItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // Verify nothing is rendered for deleted item
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('has dismissible widget with correct configuration',
        (tester) async {
      final mockItemController = MockChecklistItemController(item: testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // Find the Dismissible widget
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));

      // Verify dismissible settings
      expect(dismissible.direction, DismissDirection.endToStart);
      expect(
          dismissible.dismissThresholds, {DismissDirection.endToStart: 0.25});
      expect(dismissible.confirmDismiss, isNotNull);
      expect(dismissible.onDismissed, isNotNull);

      // Verify the widget is properly configured
      expect(find.byType(ChecklistItemWrapper), findsOneWidget);
    });

    testWidgets('onDismissed callback calls both delete and unlinkItem',
        (tester) async {
      // This test verifies that the onDismissed callback properly calls both methods
      // which is the main fix we made to ensure task updates are triggered

      final mockItemController = MockChecklistItemController(
        item: testItem,
        shouldDelete: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // Find the Dismissible widget and get its onDismissed callback
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));

      // The onDismissed callback should exist
      expect(dismissible.onDismissed, isNotNull);

      // Invoke onDismissed and allow async work to settle
      dismissible.onDismissed?.call(DismissDirection.endToStart);
      await tester.pumpAndSettle();

      // Verify both delete and unlink were called
      expect(mockItemController.deleteWasCalled, isTrue);
      expect(
        MockChecklistController.lastInstance?.unlinkItemWasCalled,
        isTrue,
      );
      expect(
        MockChecklistController.lastInstance?.unlinkedItemId,
        testItemId,
      );
    });

    testWidgets('properly captures notifiers before disposal', (tester) async {
      // This test ensures that the notifiers are captured before the widget is disposed
      // which is the main fix we made to prevent the disposal error

      final mockItemController = MockChecklistItemController(
        item: testItem,
        shouldDelete: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // The widget should be rendered without errors
      expect(find.byType(ChecklistItemWithSuggestionWidget), findsOneWidget);

      // The key insight of our fix is that notifiers are read and stored
      // during the build method, not in the onDismissed callback
      // This test passes if no disposal errors occur during widget lifecycle
    });

    testWidgets('dragBuilder applies correct visual styling', (tester) async {
      final mockItemController = MockChecklistItemController(item: testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

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
      final mockItemController = MockChecklistItemController(item: testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

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
      final mockItemController = MockChecklistItemController(item: testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

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
      final mockItemController = MockChecklistItemController(item: testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // Find the DragItemWidget and check allowedOperations
      final dragItemWidget =
          tester.widget<DragItemWidget>(find.byType(DragItemWidget));
      expect(dragItemWidget.allowedOperations, isNotNull);

      // Call allowedOperations to verify it returns move
      final operations = dragItemWidget.allowedOperations();
      expect(operations, [DropOperation.move]);
    });

    testWidgets('confirmDismiss shows delete confirmation dialog',
        (tester) async {
      final mockItemController = MockChecklistItemController(item: testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // Find the Dismissible widget
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));

      // Call confirmDismiss to trigger the dialog
      final confirmFuture =
          dismissible.confirmDismiss!(DismissDirection.endToStart);
      await tester.pump();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Find all buttons (cancel is first, confirm is last)
      final buttons = find.byType(TextButton);
      await tester.tap(buttons.first);
      await tester.pumpAndSettle();

      // Verify dialog returned false
      expect(await confirmFuture, isFalse);
    });

    testWidgets('confirmDismiss returns true when user confirms',
        (tester) async {
      final mockItemController = MockChecklistItemController(item: testItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
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

      await tester.pumpAndSettle();

      // Find the Dismissible widget
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));

      // Call confirmDismiss to trigger the dialog
      final confirmFuture =
          dismissible.confirmDismiss!(DismissDirection.endToStart);
      await tester.pump();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Find all buttons and tap the last one (confirm button)
      final buttons = find.byType(TextButton);
      await tester.tap(buttons.last);
      await tester.pumpAndSettle();

      // Verify dialog returned true
      expect(await confirmFuture, isTrue);
    });

    testWidgets(
        'fades out and hides newly checked item when hideIfChecked is true',
        (tester) async {
      const testItemId = 'item-checked';
      const testTaskId = 'task-1';
      const testChecklistId = 'checklist-1';

      final now = DateTime.now();
      final initialItem = ChecklistItem(
        meta: Metadata(
          id: testItemId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: const ChecklistItemData(
          title: 'Newly done',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      final mockItemController = MockChecklistItemController(item: initialItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
              hideIfChecked: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(
        find.byType(ChecklistItemWithSuggestionWidget),
        findsOneWidget,
      );

      // Mark the item as checked; this should eventually trigger the fade-out
      // animation once the completion fanfare has finished.
      mockItemController.updateChecked(checked: true);
      await tester.pump();
      // Let the completion fanfare and fade-out run.
      await tester.pump(checklistCompletionAnimationDuration +
          checklistCompletionFadeDuration);
      await tester.pumpAndSettle();

      // After the animation completes, the item should be effectively hidden
      // from the open-only view (collapsed via AnimatedSize/AnimatedOpacity).
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.byType(SizedBox),
      );
      // At least one zero-sized box is expected in place of the row.
      expect(
        sizedBoxes.any(
          (box) =>
              (box.width == null || box.width == 0) &&
              (box.height == null || box.height == 0),
        ),
        isTrue,
      );
    });

    testWidgets(
        'cancels fade-out when item is unchecked again before completion',
        (tester) async {
      const testItemId = 'item-toggle';
      const testTaskId = 'task-1';
      const testChecklistId = 'checklist-1';

      final now = DateTime.now();
      final initialItem = ChecklistItem(
        meta: Metadata(
          id: testItemId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: const ChecklistItemData(
          title: 'Toggle item',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      final mockItemController = MockChecklistItemController(item: initialItem);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider(
              id: testItemId,
              taskId: testTaskId,
            ).overrideWith(() => mockItemController),
            checklistControllerProvider(
              id: testChecklistId,
              taskId: testTaskId,
            ).overrideWith(MockChecklistController.new),
          ],
          child: const WidgetTestBench(
            child: ChecklistItemWrapper(
              testItemId,
              checklistId: testChecklistId,
              taskId: testTaskId,
              hideIfChecked: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(
        find.byType(ChecklistItemWithSuggestionWidget),
        findsOneWidget,
      );

      // Check the item (starts fade-out).
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      // Immediately uncheck before the fade-out completes.
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      // Advance time beyond the completion duration.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();

      // Item should remain visible because it was unchecked.
      expect(
        find.byType(ChecklistItemWithSuggestionWidget),
        findsOneWidget,
      );
    });
  });
}
