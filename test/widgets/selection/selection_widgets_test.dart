import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/selection/selection.dart';

import '../../test_helper.dart';

void main() {
  group('Selection Widgets Integration', () {
    /// Creates a complete selection modal for testing integration
    Widget createTestModal({
      required List<String> options,
      required Set<String> selectedOptions,
      required ValueChanged<List<String>> onSave,
      bool singleSelection = false,
    }) {
      return WidgetTestBench(
        child: _TestSelectionModal(
          options: options,
          selectedOptions: selectedOptions,
          onSave: onSave,
          singleSelection: singleSelection,
        ),
      );
    }

    testWidgets('complete multi-selection flow works correctly',
        (tester) async {
      final selectedOptions = <String>{};
      final savedOptions = <String>[];

      await tester.pumpWidget(createTestModal(
        options: ['Option 1', 'Option 2', 'Option 3'],
        selectedOptions: selectedOptions,
        onSave: savedOptions.addAll,
      ));
      await tester.pumpAndSettle();

      // Initially no selections
      expect(
          find.byIcon(Icons.check_rounded), findsOneWidget); // Only save button

      // Select first option
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();

      // Should show checkmark
      expect(find.byIcon(Icons.check_rounded),
          findsNWidgets(2)); // Option + save button

      // Select second option
      await tester.tap(find.text('Option 2'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded),
          findsNWidgets(3)); // 2 options + save button

      // Deselect first option
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded),
          findsNWidgets(2)); // 1 option + save button

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedOptions, ['Option 2']);
    });

    testWidgets('complete single-selection flow works correctly',
        (tester) async {
      final savedOptions = <String>[];

      await tester.pumpWidget(createTestModal(
        options: ['Option A', 'Option B', 'Option C'],
        selectedOptions: {},
        onSave: savedOptions.addAll,
        singleSelection: true,
      ));
      await tester.pumpAndSettle();

      // Initially no selection, save button should be disabled
      final saveButton =
          tester.widget<SelectionSaveButton>(find.byType(SelectionSaveButton));
      expect(saveButton.onPressed, isNull);

      // Select first option
      await tester.tap(find.text('Option A'));
      await tester.pumpAndSettle();

      // Should show radio button filled
      expect(find.byType(RadioSelectionIndicator), findsNWidgets(3));

      // Select second option (should deselect first)
      await tester.tap(find.text('Option B'));
      await tester.pumpAndSettle();

      // Save button should now be enabled
      final updatedSaveButton =
          tester.widget<SelectionSaveButton>(find.byType(SelectionSaveButton));
      expect(updatedSaveButton.onPressed, isNotNull);

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedOptions, ['Option B']);
    });

    testWidgets('all components work together in modal context',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: SelectionModalContent(
            children: [
              SelectionOptionsList(
                itemCount: 3,
                itemBuilder: (context, index) {
                  return SelectionOption(
                    title: 'Item $index',
                    description: 'Description for item $index',
                    icon: Icons.star,
                    isSelected: index == 0,
                    onTap: () {},
                  );
                },
              ),
              const SizedBox(height: 24),
              SelectionSaveButton(
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all components are present
      expect(find.byType(SelectionModalContent), findsOneWidget);
      expect(find.byType(SelectionOptionsList), findsOneWidget);
      expect(find.byType(SelectionOption), findsNWidgets(3));
      expect(find.byType(SelectionSaveButton), findsOneWidget);

      // Verify content
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Description for item 1'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.check_rounded),
          findsNWidgets(2)); // Item 0 + save button

      // Test save button
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    });

    testWidgets('handles scroll in long lists correctly', (tester) async {
      // Set a smaller viewport to ensure scrolling is necessary
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestModal(
        options: List.generate(20, (i) => 'Option $i'),
        selectedOptions: {},
        onSave: (_) {},
      ));
      await tester.pumpAndSettle();

      // Initial items visible
      expect(find.text('Option 0'), findsOneWidget);

      // Find the scrollable widget
      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsAtLeastNWidgets(1));

      // Scroll down to see later items
      await tester.scrollUntilVisible(
        find.text('Option 19'),
        500,
      );
      await tester.pumpAndSettle();

      // Last item should be visible now
      expect(find.text('Option 19'), findsOneWidget);

      // Reset viewport
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('handles empty options list gracefully', (tester) async {
      final savedOptions = <String>[];

      await tester.pumpWidget(createTestModal(
        options: [],
        selectedOptions: {},
        onSave: savedOptions.addAll,
      ));
      await tester.pumpAndSettle();

      // Should show save button only
      expect(find.byType(SelectionOption), findsNothing);
      expect(find.byType(SelectionSaveButton), findsOneWidget);

      // Can still save with empty selection
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedOptions, isEmpty);
    });

    testWidgets('handles theme changes correctly', (tester) async {
      // Test light theme
      await tester.pumpWidget(
        WidgetTestBench(
          child: Theme(
            data: ThemeData.light(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SelectionOption(
                    title: 'Option 1',
                    icon: Icons.category,
                    isSelected: false,
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 20),
                SelectionSaveButton(
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify light theme
      var context = tester.element(find.text('Option 1'));
      expect(Theme.of(context).brightness, Brightness.light);

      // Test dark theme
      await tester.pumpWidget(
        WidgetTestBench(
          child: Theme(
            data: ThemeData.dark(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SelectionOption(
                    title: 'Option 1',
                    icon: Icons.category,
                    isSelected: false,
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 20),
                SelectionSaveButton(
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify dark theme
      context = tester.element(find.text('Option 1'));
      expect(Theme.of(context).brightness, Brightness.dark);

      // All components should still be visible
      expect(find.byType(SelectionOption), findsOneWidget);
      expect(find.byType(SelectionSaveButton), findsOneWidget);
    });
  });
}

/// Test modal implementation using all selection widgets
class _TestSelectionModal extends StatefulWidget {
  const _TestSelectionModal({
    required this.options,
    required this.selectedOptions,
    required this.onSave,
    this.singleSelection = false,
  });

  final List<String> options;
  final Set<String> selectedOptions;
  final ValueChanged<List<String>> onSave;
  final bool singleSelection;

  @override
  State<_TestSelectionModal> createState() => _TestSelectionModalState();
}

class _TestSelectionModalState extends State<_TestSelectionModal> {
  late Set<String> _selectedOptions;
  String? _singleSelectedOption;

  @override
  void initState() {
    super.initState();
    _selectedOptions = Set.from(widget.selectedOptions);
    if (widget.singleSelection && _selectedOptions.isNotEmpty) {
      _singleSelectedOption = _selectedOptions.first;
    }
  }

  void _toggleOption(String option) {
    setState(() {
      if (widget.singleSelection) {
        _singleSelectedOption = option;
        _selectedOptions = {option};
      } else {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.remove(option);
        } else {
          _selectedOptions.add(option);
        }
      }
    });
  }

  void _handleSave() {
    widget.onSave(_selectedOptions.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SelectionModalContent(
        children: [
          SelectionOptionsList(
            itemCount: widget.options.length,
            itemBuilder: (context, index) {
              final option = widget.options[index];
              final isSelected = widget.singleSelection
                  ? _singleSelectedOption == option
                  : _selectedOptions.contains(option);

              return SelectionOption(
                title: option,
                icon: Icons.category,
                isSelected: isSelected,
                onTap: () => _toggleOption(option),
                selectionIndicator: widget.singleSelection
                    ? RadioSelectionIndicator(isSelected: isSelected)
                    : null,
              );
            },
          ),
          const SizedBox(height: 24),
          SelectionSaveButton(
            onPressed: widget.singleSelection && _singleSelectedOption == null
                ? null
                : _handleSave,
          ),
        ],
      ),
    );
  }
}
