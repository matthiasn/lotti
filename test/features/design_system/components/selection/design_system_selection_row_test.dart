import 'dart:ui' show CheckedState, SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
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
    expect(find.byIcon(LottiIcons.confirm), findsOneWidget);

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
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel('Design system'), findsOneWidget);
    expect(find.byType(DesignSystemCheckbox), findsOneWidget);

    await tester.tap(find.text('Design system'));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets(
    'multi selection can rely on its checkbox without tinting the row',
    (tester) async {
      await _pump(
        tester,
        DesignSystemSelectionRow(
          key: const Key('untinted-multi-row'),
          title: 'Labels',
          type: DesignSystemSelectionRowType.multiSelect,
          selected: true,
          showSelectedBackground: false,
          onTap: () {},
        ),
      );

      final ink = tester.widget<Ink>(find.byType(Ink));
      final decoration = ink.decoration! as BoxDecoration;
      expect(decoration.color, Colors.transparent);

      final semantics = tester.getSemantics(
        find.byKey(const Key('untinted-multi-row')),
      );
      expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
      expect(find.byType(DesignSystemCheckbox), findsOneWidget);
    },
  );

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

    expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirm), findsNothing);

    await tester.tap(find.text('Choose a provider'));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('forwards the compact row size to the shared list item', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Status',
        subtitle: 'All',
        size: DesignSystemListItemSize.small,
        type: DesignSystemSelectionRowType.navigation,
        onTap: () {},
      ),
    );

    expect(
      tester
          .widget<DesignSystemListItem>(find.byType(DesignSystemListItem))
          .size,
      DesignSystemListItemSize.small,
    );
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

  testWidgets('iconless action preserves the minimum interactive height', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      DesignSystemSelectionRow(
        key: const Key('iconless-action'),
        title: 'Clear selection',
        type: DesignSystemSelectionRowType.action,
        onTap: () => taps++,
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('iconless-action'))).height,
      greaterThanOrEqualTo(TapTargets.minimum),
    );
    await tester.tap(find.byKey(const Key('iconless-action')));
    expect(taps, 1);
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

  testWidgets('large text removes the title line cap', (tester) async {
    const title = 'A long project label that must remain fully readable';
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SizedBox(
          width: 220,
          child: DesignSystemSelectionRow(
            title: title,
            type: DesignSystemSelectionRowType.singleSelect,
            onTap: null,
          ),
        ),
        theme: DesignSystemTheme.light(),
        mediaQueryData: const MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(title));
    expect(text.maxLines, isNull);
    expect(text.overflow, TextOverflow.clip);
  });

  testWidgets('secondaryLine renders below the row at the title inset', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Steps',
        type: DesignSystemSelectionRowType.multiSelect,
        secondaryLine: const SizedBox(
          key: Key('secondary-line'),
          width: 40,
          height: 10,
        ),
        onTap: () {},
      ),
    );

    final itemRect = tester.getRect(find.byType(DesignSystemListItem));
    final lineRect = tester.getRect(find.byKey(const Key('secondary-line')));
    expect(lineRect.top, greaterThanOrEqualTo(itemRect.bottom));
    expect(lineRect.left - itemRect.left, dsTokensLight.spacing.step5);
  });

  testWidgets('a leading rail widens the secondaryLine title inset', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Steps',
        leading: const Icon(LottiIcons.flag),
        type: DesignSystemSelectionRowType.multiSelect,
        secondaryLine: const SizedBox(
          key: Key('secondary-line'),
          width: 40,
          height: 10,
        ),
        onTap: () {},
      ),
    );

    final itemRect = tester.getRect(find.byType(DesignSystemListItem));
    final lineRect = tester.getRect(find.byKey(const Key('secondary-line')));
    expect(
      lineRect.left - itemRect.left,
      dsTokensLight.spacing.step5 +
          dsTokensLight.spacing.step8 +
          dsTokensLight.spacing.step3,
    );
  });

  testWidgets(
    'secondaryLine content sits outside the row tap target and keeps its '
    'own semantics',
    (tester) async {
      var rowTaps = 0;
      var adjustTaps = 0;
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        DesignSystemSelectionRow(
          title: 'Steps',
          type: DesignSystemSelectionRowType.multiSelect,
          secondaryLine: TextButton(
            onPressed: () => adjustTaps++,
            child: const Text('Adjust'),
          ),
          onTap: () => rowTaps++,
        ),
      );

      // Tapping the secondary line activates its own control, never the row.
      await tester.tap(find.text('Adjust'));
      await tester.pump();
      expect(adjustTaps, 1);
      expect(rowTaps, 0);

      // The embedded control is its own semantic button, not merged into
      // the row's semantics container.
      expect(
        tester.getSemantics(find.text('Adjust')),
        matchesSemantics(
          label: 'Adjust',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );

      await tester.tap(find.text('Steps'));
      await tester.pump();
      expect(rowTaps, 1);
      expect(adjustTaps, 1);
      handle.dispose();
    },
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(width: dsTokensLight.spacing.step13 * 2, child: child),
      theme: DesignSystemTheme.light(),
    ),
  );
}
