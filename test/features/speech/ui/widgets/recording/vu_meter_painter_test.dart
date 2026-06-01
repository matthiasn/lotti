import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/ui/widgets/recording/vu_meter_painter.dart';

// ---------------------------------------------------------------------------
// Helper: record a painter onto a real Canvas backed by PictureRecorder.
// ---------------------------------------------------------------------------
ui.Picture _recordPaint(
  VuMeterPainter painter, {
  Size size = const Size(350, 140),
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  return recorder.endRecording();
}

// ---------------------------------------------------------------------------
// _CountingCanvas — implements Canvas by delegating to an inner Canvas
// while counting drawCircle and drawLine calls.
// ---------------------------------------------------------------------------
class _CountingCanvas implements Canvas {
  _CountingCanvas(this._inner);

  final Canvas _inner;

  int drawCircleCount = 0;
  int drawLineCount = 0;

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    drawCircleCount++;
    _inner.drawCircle(c, radius, paint);
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    drawLineCount++;
    _inner.drawLine(p1, p2, paint);
  }

  // Full Canvas delegation ------------------------------------------------
  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) =>
      _inner.clipPath(path, doAntiAlias: doAntiAlias);
  @override
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) =>
      _inner.clipRRect(rrect, doAntiAlias: doAntiAlias);
  @override
  void clipRect(
    ui.Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => _inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  @override
  void clipRSuperellipse(
    ui.RSuperellipse rsuperellipse, {
    bool doAntiAlias = true,
  }) => _inner.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);
  @override
  void drawArc(
    ui.Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) => _inner.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  @override
  void drawAtlas(
    ui.Image atlas,
    List<ui.RSTransform> transforms,
    List<ui.Rect> rects,
    List<ui.Color>? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    Paint paint,
  ) => _inner.drawAtlas(
    atlas,
    transforms,
    rects,
    colors,
    blendMode,
    cullRect,
    paint,
  );
  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) =>
      _inner.drawColor(color, blendMode);
  @override
  void drawDRRect(ui.RRect outer, ui.RRect inner, Paint paint) =>
      _inner.drawDRRect(outer, inner, paint);
  @override
  void drawImage(ui.Image image, ui.Offset offset, Paint paint) =>
      _inner.drawImage(image, offset, paint);
  @override
  void drawImageNine(
    ui.Image image,
    ui.Rect center,
    ui.Rect dst,
    Paint paint,
  ) => _inner.drawImageNine(image, center, dst, paint);
  @override
  void drawImageRect(
    ui.Image image,
    ui.Rect src,
    ui.Rect dst,
    Paint paint,
  ) => _inner.drawImageRect(image, src, dst, paint);
  @override
  void drawOval(ui.Rect rect, Paint paint) => _inner.drawOval(rect, paint);
  @override
  void drawPaint(Paint paint) => _inner.drawPaint(paint);
  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) =>
      _inner.drawParagraph(paragraph, offset);
  @override
  void drawPath(ui.Path path, Paint paint) => _inner.drawPath(path, paint);
  @override
  void drawPicture(ui.Picture picture) => _inner.drawPicture(picture);
  @override
  void drawPoints(
    ui.PointMode pointMode,
    List<ui.Offset> points,
    Paint paint,
  ) => _inner.drawPoints(pointMode, points, paint);
  @override
  void drawRRect(ui.RRect rrect, Paint paint) => _inner.drawRRect(rrect, paint);
  @override
  void drawRSuperellipse(ui.RSuperellipse rsuperellipse, Paint paint) =>
      _inner.drawRSuperellipse(rsuperellipse, paint);
  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    Paint paint,
  ) => _inner.drawRawAtlas(
    atlas,
    rstTransforms,
    rects,
    colors,
    blendMode,
    cullRect,
    paint,
  );
  @override
  void drawRawPoints(
    ui.PointMode pointMode,
    Float32List points,
    Paint paint,
  ) => _inner.drawRawPoints(pointMode, points, paint);
  @override
  void drawRect(ui.Rect rect, Paint paint) => _inner.drawRect(rect, paint);
  @override
  void drawShadow(
    ui.Path path,
    ui.Color color,
    double elevation,
    bool transparentOccluder,
  ) => _inner.drawShadow(path, color, elevation, transparentOccluder);
  @override
  void drawVertices(
    ui.Vertices vertices,
    ui.BlendMode blendMode,
    Paint paint,
  ) => _inner.drawVertices(vertices, blendMode, paint);
  @override
  ui.Rect getDestinationClipBounds() => _inner.getDestinationClipBounds();
  @override
  ui.Rect getLocalClipBounds() => _inner.getLocalClipBounds();
  @override
  int getSaveCount() => _inner.getSaveCount();
  @override
  Float64List getTransform() => _inner.getTransform();
  @override
  void restore() => _inner.restore();
  @override
  void restoreToCount(int count) => _inner.restoreToCount(count);
  @override
  void rotate(double radians) => _inner.rotate(radians);
  @override
  void save() => _inner.save();
  @override
  void saveLayer(ui.Rect? bounds, Paint paint) =>
      _inner.saveLayer(bounds, paint);
  @override
  void scale(double sx, [double? sy]) => _inner.scale(sx, sy);
  @override
  void skew(double sx, double sy) => _inner.skew(sx, sy);
  @override
  void transform(Float64List matrix4) => _inner.transform(matrix4);
  @override
  void translate(double dx, double dy) => _inner.translate(dx, dy);
}

