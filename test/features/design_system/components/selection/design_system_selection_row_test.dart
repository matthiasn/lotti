import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('single selection uses the shared selected band and check', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        key: const Key('single-row'),
        title: 'In progress',
        type: DesignSystemSelectionRowType.singleSelect,
        selected: true,
        selectedLabel: 'Selected',
        onTap: () {},
      ),
    );

    final ink = tester.widget<Ink>(find.byType(Ink));
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.color, dsTokensLight.colors.surface.selected);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    final semantics = tester.getSemantics(find.byKey(const Key('single-row')));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('multi selection exposes one checked row action', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();

    await _pump(
      tester,
      DesignSystemSelectionRow(
        key: const Key('multi-row'),
        title: 'Design system',
        type: DesignSystemSelectionRowType.multiSelect,
        selected: true,
        onTap: () => taps++,
      ),
    );

    final semantics = tester.getSemantics(find.byKey(const Key('multi-row')));
    expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    expect(find.byType(DesignSystemCheckbox), findsOneWidget);

    await tester.tap(find.text('Design system'));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('navigation rows use a chevron and activate as one row', (
    tester,
  ) async {
    var opened = false;
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Choose a provider',
        subtitle: 'Five providers',
        type: DesignSystemSelectionRowType.navigation,
        onTap: () => opened = true,
      ),
    );

    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.text('Choose a provider'));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('disabled row exposes its reason and cannot activate', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await _pump(
      tester,
      const DesignSystemSelectionRow(
        key: Key('disabled-row'),
        title: 'Unavailable profile',
        subtitle: 'Connect its provider first',
        type: DesignSystemSelectionRowType.singleSelect,
        onTap: null,
      ),
    );

    final semantics = tester.getSemantics(
      find.byKey(const Key('disabled-row')),
    );
    expect(semantics.label, contains('Connect its provider first'));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('keyboard focus uses the token focus fill and outline', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Keyboard target',
        type: DesignSystemSelectionRowType.singleSelect,
        onTap: () {},
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final ink = tester.widget<Ink>(find.byType(Ink));
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.color, dsTokensLight.colors.surface.focusPressed);
    final border = decoration.border! as Border;
    expect(border.top.color, dsTokensLight.colors.interactive.enabled);
    expect(border.top.width, dsTokensLight.spacing.step1);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(width: dsTokensLight.spacing.step13 * 2, child: child),
      theme: DesignSystemTheme.light(),
    ),
  );
}
