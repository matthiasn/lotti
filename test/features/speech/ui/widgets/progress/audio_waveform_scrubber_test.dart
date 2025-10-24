import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_waveform_scrubber.dart';

import '../../../../../widget_test_utils.dart';

Widget _buildHarness({
  required List<double> amplitudes,
  Duration progress = Duration.zero,
  Duration buffered = Duration.zero,
  Duration total = const Duration(seconds: 120),
  bool enabled = true,
  bool compact = false,
  double width = 240,
  ValueChanged<Duration>? onSeek,
  bool constrained = true,
}) {
  final scrubber = AudioWaveformScrubber(
    amplitudes: amplitudes,
    progress: progress,
    buffered: buffered,
    total: total,
    onSeek: onSeek ?? (_) {},
    enabled: enabled,
    compact: compact,
  );

  if (constrained) {
    return makeTestableWidgetWithScaffold(
      Center(
        child: SizedBox(
          width: width,
          child: scrubber,
        ),
      ),
    );
  }

  return makeTestableWidgetNoScroll(
    Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: scrubber,
        ),
      ),
    ),
  );
}

Finder _scrubberFinder() => find.byType(AudioWaveformScrubber);
Finder _gestureFinder() => find.byType(GestureDetector);

Rect _scrubberRect(WidgetTester tester) => tester.getRect(_scrubberFinder());

Offset _pointForRatio(WidgetTester tester, double ratio) {
  final rect = _scrubberRect(tester);
  return Offset(rect.left + rect.width * ratio, rect.top + rect.height / 2);
}

Offset _localPointForRatio(WidgetTester tester, double ratio) {
  final rect = _scrubberRect(tester);
  return Offset(rect.width * ratio, rect.height / 2);
}

GestureDetector _getGestureDetector(WidgetTester tester) {
  return tester.widget<GestureDetector>(_gestureFinder());
}

CustomPaint _findWaveformPaint(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  return paints.firstWhere(
    (paint) =>
        paint.painter != null &&
        paint.painter.runtimeType.toString().contains('Waveform'),
  );
}

Future<void> _pumpScrubber(
  WidgetTester tester, {
  required List<double> amplitudes,
  Duration progress = Duration.zero,
  Duration buffered = Duration.zero,
  Duration total = const Duration(seconds: 120),
  bool enabled = true,
  bool compact = false,
  double width = 240,
  ValueChanged<Duration>? onSeek,
  bool constrained = true,
}) async {
  await tester.pumpWidget(
    _buildHarness(
      amplitudes: amplitudes,
      progress: progress,
      buffered: buffered,
      total: total,
      enabled: enabled,
      compact: compact,
      width: width,
      onSeek: onSeek,
      constrained: constrained,
    ),
  );
  await tester.pumpAndSettle();
}

Future<CustomPainter> _pumpAndGetPainter(
  WidgetTester tester, {
  required List<double> amplitudes,
  Duration progress = Duration.zero,
  Duration buffered = Duration.zero,
  Duration total = const Duration(seconds: 120),
  bool compact = false,
  double width = 240,
}) async {
  await _pumpScrubber(
    tester,
    amplitudes: amplitudes,
    progress: progress,
    buffered: buffered,
    total: total,
    compact: compact,
    width: width,
  );

  final paint = _findWaveformPaint(tester);
  final painter = paint.painter;
  expect(painter, isNotNull);
  return painter!;
}