_CountingCanvas _makeCountingCanvas() {
  final recorder = ui.PictureRecorder();
  final inner = Canvas(recorder);
  return _CountingCanvas(inner);
}

// ---------------------------------------------------------------------------
// Shared painter factory used across tests.
// ---------------------------------------------------------------------------
VuMeterPainter _painter({
  double value = 0.5,
  double peakValue = 0,
  double clipValue = 0,
  bool isDarkMode = false,
  ColorScheme colorScheme = const ColorScheme.light(),
}) => VuMeterPainter(
  value: value,
  peakValue: peakValue,
  clipValue: clipValue,
  isDarkMode: isDarkMode,
  colorScheme: colorScheme,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const defaultSize = Size(350, 140);

  // -------------------------------------------------------------------------
  // shouldRepaint — covers every comparison branch
  // -------------------------------------------------------------------------
  group('VuMeterPainter.shouldRepaint', () {
    test('returns true when value changes', () {
      final p1 = _painter(value: 0.3);
      final p2 = _painter(value: 0.7);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('returns true when peakValue changes', () {
      final p1 = _painter(peakValue: 0.3);
      final p2 = _painter(peakValue: 0.8);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('returns true when clipValue changes from 0 to positive', () {
      final p1 = _painter();
      final p2 = _painter(clipValue: 0.9);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('returns true when clipValue changes between two positive values', () {
      final p1 = _painter(clipValue: 0.4);
      final p2 = _painter(clipValue: 0.8);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('returns true when isDarkMode changes', () {
      // ignore: avoid_redundant_argument_values
      final p1 = _painter(isDarkMode: false);
      final p2 = _painter(isDarkMode: true);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('returns false when all observed values are identical', () {
      final p1 = _painter();
      final p2 = _painter();
      expect(p1.shouldRepaint(p2), isFalse);
    });

    test('colorScheme change alone does not trigger repaint', () {
      // colorScheme is intentionally absent from shouldRepaint — document it.
      final p1 = _painter();
      final p2 = _painter(colorScheme: const ColorScheme.dark());
      expect(p1.shouldRepaint(p2), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // paint() — clip-LED branch (uncovered lines 360-401 in the source)
  // -------------------------------------------------------------------------
  group('VuMeterPainter.paint — clip indicator branch', () {
    test('clip-lit path draws exactly 4 more circles than clip-off path', () {
      final noClipCanvas = _makeCountingCanvas();
      _painter().paint(noClipCanvas, defaultSize);

      final withClipCanvas = _makeCountingCanvas();
      _painter(clipValue: 1).paint(withClipCanvas, defaultSize);

      // `if (clipValue > 0)` block adds: outer glow, medium glow,
      // LED body with radial gradient, bright white center — exactly 4 circles.
      expect(
        withClipCanvas.drawCircleCount - noClipCanvas.drawCircleCount,
        4,
        reason: 'clipValue > 0 should add exactly 4 extra drawCircle calls',
      );
    });

    test(
      'partial clip value (0 < clipValue < 1) also enters the glow branch',
      () {
        final noClipCanvas = _makeCountingCanvas();
        _painter(value: 0.3).paint(noClipCanvas, defaultSize);

        final partialClipCanvas = _makeCountingCanvas();
        _painter(
          value: 0.3,
          clipValue: 0.3,
        ).paint(partialClipCanvas, defaultSize);

        expect(
          partialClipCanvas.drawCircleCount - noClipCanvas.drawCircleCount,
          4,
          reason:
              'Any clipValue > 0 should add the same 4 glow drawCircle calls',
        );
      },
    );

    test(
      'clip LED lit in dark mode — paints without error',
      () {
        expect(
          () => _recordPaint(
            _painter(
              value: 0.8,
              clipValue: 1,
              isDarkMode: true,
              colorScheme: const ColorScheme.dark(),
            ),
          ),
          returnsNormally,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // paint() — peak indicator branch (source line 59)
  // -------------------------------------------------------------------------
  group('VuMeterPainter.paint — peak indicator branch', () {
    test(
      'peak-active path draws exactly 1 more line than peak-inactive path',
      () {
        final noPeakCanvas = _makeCountingCanvas();
        _painter().paint(noPeakCanvas, defaultSize);

        final withPeakCanvas = _makeCountingCanvas();
        _painter(peakValue: 0.7).paint(withPeakCanvas, defaultSize);

        // _drawPeakIndicator calls drawLine exactly once.
        expect(
          withPeakCanvas.drawLineCount - noPeakCanvas.drawLineCount,
          1,
          reason: '_drawPeakIndicator should add exactly 1 drawLine call',
        );
      },
    );

    test('peak indicator in dark mode paints without error', () {
      expect(
        () => _recordPaint(
          _painter(
            value: 0.4,
            peakValue: 0.9,
            isDarkMode: true,
            colorScheme: const ColorScheme.dark(),
          ),
        ),
        returnsNormally,
      );
    });
  });

  // -------------------------------------------------------------------------
  // paint() — clip and peak active simultaneously
  // -------------------------------------------------------------------------
  group('VuMeterPainter.paint — clip and peak combined', () {
    test('both branches active — paint completes without error', () {
      expect(
        () => _recordPaint(
          _painter(value: 0.9, peakValue: 0.95, clipValue: 0.8),
        ),
        returnsNormally,
      );
    });

    test(
      'dark mode with both branches — draw counts reflect both branches',
      () {
        final baselineCanvas = _makeCountingCanvas();
        _painter(
          isDarkMode: true,
          colorScheme: const ColorScheme.dark(),
        ).paint(baselineCanvas, defaultSize);

        final fullCanvas = _makeCountingCanvas();
        _painter(
          peakValue: 0.6,
          clipValue: 0.7,
          isDarkMode: true,
          colorScheme: const ColorScheme.dark(),
        ).paint(fullCanvas, defaultSize);

        // 4 extra circles from clip branch.
        expect(
          fullCanvas.drawCircleCount - baselineCanvas.drawCircleCount,
          4,
          reason: 'clip branch adds 4 circles even when peak is also active',
        );
        // 1 extra line from peak branch.
        expect(
          fullCanvas.drawLineCount - baselineCanvas.drawLineCount,
          1,
          reason: 'peak branch adds 1 line even when clip is also active',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // paint() — edge sizes
  // -------------------------------------------------------------------------
  group('VuMeterPainter.paint — edge cases', () {
    test('paints on wide canvas without error', () {
      expect(
        () => _recordPaint(
          _painter(peakValue: 0.5, clipValue: 0.5),
          size: const Size(700, 100),
        ),
        returnsNormally,
      );
    });

    test('paints on tall canvas without error', () {
      expect(
        () => _recordPaint(
          _painter(peakValue: 0.5, clipValue: 0.5),
          size: const Size(200, 400),
        ),
        returnsNormally,
      );
    });

    test('paints at minimum values without error', () {
      expect(
        () => _recordPaint(_painter()),
        returnsNormally,
      );
    });

    test('paints at maximum values without error', () {
      expect(
        () => _recordPaint(_painter(value: 1, peakValue: 1, clipValue: 1)),
        returnsNormally,
      );
    });
  });
}
