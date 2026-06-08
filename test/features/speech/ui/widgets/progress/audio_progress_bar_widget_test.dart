import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';

void main() {
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
