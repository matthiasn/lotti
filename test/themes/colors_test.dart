import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/colors.dart';

void main() {
  group('syncErrorCountAccentColor', () {
    test('lightens the scheme error color', () {
      const scheme = ColorScheme.dark(error: Color(0xFF990000));

      final accent = syncErrorCountAccentColor(scheme);

      expect(accent, isNot(scheme.error));
      // Lightened: higher computed luminance than the source error color.
      expect(
        accent.computeLuminance(),
        greaterThan(scheme.error.computeLuminance()),
      );
    });
  });

  group('module-level computed colors', () {
    test('derive without throwing and differ from their sources', () {
      expect(habitSkipColor, isA<Color>());
      expect(syncPendingCountAccentColor, isA<Color>());
      // Lightened pending accent must be brighter than its source.
      expect(
        syncPendingCountAccentColor.computeLuminance(),
        greaterThan(syncPendingAccentColor.computeLuminance()),
      );
    });
  });

  group('ModernGradientThemes', () {
    Future<BuildContext> contextFor(
      WidgetTester tester,
      Brightness brightness,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // MaterialApp animates theme switches; let the transition finish so
      // Theme.of reflects the requested brightness.
      await tester.pump(const Duration(milliseconds: 300));
      return context;
    }

    testWidgets('primaryGradient switches palettes between modes', (
      tester,
    ) async {
      final light = ModernGradientThemes.primaryGradient(
        await contextFor(tester, Brightness.light),
      );
      expect(light.colors, [
        ModernGradientColors.primaryStart,
        ModernGradientColors.primaryEnd,
      ]);

      final dark = ModernGradientThemes.primaryGradient(
        await contextFor(tester, Brightness.dark),
      );
      expect(dark.colors, [
        ModernGradientColors.darkPrimaryStart,
        ModernGradientColors.darkPrimaryEnd,
      ]);
    });

    testWidgets('cardGradient is flat in light mode and layered in dark', (
      tester,
    ) async {
      final lightContext = await contextFor(tester, Brightness.light);
      final lightScheme = Theme.of(lightContext).colorScheme;
      final light = ModernGradientThemes.cardGradient(lightContext);
      expect(light.colors, [lightScheme.surface, lightScheme.surface]);

      final darkContext = await contextFor(tester, Brightness.dark);
      final darkScheme = Theme.of(darkContext).colorScheme;
      final dark = ModernGradientThemes.cardGradient(darkContext);
      expect(dark.colors, [
        darkScheme.surfaceContainerHigh,
        darkScheme.surfaceContainer,
      ]);
    });

    testWidgets('accentGradient layers translucent inversePrimary', (
      tester,
    ) async {
      final context = await contextFor(tester, Brightness.light);
      final scheme = Theme.of(context).colorScheme;

      final gradient = ModernGradientThemes.accentGradient(context);

      expect(gradient.colors, [
        scheme.inversePrimary.withAlpha(50),
        scheme.inversePrimary.withAlpha(75),
      ]);
    });

    testWidgets('backgroundGradient uses a stronger overlay in dark mode', (
      tester,
    ) async {
      final light = ModernGradientThemes.backgroundGradient(
        await contextFor(tester, Brightness.light),
      );
      final dark = ModernGradientThemes.backgroundGradient(
        await contextFor(tester, Brightness.dark),
      );

      // Both start on the surface color and overlay a translucent container
      // tint — stronger (0.15) in dark mode than in light (0.08).
      expect(light.colors.first.a, 1.0);
      expect(dark.colors[1].a, closeTo(0.15, 0.001));
      expect(light.colors[1].a, closeTo(0.08, 0.001));
    });
  });
}
