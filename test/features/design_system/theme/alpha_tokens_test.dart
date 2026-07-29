import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/alpha_tokens.dart';

// `SurfaceAlphas` is a hand-authored const group, so there is no generator to
// regress and no lerp to exercise. What is worth pinning is the reason the
// group exists at all: it replaced six unowned magic numbers scattered across
// the sync feature, and it is only defensible while it stays a small set of
// *distinct*, genuinely-partial fades. Each test below fails on a specific way
// that discipline could erode.

void main() {
  // Every alpha in the group, paired with its name so a failure names the
  // offender instead of an index.
  const alphas = <String, double>{
    'tint': SurfaceAlphas.tint,
    'muted': SurfaceAlphas.muted,
    'linework': SurfaceAlphas.linework,
  };

  group('SurfaceAlphas', () {
    test('every value is a partial fade, not an endpoint', () {
      // 0 renders nothing and 1 is the colour itself — either means the call
      // site wanted a different colour token, not an alpha.
      for (final MapEntry(key: name, value: alpha) in alphas.entries) {
        expect(
          alpha,
          greaterThan(0),
          reason: '$name is fully transparent, so it paints nothing',
        );
        expect(
          alpha,
          lessThan(1),
          reason: '$name is fully opaque, so it is not a fade',
        );
      }
    });

    test('no two names describe the same fade', () {
      // Two names for one value is exactly the drift this group replaced:
      // `device_card` and `backfill_settings_recovery` had each invented their
      // own answer for one shared role.
      expect(
        alphas.values.toSet(),
        hasLength(alphas.length),
        reason: 'duplicate alphas mean one of these names is redundant',
      );
    });

    test('the ramp orders by how present the fill should read', () {
      // tint sits behind content, muted is a satisfied accent, linework is
      // read directly. Reordering these would invert the semantics the doc
      // comments promise.
      expect(SurfaceAlphas.tint, lessThan(SurfaceAlphas.muted));
      expect(SurfaceAlphas.muted, lessThan(SurfaceAlphas.linework));
    });

    test('the tint stays faint enough to sit under text', () {
      // `MetricTile` paints its value and label directly on this fill. Past
      // roughly a tenth the tone starts competing with the glyphs on top of
      // it, which is the failure the 0.08 was chosen to avoid.
      expect(SurfaceAlphas.tint, lessThanOrEqualTo(0.1));
    });
  });
}
