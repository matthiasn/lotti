import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/distant_jet_layer.dart';
import 'package:lotti/features/scenery/layers/drone_show_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';

Future<Uint8List> _render(
  double timeSeconds, {
  int w = 640,
  int h = 360,
  bool reducedMotion = false,
}) async {
  final recorder = ui.PictureRecorder();
  final jetImage = await _fakeJetImage();
  const DistantJetLayer().paint(
    Canvas(recorder),
    BackdropContext(
      size: ui.Size(w.toDouble(), h.toDouble()),
      timeSeconds: timeSeconds,
      palette: kBlueHourPalette,
      reducedMotion: reducedMotion,
      images: {SceneryAssets.lufthansa747: jetImage},
    ),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData();
  jetImage.dispose();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> _fakeJetImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(0, 18, 280, 36),
        const ui.Radius.circular(18),
      ),
      ui.Paint()..color = const ui.Color(0xFFE7EEF7),
    )
    ..drawPath(
      ui.Path()
        ..moveTo(50, 28)
        ..lineTo(166, 4)
        ..lineTo(236, 18)
        ..lineTo(118, 38)
        ..close(),
      ui.Paint()..color = const ui.Color(0xFF233B68),
    );
  return recorder.endRecording().toImage(280, 72);
}

int _paintedPixels(Uint8List px) {
  var n = 0;
  for (var i = 3; i < px.length; i += 4) {
    if (px[i] != 0) n++;
  }
  return n;
}

int _paintedPixelsOutside(
  Uint8List px, {
  required int w,
  required int h,
  required ui.Rect rect,
}) {
  var n = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final alpha = px[(y * w + x) * 4 + 3];
      final center = ui.Offset(x + 0.5, y + 0.5);
      if (alpha != 0 && !rect.contains(center)) n++;
    }
  }
  return n;
}

