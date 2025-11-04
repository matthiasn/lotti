import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../test_helper.dart';

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

    setUp(() {
      mockState = MockChecklistState(
        title: 'Test Checklist',
        itemIds: [], // Empty to avoid issues with ChecklistItemWrapper
      );
    });

    testWidgets('renders title and progress indicator correctly',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
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

      // Verify the ExpansionTile exists (it's the main container widget)
      expect(find.byType(ExpansionTile), findsOneWidget);

      // Verify a progress indicator exists
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify we have the edit icon (which means we're not in edit mode)
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('enters edit mode when edit button is tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
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

      // Verify we start in non-edit mode by finding the edit icon
      expect(find.byIcon(Icons.edit), findsOneWidget);

      // Tap the edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      // In edit mode, we should see the TitleTextField for editing
      // This is a bit tricky since there are multiple TitleTextField widgets
      // Find the first TitleTextField (which should be the title editor)
      final editableTextFields = find.byType(TitleTextField);
      expect(editableTextFields, findsWidgets);

      // Look for an ancestor AnimatedCrossFade that contains the TitleTextField
      final crossFade = find.ancestor(
        of: editableTextFields.first,
        matching: find.byType(AnimatedCrossFade),
      );
      expect(crossFade, findsOneWidget);
    });

    testWidgets('saves title when edited', (tester) async {
      String? savedTitle;

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
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

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      // After tapping edit, there should be at least one TextField
      // Find the title text field by looking for one inside a TitleTextField
      // that is inside an AnimatedCrossFade
      final textFields = find.descendant(
        of: find.ancestor(
          of: find.byType(TitleTextField).first,
          matching: find.byType(AnimatedCrossFade),
        ),
        matching: find.byType(TextField),
      );
      expect(textFields, findsOneWidget);

      // Enter new text
      await tester.enterText(textFields, 'Updated Checklist Title');

      // Submit the form (simulating done button press)
      await tester.testTextInput.receiveAction(TextInputAction.done);
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

      // Enter new text for the item
      await tester.enterText(textField, 'New checklist item');

      // Submit the form
      await tester.testTextInput.receiveAction(TextInputAction.done);
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

      // Enter edit mode to see the delete button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      // Find and tap the delete button - using MdiIcons
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pump();

      // Verify the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Find and tap the confirm button (second button in dialog)
      final buttons = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      );
      expect(buttons, findsAtLeastNWidgets(1));

      // Tap the last button (confirm)
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();

      // Verify delete action was called
      expect(deleteActionCalled, isTrue);
    });

    testWidgets('proxyDecorator applies correct styling during reorder',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Verify the ReorderableListView exists
      final reorderableListView =
          tester.widget<ReorderableListView>(find.byType(ReorderableListView));

      // The proxyDecorator should be defined
      expect(reorderableListView.proxyDecorator, isNotNull);

      // Test the proxyDecorator by calling it directly
      final testChild = Container(
        key: const ValueKey('test-child'),
        child: const Text('Test Item'),
      );
      final context = tester.element(find.byType(ChecklistWidget));
      final decoratedWidget = reorderableListView.proxyDecorator!(
        testChild,
        0,
        const AlwaysStoppedAnimation(1),
      );

      // Verify the decorated widget is a Container with correct styling
      expect(decoratedWidget, isA<Container>());
      final container = decoratedWidget as Container;
      final decoration = container.decoration! as BoxDecoration;
      final theme = Theme.of(context);

      expect(decoration.color, theme.colorScheme.surface);
      expect(decoration.border, isA<Border>());
      final border = decoration.border! as Border;
      expect(border.top.color, theme.colorScheme.primary);
      expect(border.top.width, 2);
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('shows export button when onExportMarkdown is provided',
        (tester) async {
      var exportCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
              onExportMarkdown: () {
                exportCalled = true;
              },
            ),
          ),
        ),
      );

      // Find the export icon (MdiIcons.exportVariant)
      expect(find.byIcon(MdiIcons.exportVariant), findsOneWidget);

      // Tap the export button
      await tester.tap(find.byIcon(MdiIcons.exportVariant));
      await tester.pump();

      // Verify callback was called
      expect(exportCalled, isTrue);
    });

    testWidgets('does not show export button when onExportMarkdown is null',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // Export icon should not be present
      expect(find.byIcon(MdiIcons.exportVariant), findsNothing);
    });

    testWidgets('has GestureDetector for share on long press', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5,
              updateItemOrder: (_) async {},
              onExportMarkdown: () {},
              onShareMarkdown: () {},
            ),
          ),
        ),
      );

      // Verify export icon exists
      expect(find.byIcon(MdiIcons.exportVariant), findsOneWidget);

      // Find GestureDetector wrapping the export IconButton
      final gestureDetectors = find.ancestor(
        of: find.byIcon(MdiIcons.exportVariant),
        matching: find.byType(GestureDetector),
      );

      // Verify GestureDetector exists (enables long press and secondary click)
      // There may be multiple due to Flutter's widget hierarchy
      expect(gestureDetectors, findsWidgets);
    });

    testWidgets('checklist expands by default when incomplete', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 0.5, // Not complete
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // The ExpansionTile should be initially expanded
      final expansionTile =
          tester.widget<ExpansionTile>(find.byType(ExpansionTile));

      // Verify initiallyExpanded is true (completion rate < 1)
      expect(expansionTile.initiallyExpanded, isTrue);
    });

    testWidgets('checklist collapses by default when complete', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistWidget(
              id: 'checklist1',
              taskId: 'task1',
              title: mockState.title,
              itemIds: const [],
              onTitleSave: (title) {},
              onCreateChecklistItem: (_) async => 'new-item-id',
              completionRate: 1, // Complete
              updateItemOrder: (_) async {},
            ),
          ),
        ),
      );

      // The ExpansionTile should be initially collapsed
      final expansionTile =
          tester.widget<ExpansionTile>(find.byType(ExpansionTile));

      // Verify initiallyExpanded is false (completion rate == 1)
      expect(expansionTile.initiallyExpanded, isFalse);
    });
  });
}
