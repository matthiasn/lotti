import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/chart_multi_select.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

import '../../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChartMultiSelect', () {
    final testItems = [
      MultiSelectItem<String>('item1', 'First Item'),
      MultiSelectItem<String>('item2', 'Second Item'),
      MultiSelectItem<String>('item3', 'Third Item'),
    ];

    testWidgets('displays button with icon and text', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Items'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    testWidgets('button is tappable', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Add Items');
      expect(buttonFinder, findsOneWidget);

      // Verify InkWell is present for tap handling
      final inkWell = find.ancestor(
        of: buttonFinder,
        matching: find.byType(InkWell),
      );
      expect(inkWell, findsOneWidget);
    });

    testWidgets('handles empty items list', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: const [],
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Items'), findsOneWidget);
    });

    testWidgets('opens modal when tapped', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the button to open modal
      await tester.tap(find.text('Add Items'));
      await tester.pumpAndSettle();

      // Modal should be open - verify by checking for modal content
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);
    });

    testWidgets('modal displays search field and items', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to open modal
      await tester.tap(find.text('Add Items'));
      await tester.pumpAndSettle();

      // Search field should be visible
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Items should be displayed
      expect(find.text('First Item'), findsOneWidget);
      expect(find.text('Second Item'), findsOneWidget);
      expect(find.text('Third Item'), findsOneWidget);
    });

    testWidgets('modal allows selecting items and calls onConfirm',
        (tester) async {
      List<String?>? confirmedItems;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (items) => confirmedItems = items,
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Add Items'));
      await tester.pumpAndSettle();

      // Select First Item
      await tester.tap(find.widgetWithText(CheckboxListTile, 'First Item'));
      await tester.pumpAndSettle();

      // Tap Add button (should show "Add (1)")
      final addButton = find.widgetWithText(FilledButton, 'Add (1)');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify onConfirm was called
      expect(confirmedItems, isNotNull);
      expect(confirmedItems, contains('item1'));
    });

    testWidgets('modal search filters items', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Add Items'));
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'First');
      await tester.pumpAndSettle();

      // Only First Item should be visible
      expect(find.text('First Item'), findsOneWidget);
      expect(find.text('Second Item'), findsNothing);
      expect(find.text('Third Item'), findsNothing);
    });

    testWidgets('modal cancel button closes without calling onConfirm',
        (tester) async {
      var onConfirmCalled = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) => onConfirmCalled = true,
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Add Items'));
      await tester.pumpAndSettle();

      // Select an item first
      await tester.tap(find.widgetWithText(CheckboxListTile, 'First Item'));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      // onConfirm should not have been called
      expect(onConfirmCalled, isFalse);
    });

    testWidgets('modal shows empty state when search has no results',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Add Items'));
      await tester.pumpAndSettle();

      // Enter search text that matches nothing
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();

      // Should show "No items found"
      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('modal clear button resets search', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Add Items'));
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'First');
      await tester.pumpAndSettle();

      expect(find.text('Second Item'), findsNothing);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All items should be visible again
      expect(find.text('First Item'), findsOneWidget);
      expect(find.text('Second Item'), findsOneWidget);
      expect(find.text('Third Item'), findsOneWidget);
    });

    testWidgets('modal allows deselecting items', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChartMultiSelect<String>(
            multiSelectItems: testItems,
            onConfirm: (_) {},
            title: 'Select Items',
            buttonText: 'Add Items',
            semanticsLabel: 'Add items button',
            iconData: Icons.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Add Items'));
      await tester.pumpAndSettle();

      // Select First Item
      await tester.tap(find.widgetWithText(CheckboxListTile, 'First Item'));
      await tester.pumpAndSettle();
      expect(find.text('Add (1)'), findsOneWidget);

      // Deselect First Item
      await tester.tap(find.widgetWithText(CheckboxListTile, 'First Item'));
      await tester.pumpAndSettle();

      // Should show "Add" without count
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Add (1)'), findsNothing);
    });
  });
}
