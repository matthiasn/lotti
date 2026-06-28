import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';

void main() {
  group('StageLightRig', () {
    const rig = StageLightRig();

    test('samples one entry per light', () {
      expect(rig.sample(time: 1.2, beat: 0.3), hasLength(rig.count));
    });

    test('colours snap (do not lerp) and rotate per light', () {
      // At t=0 the three lights show the cycle in order: R, G, B.
      expect(rig.colorIndexAt(0, 0), 0);
      expect(rig.colorIndexAt(1, 0), 1);
      expect(rig.colorIndexAt(2, 0), 2);
      // Within one colourPeriod the index is unchanged (a hold, not a fade)...
      expect(rig.colorIndexAt(0, rig.colorPeriod * 0.99), 0);
      // ...then snaps to the next colour at the boundary, and wraps.
      expect(rig.colorIndexAt(0, rig.colorPeriod * 1.01), 1);
      expect(rig.colorIndexAt(2, rig.colorPeriod * 1.01), 0);
    });

    test('leadGoldIndex pins the hero lane to gold while flankers rotate', () {
      const lead = StageLightRig(leadGoldIndex: 1);
      // The locked lane holds colours[0] (gold) at every time...
      for (final t in [0.0, 0.3, 0.6, 1.7, 3.4]) {
        expect(
          lead.colorIndexAt(1, t),
          0,
          reason: 'lead lane stays gold at t=$t',
        );
      }
      // ...while the flanking lanes still cycle off the clock.
      expect(lead.colorIndexAt(0, 0), 0);
      expect(lead.colorIndexAt(0, rig.colorPeriod * 1.01), 1);
      expect(lead.colorIndexAt(2, rig.colorPeriod * 1.01), 0);
    });

    test('the row never shows every beam the same colour at once', () {
      for (final t in [0.0, 0.2, 0.7, 1.3, 2.6]) {
        final idx = {
          for (var i = 0; i < rig.count; i++) rig.colorIndexAt(i, t),
        };
        expect(idx.length, rig.count, reason: 'distinct colours at t=$t');
      }
    });

    test('beat boosts brightness over the no-beat base', () {
      final calm = rig.sample(time: 0.4)[0].intensity;
      final hit = rig.sample(time: 0.4, beat: 1)[0].intensity;
      expect(calm, closeTo(rig.baseIntensity, 1e-9));
      expect(hit, greaterThan(calm));
      expect(hit, lessThanOrEqualTo(1.0));
    });

    test('every pool target stays on stage (0..1) as it sweeps', () {
      for (var ms = 0; ms < 4000; ms += 50) {
        for (final l in rig.sample(time: ms / 1000)) {
          expect(l.targetX, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('reduced motion freezes sweep + beat to a calm static frame', () {
      final a = rig.sample(time: 0, beat: 1, reducedMotion: true);
      final b = rig.sample(time: 3.3, beat: 0.2, reducedMotion: true);
      for (var i = 0; i < rig.count; i++) {
        // Pools sit on their anchors, brightness is the base (no beat boost),
        // and nothing moves between two different clock values.
        expect(a[i].targetX, closeTo(rig.anchors[i], 1e-9));
        expect(a[i].intensity, closeTo(rig.baseIntensity, 1e-9));
        expect(b[i].targetX, closeTo(a[i].targetX, 1e-9));
        expect(b[i].color, a[i].color);
      }
    });

    test('is deterministic for identical inputs', () {
      final a = rig.sample(time: 1.234, beat: 0.6);
      final b = rig.sample(time: 1.234, beat: 0.6);
      for (var i = 0; i < rig.count; i++) {
        expect(b[i].color, a[i].color);
        expect(b[i].targetX, a[i].targetX);
        expect(b[i].intensity, a[i].intensity);
      }
    });

    test('colourPeriod scales the snap cadence (tempo lock)', () {
      const fast = StageLightRig(colorPeriod: 0.25);
      // Half the period -> the first snap happens at half the time.
      expect(fast.colorIndexAt(0, 0.24), 0);
      expect(fast.colorIndexAt(0, 0.26), 1);
    });
  });
}
