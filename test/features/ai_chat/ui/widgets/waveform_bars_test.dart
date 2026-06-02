import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';

/// Returns the *real* (private) `_WaveformBarsPainter` from the live
/// `CustomPaint` nested under the [WaveformBars] reachable via [finder].
///
/// Material adds unrelated `CustomPaint` widgets to the tree, so we filter on
/// the painter's runtime type. This lets the tests drive the production
/// `paint`/`shouldRepaint` implementations directly instead of re-implementing
/// them.
CustomPainter _painterUnder(WidgetTester tester, Finder finder) {
  return tester
      .widgetList<CustomPaint>(
        find.descendant(of: finder, matching: find.byType(CustomPaint)),
      )
      .map((cp) => cp.painter)
      .whereType<CustomPainter>()
      .firstWhere(
        (p) => p.runtimeType.toString() == '_WaveformBarsPainter',
        orElse: () => throw StateError('Waveform painter not found'),
      );
}

/// Pumps a single themed [WaveformBars] and returns its real painter.
Future<CustomPainter> _pumpAndCapturePainter(
  WidgetTester tester, {
  required List<double> amplitudes,
  double barWidth = 2,
  double barSpacing = 3,
  double minBarHeight = 2,
  Color primary = Colors.blue,
  Color secondary = Colors.green,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.light(primary: primary, secondary: secondary),
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: WaveformBars(
              amplitudesNormalized: amplitudes,
              barWidth: barWidth,
              barSpacing: barSpacing,
              minBarHeight: minBarHeight,
            ),
          ),
        ),
      ),
    ),
  );
  return _painterUnder(tester, find.byType(WaveformBars));
}

/// Pumps two [WaveformBars] (keys `a` and `b`) side by side, each wrapped in
/// its own [Theme]/config, and returns their real painters captured from a
/// single tree. Sequential `pumpWidget` calls reuse the same element and yield
/// stale painter references, so coexisting subtrees are used to compare two
/// independent painter instances reliably.
Future<(CustomPainter a, CustomPainter b)> _pumpPair(
  WidgetTester tester, {
  required _PainterConfig a,
  required _PainterConfig b,
}) async {
  Widget cell(Key key, _PainterConfig cfg) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.light(
          primary: cfg.primary,
          secondary: cfg.secondary,
        ),
      ),
      child: SizedBox(
        width: 300,
        child: WaveformBars(
          key: key,
          amplitudesNormalized: cfg.amplitudes,
          barWidth: cfg.barWidth,
          barSpacing: cfg.barSpacing,
          minBarHeight: cfg.minBarHeight,
        ),
      ),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [cell(const Key('a'), a), cell(const Key('b'), b)],
        ),
      ),
    ),
  );

  return (
    _painterUnder(tester, find.byKey(const Key('a'))),
    _painterUnder(tester, find.byKey(const Key('b'))),
  );
}

class _PainterConfig {
  const _PainterConfig({
    this.amplitudes = const [0.5, 0.7],
    this.barWidth = 2,
    this.barSpacing = 3,
    this.minBarHeight = 2,
    this.primary = Colors.blue,
    this.secondary = Colors.green,
  });

  final List<double> amplitudes;
  final double barWidth;
  final double barSpacing;
  final double minBarHeight;
  final Color primary;
  final Color secondary;

  _PainterConfig copyWith({
    List<double>? amplitudes,
    double? barWidth,
    double? barSpacing,
    double? minBarHeight,
    Color? primary,
    Color? secondary,
  }) {
    return _PainterConfig(
      amplitudes: amplitudes ?? this.amplitudes,
      barWidth: barWidth ?? this.barWidth,
      barSpacing: barSpacing ?? this.barSpacing,
      minBarHeight: minBarHeight ?? this.minBarHeight,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
    );
  }
}

