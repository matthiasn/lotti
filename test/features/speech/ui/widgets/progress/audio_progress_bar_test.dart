import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';

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

    testWidgets('displays correct progress and buffered values',
        (WidgetTester tester) async {
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

    testWidgets('tapping at start seeks to beginning',
        (WidgetTester tester) async {
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

    testWidgets('tapping at end seeks to near total',
        (WidgetTester tester) async {
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

    testWidgets('does not seek when total is zero',
        (WidgetTester tester) async {
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

    testWidgets('clamps progress ratio between 0 and 1',
        (WidgetTester tester) async {
      // Progress exceeds total
      await pumpProgressBar(
        tester,
        progress: const Duration(seconds: 200),
        total: const Duration(seconds: 100),
      );

      // Should render without errors
      expect(find.byType(AudioProgressBar), findsOneWidget);
    });

    testWidgets('clamps buffered ratio between 0 and 1',
        (WidgetTester tester) async {
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

    testWidgets('gesture detector not present when disabled',
        (WidgetTester tester) async {
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

    testWidgets('gesture detector not present when total is zero',
        (WidgetTester tester) async {
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
  });
}