void main() {
  group('AudioWaveformScrubber interactions', () {
    testWidgets('tap triggers immediate seek', (tester) async {
      final seeks = <Duration>[];
      await _pumpScrubber(
        tester,
        amplitudes: List<double>.filled(32, 0.5),
        onSeek: seeks.add,
      );

      final detector = _getGestureDetector(tester);
      detector.onTapDown?.call(
        TapDownDetails(
          localPosition: _localPointForRatio(tester, 0.25),
          globalPosition: _pointForRatio(tester, 0.25),
        ),
      );
      await tester.pump();

      expect(seeks, [const Duration(seconds: 30)]);
    });

    testWidgets('drag triggers throttled seek every 60ms', (tester) async {
      final seeks = <Duration>[];
      await _pumpScrubber(
        tester,
        amplitudes: List<double>.filled(48, 0.4),
        total: const Duration(seconds: 100),
        onSeek: seeks.add,
      );

      final detector = _getGestureDetector(tester);
      detector.onHorizontalDragStart?.call(
        DragStartDetails(
          localPosition: _localPointForRatio(tester, 0.1),
          globalPosition: _pointForRatio(tester, 0.1),
        ),
      );
      detector.onHorizontalDragUpdate?.call(
        DragUpdateDetails(
          localPosition: _localPointForRatio(tester, 0.3),
          globalPosition: _pointForRatio(tester, 0.3),
        ),
      );
      await tester.pump();
      expect(seeks, [const Duration(seconds: 30)]);

      detector.onHorizontalDragUpdate?.call(
        DragUpdateDetails(
          localPosition: _localPointForRatio(tester, 0.5),
          globalPosition: _pointForRatio(tester, 0.5),
        ),
      );
      await tester.pump();
      expect(seeks.length, 1);

      await tester.pump(const Duration(milliseconds: 59));
      expect(seeks.length, 1);

      await tester.pump(const Duration(milliseconds: 1));
      expect(seeks.length, 2);
      expect(seeks.last, const Duration(seconds: 50));

      detector.onHorizontalDragEnd?.call(DragEndDetails());
      await tester.pump();
    });

    testWidgets('drag end emits pending seek immediately', (tester) async {
      final seeks = <Duration>[];
      await _pumpScrubber(
        tester,
        amplitudes: List<double>.filled(40, 0.6),
        total: const Duration(seconds: 90),
        onSeek: seeks.add,
      );

      final detector = _getGestureDetector(tester);
      detector.onHorizontalDragStart?.call(
        DragStartDetails(
          localPosition: _localPointForRatio(tester, 0.2),
          globalPosition: _pointForRatio(tester, 0.2),
        ),
      );
      detector.onHorizontalDragUpdate?.call(
        DragUpdateDetails(
          localPosition: _localPointForRatio(tester, 0.4),
          globalPosition: _pointForRatio(tester, 0.4),
        ),
      );
      await tester.pump();
      expect(seeks, [const Duration(seconds: 36)]);

      detector.onHorizontalDragUpdate?.call(
        DragUpdateDetails(
          localPosition: _localPointForRatio(tester, 0.7),
          globalPosition: _pointForRatio(tester, 0.7),
        ),
      );
      await tester.pump();
      expect(seeks.length, 1);

      detector.onHorizontalDragEnd?.call(DragEndDetails());
      await tester.pump();
      expect(seeks.length, 2);
      expect(seeks.last, const Duration(seconds: 63));
    });

    testWidgets('rapid drags remain throttled to trailing seek',
        (tester) async {
      final seeks = <Duration>[];
      await _pumpScrubber(
        tester,
        amplitudes: List<double>.filled(60, 0.5),
        total: const Duration(seconds: 80),
        onSeek: seeks.add,
      );

      final detector = _getGestureDetector(tester);
      detector.onHorizontalDragStart?.call(
        DragStartDetails(
          localPosition: _localPointForRatio(tester, 0.1),
          globalPosition: _pointForRatio(tester, 0.1),
        ),
      );
      detector.onHorizontalDragUpdate?.call(
        DragUpdateDetails(
          localPosition: _localPointForRatio(tester, 0.2),
          globalPosition: _pointForRatio(tester, 0.2),
        ),
      );
      await tester.pump();
      expect(seeks, [const Duration(seconds: 16)]);

      for (final ratio in <double>[0.35, 0.55, 0.8]) {
        detector.onHorizontalDragUpdate?.call(
          DragUpdateDetails(
            localPosition: _localPointForRatio(tester, ratio),
            globalPosition: _pointForRatio(tester, ratio),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(seeks.length, 1);

      await tester.pump(const Duration(milliseconds: 60));
      expect(seeks.length, 2);
      expect(seeks.last, const Duration(seconds: 64));

      detector.onHorizontalDragEnd?.call(DragEndDetails());
      await tester.pump();
    });

    testWidgets('disabled state prevents seeking', (tester) async {
      final seeks = <Duration>[];
      await _pumpScrubber(
        tester,
        amplitudes: List<double>.filled(24, 0.5),
        total: const Duration(seconds: 70),
        enabled: false,
        onSeek: seeks.add,
      );

      expect(_gestureFinder(), findsNothing);
      await tester.tapAt(_pointForRatio(tester, 0.5));
      await tester.pump();
      await tester.dragFrom(
        _pointForRatio(tester, 0.2),
        const Offset(100, 0),
      );
      await tester.pump();

      expect(seeks, isEmpty);
    });

    testWidgets('zero total duration disables interaction', (tester) async {
      final seeks = <Duration>[];
      await _pumpScrubber(
        tester,
        amplitudes: List<double>.filled(24, 0.5),
        total: Duration.zero,
        onSeek: seeks.add,
      );

      expect(_gestureFinder(), findsNothing);
      await tester.tapAt(_pointForRatio(tester, 0.6));
      await tester.pump();
      await tester.dragFrom(
        _pointForRatio(tester, 0.4),
        const Offset(120, 0),
      );
      await tester.pump();

      expect(seeks, isEmpty);
    });

    testWidgets('semantics expose labels and hints', (tester) async {
      final handle = tester.ensureSemantics();
      final seeks = <Duration>[];
      try {
        await _pumpScrubber(
          tester,
          amplitudes: List<double>.filled(32, 0.5),
          progress: const Duration(seconds: 15),
          total: const Duration(seconds: 45),
          onSeek: seeks.add,
        );

        final semanticsFinder = find.bySemanticsLabel('Audio waveform');
        expect(semanticsFinder, findsOneWidget);

        final node = tester.getSemantics(semanticsFinder);
        final data = node.getSemanticsData();
        expect(data.value, '00:15 of 00:45');
        expect(data.hint, 'Tap to seek, drag to scrub');
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('handles empty amplitudes safely', (tester) async {
      final seeks = <Duration>[];
      await _pumpScrubber(
        tester,
        amplitudes: const <double>[],
        total: const Duration(seconds: 30),
        onSeek: seeks.add,
      );

      expect(find.byType(AudioWaveformScrubber), findsOneWidget);
      expect(() => _findWaveformPaint(tester), returnsNormally);

      final detector = _getGestureDetector(tester);
      detector.onTapDown?.call(
        TapDownDetails(
          localPosition: _localPointForRatio(tester, 0.3),
          globalPosition: _pointForRatio(tester, 0.3),
        ),
      );
      await tester.pump();
      expect(seeks.length, 1);
      expect(seeks.first, isA<Duration>());
    });
  });

  group('AudioWaveformScrubber painter', () {
    testWidgets('exposes empty amplitude list without painting',
        (tester) async {
      final painter = await _pumpAndGetPainter(
        tester,
        amplitudes: const <double>[],
      );
      expect((painter as dynamic).amplitudes, isEmpty);
    });

    testWidgets('exposes single amplitude entry', (tester) async {
      final painter = await _pumpAndGetPainter(
        tester,
        amplitudes: const <double>[0.8],
      );
      expect((painter as dynamic).amplitudes, [0.8]);
    });

    testWidgets('clamps progress ratio above 1.0', (tester) async {
      final painter = await _pumpAndGetPainter(
        tester,
        amplitudes: List<double>.filled(8, 0.4),
        progress: const Duration(seconds: 12),
        total: const Duration(seconds: 6),
      );
      expect((painter as dynamic).progressRatio, 1.0);
    });

    testWidgets('clamps buffered ratio above 1.0', (tester) async {
      final painter = await _pumpAndGetPainter(
        tester,
        amplitudes: List<double>.filled(8, 0.4),
        progress: const Duration(seconds: 2),
        buffered: const Duration(seconds: 12),
        total: const Duration(seconds: 6),
      );
      expect((painter as dynamic).bufferedRatio, 1.0);
    });

    testWidgets('clamps negative durations to zero ratios', (tester) async {
      final painter = await _pumpAndGetPainter(
        tester,
        amplitudes: List<double>.filled(8, 0.4),
        progress: const Duration(seconds: -5),
        buffered: const Duration(seconds: -3),
        total: const Duration(seconds: 20),
      );
      expect((painter as dynamic).progressRatio, 0.0);
      expect((painter as dynamic).bufferedRatio, 0.0);
    });

    testWidgets('renders with zero width constraints', (tester) async {
      await _pumpScrubber(
        tester,
        amplitudes: List<double>.filled(4, 0.5),
        width: 0,
      );
      expect(tester.takeException(), isNull);
      final rect = _scrubberRect(tester);
      expect(rect.width, 0);
    });

    testWidgets('renders with very wide constraints', (tester) async {
      await _pumpScrubber(
        tester,
        amplitudes: List<double>.filled(4, 0.5),
        width: 2400,
        constrained: false,
      );
      expect(tester.takeException(), isNull);
      final rect = _scrubberRect(tester);
      expect(rect.width, closeTo(2400, 0.001));
    });

    testWidgets('shouldRepaint returns true when amplitudes change',
        (tester) async {
      await _pumpScrubber(
        tester,
        amplitudes: <double>[0.2, 0.4],
      );
      final firstPainter = _findWaveformPaint(tester).painter!;

      await _pumpScrubber(
        tester,
        amplitudes: <double>[0.1, 0.9],
      );
      final secondPainter = _findWaveformPaint(tester).painter!;

      expect(secondPainter.shouldRepaint(firstPainter), isTrue);
    });

    testWidgets('shouldRepaint returns false when values are identical',
        (tester) async {
      final shared = <double>[0.3, 0.6];
      await _pumpScrubber(
        tester,
        amplitudes: shared,
      );
      final firstPainter = _findWaveformPaint(tester).painter!;

      await _pumpScrubber(
        tester,
        amplitudes: shared,
      );
      final secondPainter = _findWaveformPaint(tester).painter!;

      expect(secondPainter.shouldRepaint(firstPainter), isFalse);
    });
  });
}
