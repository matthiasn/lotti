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
