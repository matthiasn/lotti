import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';

// ---------------------------------------------------------------------------
// Generators for formatAudioDuration property tests
// ---------------------------------------------------------------------------

extension _AnyAudioDuration on glados.Any {
  /// A duration in seconds drawn uniformly from [−10000, 400010] to exercise
  /// the negative-clamp and the ≥ 359 999 s cap paths.
  glados.Generator<int> get audioSeconds =>
      glados.any.intInRange(-10000, 400010);
}

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
    test('light mode brightens medium primary for thumb', () {
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.teal,
          secondary: Colors.deepPurple,
        ),
      );

      final colors = resolveAudioProgressColors(theme);

      expect(colors.progress, Colors.teal);
      expect(
        colors.thumb.computeLuminance(),
        greaterThan(colors.progress.computeLuminance()),
      );
      expect(colors.glow.a, greaterThan(0));
    });

    test('dark mode brightens primary for thumb', () {
      final theme = ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueGrey,
          secondary: Colors.amber,
        ),
      );

      final colors = resolveAudioProgressColors(theme);

      expect(colors.progress, Colors.blueGrey);
      expect(
        colors.thumb.computeLuminance(),
        greaterThan(colors.progress.computeLuminance()),
      );
      expect(colors.glow, Colors.transparent);
    });

    test('thumb lifts toward white for mid-luminance primaries', () {
      const primary = Color(0xFF2BA184);
      final lightTheme = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: Colors.deepPurple,
        ),
      );
      final darkTheme = ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: Colors.amber,
        ),
      );

      final lightColors = resolveAudioProgressColors(lightTheme);
      final darkColors = resolveAudioProgressColors(darkTheme);

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
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.yellow,
          secondary: Colors.deepPurple,
        ),
      );

      final colors = resolveAudioProgressColors(theme);

      expect(colors.progress, Colors.yellow);
      expect(
        colors.thumb.computeLuminance(),
        lessThan(colors.progress.computeLuminance()),
      );
    });
  });

  group('AudioProgressBar widget', () {
    late List<Duration> seekCalls;

    setUp(() {
      seekCalls = [];
    });

    Future<void> pumpProgressBar(
      WidgetTester tester, {
      Duration progress = Duration.zero,
      Duration buffered = Duration.zero,
      Duration total = const Duration(minutes: 5),
      bool enabled = true,
      bool compact = false,
      String? semanticLabel,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: AudioProgressBar(
                  progress: progress,
                  buffered: buffered,
                  total: total,
                  onSeek: seekCalls.add,
                  enabled: enabled,
                  compact: compact,
                  semanticLabel: semanticLabel,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders with zero progress', (WidgetTester tester) async {
      await pumpProgressBar(tester);
      expect(find.byType(AudioProgressBar), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('renders compact variant', (WidgetTester tester) async {
      await pumpProgressBar(tester, compact: true);

      final sizedBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(AudioProgressBar),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sizedBox.height, 32);
    });

    testWidgets('renders standard variant', (WidgetTester tester) async {
      await pumpProgressBar(tester);

      final sizedBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(AudioProgressBar),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sizedBox.height, 36);
    });

    testWidgets('displays correct progress and buffered values', (
      WidgetTester tester,
    ) async {
      await pumpProgressBar(
        tester,
        progress: const Duration(seconds: 30),
        buffered: const Duration(minutes: 2),
      );

      expect(find.byType(AudioProgressBar), findsOneWidget);
    });

    testWidgets('tapping seeks to position', (WidgetTester tester) async {
      await pumpProgressBar(
        tester,
        total: const Duration(seconds: 100),
      );

      final progressBar = find.byType(AudioProgressBar);
      final center = tester.getCenter(progressBar);

      await tester.tapAt(center);
      await tester.pump();

      expect(seekCalls.length, 1);
      // Tapping at center should seek to ~50 seconds
      expect(seekCalls.first.inSeconds, closeTo(50, 5));
    });

    testWidgets('tapping at start seeks to beginning', (
      WidgetTester tester,
    ) async {
      await pumpProgressBar(
        tester,
        total: const Duration(seconds: 100),
      );

      final progressBar = find.byType(AudioProgressBar);
      final rect = tester.getRect(progressBar);

      await tester.tapAt(rect.centerLeft);
      await tester.pump();

      expect(seekCalls.length, 1);
      expect(seekCalls.first.inSeconds, lessThan(5));
    });

    testWidgets('tapping at end seeks to near total', (
      WidgetTester tester,
    ) async {
      await pumpProgressBar(
        tester,
        total: const Duration(seconds: 100),
      );

      final progressBar = find.byType(AudioProgressBar);
      final rect = tester.getRect(progressBar);
      // Tap slightly inward from the right edge to avoid edge issues
      final tapPosition = Offset(rect.right - 5, rect.center.dy);

      await tester.tapAt(tapPosition);
      await tester.pump();

      expect(seekCalls.length, 1);
      expect(seekCalls.first.inSeconds, greaterThan(90));
    });

    testWidgets('does not seek when disabled', (WidgetTester tester) async {
      await pumpProgressBar(
        tester,
        total: const Duration(seconds: 100),
        enabled: false,
      );

      final progressBar = find.byType(AudioProgressBar);
      final center = tester.getCenter(progressBar);

      await tester.tapAt(center);
      await tester.pump();

      expect(seekCalls.length, 0);
    });

    testWidgets('does not seek when total is zero', (
      WidgetTester tester,
    ) async {
      await pumpProgressBar(
        tester,
        total: Duration.zero,
      );

      final progressBar = find.byType(AudioProgressBar);
      final center = tester.getCenter(progressBar);

      await tester.tapAt(center);
      await tester.pump();

      expect(seekCalls.length, 0);
    });

    testWidgets('dragging seeks during drag', (WidgetTester tester) async {
      await pumpProgressBar(
        tester,
        total: const Duration(seconds: 100),
      );

      final progressBar = find.byType(AudioProgressBar);
      final rect = tester.getRect(progressBar);

      // Start drag from left
      await tester.dragFrom(
        rect.centerLeft,
        Offset(rect.width / 2, 0),
      );
      await tester.pump();

      // Should have called seek at least once
      expect(seekCalls.isNotEmpty, true);
    });

    testWidgets('drag end flushes pending seek', (WidgetTester tester) async {
      await pumpProgressBar(
        tester,
        total: const Duration(seconds: 100),
      );

      final progressBar = find.byType(AudioProgressBar);
      final rect = tester.getRect(progressBar);

      final gesture = await tester.startGesture(rect.centerLeft);
      await tester.pump(const Duration(milliseconds: 10));

      await gesture.moveBy(Offset(rect.width / 4, 0));
      await tester.pump(const Duration(milliseconds: 10));

      final seekCountBeforeEnd = seekCalls.length;

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      // Should have flushed any pending seek on drag end
      expect(seekCalls.length, greaterThanOrEqualTo(seekCountBeforeEnd));
    });

    testWidgets('uses default semantic label', (WidgetTester tester) async {
      await pumpProgressBar(
        tester,
        progress: const Duration(seconds: 30),
        total: const Duration(minutes: 2),
      );

      expect(
        find.bySemanticsLabel(
          'Audio timeline',
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses custom semantic label', (WidgetTester tester) async {
      await pumpProgressBar(
        tester,
        progress: const Duration(seconds: 30),
        total: const Duration(minutes: 2),
        semanticLabel: 'Custom progress bar',
      );

      expect(
        find.bySemanticsLabel(
          'Custom progress bar',
        ),
        findsOneWidget,
      );
    });

    testWidgets('clamps progress ratio between 0 and 1', (
      WidgetTester tester,
    ) async {
      // Progress exceeds total
      await pumpProgressBar(
        tester,
        progress: const Duration(seconds: 200),
        total: const Duration(seconds: 100),
      );

      // Should render without errors
      expect(find.byType(AudioProgressBar), findsOneWidget);
    });

    testWidgets('clamps buffered ratio between 0 and 1', (
      WidgetTester tester,
    ) async {
      // Buffered exceeds total
      await pumpProgressBar(
        tester,
        buffered: const Duration(seconds: 200),
        total: const Duration(seconds: 100),
      );

      // Should render without errors
      expect(find.byType(AudioProgressBar), findsOneWidget);
    });

    testWidgets('handles zero width gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 0,
              child: AudioProgressBar(
                progress: const Duration(seconds: 30),
                buffered: const Duration(minutes: 1),
                total: const Duration(minutes: 5),
                onSeek: seekCalls.add,
                enabled: true,
                compact: false,
              ),
            ),
          ),
        ),
      );

      // Tap should not crash, should return Duration.zero
      final progressBar = find.byType(AudioProgressBar);
      await tester.tap(progressBar, warnIfMissed: false);
      await tester.pump();

      if (seekCalls.isNotEmpty) {
        expect(seekCalls.first, Duration.zero);
      }
    });

    testWidgets('gesture detector not present when disabled', (
      WidgetTester tester,
    ) async {
      await pumpProgressBar(
        tester,
        enabled: false,
      );

      // When disabled, there should be no GestureDetector with onTapDown
      final gestures = find.descendant(
        of: find.byType(AudioProgressBar),
        matching: find.byType(GestureDetector),
      );
      expect(gestures, findsNothing);
    });

    testWidgets('gesture detector not present when total is zero', (
      WidgetTester tester,
    ) async {
      await pumpProgressBar(
        tester,
        total: Duration.zero,
      );

      // When total is zero, there should be no GestureDetector
      final gestures = find.descendant(
        of: find.byType(AudioProgressBar),
        matching: find.byType(GestureDetector),
      );
      expect(gestures, findsNothing);
    });

    testWidgets('drag cancel cleans up state', (WidgetTester tester) async {
      await pumpProgressBar(
        tester,
        total: const Duration(seconds: 100),
      );

      final progressBar = find.byType(AudioProgressBar);
      final rect = tester.getRect(progressBar);

      final gesture = await tester.startGesture(rect.centerLeft);
      await gesture.moveBy(Offset(rect.width / 4, 0));
      await tester.pump(const Duration(milliseconds: 10));

      // Cancel the gesture
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 100));

      // Should not crash
      expect(find.byType(AudioProgressBar), findsOneWidget);
    });

    testWidgets(
      'throttle timer flushes the last pending seek after the delay',
      (WidgetTester tester) async {
        await pumpProgressBar(
          tester,
          total: const Duration(seconds: 100),
        );

        final progressBar = find.byType(AudioProgressBar);
        final rect = tester.getRect(progressBar);

        // Begin a horizontal drag near the left edge. The first move resolves
        // the gesture arena as a drag and fires onHorizontalDragStart, which
        // emits immediately because there is no prior invocation (recording
        // _lastSeekInvocation).
        final gesture = await tester.startGesture(rect.centerLeft);
        // Move past the touch slop (kTouchSlop ~= 18) so the horizontal drag is
        // recognised and onHorizontalDragStart fires.
        await gesture.moveBy(const Offset(40, 0));
        expect(seekCalls.length, 1);
        final immediateSeek = seekCalls.last;

        // A second update happens within the 60ms throttle window, so instead
        // of emitting immediately it stores a pending seek and arms the timer.
        await gesture.moveTo(Offset(rect.right - 5, rect.center.dy));
        expect(
          seekCalls.length,
          1,
          reason: 'second update should be throttled, not emitted',
        );

        // Advance time past the throttle delay WITHOUT ending the drag so the
        // pending seek is flushed by the timer callback itself.
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          seekCalls.length,
          2,
          reason: 'timer callback should emit the pending seek',
        );
        // The flushed seek targets the right edge (~end), clearly past the
        // initial left-edge seek.
        expect(
          seekCalls.last.inSeconds,
          greaterThan(immediateSeek.inSeconds + 80),
        );

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      'falls back to MediaQuery width when constraints are unbounded',
      (WidgetTester tester) async {
        // A horizontally-scrolling viewport hands the LayoutBuilder unbounded
        // width constraints, exercising the MediaQuery.sizeOf fallback path.
        const viewportWidth = 600.0;
        tester.view.physicalSize = const Size(viewportWidth, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: viewportWidth,
                  child: AudioProgressBar(
                    progress: Duration.zero,
                    buffered: Duration.zero,
                    total: const Duration(seconds: 100),
                    onSeek: seekCalls.add,
                    enabled: true,
                    compact: false,
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap near the centre of the visible viewport. Because width came from
        // MediaQuery (== viewportWidth), the centre maps to ~50% of total.
        await tester.tapAt(const Offset(viewportWidth / 2, 18));
        await tester.pump();

        expect(seekCalls.length, 1);
        expect(seekCalls.first.inSeconds, closeTo(50, 5));
      },
    );
  });
}
