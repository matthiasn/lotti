import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/tooltip_icons/design_system_tooltip_icon.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTooltipIcon', () {
    testWidgets('renders with default help icon', (tester) async {
      const key = Key('default-tooltip');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemTooltipIcon(
            key: key,
            message: 'Help text',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byIcon(Icons.help_outline_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders with custom icon', (tester) async {
      const key = Key('custom-tooltip');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemTooltipIcon(
            key: key,
            message: 'Info text',
            icon: Icons.info_outline_rounded,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byIcon(Icons.info_outline_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses medium emphasis color from tokens', (tester) async {
      const key = Key('color-tooltip');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemTooltipIcon(
            key: key,
            message: 'Help',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Icon),
        ),
      );

      expect(icon.color, dsTokensLight.colors.text.mediumEmphasis);
      expect(icon.size, 16);
    });

    testWidgets('wraps icon in a Tooltip widget', (tester) async {
      const key = Key('tooltip-wrapper');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemTooltipIcon(
            key: key,
            message: 'Tooltip message',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final tooltip = tester.widget<Tooltip>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Tooltip),
        ),
      );

      expect(tooltip.message, 'Tooltip message');
    });

    testWidgets('provides semantics label from message', (tester) async {
      const key = Key('semantics-tooltip');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemTooltipIcon(
            key: key,
            message: 'Help info',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Help info',
          ),
        ),
      );

      expect(semantics.properties.label, 'Help info');
    });

    testWidgets('uses custom semantics label when provided', (tester) async {
      const key = Key('custom-semantics');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemTooltipIcon(
            key: key,
            message: 'Help info',
            semanticsLabel: 'Custom label',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Custom label',
          ),
        ),
      );

      expect(semantics.properties.label, 'Custom label');
    });
  });
}
