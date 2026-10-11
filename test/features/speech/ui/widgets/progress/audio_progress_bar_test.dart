import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('resolveAudioProgressColors', () {
    // resolveAudioProgressColors only reads brightness + colorScheme.primary
    // (when no DsTokens extension is present). secondary is irrelevant to the
    // colour logic, so the helper fixes it and varies only the inputs the
    // function actually consumes.
    ThemeData makeTheme(Brightness brightness, Color primary) {
      final colorScheme = brightness == Brightness.dark
          ? ColorScheme.dark(primary: primary)
          : ColorScheme.light(primary: primary);
      return ThemeData(colorScheme: colorScheme);
    }

    test('light mode brightens medium primary for thumb', () {
      final colors = resolveAudioProgressColors(
        makeTheme(Brightness.light, Colors.teal),
      );

      expect(colors.progress, Colors.teal);
      expect(
        colors.thumb.computeLuminance(),
        greaterThan(colors.progress.computeLuminance()),
      );
      expect(colors.glow.a, greaterThan(0));
    });

    test('dark mode brightens primary for thumb', () {
      final colors = resolveAudioProgressColors(
        makeTheme(Brightness.dark, Colors.blueGrey),
      );

      expect(colors.progress, Colors.blueGrey);
      expect(
        colors.thumb.computeLuminance(),
        greaterThan(colors.progress.computeLuminance()),
      );
      expect(colors.glow, Colors.transparent);
    });

    test('thumb lifts toward white for mid-luminance primaries', () {
      const primary = Color(0xFF2BA184);

      final lightColors = resolveAudioProgressColors(
        makeTheme(Brightness.light, primary),
      );
      final darkColors = resolveAudioProgressColors(
        makeTheme(Brightness.dark, primary),
      );

      // Thumb is brighter than the brand color in both modes so it remains
      // visible against the filled progress.
      expect(
        lightColors.thumb.computeLuminance(),
        greaterThan(primary.computeLuminance()),
      );
      expect(
        darkColors.thumb.computeLuminance(),
        greaterThan(lightColors.thumb.computeLuminance()),
      );
    });

    test('light mode darkens overly bright primary for thumb contrast', () {
      final colors = resolveAudioProgressColors(
        makeTheme(Brightness.light, Colors.yellow),
      );

      expect(colors.progress, Colors.yellow);
      expect(
        colors.thumb.computeLuminance(),
        lessThan(colors.progress.computeLuminance()),
      );
    });
  });

  group('AudioProgressBar painting', () {
    testWidgets('paints without throwing when narrower than the thumb radius', (
      tester,
    ) async {
      // The always-drawn thumb clamps its centre to a thumb-radius inset; when
      // the bar is laid out narrower than that radius the lower clamp bound
      // must not exceed the width (a regression that threw ArgumentError in
      // paint()).
      await tester.pumpWidget(
        makeTestableWidget(
          SizedBox(
            width: 4,
            child: AudioProgressBar(
              progress: const Duration(seconds: 30),
              buffered: const Duration(seconds: 40),
              total: const Duration(minutes: 1),
              onSeek: (_) {},
              enabled: true,
              compact: false,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AudioProgressBar), findsOneWidget);
    });
  });
}
