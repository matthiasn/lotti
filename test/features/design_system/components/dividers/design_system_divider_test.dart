import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemDivider', () {
    testWidgets('renders the labeled horizontal variant from tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 320,
            child: DesignSystemDivider(
              label: 'Divider label',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final label = tester.widget<Text>(find.text('DIVIDER LABEL'));
      final lines = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == dsTokensLight.colors.decorative.level01,
      );

      expect(lines, findsNWidgets(2));
      expect(label.style?.fontSize, dsTokensLight.typography.size.overline);
      expect(label.style?.color, dsTokensLight.colors.text.mediumEmphasis);
    });

    testWidgets('renders the default vertical variant with Figma height', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemDivider(
            orientation: DesignSystemDividerOrientation.vertical,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final vertical = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 1 && widget.height == 256,
      );

      expect(vertical, findsOneWidget);
    });

    testWidgets(
      'keeps the unlabeled horizontal variant visible in shrink-wrap layouts',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const UnconstrainedBox(
              child: DesignSystemDivider(),
            ),
            theme: DesignSystemTheme.light(),
          ),
        );

        final horizontal = find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 320 && widget.height == 1,
        );
        final line = find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color == dsTokensLight.colors.decorative.level01,
        );

        expect(horizontal, findsOneWidget);
        expect(line, findsOneWidget);
      },
    );
  });
}
