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

    group('color override', () {
      /// The rules the divider itself paints. Scoped to the component, since
      /// the surrounding test scaffold contributes a [ColoredBox] of its own.
      final rules = find.descendant(
        of: find.byType(DesignSystemDivider),
        matching: find.byType(ColoredBox),
      );

      /// The ink of every rule rendered, in order. The labeled variant draws
      /// two, so reading them as a list is what proves the override reaches
      /// both and not just the first.
      List<Color> ruleColors(WidgetTester tester) =>
          tester.widgetList<ColoredBox>(rules).map((box) => box.color).toList();

      Future<void> pump(WidgetTester tester, DesignSystemDivider divider) =>
          tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              SizedBox(width: 320, child: divider),
              theme: DesignSystemTheme.light(),
            ),
          );

      testWidgets('inks the unlabeled horizontal rule', (tester) async {
        await pump(tester, const DesignSystemDivider(color: Colors.red));

        expect(ruleColors(tester), [Colors.red]);
      });

      testWidgets(
        'inks BOTH rules of the labeled variant, leaving the label alone — '
        'a half-overridden divider would read as a broken line',
        (tester) async {
          await pump(
            tester,
            const DesignSystemDivider(label: 'Section', color: Colors.red),
          );

          expect(ruleColors(tester), [Colors.red, Colors.red]);
          expect(
            tester.widget<Text>(find.text('SECTION')).style?.color,
            dsTokensLight.colors.text.mediumEmphasis,
          );
        },
      );

      testWidgets('inks the vertical rule', (tester) async {
        await pump(
          tester,
          const DesignSystemDivider(
            orientation: DesignSystemDividerOrientation.vertical,
            color: Colors.red,
          ),
        );

        expect(ruleColors(tester), [Colors.red]);
      });

      testWidgets(
        'a null color keeps the decorative token — the override is opt-in, '
        'so every existing caller is unaffected',
        (tester) async {
          await pump(tester, const DesignSystemDivider());

          expect(ruleColors(tester), [
            dsTokensLight.colors.decorative.level01,
          ]);
        },
      );

      testWidgets(
        'Colors.transparent suppresses the line WITHOUT collapsing its 1 px '
        'of height — the whole point of fading by colour is that hovering '
        'never shifts the rows below',
        (tester) async {
          await pump(tester, const DesignSystemDivider());
          final opaqueHeight = tester.getSize(rules).height;

          await pump(
            tester,
            const DesignSystemDivider(color: Colors.transparent),
          );

          expect(ruleColors(tester), [Colors.transparent]);
          expect(tester.getSize(rules).height, opaqueHeight);
          expect(opaqueHeight, 1);
        },
      );

      testWidgets(
        'survives the explicit-length path, which skips the LayoutBuilder '
        'that measures the rule',
        (tester) async {
          await pump(
            tester,
            const DesignSystemDivider(length: 120, color: Colors.red),
          );

          expect(ruleColors(tester), [Colors.red]);
          // The declared extent, not the laid-out one: the enclosing box in
          // `pump` constrains the rule tightly, so only the widget's own
          // width proves the length path (not the LayoutBuilder) ran.
          expect(
            tester
                .widget<SizedBox>(
                  find.descendant(
                    of: find.byType(DesignSystemDivider),
                    matching: find.byType(SizedBox),
                  ),
                )
                .width,
            120,
          );
        },
      );

      testWidgets('survives the indent path, which wraps the rule in padding', (
        tester,
      ) async {
        await pump(
          tester,
          const DesignSystemDivider(indent: 20, color: Colors.red),
        );

        expect(ruleColors(tester), [Colors.red]);
        expect(tester.getSize(rules).width, 320 - 40);
      });
    });
  });
}
