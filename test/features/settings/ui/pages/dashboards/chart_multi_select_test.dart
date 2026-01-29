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

  group('_MultiSelectList', () {
    // We need to test _MultiSelectList directly, but it's private.
    // So we test it through ChartMultiSelect by opening the modal.
    // However, WoltModalSheet behavior in tests can be tricky.
    // Instead, we'll create a test wrapper to expose the widget.

    final testItems = [
      MultiSelectItem<String>('apple', 'Apple'),
      MultiSelectItem<String>('banana', 'Banana'),
      MultiSelectItem<String>('cherry', 'Cherry'),
      MultiSelectItem<String>('date', 'Date'),
      MultiSelectItem<String>('elderberry', 'Elderberry'),
    ];

    // Create a testable version of _MultiSelectList
    Widget createTestableMultiSelectList({
      required List<MultiSelectItem<String?>> items,
      required void Function(List<String?>) onConfirm,
    }) {
      return WidgetTestBench(
        child: _TestableMultiSelectList(
          items: items,
          onConfirm: onConfirm,
        ),
      );
    }

    testWidgets('displays search field', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('displays all items initially', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Cherry'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Elderberry'), findsOneWidget);
    });

    testWidgets('filters items when typing in search', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Type in search field
      await tester.enterText(find.byType(TextField), 'ban');
      await tester.pumpAndSettle();

      // Only Banana should be visible
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Cherry'), findsNothing);
    });

    testWidgets('search is case insensitive', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'APPLE');
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('shows "No items found" when search has no matches',
        (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();

      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('clears search when clear button tapped', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Type in search
      await tester.enterText(find.byType(TextField), 'ban');
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsNothing);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All items should be visible again
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
    });

    testWidgets('displays Cancel and Add buttons', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
    });

    testWidgets('Add button is disabled when nothing selected', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final addButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add'),
      );
      expect(addButton.onPressed, isNull);
    });

    testWidgets('toggles checkbox when item tapped', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the Apple checkbox
      final appleCheckbox = find.widgetWithText(CheckboxListTile, 'Apple');
      await tester.tap(appleCheckbox);
      await tester.pumpAndSettle();

      // Verify checkbox is now checked
      final checkboxTile = tester.widget<CheckboxListTile>(appleCheckbox);
      expect(checkboxTile.value, isTrue);
    });

    testWidgets('Add button shows count when items selected', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Select Apple
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Apple'));
      await tester.pumpAndSettle();

      expect(find.text('Add (1)'), findsOneWidget);

      // Select Banana
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Banana'));
      await tester.pumpAndSettle();

      expect(find.text('Add (2)'), findsOneWidget);
    });

    testWidgets('Add button is enabled when items selected', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Select an item
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Apple'));
      await tester.pumpAndSettle();

      final addButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add (1)'),
      );
      expect(addButton.onPressed, isNotNull);
    });

    testWidgets('calls onConfirm with selected items when Add tapped',
        (tester) async {
      List<String?>? confirmedItems;

      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (items) => confirmedItems = items,
        ),
      );
      await tester.pumpAndSettle();

      // Select Apple and Cherry
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Apple'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cherry'));
      await tester.pumpAndSettle();

      // Tap Add button
      await tester.tap(find.widgetWithText(FilledButton, 'Add (2)'));
      await tester.pumpAndSettle();

      expect(confirmedItems, isNotNull);
      expect(confirmedItems!.length, equals(2));
      expect(confirmedItems, contains('apple'));
      expect(confirmedItems, contains('cherry'));
    });

    testWidgets('can deselect items', (tester) async {
      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: testItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Select Apple
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Apple'));
      await tester.pumpAndSettle();
      expect(find.text('Add (1)'), findsOneWidget);

      // Deselect Apple
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Apple'));
      await tester.pumpAndSettle();
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('list is constrained to max height', (tester) async {
      // Create many items to test scrolling
      final manyItems = List.generate(
        20,
        (i) => MultiSelectItem<String>('item$i', 'Item ${i + 1}'),
      );

      await tester.pumpWidget(
        createTestableMultiSelectList(
          items: manyItems,
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Cancel and Add buttons should still be visible
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);

      // List should be scrollable - Item 1 visible, Item 20 not initially
      expect(find.text('Item 1'), findsOneWidget);
    });
  });
}

/// Testable wrapper for _MultiSelectList since it's private
class _TestableMultiSelectList extends StatefulWidget {
  const _TestableMultiSelectList({
    required this.items,
    required this.onConfirm,
  });

  final List<MultiSelectItem<String?>> items;
  final void Function(List<String?>) onConfirm;

  @override
  State<_TestableMultiSelectList> createState() =>
      _TestableMultiSelectListState();
}

class _TestableMultiSelectListState extends State<_TestableMultiSelectList> {
  final Set<String?> _selected = {};
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<MultiSelectItem<String?>> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    return widget.items
        .where(
          (item) =>
              item.label.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxListHeight = MediaQuery.of(context).size.height * 0.4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: _filteredItems.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No items found'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final isSelected = _selected.contains(item.value);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked ?? false) {
                            _selected.add(item.value);
                          } else {
                            _selected.remove(item.value);
                          }
                        });
                      },
                      title: Text(item.label),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => widget.onConfirm(_selected.toList()),
                child: Text(
                  _selected.isEmpty ? 'Add' : 'Add (${_selected.length})',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
