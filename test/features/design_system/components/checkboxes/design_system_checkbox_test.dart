import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemCheckbox', () {
    testWidgets('renders the unchecked checkbox from tokens', (tester) async {
      const checkboxKey = Key('checkbox-unchecked');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemCheckbox(
            key: checkboxKey,
            value: false,
            label: 'Accept terms',
            onChanged: _noop,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(checkboxKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border != null,
          ),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(checkboxKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText() == 'Accept terms',
          ),
        ),
      );

      expect(decoration.color, dsTokensLight.colors.background.level01);
      expect(
        decoration.border!.top.color,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(dsTokensLight.radii.xs),
      );
      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.body.bodySmall,
        dsTokensLight.colors.text.highEmphasis,
      );
    });

    testWidgets('toggles from false to true on tap', (tester) async {
      bool? value = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          StatefulBuilder(
            builder: (context, setState) {
              return DesignSystemCheckbox(
                value: value,
                label: 'Accept terms',
                onChanged: (nextValue) {
                  setState(() {
                    value = nextValue;
                  });
                },
              );
            },
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.tap(find.byType(DesignSystemCheckbox));
      await tester.pump();

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DesignSystemCheckbox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(value, isTrue);
      expect(decoration.color, dsTokensLight.colors.interactive.enabled);
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(DesignSystemCheckbox),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == 'Accept terms',
              ),
            )
            .first,
      );
      expect(semantics.properties.checked, isTrue);
      expect(semantics.properties.mixed, isFalse);
      expect(semantics.properties.enabled, isTrue);
    });

    testWidgets('renders the indeterminate state with mixed semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemCheckbox(
            value: null,
            label: 'Accept terms',
            onChanged: _noop,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DesignSystemCheckbox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(DesignSystemCheckbox),
          matching: find.byType(CustomPaint),
        ),
      );
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(DesignSystemCheckbox),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == 'Accept terms',
              ),
            )
            .first,
      );

      expect(
        decoratedBox.decoration,
        isA<BoxDecoration>()
            .having(
              (decoration) => decoration.color,
              'color',
              dsTokensLight.colors.interactive.enabled,
            )
            .having(
              (decoration) => decoration.borderRadius,
              'borderRadius',
              BorderRadius.circular(dsTokensLight.radii.xs),
            ),
      );
      expect(customPaint.painter, isNotNull);
      expect(semantics.properties.checked, isFalse);
      expect(semantics.properties.mixed, isTrue);
      expect(semantics.properties.enabled, isTrue);
    });

    testWidgets('applies token-driven disabled opacity', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemCheckbox(
            value: true,
            label: 'Accept terms',
            onChanged: null,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(DesignSystemCheckbox),
          matching: find.byType(Opacity),
        ),
      );

      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(DesignSystemCheckbox),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == 'Accept terms',
              ),
            )
            .first,
      );
      expect(semantics.properties.enabled, isFalse);
    });

    testWidgets('uses the forced hover state from tokens', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemCheckbox(
            value: false,
            label: 'Accept terms',
            forcedState: DesignSystemCheckboxVisualState.hover,
            onChanged: _noop,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DesignSystemCheckbox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.hover);
      expect(
        decoration.border!.top.color,
        dsTokensLight.colors.interactive.hover,
      );
    });
  });
}

void _noop(bool? value) {}
