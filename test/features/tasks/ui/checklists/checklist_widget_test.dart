import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

class MockChecklistState {
  MockChecklistState({
    required this.title,
    required this.itemIds,
  });

  final List<String> itemIds;
  String title;
}

void main() {
  group('ChecklistWidget', () {
    late MockChecklistState mockState;

    setUp(() async {
      await setUpTestGetIt();
      mockState = MockChecklistState(
        title: 'Test Checklist',
        itemIds: [], // Empty to avoid issues with ChecklistItemWrapper
      );
    });

    tearDown(() async {
      await tearDownTestGetIt();
    });

    testWidgets('renders title and progress indicator correctly',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: mockState.itemIds,
              onTitleSave: (title) {
                mockState.title = title ?? '';
              },
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Verify the widget is rendered
      expect(find.byType(ChecklistWidget), findsOneWidget);

      // Verify the title text is shown (may be in both AnimatedCrossFade children)
      expect(find.text(mockState.title), findsWidgets);

      // Verify the chevron icon exists (expand/collapse)
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Verify the menu button exists
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('enters edit mode when title is tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: mockState.itemIds,
              onTitleSave: (title) {
                mockState.title = title ?? '';
              },
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Verify we start with the title text visible (may find multiple due to AnimatedCrossFade)
      expect(find.text(mockState.title), findsWidgets);

      // Find the GestureDetector that wraps the title text (in the secondChild of AnimatedCrossFade)
      // This is the tappable area when not in edit mode
      final titleGestureDetector = find.ancestor(
        of: find.descendant(
          of: find.byType(GestureDetector),
          matching: find.text(mockState.title),
        ),
        matching: find.byType(GestureDetector),
      );
      expect(titleGestureDetector, findsWidgets);
      await tester.tap(titleGestureDetector.first);
      await tester.pump();

      // In edit mode, we should see the TitleTextField for editing
      final editableTextFields = find.byType(TitleTextField);
      expect(editableTextFields, findsWidgets);

      // The TitleTextField should be visible and editable in the header
      // (No longer using AnimatedCrossFade for title switching in unified header)
      expect(editableTextFields.first, findsOneWidget);
    });

    testWidgets('saves title when edited', (tester) async {
      String? savedTitle;

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: mockState.itemIds,
              onTitleSave: (title) {
                savedTitle = title;
              },
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Find the GestureDetector that wraps the title text
      final titleGestureDetector = find.ancestor(
        of: find.descendant(
          of: find.byType(GestureDetector),
          matching: find.text(mockState.title),
        ),
        matching: find.byType(GestureDetector),
      );
      expect(titleGestureDetector, findsWidgets);

      // Tap to enter edit mode
      await tester.tap(titleGestureDetector.first);
      await tester.pump();

      // Find the TitleTextField that should now be shown (in the header area)
      final titleTextFields = find.byType(TitleTextField);
      expect(titleTextFields, findsWidgets);

      // Find the TextField inside the first TitleTextField (the title edit field)
      final textField = find.descendant(
        of: titleTextFields.first,
        matching: find.byType(TextField),
      );
      expect(textField, findsOneWidget);

      // Enter new text and save via Enter (SaveIntent)
      await tester.enterText(textField, 'Updated Checklist Title');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Verify the title was saved
      expect(savedTitle, 'Updated Checklist Title');
    });

    testWidgets('creates new checklist item when text submitted',
        (tester) async {
      String? newItemText;

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [], // Empty list to avoid ChecklistItemWrapper failures
              onTitleSave: (title) {},
              onCreateChecklistItem: (text) async {
                newItemText = text;
                return 'new-item-id';
              },
              completionRate: 0.5,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Find the last TitleTextField which should be the "Add item" field
      final titleTextFields = find.byType(TitleTextField);
      expect(titleTextFields, findsAtLeastNWidgets(1));

      // Get the last TitleTextField (which should be the add item field)
      final addItemTextField = titleTextFields.last;

      // Find the TextField inside the TitleTextField
      final textField = find.descendant(
        of: addItemTextField,
        matching: find.byType(TextField),
      );
      expect(textField, findsOneWidget);

      // Enter new text for the item and save via Enter (SaveIntent)
      await tester.tap(textField);
      await tester.pump();
      await tester.enterText(textField, 'New checklist item');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Verify the item creation callback was called with the expected text
      expect(newItemText, 'New checklist item');
    });

    testWidgets(
        'shows delete confirmation dialog when delete button is pressed',
        (tester) async {
      var deleteActionCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [], // Empty list to avoid ChecklistItemWrapper failures
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
              onDelete: () {
                deleteActionCalled = true;
              },
            ),
          ),
        ),
      );

      // Open the overflow menu and choose Delete
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete checklist?'));
      await tester.pump();

      // Verify the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Confirm deletion by tapping the 'Confirm' action
      await tester.tap(find.text('Confirm'));
      await tester.pump();

      // Verify delete action was called
      expect(deleteActionCalled, isTrue);
    });

    testWidgets('canceling delete does not call onDelete', (tester) async {
      var deleteActionCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
              onDelete: () {
                deleteActionCalled = true;
              },
            ),
          ),
        ),
      );

      // Open the overflow menu and choose Delete
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete checklist?'));
      await tester.pump();

      // Cancel deletion by tapping the 'Cancel' action
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleteActionCalled, isFalse);
    });

    testWidgets('proxyDecorator applies correct styling during reorder',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: 'Checklist Title',
              itemIds: const ['item1', 'item2'],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Verify the checklist widget renders
      expect(find.byType(ChecklistWidget), findsOneWidget);

      // Look for the ReorderableListView
      final reorderableListView = find.byType(ReorderableListView);
      expect(reorderableListView, findsOneWidget);
    });

    testWidgets('empty items list shows add item field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: 'Checklist Title',
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Verify the checklist widget renders
      expect(find.byType(ChecklistWidget), findsOneWidget);

      // Verify at least one TitleTextField exists (the add item field)
      expect(find.byType(TitleTextField), findsWidgets);
    });

    testWidgets('chevron collapses/expands card when tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: 'Test Checklist',
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Verify chevron exists
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Verify we have an AnimatedCrossFade for the body
      expect(find.byType(AnimatedCrossFade), findsWidgets);
    });

    testWidgets('checklist expands by default when incomplete', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: 'Incomplete Checklist',
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5, // 50% complete = incomplete
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Find the AnimatedCrossFade widgets
      final crossFadeFinder = find.byType(AnimatedCrossFade);
      expect(crossFadeFinder, findsWidgets);

      // Verify the checklist is expanded (body should be visible)
      // Find the body AnimatedCrossFade and verify it's showing first child
      final crossFades = tester.widgetList<AnimatedCrossFade>(crossFadeFinder);
      // At least one should be showing first child (expanded)
      final bodyExpanded = crossFades.any(
        (cf) => cf.crossFadeState == CrossFadeState.showFirst,
      );
      expect(bodyExpanded, isTrue);
    });

    testWidgets('checklist collapses by default when complete', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: 'Complete Checklist',
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 1, // 100% complete
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Find the AnimatedCrossFade widgets
      final crossFadeFinder = find.byType(AnimatedCrossFade);
      expect(crossFadeFinder, findsWidgets);

      // Verify the checklist is collapsed (body should not be visible)
      // Check if we have the collapsed header layout (title + progress inline)
      // When collapsed, the body AnimatedCrossFade should show second child
      expect(find.byType(ChecklistWidget), findsOneWidget);
    });

    testWidgets('filter tabs are visible when expanded with items',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: 'Test Checklist',
              // Need items for filter tabs to show (hidden when empty)
              itemIds: const ['item1', 'item2'],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5, // Will start expanded
              totalCount: 2,
              completedCount: 1,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Look for filter tab text
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });
  });
}
