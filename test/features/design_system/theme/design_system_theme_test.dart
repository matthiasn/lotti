import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTheme', () {
    // Both factories share _build, so every wiring assertion runs against
    // light and dark to guard asymmetric regressions.
    for (final (name, theme, tokens) in [
      ('light', DesignSystemTheme.light(), dsTokensLight),
      ('dark', DesignSystemTheme.dark(), dsTokensDark),
    ]) {
      test('$name theme attaches the $name token extension', () {
        expect(theme.extension<DsTokens>(), tokens);
        expect(
          theme.brightness,
          name == 'light' ? Brightness.light : Brightness.dark,
        );
      });

      test('$name theme wires every colorScheme slot from tokens', () {
        final scheme = theme.colorScheme;
        final colors = tokens.colors;
        final slots = <(String, Color, Color)>[
          ('primary', scheme.primary, colors.interactive.enabled),
          ('onPrimary', scheme.onPrimary, colors.text.onInteractiveAlert),
          ('secondary', scheme.secondary, colors.surface.active),
          ('onSecondary', scheme.onSecondary, colors.text.highEmphasis),
          ('error', scheme.error, colors.alert.error.defaultColor),
          ('onError', scheme.onError, colors.text.onInteractiveAlert),
          ('surface', scheme.surface, colors.background.level01),
          ('onSurface', scheme.onSurface, colors.text.highEmphasis),
          (
            'primaryContainer',
            scheme.primaryContainer,
            colors.background.level02,
          ),
          (
            'secondaryContainer',
            scheme.secondaryContainer,
            colors.background.level03,
          ),
          ('tertiary', scheme.tertiary, colors.background.alternative01),
          (
            'errorContainer',
            scheme.errorContainer,
            colors.alert.error.hover,
          ),
          (
            'surfaceContainerHighest',
            scheme.surfaceContainerHighest,
            colors.background.level02,
          ),
          (
            'onSurfaceVariant',
            scheme.onSurfaceVariant,
            colors.text.mediumEmphasis,
          ),
          ('outline', scheme.outline, colors.decorative.level01),
          ('outlineVariant', scheme.outlineVariant, colors.decorative.level02),
          (
            'inverseSurface',
            scheme.inverseSurface,
            colors.background.level03,
          ),
          ('inversePrimary', scheme.inversePrimary, colors.interactive.hover),
          ('surfaceTint', scheme.surfaceTint, colors.interactive.enabled),
        ];
        for (final (label, actual, expected) in slots) {
          expect(actual, expected, reason: '$name $label');
        }

        expect(
          theme.scaffoldBackgroundColor,
          colors.background.level01,
          reason: '$name scaffoldBackgroundColor',
        );
        expect(
          theme.canvasColor,
          colors.background.level01,
          reason: '$name canvasColor',
        );
        expect(
          theme.disabledColor,
          colors.text.lowEmphasis,
          reason: '$name disabledColor',
        );
      });

      test('$name theme maps the full textTheme from typography tokens', () {
        final styles = tokens.typography.styles;
        final textTheme = theme.textTheme;
        final mapping = <(String, TextStyle?, TextStyle)>[
          ('displayLarge', textTheme.displayLarge, styles.display.display0),
          ('displayMedium', textTheme.displayMedium, styles.display.display1),
          ('displaySmall', textTheme.displaySmall, styles.display.display2),
          ('headlineLarge', textTheme.headlineLarge, styles.heading.heading1),
          ('headlineMedium', textTheme.headlineMedium, styles.heading.heading2),
          ('headlineSmall', textTheme.headlineSmall, styles.heading.heading3),
          ('titleLarge', textTheme.titleLarge, styles.subtitle.subtitle1),
          ('titleMedium', textTheme.titleMedium, styles.subtitle.subtitle2),
          ('bodyLarge', textTheme.bodyLarge, styles.body.bodyLarge),
          ('bodyMedium', textTheme.bodyMedium, styles.body.bodyMedium),
          ('bodySmall', textTheme.bodySmall, styles.body.bodySmall),
          ('labelLarge', textTheme.labelLarge, styles.subtitle.subtitle2),
          ('labelMedium', textTheme.labelMedium, styles.others.caption),
          ('labelSmall', textTheme.labelSmall, styles.others.overline),
        ];
        for (final (label, actual, tokenStyle) in mapping) {
          // ThemeData merges the provided textTheme into the typography
          // defaults, so assert the token-driven fields rather than full
          // style equality.
          expect(
            actual?.fontSize,
            tokenStyle.fontSize,
            reason: '$name $label fontSize',
          );
          expect(
            actual?.fontWeight,
            tokenStyle.fontWeight,
            reason: '$name $label fontWeight',
          );
          expect(
            actual?.fontFamily,
            tokenStyle.fontFamily,
            reason: '$name $label fontFamily',
          );
          expect(
            actual?.height,
            tokenStyle.height,
            reason: '$name $label height',
          );
          expect(
            actual?.letterSpacing,
            tokenStyle.letterSpacing,
            reason: '$name $label letterSpacing',
          );
          // _build applies highEmphasis as both bodyColor and displayColor.
          expect(
            actual?.color,
            tokens.colors.text.highEmphasis,
            reason: '$name $label color',
          );
        }
      });
    }

    testWidgets('designTokens getter returns the active extension', (
      tester,
    ) async {
      late DsTokens resolvedTokens;

      // Use the shared helper and feed it the real DesignSystemTheme.light().
      // resolveTestTheme() passes a theme through untouched when it already
      // carries a DsTokens extension, so this exercises the production wiring
      // rather than the helper's default-injected tokens.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              resolvedTokens = context.designTokens;
              return const SizedBox.shrink();
            },
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(resolvedTokens, dsTokensLight);
    });

    testWidgets('designTokens getter throws a StateError when missing', (
      tester,
    ) async {
      // Intentionally NOT using a shared helper here: resolveTestTheme() always
      // injects a DsTokens extension, which would defeat the "missing"
      // assertion. A bare MaterialApp with no extension is required.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              context.designTokens;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final exception = tester.takeException();
      expect(exception, isA<StateError>());
      expect(
        exception.toString(),
        contains('DsTokens extension is missing from the active theme.'),
      );
    });
  });
}
