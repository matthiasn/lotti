import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/tabs/design_system_tab.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTab', () {
    testWidgets('renders the default enabled tab from tokens', (tester) async {
      const tabKey = Key('default-tab');

      await _pumpTab(
        tester,
        const DesignSystemTab(
          key: tabKey,
          selected: false,
          label: 'Pending',
          onPressed: _noop,
        ),
      );

      final contentDecoration = _contentDecoration(tester, tabKey);
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byKey(tabKey),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Padding && widget.padding != EdgeInsets.zero,
              ),
            )
            .first,
      );
      final title = _findTextNode(tester, tabKey, 'Pending');
      final divider = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == dsTokensLight.colors.decorative.level02,
          ),
        ),
      );

      expect(tester.getSize(find.byKey(tabKey)).height, 49);
      expect(contentDecoration.color, dsTokensLight.colors.surface.enabled);
      expect(
        padding.padding,
        EdgeInsets.only(
          left: dsTokensLight.spacing.step5,
          right: dsTokensLight.spacing.step5,
          top: dsTokensLight.spacing.step4,
          bottom: dsTokensLight.spacing.step4,
        ),
      );
      expectTextStyle(
        title.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(divider.color, dsTokensLight.colors.decorative.level02);
      expect(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.height == 3,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('renders the small activated tab with token-driven slots', (
      tester,
    ) async {
      const tabKey = Key('activated-small-tab');

      await _pumpTab(
        tester,
        const DesignSystemTab(
          key: tabKey,
          selected: true,
          size: DesignSystemTabSize.small,
          label: 'Pending',
          counter: '10',
          leadingIcon: Icons.schedule_rounded,
          trailingIcon: Icons.close_rounded,
          onPressed: _noop,
        ),
      );

      final contentDecoration = _contentDecoration(tester, tabKey);
      final title = _findTextNode(tester, tabKey, 'Pending');
      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.button == true,
          ),
        ),
      );
      final selector = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == dsTokensLight.colors.interactive.enabled,
          ),
        ),
      );
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byKey(tabKey),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Padding && widget.padding != EdgeInsets.zero,
              ),
            )
            .first,
      );
      final leadingIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byIcon(Icons.schedule_rounded),
        ),
      );
      final trailingIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );

      expect(tester.getSize(find.byKey(tabKey)).height, 41);
      expect(contentDecoration.color, dsTokensLight.colors.surface.active);
      expect(
        padding.padding,
        EdgeInsets.only(
          left: dsTokensLight.spacing.step4,
          right: dsTokensLight.spacing.step4,
          top: dsTokensLight.spacing.step4 - dsTokensLight.spacing.step1,
          bottom:
              dsTokensLight.spacing.step3 - (dsTokensLight.spacing.step1 / 2),
        ),
      );
      expectTextStyle(
        title.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(selector.color, dsTokensLight.colors.interactive.enabled);
      expect(leadingIcon.size, dsTokensLight.typography.size.subtitle2);
      expect(leadingIcon.color, dsTokensLight.colors.interactive.enabled);
      expect(trailingIcon.size, dsTokensLight.typography.size.subtitle2);
      expect(trailingIcon.color, dsTokensLight.colors.text.highEmphasis);
      expect(find.text('10'), findsOneWidget);
      expect(semantics.properties.selected, isTrue);
    });

    testWidgets('renders hover and pressed treatments from tokens', (
      tester,
    ) async {
      const hoverKey = Key('hover-tab');
      const pressedKey = Key('pressed-tab');

      await _pumpTab(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DesignSystemTab(
              key: hoverKey,
              selected: false,
              label: 'Hover',
              forcedState: DesignSystemTabVisualState.hover,
              onPressed: _noop,
            ),
            DesignSystemTab(
              key: pressedKey,
              selected: false,
              label: 'Pressed',
              forcedState: DesignSystemTabVisualState.pressed,
              onPressed: _noop,
            ),
          ],
        ),
      );

      expect(
        _contentDecoration(tester, hoverKey).color,
        dsTokensLight.colors.surface.hover,
      );
      expect(
        _contentDecoration(tester, pressedKey).color,
        dsTokensLight.colors.surface.focusPressed,
      );
    });

    testWidgets('renders disabled tabs without a divider and without taps', (
      tester,
    ) async {
      const tabKey = Key('disabled-tab');

      await _pumpTab(
        tester,
        const DesignSystemTab(
          key: tabKey,
          selected: false,
          label: 'Disabled',
          leadingIcon: Icons.schedule_rounded,
          trailingIcon: Icons.close_rounded,
          onPressed: null,
        ),
      );

      final title = _findTextNode(tester, tabKey, 'Disabled');
      final leadingIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byIcon(Icons.schedule_rounded),
        ),
      );
      final trailingIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byType(InkWell),
        ),
      );

      expect(
        _contentDecoration(tester, tabKey).color,
        dsTokensLight.colors.surface.enabled,
      );
      expectTextStyle(
        title.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.text.lowEmphasis,
      );
      expect(leadingIcon.color, dsTokensLight.colors.text.lowEmphasis);
      expect(trailingIcon.color, dsTokensLight.colors.text.lowEmphasis);
      expect(inkWell.onTap, isNull);
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
      expect(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == dsTokensLight.colors.decorative.level02,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('invokes the callback when tapped', (tester) async {
      var tapCount = 0;

      await _pumpTab(
        tester,
        DesignSystemTab(
          selected: false,
          label: 'Tap target',
          onPressed: () => tapCount++,
        ),
      );

      await tester.tap(find.byType(DesignSystemTab));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('keeps intrinsic width by default inside wider parents', (
      tester,
    ) async {
      const tabKey = Key('intrinsic-width-tab');

      await _pumpTab(
        tester,
        const SizedBox(
          width: 320,
          child: Align(
            alignment: Alignment.centerLeft,
            child: DesignSystemTab(
              key: tabKey,
              selected: false,
              label: 'Instances',
              onPressed: _noop,
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(tabKey)).width, lessThan(320));
    });

    testWidgets('uses rectangular shape without rounded corners', (
      tester,
    ) async {
      const tabKey = Key('rectangular-tab');

      await _pumpTab(
        tester,
        const DesignSystemTab(
          key: tabKey,
          selected: true,
          shape: DesignSystemTabShape.rectangular,
          label: 'Pending Wakes',
          onPressed: _noop,
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byType(Material),
        ),
      );
      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(tabKey),
          matching: find.byType(InkWell),
        ),
      );

      expect(material.borderRadius, BorderRadius.zero);
      expect(inkWell.borderRadius, BorderRadius.zero);
    });

    testWidgets('preferredWidth accounts for icons and multi-digit counters', (
      tester,
    ) async {
      late double textOnlyWidth;
      late double decoratedWidth;

      await _pumpTab(
        tester,
        Builder(
          builder: (context) {
            textOnlyWidth = DesignSystemTab.preferredWidth(
              context,
              label: 'Pending',
            );
            decoratedWidth = DesignSystemTab.preferredWidth(
              context,
              label: 'Pending',
              counter: '100',
              leadingIcon: Icons.schedule_rounded,
              trailingIcon: Icons.close_rounded,
            );
            return const SizedBox.shrink();
          },
        ),
      );

      expect(decoratedWidth, greaterThan(textOnlyWidth));
    });

    testWidgets('uses semanticsLabel when the visible label is omitted', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await _pumpTab(
        tester,
        const DesignSystemTab(
          selected: false,
          label: '',
          semanticsLabel: 'Pending tab',
          leadingIcon: Icons.schedule_rounded,
          onPressed: _noop,
        ),
      );

      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Pending tab'), findsOneWidget);

      semantics.dispose();
    });

    test(
      'asserts when neither a visible label nor semanticsLabel is provided',
      () {
        expect(
          () => DesignSystemTab(
            selected: false,
            label: '',
            onPressed: _noop,
          ),
          throwsAssertionError,
        );
      },
    );
  });
}

Future<void> _pumpTab(
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

BoxDecoration _contentDecoration(WidgetTester tester, Key tabKey) {
  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byKey(tabKey),
      matching: find.byType(Ink),
    ),
  );

  return ink.decoration! as BoxDecoration;
}

RichText _findTextNode(
  WidgetTester tester,
  Key tabKey,
  String text,
) {
  return tester.widget<RichText>(
    find.descendant(
      of: find.byKey(tabKey),
      matching: find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == text,
      ),
    ),
  );
}

void _noop() {}