void main() {
  group('WaveformBars widget', () {
    testWidgets('empty amplitudes build and paint without exception', (
      tester,
    ) async {
      final painter = await _pumpAndCapturePainter(
        tester,
        amplitudes: const [],
      );
      expect(tester.takeException(), isNull);

      // Painting an empty list must early-return without drawing/crashing.
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), const Size(300, 24));
      recorder.endRecording();
      expect(tester.takeException(), isNull);
    });

    testWidgets('CustomPaint size accounts for padding and border', (
      tester,
    ) async {
      await _pumpAndCapturePainter(tester, amplitudes: const [0.5, 0.7]);

      final waveformPaint = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(WaveformBars),
              matching: find.byType(CustomPaint),
            ),
          )
          .firstWhere(
            (cp) =>
                cp.painter?.runtimeType.toString() == '_WaveformBarsPainter',
          );

      // Container is 300 wide with 12px horizontal padding on each side and a
      // 1px border on each side: 300 - 24 - 2 = 274. Height is default 48 / 2.
      expect(waveformPaint.size, const Size(274, 24));
    });

    testWidgets('respects custom height on the rendered box', (tester) async {
      const customHeight = 100.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.5, 0.7],
                  height: customHeight,
                ),
              ),
            ),
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(
        find.byType(WaveformBars),
      );
      expect(renderBox.size.height, customHeight);
    });

    testWidgets('applies border radius, border and right alignment', (
      tester,
    ) async {
      const customBorderRadius = 12.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(dividerColor: Colors.grey),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.5],
                  borderRadius: customBorderRadius,
                ),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(WaveformBars),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      final radius = decoration.borderRadius! as BorderRadius;
      expect(radius.topLeft.x, customBorderRadius);
      expect(decoration.border, isNotNull);
      expect(container.alignment, Alignment.centerRight);
    });

    testWidgets('paints a large amplitude list without throwing', (
      tester,
    ) async {
      final amplitudes = List.generate(500, (i) => (i % 100) / 100.0);
      final painter = await _pumpAndCapturePainter(
        tester,
        amplitudes: amplitudes,
      );

      // Exercise the real paint loop (sublist clamping + easing + drawing).
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), const Size(274, 24));
      recorder.endRecording();
      expect(tester.takeException(), isNull);
    });

    testWidgets('clamps out-of-range amplitudes while painting', (
      tester,
    ) async {
      final painter = await _pumpAndCapturePainter(
        tester,
        amplitudes: const [-0.5, 0.5, 1.5],
      );

      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), const Size(274, 24));
      recorder.endRecording();
      expect(tester.takeException(), isNull);
    });
  });

  group('_WaveformBarsPainter.shouldRepaint (real implementation)', () {
    const baseline = _PainterConfig();

    // Each mutation differs from the baseline in exactly one input and must
    // make the real production shouldRepaint report that a repaint is needed.
    final mutations = <String, _PainterConfig>{
      'amplitudes value': baseline.copyWith(amplitudes: const [0.3, 0.9]),
      'amplitudes length': baseline.copyWith(amplitudes: const [0.5, 0.7, 0.9]),
      'primary color': baseline.copyWith(primary: Colors.red),
      'secondary color': baseline.copyWith(secondary: Colors.yellow),
      'barWidth': baseline.copyWith(barWidth: 4),
      'barSpacing': baseline.copyWith(barSpacing: 5),
      'minBarHeight': baseline.copyWith(minBarHeight: 4),
    };

    for (final entry in mutations.entries) {
      testWidgets('returns true when ${entry.key} changes', (tester) async {
        final (oldPainter, newPainter) = await _pumpPair(
          tester,
          a: baseline,
          b: entry.value,
        );

        expect(newPainter.shouldRepaint(oldPainter), isTrue);
      });
    }

    testWidgets(
      'returns true when a new amplitude list instance has equal values',
      (tester) async {
        // Distinct (non-canonicalized) list instances with identical contents
        // still trigger a repaint because the painter compares by reference.
        final (oldPainter, newPainter) = await _pumpPair(
          tester,
          a: _PainterConfig(amplitudes: List<double>.of(const [0.5, 0.7])),
          b: _PainterConfig(amplitudes: List<double>.of(const [0.5, 0.7])),
        );

        expect(newPainter.shouldRepaint(oldPainter), isTrue);
      },
    );

    testWidgets('returns false when every input is identical', (tester) async {
      // The default amplitudes are a const list literal canonicalized to a
      // single instance, and every scalar/color input matches, so no repaint
      // is required.
      final (oldPainter, newPainter) = await _pumpPair(
        tester,
        a: const _PainterConfig(),
        b: const _PainterConfig(),
      );

      expect(newPainter.shouldRepaint(oldPainter), isFalse);
    });
  });
}
