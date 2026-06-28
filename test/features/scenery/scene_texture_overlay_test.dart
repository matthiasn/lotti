import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/scene_texture_overlay.dart';

const _w = 240;
const _h = 135;
const _base = Color(0xFF808080);

Future<Uint8List> _render(SceneTexturePainter painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
      Paint()..color = _base,
    );
  painter.paint(canvas, const Size(240, 135));
  final out = await recorder.endRecording().toImage(_w, _h);
  final bytes = (await out.toByteData())!.buffer.asUint8List();
  out.dispose();
  return bytes;
}

Color _at(Uint8List bytes, int x, int y) {
  final i = (y * _w + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}

int _changedPixels(Uint8List bytes, {required int startX, required int endX}) {
  var changed = 0;
  for (var y = 0; y < _h; y++) {
    for (var x = startX; x < endX; x++) {
      final c = _at(bytes, x, y);
      if (c != _base) changed++;
    }
  }
  return changed;
}

void main() {
  group('SceneTexturePainter', () {
    testWidgets('adds grain to both vertical side strips', (tester) async {
      await tester.runAsync(() async {
        final bytes = await _render(
          const SceneTexturePainter(vignetteStrength: 0, grainOpacity: 0.08),
        );

        expect(
          _changedPixels(bytes, startX: 0, endX: 32),
          greaterThan(8),
        );
        expect(
          _changedPixels(bytes, startX: _w - 32, endX: _w),
          greaterThan(8),
        );
      });
    });

    testWidgets('keeps the centre cleaner than the vignetted corners', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final bytes = await _render(
          const SceneTexturePainter(vignetteStrength: 0.18, grainOpacity: 0),
        );

        final centre = _at(bytes, _w ~/ 2, (_h * 0.43).round()).r;
        final corner = _at(bytes, _w - 1, _h - 1).r;
        expect(corner, lessThan(centre));
        expect(centre, closeTo(_base.r, 0.02));
      });
    });

    test('empty viewport is a no-op', () {
      final recorder = ui.PictureRecorder();
      expect(
        () => const SceneTexturePainter().paint(Canvas(recorder), Size.zero),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });
  });
}
