import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/radio_buttons/design_system_radio_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemRadioButton', () {
    testWidgets('renders the default off radio from tokens', (tester) async {
      const radioKey = Key('radio-default-off');

      await _pumpRadio(
        tester,
        const DesignSystemRadioButton(
          key: radioKey,
          selected: false,
          label: 'Radio button',
          showTooltipIcon: true,
          tooltipMessage: 'More information',
          onPressed: _noop,
        ),
      );

      final radioFinder = find.byKey(radioKey);
      final controlDecoration = _radioDecoration(tester, 20);
      final richText = tester.widget<RichText>(
        find.descendant(
          of: radioFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText() == 'Radio button',
          ),
        ),
      );
      final tooltip = tester.widget<Tooltip>(
        find.descendant(
          of: radioFinder,
          matching: find.byType(Tooltip),
        ),
      );
      final iconTheme = tester.widget<IconTheme>(
        find.ancestor(
          of: find.descendant(
            of: radioFinder,
            matching: find.byIcon(Icons.info_outline_rounded),
          ),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is IconTheme &&
                widget.data.size ==
                    dsTokensLight.typography.lineHeight.caption &&
                widget.data.color == dsTokensLight.colors.text.mediumEmphasis,
          ),
        ),
      );

      expect(_radioControlSize(tester, 20), const Size.square(20));
      expect(controlDecoration.shape, BoxShape.circle);
      expect(controlDecoration.color, dsTokensLight.colors.background.level01);
      expect(
        controlDecoration.border,
        isNotNull,
      );
      expect(
        controlDecoration.border!.top.width,
        dsTokensLight.spacing.step1 / 2,
      );
      expect(
        controlDecoration.border!.top.color,
        dsTokensLight.colors.alert.info.defaultColor,
      );
      expect(
        _radioSquareCount(tester, 8),
        0,
      );
      expect(tooltip.message, 'More information');
      expect(iconTheme.data.size, dsTokensLight.typography.lineHeight.caption);
      expect(iconTheme.data.color, dsTokensLight.colors.text.mediumEmphasis);

      _expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.body.bodySmall,
        dsTokensLight.colors.text.highEmphasis,
      );
    });

    testWidgets('renders the large selected radio from tokens', (tester) async {
      await _pumpRadio(
        tester,
        const DesignSystemRadioButton(
          selected: true,
          size: DesignSystemRadioButtonSize.large,
          label: 'Radio button',
          onPressed: _noop,
        ),
      );

      final controlDecoration = _radioDecoration(tester, 24);
      final richText = _findTextNode(tester, 'Radio button');
      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.button == true,
        ),
      );

      expect(_radioControlSize(tester, 24), const Size.square(24));
      expect(_radioSquareCount(tester, 10), 1);
      expect(
        controlDecoration.border!.top.color,
        dsTokensLight.colors.alert.info.defaultColor,
      );
      expect(semantics.properties.selected, isTrue);

      _expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.body.bodyMedium,
        dsTokensLight.colors.text.highEmphasis,
      );
    });

    testWidgets('renders the hover state from tokens', (tester) async {
      await _pumpRadio(
        tester,
        const DesignSystemRadioButton(
          selected: false,
          label: 'Radio button',
          forcedState: DesignSystemRadioButtonVisualState.hover,
          onPressed: _noop,
        ),
      );

      expect(
        _radioDecoration(tester, 20).border!.top.color,
        dsTokensLight.colors.alert.info.hover,
      );
    });

    testWidgets('renders the control only when the label is omitted', (
      tester,
    ) async {
      await _pumpRadio(
        tester,
        const DesignSystemRadioButton(
          selected: false,
          onPressed: _noop,
        ),
      );

      expect(find.text('Radio button'), findsNothing);
      expect(_radioControlSize(tester, 20), const Size.square(20));
      expect(_radioSquareCount(tester, 8), 0);
    });

    testWidgets('applies token-driven disabled opacity', (tester) async {
      await _pumpRadio(
        tester,
        const DesignSystemRadioButton(
          selected: false,
          label: 'Disabled',
          onPressed: null,
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));

      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
      expect(inkWell.onTap, isNull);
    });

    testWidgets('invokes the callback when tapped', (tester) async {
      var tapCount = 0;

      await _pumpRadio(
        tester,
        DesignSystemRadioButton(
          selected: false,
          label: 'Tap target',
          onPressed: () => tapCount++,
        ),
      );

      await tester.tap(find.byType(DesignSystemRadioButton));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('uses the active dark theme tokens', (tester) async {
      await _pumpRadio(
        tester,
        const DesignSystemRadioButton(
          selected: true,
          label: 'Primary',
          onPressed: _noop,
        ),
        theme: DesignSystemTheme.dark(),
      );

      final controlDecoration = _radioDecoration(tester, 20);
      final richText = _findTextNode(tester, 'Primary');

      expect(
        controlDecoration.border!.top.color,
        dsTokensDark.colors.alert.info.defaultColor,
      );
      _expectTextStyle(
        richText.text.style!,
        dsTokensDark.typography.styles.body.bodySmall,
        dsTokensDark.colors.text.highEmphasis,
      );
    });
  });
}

Future<void> _pumpRadio(
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

Size _radioControlSize(
  WidgetTester tester,
  double controlSize,
) {
  return tester.getSize(_radioControlFinder(controlSize));
}

BoxDecoration _radioDecoration(
  WidgetTester tester,
  double controlSize,
) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.descendant(
      of: _radioControlFinder(controlSize),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    ),
  );

  return decoratedBox.decoration as BoxDecoration;
}

Finder _radioControlFinder(double controlSize) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is SizedBox &&
        widget.child is DecoratedBox &&
        widget.width == controlSize &&
        widget.height == controlSize,
  );
}

int _radioSquareCount(
  WidgetTester tester,
  double size,
) {
  return find
      .byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == size && widget.height == size,
      )
      .evaluate()
      .length;
}

RichText _findTextNode(WidgetTester tester, String label) {
  return tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == label,
    ),
  );
}

void _expectTextStyle(TextStyle actual, TextStyle expected, Color color) {
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.fontSize, expected.fontSize);
  expect(actual.fontWeight, expected.fontWeight);
  expect(actual.letterSpacing, expected.letterSpacing);
  expect(actual.height, expected.height);
  expect(actual.color, color);
}

void _noop() {}
