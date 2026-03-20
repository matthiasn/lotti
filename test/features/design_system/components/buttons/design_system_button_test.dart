import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemButton', () {
    testWidgets('renders the primary small variant from tokens', (
      tester,
    ) async {
      const buttonKey = Key('primary-small');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemButton(
            key: buttonKey,
            label: 'Primary',
            leadingIcon: Icons.add,
            trailingIcon: Icons.keyboard_arrow_down,
            onPressed: _noop,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(of: find.byKey(buttonKey), matching: find.byType(Ink)),
      );
      final decoration = ink.decoration! as ShapeDecoration;
      final shape = decoration.shape as RoundedRectangleBorder;
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byKey(buttonKey),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Padding && widget.padding != EdgeInsets.zero,
              ),
            )
            .first,
      );
      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == 'Primary',
          ),
        ),
      );
      final iconTheme = tester.widget<IconTheme>(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is IconTheme &&
                widget.data.size ==
                    dsTokensLight.typography.lineHeight.subtitle2 &&
                widget.data.color ==
                    dsTokensLight.colors.text.onInteractiveAlert,
          ),
        ),
      );

      expect(decoration.color, dsTokensLight.colors.interactive.enabled);
      expect(shape.borderRadius, BorderRadius.circular(dsTokensLight.radii.l));
      expect(
        padding.padding,
        EdgeInsets.symmetric(
          horizontal: dsTokensLight.spacing.step3,
          vertical: dsTokensLight.spacing.step3,
        ),
      );

      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
      expect(
        iconTheme.data.size,
        dsTokensLight.typography.lineHeight.subtitle2,
      );
      expect(
        iconTheme.data.color,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
    });

    testWidgets('renders the tertiary hover state from tokens', (tester) async {
      const buttonKey = Key('tertiary-hover');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemButton(
            key: buttonKey,
            label: 'Tertiary',
            variant: DesignSystemButtonVariant.tertiary,
            forcedState: DesignSystemButtonVisualState.hover,
            leadingIcon: Icons.add,
            trailingIcon: Icons.keyboard_arrow_down,
            onPressed: _noop,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(of: find.byKey(buttonKey), matching: find.byType(Ink)),
      );
      final decoration = ink.decoration! as ShapeDecoration;
      expect(decoration.color, dsTokensLight.colors.surface.hover);
      expect(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DefaultTextStyle &&
                widget.style.color == dsTokensLight.colors.interactive.hover,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('applies token-driven disabled opacity to danger buttons', (
      tester,
    ) async {
      const buttonKey = Key('danger-disabled');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemButton(
            key: buttonKey,
            label: 'Danger',
            variant: DesignSystemButtonVariant.danger,
            leadingIcon: Icons.add,
            trailingIcon: Icons.keyboard_arrow_down,
            onPressed: null,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byType(Opacity),
        ),
      );
      final ink = tester.widget<Ink>(
        find.descendant(of: find.byKey(buttonKey), matching: find.byType(Ink)),
      );
      final decoration = ink.decoration! as ShapeDecoration;

      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
      expect(decoration.color, dsTokensLight.colors.alert.error.defaultColor);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(buttonKey),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
    });

    testWidgets('renders the large size shell from tokens', (tester) async {
      const buttonKey = Key('large-primary');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemButton(
            key: buttonKey,
            label: 'Large',
            size: DesignSystemButtonSize.large,
            leadingIcon: Icons.add,
            trailingIcon: Icons.keyboard_arrow_down,
            onPressed: _noop,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byKey(buttonKey),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Padding && widget.padding != EdgeInsets.zero,
              ),
            )
            .first,
      );
      final ink = tester.widget<Ink>(
        find.descendant(of: find.byKey(buttonKey), matching: find.byType(Ink)),
      );
      final decoration = ink.decoration! as ShapeDecoration;
      final shape = decoration.shape as RoundedRectangleBorder;
      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == 'Large',
          ),
        ),
      );
      final iconTheme = tester.widget<IconTheme>(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is IconTheme &&
                widget.data.size ==
                    dsTokensLight.typography.lineHeight.subtitle1 &&
                widget.data.color ==
                    dsTokensLight.colors.text.onInteractiveAlert,
          ),
        ),
      );

      expect(
        padding.padding,
        EdgeInsets.symmetric(
          horizontal: dsTokensLight.spacing.step4,
          vertical: dsTokensLight.spacing.step4,
        ),
      );
      expect(shape.borderRadius, BorderRadius.circular(dsTokensLight.radii.xl));

      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.subtitle.subtitle1,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
      expect(
        iconTheme.data.size,
        dsTokensLight.typography.lineHeight.subtitle1,
      );
    });

    testWidgets('renders icon-only content with a single gap', (tester) async {
      const buttonKey = Key('icon-only');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemButton(
            key: buttonKey,
            label: '',
            leadingIcon: Icons.add,
            trailingIcon: Icons.keyboard_arrow_down,
            onPressed: _noop,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byType(Flexible),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.width == dsTokensLight.spacing.step2,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('wraps long labels in a flexible ellipsis text node', (
      tester,
    ) async {
      const buttonKey = Key('long-label');
      const label = 'A very long button label that should truncate cleanly';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 180,
            child: DesignSystemButton(
              key: buttonKey,
              label: label,
              leadingIcon: Icons.add,
              trailingIcon: Icons.keyboard_arrow_down,
              onPressed: _noop,
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byType(Flexible),
        ),
        findsOneWidget,
      );

      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == label,
          ),
        ),
      );

      expect(richText.overflow, TextOverflow.ellipsis);
      expect(richText.maxLines, 1);
    });
  });
}

void _noop() {}
