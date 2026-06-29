import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/bridge_police_layer.dart';
import 'package:lotti/features/scenery/layers/drone_show_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

/// Renders the cordon to an [w]x[h] RGBA buffer at [timeSeconds].
Future<Uint8List> _render(
  double timeSeconds, {
  int w = 640,
  int h = 360,
  bool reducedMotion = false,
}) async {
  final recorder = ui.PictureRecorder();
  const BridgePoliceLayer().paint(
    Canvas(recorder),
    BackdropContext(
      size: ui.Size(w.toDouble(), h.toDouble()),
      timeSeconds: timeSeconds,
      palette: kBlueHourPalette,
      reducedMotion: reducedMotion,
    ),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  group('trafficStopIntensity', () {
    test('holds full from before launch through the on-road hold', () {
      // Launch instant is cycleProgress 0; the drones sit on the road until
      // ~0.03, so the cordon must be at full across that window (and just
      // before it, across the loop wrap).
      expect(trafficStopIntensity(0), 1.0);
      expect(trafficStopIntensity(0.02), 1.0);
      expect(trafficStopIntensity(0.96), 1.0); // d = -0.04, still full
    });

    test('is dark once the drones have lifted into the sky', () {
      // Beam/fan/formation all sit past cycleProgress 0.12, so the road must be
      // dark there — the lights disappear when the drones have lifted.
      expect(trafficStopIntensity(0.13), 0.0);
      expect(trafficStopIntensity(0.3), 0.0);
      expect(trafficStopIntensity(0.45), 0.0);
      expect(trafficStopIntensity(0.5), 0.0);
    });

    test('rolls in toward launch and clears out as the drones climb', () {
      // Rolling in (late previous loop): brighter the closer to launch.
      final rollEarly = trafficStopIntensity(0.82);
      final rollLate = trafficStopIntensity(0.88);
      expect(rollEarly, inExclusiveRange(0, 1));
      expect(rollLate, inExclusiveRange(0, 1));
      expect(rollLate, greaterThan(rollEarly));

      // Clearing out (drones climbing): dimmer the further from launch.
      final clearEarly = trafficStopIntensity(0.06);
      final clearLate = trafficStopIntensity(0.10);
      expect(clearEarly, inExclusiveRange(0, 1));
      expect(clearLate, inExclusiveRange(0, 1));
      expect(clearEarly, greaterThan(clearLate));
    });

    test('stays within 0..1 across the whole loop', () {
      for (var i = 0; i <= 100; i++) {
        final v = trafficStopIntensity(i / 100);
        expect(v, inInclusiveRange(0, 1), reason: 'cycleProgress ${i / 100}');
      }
    });
  });

  group('policeStrobe', () {
    test('pegs to full during a flash and rests on the dim floor', () {
      expect(policeStrobe(0, 0), 1.0); // first flash window
      expect(policeStrobe(0.07, 0), 0.3); // in the gap after the first flash
    });

    test('never goes dark and never exceeds full', () {
      for (var i = 0; i <= 180; i++) {
        final v = policeStrobe(i / 100, 0);
        expect(v, inInclusiveRange(0.3, 1.0), reason: 't ${i / 100}');
      }
    });

    test('is periodic over the 0.9 s cycle', () {
      for (final t in const [0.0, 0.12, 0.31, 0.55, 0.8]) {
        expect(policeStrobe(t, 0), policeStrobe(t + 0.9, 0), reason: 't $t');
      }
    });

    test('phase desynchronises units so they do not flash in unison', () {
      // At the same instant, a phase offset can move one unit into a flash while
      // another rests on the floor.
      expect(policeStrobe(0.07, 0), isNot(policeStrobe(0.07, 0.03)));
    });
  });

  group('policeCordonPoints', () {
    test('returns the requested count and is empty for non-positive', () {
      expect(policeCordonPoints().length, kBridgePoliceUnitCount);
      expect(policeCordonPoints(count: 5).length, 5);
      expect(policeCordonPoints(count: 0), isEmpty);
    });

    test('lines the bridge deck left-to-right within the road band', () {
      final units = policeCordonPoints();
      for (var i = 0; i < units.length; i++) {
        final p = units[i].position;
        expect(p.dx, inExclusiveRange(0, 1));
        expect(p.dy, inInclusiveRange(0.47, 0.49), reason: 'on the deck');
        expect(units[i].phase, inInclusiveRange(0, 0.9));
        if (i > 0) {
          expect(
            p.dx,
            greaterThan(units[i - 1].position.dx),
            reason: 'cordon runs left to right',
          );
        }
      }
    });

    test('is dominantly blue with a sparse pair of red accents', () {
      final reds = policeCordonPoints().where((u) => u.isRed).length;
      expect(reds, 2);
      expect(reds, lessThan(kBridgePoliceUnitCount ~/ 2));
    });
  });

  group('BridgePoliceLayer.paint', () {
    // Blue-dominant painted pixels in the deck band, given a coverFit where the
    // art maps 1:1-scaled into a 16:9 viewport (640x360 → normalized * size).
    int bluePixelsOnDeck(Uint8List px, {int w = 640, int h = 360}) {
      var n = 0;
      for (var y = (0.46 * h).round(); y < (0.50 * h).round(); y++) {
        for (var x = (0.54 * w).round(); x < (0.76 * w).round(); x++) {
          final o = (y * w + x) * 4;
          if (px[o + 3] == 0) continue;
          if (px[o + 2] > px[o] && px[o + 2] > 25) n++; // blue beats red
        }
      }
      return n;
    }

    test('paints a blue cordon on the deck while traffic is stopped', () async {
      final px = await _render(2); // cycleProgress ~0.014 → full hold
      expect(
        bluePixelsOnDeck(px),
        greaterThan(60),
        reason: 'plenty of blue police lights line the bridge road',
      );
    });

    test('paints nothing once the drones have lifted', () async {
      final px = await _render(0.45 * kDroneShowCycleSeconds); // formation
      expect(bluePixelsOnDeck(px), 0);
      // The whole buffer is untouched (fully transparent).
      var painted = 0;
      for (var i = 3; i < px.length; i += 4) {
        if (px[i] != 0) painted++;
      }
      expect(painted, 0);
    });

    test('is suppressed under reduce-motion', () async {
      final px = await _render(2, reducedMotion: true);
      var painted = 0;
      for (var i = 3; i < px.length; i += 4) {
        if (px[i] != 0) painted++;
      }
      expect(painted, 0, reason: 'no flashing strobes under reduce-motion');
    });
  });
}