void main() {
  group('distantJetStageRect', () {
    test('extracts the active 16:9 rect from a wide viewport', () {
      final rect = distantJetStageRect(const ui.Size(1400, 720));

      expect(rect.left, closeTo(60, 1e-12));
      expect(rect.top, 0);
      expect(rect.width, closeTo(1280, 1e-12));
      expect(rect.height, 720);
    });

    test('extracts the active 16:9 rect from a tall viewport', () {
      final rect = distantJetStageRect(const ui.Size(1080, 900));

      expect(rect.left, 0);
      expect(rect.top, closeTo(146.25, 1e-12));
      expect(rect.width, 1080);
      expect(rect.height, closeTo(607.5, 1e-12));
    });
  });

  group('sampleDistantJet', () {
    test('uses a readable but still distant airliner pass', () {
      expect(kDistantJetPassSeconds, inInclusiveRange(56, 64));
    });

    test('starts after a short blank lead-in', () {
      expect(sampleDistantJet(0), isNull);
      expect(sampleDistantJet(kDistantJetStartDelaySeconds / 2), isNull);
      expect(sampleDistantJet(kDistantJetStartDelaySeconds), isNotNull);
    });

    test('crosses from right to left during the pass', () {
      final start = sampleDistantJet(kDistantJetStartDelaySeconds)!;
      final early = sampleDistantJet(kDistantJetStartDelaySeconds + 2)!;
      final mid = sampleDistantJet(
        kDistantJetStartDelaySeconds + kDistantJetPassSeconds * 0.5,
      )!;
      final late = sampleDistantJet(
        kDistantJetStartDelaySeconds + kDistantJetPassSeconds - 2,
      )!;

      expect(start.position.dx, inInclusiveRange(0.96, 1));
      expect(early.position.dx, lessThan(start.position.dx));
      expect(mid.position.dx, inInclusiveRange(0.42, 0.44));
      expect(late.position.dx, lessThan(0));
      expect(early.position.dy, greaterThan(late.position.dy));
      expect(mid.widthFraction, lessThanOrEqualTo(early.widthFraction));
      expect(mid.opacity, lessThan(early.opacity));
    });

    test('starts close enough to enter during the first second', () {
      final firstSecond = sampleDistantJet(kDistantJetStartDelaySeconds + 1)!;
      final halfWidth = firstSecond.widthFraction / 2;

      expect(
        firstSecond.position.dx - halfWidth,
        lessThan(1),
        reason: 'left edge of the clipped plane should be inside the stage',
      );
    });

    test('has already cleared the center by the drone-show peak', () {
      final beamPeak = sampleDistantJet(kDroneShowCycleSeconds * 0.38)!;

      expect(beamPeak.position.dx, lessThan(0.02));
      expect(
        beamPeak.position.dy,
        greaterThan(0.17),
        reason: 'plane remains background traffic, not a near collision',
      );
      expect(beamPeak.widthFraction, inInclusiveRange(0.04, 0.06));
    });

    test(
      'keeps fading contrails briefly after the aircraft clears',
      () {
        final exit = sampleDistantJet(
          kDistantJetStartDelaySeconds + kDistantJetPassSeconds + 6,
        )!;

        expect(exit.opacity, 0);
        expect(exit.trailOpacity, greaterThan(0));
        expect(
          sampleDistantJet(
            kDistantJetStartDelaySeconds +
                kDistantJetPassSeconds +
                kDistantJetTrailHoldSeconds +
                0.1,
          ),
          isNull,
        );
      },
    );

    test(
      'wraps the opening pass with the scene loop',
      () {
        expect(
          sampleDistantJet(kDroneShowCycleSeconds + 2)!.position.dx,
          closeTo(sampleDistantJet(2)!.position.dx, 1e-12),
        );
      },
    );
  });

  group('distantJetEdgeVisibility', () {
    test('fades at both frame edges', () {
      expect(distantJetEdgeVisibility(1.24), 0);
      expect(distantJetEdgeVisibility(0.5), 1);
      expect(distantJetEdgeVisibility(-0.22), 0);
    });
  });

  group('aircraft lights', () {
    test('anti-collision cadence stays inside the FAA 40-100 cpm band', () {
      expect(
        kAircraftAntiCollisionCyclesPerMinute,
        inInclusiveRange(40, 100),
      );
      expect(kAircraftAntiCollisionPeriodSeconds, closeTo(1, 1e-12));
    });

    test('red beacon pulses once per second at 60 cpm', () {
      expect(aircraftBeaconPulse(0), greaterThan(0.9));
      expect(aircraftBeaconPulse(0.2), 0);
      expect(
        aircraftBeaconPulse(kAircraftAntiCollisionPeriodSeconds),
        closeTo(aircraftBeaconPulse(0), 1e-12),
      );
    });

    test('white strobe follows the same anti-collision cadence', () {
      expect(aircraftWingStrobe(0), greaterThan(0.9));
      expect(aircraftWingStrobe(0.08), greaterThan(0));
      expect(aircraftWingStrobe(0.2), 0);
      expect(aircraftWingStrobe(0.3), 0);
    });
  });

  group('DistantJetLayer.paint', () {
    test('draws a small sky silhouette with lights during the pass', () async {
      final px = await _render(
        kDistantJetStartDelaySeconds + kDistantJetPassSeconds * 0.5,
      );
      expect(
        _paintedPixels(px),
        inInclusiveRange(300, 9000),
        reason: 'far jet should be visible but not dominate the frame',
      );
    });

    test('clips the jet to the active 16:9 stage rect', () async {
      const w = 1400;
      const h = 720;
      final px = await _render(kDistantJetStartDelaySeconds + 1, w: w, h: h);

      expect(_paintedPixels(px), greaterThan(0));
      expect(
        _paintedPixelsOutside(
          px,
          w: w,
          h: h,
          rect: distantJetStageRect(ui.Size(w.toDouble(), h.toDouble())),
        ),
        0,
      );
    });

    test('paints nothing after the contrails fade out', () async {
      final px = await _render(
        kDistantJetStartDelaySeconds +
            kDistantJetPassSeconds +
            kDistantJetTrailHoldSeconds +
            0.1,
      );
      expect(_paintedPixels(px), 0);
    });

    test('is suppressed under reduce-motion', () async {
      final px = await _render(
        kDistantJetStartDelaySeconds + kDistantJetPassSeconds * 0.5,
        reducedMotion: true,
      );
      expect(_paintedPixels(px), 0);
    });
  });
}
