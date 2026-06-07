import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/theme/design_tokens.dart';

// Algebraic invariants of the hand-authored `lerp` logic in the generated
// `design_tokens.g.dart`. The file itself is generated, but the generator's
// lerp template is non-trivial — a generator regression would silently break
// theme transitions, so the contract is pinned here from the outside.
//
// The BuildContext `designTokens` extension getter (the only hand-written
// code in `design_tokens.dart`) is covered in `design_system_theme_test.dart`
// alongside the ThemeData assembly it depends on.

extension _AnyT on glados.Any {
  /// Interpolation factor inside the contractually valid [0, 1] range.
  glados.Generator<double> get unitT =>
      glados.DoubleAnys(this).doubleInRange(0, 1);

  /// Unconstrained factor: the null-identity short-circuit must hold for
  /// any t, including out-of-range extrapolation values.
  glados.Generator<double> get anyT =>
      glados.DoubleAnys(this).doubleInRange(-2, 3);
}

List<double> _spacingFields(DsSpacing s) => [
  s.step1,
  s.step2,
  s.step3,
  s.step4,
  s.step5,
  s.step6,
  s.step7,
  s.step8,
  s.step9,
  s.step10,
  s.step11,
  s.step12,
  s.step13,
  s.cardPadding,
  s.cardItemSpacing,
  s.sectionGap,
];

List<double> _radiiFields(DsRadii r) => [
  r.xs,
  r.s,
  r.m,
  r.l,
  r.xl,
  r.sectionCards,
  r.badgesPills,
  r.smallChips,
];

/// A synthetic far endpoint with every field strictly above the original,
/// so betweenness/monotonicity assertions are non-vacuous (the light and
/// dark themes share identical spacing/radii scales).
DsSpacing _scaledSpacing(DsSpacing a, double factor) => a.copyWith(
  step1: a.step1 * factor,
  step2: a.step2 * factor,
  step3: a.step3 * factor,
  step4: a.step4 * factor,
  step5: a.step5 * factor,
  step6: a.step6 * factor,
  step7: a.step7 * factor,
  step8: a.step8 * factor,
  step9: a.step9 * factor,
  step10: a.step10 * factor,
  step11: a.step11 * factor,
  step12: a.step12 * factor,
  step13: a.step13 * factor,
  cardPadding: a.cardPadding * factor,
  cardItemSpacing: a.cardItemSpacing * factor,
  sectionGap: a.sectionGap * factor,
);

DsRadii _scaledRadii(DsRadii a, double factor) => a.copyWith(
  xs: a.xs * factor,
  s: a.s * factor,
  m: a.m * factor,
  l: a.l * factor,
  xl: a.xl * factor,
  sectionCards: a.sectionCards * factor,
  badgesPills: a.badgesPills * factor,
  smallChips: a.smallChips * factor,
);

void main() {
  group('DsTokens.lerp endpoint identities', () {
    test('t=0 returns the receiver, t=1 returns the other endpoint', () {
      expect(dsTokensLight.lerp(dsTokensDark, 0), dsTokensLight);
      expect(dsTokensLight.lerp(dsTokensDark, 1), dsTokensDark);
      expect(dsTokensDark.lerp(dsTokensLight, 0), dsTokensDark);
      expect(dsTokensDark.lerp(dsTokensLight, 1), dsTokensLight);
    });

    test('spacing and radii endpoint identities against a scaled endpoint', () {
      final farSpacing = _scaledSpacing(dsTokensLight.spacing, 3);
      final farRadii = _scaledRadii(dsTokensLight.radii, 3);

      expect(dsTokensLight.spacing.lerp(farSpacing, 0), dsTokensLight.spacing);
      expect(dsTokensLight.spacing.lerp(farSpacing, 1), farSpacing);
      expect(dsTokensLight.radii.lerp(farRadii, 0), dsTokensLight.radii);
      expect(dsTokensLight.radii.lerp(farRadii, 1), farRadii);
    });
  });

  glados.Glados<double>(glados.any.anyT).test(
    'lerp(null, t) is the instance-wise identity for any t',
    (t) {
      expect(dsTokensLight.lerp(null, t), same(dsTokensLight));
      expect(dsTokensDark.lerp(null, t), same(dsTokensDark));
      expect(
        dsTokensLight.spacing.lerp(null, t),
        same(dsTokensLight.spacing),
      );
      expect(dsTokensLight.radii.lerp(null, t), same(dsTokensLight.radii));
    },
    tags: 'glados',
  );

  glados.Glados<double>(glados.any.unitT).test(
    'DsSpacing.lerp stays field-wise between its endpoints for t in [0, 1]',
    (t) {
      final a = dsTokensLight.spacing;
      final b = _scaledSpacing(a, 3);
      final lerped = _spacingFields(a.lerp(b, t));
      final lower = _spacingFields(a);
      final upper = _spacingFields(b);

      for (var i = 0; i < lerped.length; i++) {
        expect(lerped[i], greaterThanOrEqualTo(lower[i]), reason: 'field $i');
        expect(lerped[i], lessThanOrEqualTo(upper[i]), reason: 'field $i');
      }
    },
    tags: 'glados',
  );

  glados.Glados2<double, double>(glados.any.unitT, glados.any.unitT).test(
    'DsSpacing.lerp and DsRadii.lerp are field-wise monotonic in t',
    (x, y) {
      final t1 = x < y ? x : y;
      final t2 = x < y ? y : x;

      final spacingA = dsTokensLight.spacing;
      final spacingB = _scaledSpacing(spacingA, 3);
      final spacingAt1 = _spacingFields(spacingA.lerp(spacingB, t1));
      final spacingAt2 = _spacingFields(spacingA.lerp(spacingB, t2));
      for (var i = 0; i < spacingAt1.length; i++) {
        expect(
          spacingAt1[i],
          lessThanOrEqualTo(spacingAt2[i]),
          reason: 'spacing field $i at t1=$t1 t2=$t2',
        );
      }

      final radiiA = dsTokensLight.radii;
      final radiiB = _scaledRadii(radiiA, 3);
      final radiiAt1 = _radiiFields(radiiA.lerp(radiiB, t1));
      final radiiAt2 = _radiiFields(radiiA.lerp(radiiB, t2));
      for (var i = 0; i < radiiAt1.length; i++) {
        expect(
          radiiAt1[i],
          lessThanOrEqualTo(radiiAt2[i]),
          reason: 'radii field $i at t1=$t1 t2=$t2',
        );
      }
    },
    tags: 'glados',
  );
}
