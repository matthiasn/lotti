import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/split_buttons/design_system_split_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemSplitButton', () {
    testWidgets('renders the small closed split button from tokens', (
      tester,
    ) async {
      const buttonKey = Key('split-small');

      await _pumpSplitButton(
        tester,
        const DesignSystemSplitButton(
          key: buttonKey,
          label: 'Small',
          onPressed: _noop,
          onDropdownPressed: _noop,
        ),
      );

      final decoration = _splitButtonDecoration(tester);
      final shape = decoration.shape as RoundedRectangleBorder;
      final richText = _findTextNode(tester, 'Small');

      expect(
        _splitButtonSize(tester, buttonKey).height,
        dsTokensLight.typography.lineHeight.subtitle2 +
            dsTokensLight.spacing.step2 * 2,
      );
      expect(
        decoration.color,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(
        shape.borderRadius,
        BorderRadius.circular(
          (dsTokensLight.typography.lineHeight.subtitle2 +
                  dsTokensLight.spacing.step2 * 2) /
              2,
        ),
      );
      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
      expect(
        find.byIcon(Icons.keyboard_arrow_down),
        findsOneWidget,
      );
    });

    testWidgets('renders the compact open split button from tokens', (
      tester,
    ) async {
      const buttonKey = Key('split-compact-open');

      await _pumpSplitButton(
        tester,
        const DesignSystemSplitButton(
          key: buttonKey,
          label: 'Compact',
          size: DesignSystemSplitButtonSize.compact,
          isDropdownOpen: true,
          onPressed: _noop,
          onDropdownPressed: _noop,
        ),
      );

      final decoration = _splitButtonDecoration(tester);
      final shape = decoration.shape as RoundedRectangleBorder;
      final icon = tester.widget<Icon>(find.byIcon(Icons.keyboard_arrow_up));
      final richText = _findTextNode(tester, 'Compact');

      expect(
        _splitButtonSize(tester, buttonKey).height,
        dsTokensLight.typography.lineHeight.subtitle2 +
            dsTokensLight.spacing.step3 * 2,
      );
      expect(
        shape.borderRadius,
        BorderRadius.circular(
          (dsTokensLight.typography.lineHeight.subtitle2 +
                  dsTokensLight.spacing.step3 * 2) /
              2,
        ),
      );
      expect(icon.icon, Icons.keyboard_arrow_up);
      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
    });

    testWidgets('renders the default closed split button from tokens', (
      tester,
    ) async {
      const buttonKey = Key('split-default');

      await _pumpSplitButton(
        tester,
        const DesignSystemSplitButton(
          key: buttonKey,
          label: 'Default',
          size: DesignSystemSplitButtonSize.defaultSize,
          onPressed: _noop,
          onDropdownPressed: _noop,
        ),
      );

      final decoration = _splitButtonDecoration(tester);
      final shape = decoration.shape as RoundedRectangleBorder;
      final richText = _findTextNode(tester, 'Default');

      expect(
        _splitButtonSize(tester, buttonKey).height,
        dsTokensLight.typography.lineHeight.subtitle1 +
            dsTokensLight.spacing.step4 * 2,
      );
      expect(
        shape.borderRadius,
        BorderRadius.circular(
          (dsTokensLight.typography.lineHeight.subtitle1 +
                  dsTokensLight.spacing.step4 * 2) /
              2,
        ),
      );
      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle1,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
    });

    testWidgets('invokes both callbacks from the correct segment', (
      tester,
    ) async {
      var mainTapCount = 0;
      var dropdownTapCount = 0;

      await _pumpSplitButton(
        tester,
        DesignSystemSplitButton(
          label: 'Action',
          size: DesignSystemSplitButtonSize.defaultSize,
          onPressed: () => mainTapCount++,
          onDropdownPressed: () => dropdownTapCount++,
        ),
      );

      await tester.tap(find.byType(InkWell).at(0));
      await tester.pump();
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();

      expect(mainTapCount, 1);
      expect(dropdownTapCount, 1);
    });

    testWidgets('renders the divider and dropdown toggle from tokens', (
      tester,
    ) async {
      await _pumpSplitButton(
        tester,
        const DesignSystemSplitButton(
          label: 'Action',
          size: DesignSystemSplitButtonSize.defaultSize,
          isDropdownOpen: true,
          onPressed: _noop,
          onDropdownPressed: _noop,
        ),
      );

      final divider = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.width == dsTokensLight.spacing.step1 / 2,
        ),
      );

      expect(divider.width, dsTokensLight.spacing.step1 / 2);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    });

    testWidgets('provides a default accessible label for the dropdown action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await _pumpSplitButton(
        tester,
        const DesignSystemSplitButton(
          label: 'Action',
          onPressed: _noop,
          onDropdownPressed: _noop,
        ),
      );

      expect(find.bySemanticsLabel('Open Action options'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('keeps long labels inside constrained layouts', (tester) async {
      await _pumpSplitButton(
        tester,
        const SizedBox(
          width: 160,
          child: DesignSystemSplitButton(
            label: 'A very long split button label',
            size: DesignSystemSplitButtonSize.defaultSize,
            onPressed: _noop,
            onDropdownPressed: _noop,
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('applies disabled opacity and blocks both segments', (
      tester,
    ) async {
      var mainTapCount = 0;
      var dropdownTapCount = 0;

      await _pumpSplitButton(
        tester,
        DesignSystemSplitButton(
          label: 'Disabled',
          enabled: false,
          onPressed: () => mainTapCount++,
          onDropdownPressed: () => dropdownTapCount++,
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      final inkWells = tester
          .widgetList<InkWell>(find.byType(InkWell))
          .toList();

      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
      expect(inkWells, hasLength(2));
      expect(inkWells[0].onTap, isNull);
      expect(inkWells[1].onTap, isNull);

      await tester.tap(find.text('Disabled'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(mainTapCount, 0);
      expect(dropdownTapCount, 0);
    });

    testWidgets('exposes disabled semantics for both segments', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await _pumpSplitButton(
        tester,
        const DesignSystemSplitButton(
          label: 'Disabled',
          enabled: false,
          onPressed: _noop,
          onDropdownPressed: _noop,
        ),
      );

      final semanticWidgets = tester
          .widgetList<Semantics>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.button == true,
            ),
          )
          .where(
            (widget) =>
                widget.properties.label == 'Disabled' ||
                widget.properties.label == 'Open Disabled options',
          )
          .toList();

      expect(semanticWidgets, hasLength(2));
      expect(
        semanticWidgets.map((widget) => widget.properties.enabled),
        everyElement(isFalse),
      );

      semantics.dispose();
    });
  });
}

Future<void> _pumpSplitButton(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: DesignSystemTheme.light(),
    ),
  );
}

ShapeDecoration _splitButtonDecoration(WidgetTester tester) {
  final ink = tester.widget<Ink>(find.byType(Ink));
  return ink.decoration! as ShapeDecoration;
}

Size _splitButtonSize(
  WidgetTester tester,
  Key key,
) {
  return tester.getSize(find.byKey(key));
}

RichText _findTextNode(WidgetTester tester, String label) {
  return tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == label,
    ),
  );
}

void _noop() {}
