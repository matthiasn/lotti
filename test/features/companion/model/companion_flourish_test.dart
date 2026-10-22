import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_flourish.dart';

/// How far [f] moves her face and head, all its values together.
double _reach(CompanionFlourish f) => [
  f.brow,
  f.browSkew,
  f.tilt,
  f.smile,
  f.smileSkew,
  f.squint,
  f.lids,
  f.oneEye,
  f.roll,
  f.yaw,
  f.pitch,
  f.gaze?.$1 ?? 0,
  f.gaze?.$2 ?? 0,
].fold(0, (sum, v) => sum + v.abs());

void main() {
  test('every flourish shows on her face, and fades within two seconds', () {
    for (final f in CompanionFlourish.values) {
      expect(_reach(f), greaterThan(0.5), reason: f.name);
      expect(f.duration, inInclusiveRange(0.5, 2), reason: f.name);
    }
  });

  test('only the wink shuts one eye', () {
    expect(
      CompanionFlourish.values.where((f) => f.oneEye != 0),
      [CompanionFlourish.wink],
    );
  });

  test('the side-eye looks away and the look over the glasses looks up', () {
    expect(CompanionFlourish.sideEye.gaze!.$1.abs(), greaterThan(0.5));
    expect(CompanionFlourish.overTheGlasses.gaze!.$2, lessThan(-0.5));
    // Chin down, so the eyes come up over the rims.
    expect(CompanionFlourish.overTheGlasses.pitch, greaterThan(0));
  });

  group('envelope', () {
    const f = CompanionFlourish.sideEye;

    test('is nothing before it starts and once it is over', () {
      expect(f.envelope(-0.01), 0);
      expect(f.envelope(f.duration), 0);
      expect(f.envelope(f.duration + 1), 0);
    });

    test('rises, holds at full strength, and fades', () {
      final samples = [
        for (var i = 0; i <= 100; i++) f.envelope(f.duration * i / 100),
      ];
      final peak = samples.indexOf(1);
      expect(peak, greaterThan(0));
      for (var i = 1; i <= peak; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
      }
      expect(f.envelope(f.duration / 2), 1);
      final lastFull = samples.lastIndexOf(1);
      for (var i = lastFull + 1; i < samples.length; i++) {
        expect(samples[i], lessThanOrEqualTo(samples[i - 1]));
      }
      expect(samples.last, 0);
    });
  });
}
