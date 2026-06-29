import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/atmospheric_haze_layer.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';

// 16:9 to match the scenery art aspect exactly, so the cover-fit is identity and
// the normalized waterline maps straight to a screen row (art-y * _h).
const _w = 160;
const _h = 90;

// Screen rows of interest derived from the manifest waterline + the layer's
// default reaches (skyReach 0.18, waterReach 0.12). The band hugs the waterline
// and reaches further UP (onto the distant bases) than DOWN (off the water).
final int _waterRow = (kPlaceholderSkylineManifest.waterline * _h).round();
final int _skyRow =
    (_waterRow - 0.18 * _h).round() - 4; // clear sky, above band
final int _deckRow = (_waterRow + 0.12 * _h).round() + 4; // clear near water

// Paint the haze over solid black so the cool lift it adds is directly readable
// as surviving luminance.
Future<Uint8List> _renderOverBlack(AtmosphericHazeLayer layer) async {
  final ctx = BackdropContext(
    size: Size(_w.toDouble(), _h.toDouble()),
    timeSeconds: 0,
    palette: kBlueHourPalette,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
      Paint()..color = const Color(0xFF000000),
    );
  layer.paint(canvas, ctx);
  final out = await recorder.endRecording().toImage(_w, _h);
  final bytes = (await out.toByteData())!.buffer.asUint8List();
  out.dispose();
  return bytes;
}

Color _at(Uint8List bytes, int x, int y) {
  final i = (y * _w + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}

double _lum(Color c) => c.r + c.g + c.b;

void main() {
  group('AtmosphericHazeLayer', () {
    testWidgets('peaks on the waterline and clears the open sky + near water', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final bytes = await _renderOverBlack(const AtmosphericHazeLayer());
        const x = _w ~/ 2;
        final water = _at(bytes, x, _waterRow);
        final sky = _at(bytes, x, _skyRow);
        final deck = _at(bytes, x, _deckRow);

        // The veil lifts the waterline band off black...
        expect(_lum(water), greaterThan(0.05));
        // ...while the open sky above and the near water below stay clear (the
        // foreground deck, drawn after this layer, keeps full contrast).
        expect(
          _lum(sky),
          lessThan(0.01),
          reason: 'sky above the band is clear',
        );
        expect(
          _lum(deck),
          lessThan(0.01),
          reason: 'near water below the band is clear',
        );
        // The lift is brightest ON the waterline, not partway up or down it.
        expect(
          _lum(water),
          greaterThan(_lum(_at(bytes, x, (_waterRow + _deckRow) ~/ 2))),
        );
      });
    });

    testWidgets('the haze reads as cool twilight air (blue over red)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final bytes = await _renderOverBlack(const AtmosphericHazeLayer());
        final water = _at(bytes, _w ~/ 2, _waterRow);
        // Cool air-light: blue dominates red, green sits between (teal-slate).
        expect(water.b, greaterThan(water.r));
        expect(water.g, greaterThan(water.r));
      });
    });

    testWidgets('stronger haze lifts the waterline further', (tester) async {
      await tester.runAsync(() async {
        final soft = await _renderOverBlack(
          const AtmosphericHazeLayer(strength: 0.1),
        );
        final hard = await _renderOverBlack(
          const AtmosphericHazeLayer(strength: 0.35),
        );
        expect(
          _lum(_at(hard, _w ~/ 2, _waterRow)),
          greaterThan(_lum(_at(soft, _w ~/ 2, _waterRow))),
        );
      });
    });

    testWidgets('zero strength is a no-op', (tester) async {
      await tester.runAsync(() async {
        final bytes = await _renderOverBlack(
          const AtmosphericHazeLayer(strength: 0),
        );
        expect(_lum(_at(bytes, _w ~/ 2, _waterRow)), lessThan(0.01));
      });
    });

    testWidgets('coolMix steers the veil from warm-grey toward horizon cyan', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // At coolMix 0 the veil is the raw warm-grey smog; at 1 it is the cool
        // horizon tone — so the blue:red ratio must climb with coolMix.
        final warm = await _renderOverBlack(
          const AtmosphericHazeLayer(coolMix: 0),
        );
        final cool = await _renderOverBlack(
          const AtmosphericHazeLayer(coolMix: 1),
        );
        double blueBias(Uint8List b) {
          final c = _at(b, _w ~/ 2, _waterRow);
          return c.b - c.r;
        }

        expect(blueBias(cool), greaterThan(blueBias(warm)));
      });
    });
  });
}
