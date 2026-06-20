import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';
import 'audio_progress_bar_test_helpers.dart';

void main() {
  group('formatAudioDuration', () {
    test('formats zero duration', () {
      expect(formatAudioDuration(Duration.zero), '00:00');
    });

    test('formats seconds only', () {
      expect(formatAudioDuration(const Duration(seconds: 5)), '00:05');
      expect(formatAudioDuration(const Duration(seconds: 45)), '00:45');
    });

    test('formats minutes and seconds', () {
      expect(formatAudioDuration(const Duration(minutes: 1)), '01:00');
      expect(
        formatAudioDuration(const Duration(minutes: 1, seconds: 30)),
        '01:30',
      );
      expect(
        formatAudioDuration(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('formats hours, minutes, and seconds', () {
      expect(
        formatAudioDuration(const Duration(hours: 1)),
        '01:00:00',
      );
      expect(
        formatAudioDuration(
          const Duration(hours: 1, minutes: 23, seconds: 45),
        ),
        '01:23:45',
      );
      expect(
        formatAudioDuration(
          const Duration(hours: 12, minutes: 34, seconds: 56),
        ),
        '12:34:56',
      );
    });

    test('clamps negative values to zero', () {
      expect(
        formatAudioDuration(const Duration(seconds: -10)),
        '00:00',
      );
    });

    test('clamps values above max (359999 seconds)', () {
      // Max value: 99:59:59 = 359999 seconds
      expect(
        formatAudioDuration(const Duration(seconds: 359999)),
        '99:59:59',
      );
      // Above max should be clamped
      expect(
        formatAudioDuration(const Duration(seconds: 400000)),
        '99:59:59',
      );
    });

    test('pads single digits with zeros', () {
      expect(
        formatAudioDuration(const Duration(minutes: 5, seconds: 3)),
        '05:03',
      );
      expect(
        formatAudioDuration(
          const Duration(hours: 2, minutes: 5, seconds: 3),
        ),
        '02:05:03',
      );
    });
  });

  // -------------------------------------------------------------------------
  // formatAudioDuration — Glados property tests
  // -------------------------------------------------------------------------

  group('formatAudioDuration — properties', () {
    glados.Glados<int>(
      glados.any.audioSeconds,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is never empty and always contains exactly one or two colons',
      (seconds) {
        final result = formatAudioDuration(Duration(seconds: seconds));
        expect(result, isNotEmpty);
        final colonCount = result.split(':').length - 1;
        // mm:ss → 1 colon; hh:mm:ss → 2 colons
        expect(colonCount, anyOf(1, 2));
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.audioSeconds,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output for non-negative inputs never starts with a negative sign',
      (seconds) {
        final result = formatAudioDuration(Duration(seconds: seconds));
        // All components are clamped ≥ 0 so no minus sign is possible.
        expect(result.startsWith('-'), isFalse);
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(0, 3599),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'durations under one hour produce exactly mm:ss (no hour cell)',
      (seconds) {
        final result = formatAudioDuration(Duration(seconds: seconds));
        // Must contain exactly one colon → mm:ss form.
        expect(result.contains(':'), isTrue);
        expect(
          result.split(':').length,
          2,
          reason: 'expected mm:ss but got "$result"',
        );
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(3600, 360000),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'durations of at least one hour produce exactly hh:mm:ss (two colons)',
      (seconds) {
        final result = formatAudioDuration(Duration(seconds: seconds));
        expect(
          result.split(':').length,
          3,
          reason: 'expected hh:mm:ss but got "$result"',
        );
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(0, 360000),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'every component is exactly two digits (zero-padded)',
      (seconds) {
        final result = formatAudioDuration(Duration(seconds: seconds));
        for (final part in result.split(':')) {
          expect(
            part.length,
            2,
            reason: 'component "$part" in "$result" is not 2 digits',
          );
        }
      },
      tags: 'glados',
    );
  });

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
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
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
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AudioProgressBar), findsOneWidget);
    });
  });
}
