import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemDropdown', () {
    testWidgets('renders the closed dropdown trigger from tokens', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            items: _items(['Title']),
          ),
        ),
      );

      final decoration = _triggerDecoration(tester);
      final shape = decoration.shape as RoundedRectangleBorder;
      final labelText = _findTextNode(tester, 'Label');
      final inputText = _findTextNode(tester, 'Input');

      expect(_triggerSize(tester).height, 56);
      expect(decoration.color, dsTokensLight.colors.background.level01);
      expect(shape.side.color, dsTokensLight.colors.decorative.level02);
      expect(shape.side.width, dsTokensLight.spacing.step1);
      expectTextStyle(
        labelText.text.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      expectTextStyle(
        inputText.text.style!,
        dsTokensLight.typography.styles.body.bodyLarge,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.byType(RawScrollbar), findsNothing);
    });

    testWidgets('opens the menu and notifies expansion changes', (
      tester,
    ) async {
      final expansionStates = <bool>[];

      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            items: _items(['First option', 'Second option']),
            onExpandedChanged: expansionStates.add,
          ),
        ),
      );

      await tester.tap(find.text('Input'));
      await tester.pump();

      expect(expansionStates, [true]);
      expect(find.text('First option'), findsOneWidget);
      expect(find.byType(RawScrollbar), findsOneWidget);
    });

    testWidgets('calls the item callback and closes a single-select menu', (
      tester,
    ) async {
      DesignSystemDropdownItem? selectedItem;

      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            initiallyExpanded: true,
            items: _items(['Alpha', 'Beta']),
            onItemPressed: (item) => selectedItem = item,
          ),
        ),
      );

      await tester.tap(find.text('Beta'));
      await tester.pump();

      expect(selectedItem?.id, 'item-1');
      expect(find.byType(RawScrollbar), findsNothing);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('renders multiselect chips and selected rows from tokens', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        const SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            type: DesignSystemDropdownType.multiselect,
            initiallyExpanded: true,
            items: [
              DesignSystemDropdownItem(
                id: 'item-0',
                label: 'Title',
                chipLabel: 'Chip label',
                selected: true,
              ),
              DesignSystemDropdownItem(
                id: 'item-1',
                label: 'Title',
                chipLabel: 'Chip label',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Chip label'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(RawScrollbar), findsOneWidget);
      expect(find.byType(DesignSystemDropdown), findsOneWidget);
    });

    testWidgets('applies token-driven disabled opacity and blocks taps', (
      tester,
    ) async {
      final expansionStates = <bool>[];

      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            enabled: false,
            items: _items(['Alpha']),
            onExpandedChanged: expansionStates.add,
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);

      await tester.tap(find.text('Input'));
      await tester.pump();

      expect(expansionStates, isEmpty);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('collapses when disabled while expanded', (tester) async {
      var enabled = true;
      final expansionStates = <bool>[];

      await _pumpDropdown(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 320,
              child: Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() => enabled = false),
                    child: const Text('Disable'),
                  ),
                  DesignSystemDropdown(
                    label: 'Label',
                    inputLabel: 'Input',
                    enabled: enabled,
                    initiallyExpanded: true,
                    items: _items(['Alpha']),
                    onExpandedChanged: expansionStates.add,
                  ),
                ],
              ),
            );
          },
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);

      await tester.tap(find.text('Disable'));
      await tester.pump();

      expect(expansionStates, [false]);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('calls onChipRemoved when a chip is tapped', (tester) async {
      final removedItems = <DesignSystemDropdownItem>[];

      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            type: DesignSystemDropdownType.multiselect,
            items: const [
              DesignSystemDropdownItem(
                id: 'a',
                label: 'Alpha',
                selected: true,
              ),
              DesignSystemDropdownItem(
                id: 'b',
                label: 'Beta',
                selected: true,
              ),
            ],
            onChipRemoved: removedItems.add,
          ),
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pump();

      expect(removedItems, hasLength(1));
      expect(removedItems.single.id, 'b');
    });

    testWidgets(
      'renders chip with resolvedChipLabel and checkbox for selected item',
      (tester) async {
        await _pumpDropdown(
          tester,
          const SizedBox(
            width: 320,
            child: DesignSystemDropdown(
              label: 'Label',
              inputLabel: 'Input',
              type: DesignSystemDropdownType.multiselect,
              initiallyExpanded: true,
              items: [
                DesignSystemDropdownItem(
                  id: 'item-0',
                  label: 'Full name',
                  chipLabel: 'Short',
                  selected: true,
                ),
                DesignSystemDropdownItem(
                  id: 'item-1',
                  label: 'Other',
                ),
              ],
            ),
          ),
        );

        // Chip shows chipLabel, not the full label
        expect(find.text('Short'), findsOneWidget);
        // Only the selected row shows a checkmark
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        // Both menu rows are visible
        expect(find.text('Full name'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
      },
    );

    testWidgets('hides chip remove icon when onChipRemoved is null', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        const SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            type: DesignSystemDropdownType.multiselect,
            items: [
              DesignSystemDropdownItem(
                id: 'a',
                label: 'Alpha',
                selected: true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    });

    testWidgets('exposes selected semantics on multiselect rows', (
      tester,
    ) async {
      await _pumpDropdown(
        tester,
        const SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            type: DesignSystemDropdownType.multiselect,
            initiallyExpanded: true,
            items: [
              DesignSystemDropdownItem(
                id: 'a',
                label: 'Selected row',
                chipLabel: 'Sel chip',
                selected: true,
              ),
              DesignSystemDropdownItem(
                id: 'b',
                label: 'Unselected row',
              ),
            ],
          ),
        ),
      );

      final selectedSemantics = tester.getSemantics(
        find.text('Selected row'),
      );
      final unselectedSemantics = tester.getSemantics(
        find.text('Unselected row'),
      );

      expect(
        selectedSemantics.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        unselectedSemantics.getSemanticsData().flagsCollection.isSelected,
        Tristate.isFalse,
      );
    });

    testWidgets('uses the active dark theme tokens', (tester) async {
      await _pumpDropdown(
        tester,
        SizedBox(
          width: 320,
          child: DesignSystemDropdown(
            label: 'Label',
            inputLabel: 'Input',
            items: _items(['Title']),
          ),
        ),
        theme: DesignSystemTheme.dark(),
      );

      final decoration = _triggerDecoration(tester);
      final shape = decoration.shape as RoundedRectangleBorder;

      expect(decoration.color, dsTokensDark.colors.background.level01);
      expect(shape.side.color, dsTokensDark.colors.decorative.level02);
    });
  });
}

Future<void> _pumpDropdown(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: theme ?? DesignSystemTheme.light(),
    ),
  );
}

List<DesignSystemDropdownItem> _items(List<String> labels) {
  return [
    for (var index = 0; index < labels.length; index++)
      DesignSystemDropdownItem(
        id: 'item-$index',
        label: labels[index],
      ),
  ];
}

ShapeDecoration _triggerDecoration(WidgetTester tester) {
  final ink = tester.widget<Ink>(find.byType(Ink).first);
  return ink.decoration! as ShapeDecoration;
}

Size _triggerSize(WidgetTester tester) {
  return tester.getSize(
    find.byKey(const ValueKey('design-system-dropdown-trigger')),
  );
}

RichText _findTextNode(WidgetTester tester, String label) {
  return tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == label,
    ),
  );
}
