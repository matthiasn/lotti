import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../test_utils/wcag_contrast.dart';

// Algebraic invariants of the hand-authored `lerp` logic in the generated
// `design_tokens.g.dart`, plus the palette's accessibility contract. The file
// itself is generated, but the generator's lerp template is non-trivial — a
// generator regression would silently break theme transitions — and the
// palette values it emits carry contrast obligations that nothing else in the
// build checks. Both are pinned here from the outside.
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

/// AA for body text (SC 1.4.3). The bar for `ink`, which exists precisely so
/// small alert-toned labels have somewhere safe to bind.
const _aaText = 4.5;

/// Graphical objects and UI-component state (SC 1.4.11). The bar for
/// `defaultColor`, which paints dots, borders, glyphs and chart series that
/// carry their meaning through colour alone.
const _uiComponent = 3.0;

/// The four alert families, flattened — the generated classes are siblings
/// with no common supertype, so the ramp has to be projected into records to
/// be iterated over.
List<
  ({
    String name,
    Color defaultColor,
    Color hover,
    Color pressed,
    Color ink,
    Color glyphOnLevel03,
  })
>
_alertFamilies(DsTokens tokens) {
  final alert = tokens.colors.alert;
  return [
    (
      name: 'error',
      defaultColor: alert.error.defaultColor,
      hover: alert.error.hover,
      pressed: alert.error.pressed,
      ink: alert.error.ink,
      glyphOnLevel03: alert.error.glyphOnLevel03,
    ),
    (
      name: 'success',
      defaultColor: alert.success.defaultColor,
      hover: alert.success.hover,
      pressed: alert.success.pressed,
      ink: alert.success.ink,
      glyphOnLevel03: alert.success.glyphOnLevel03,
    ),
    (
      name: 'warning',
      defaultColor: alert.warning.defaultColor,
      hover: alert.warning.hover,
      pressed: alert.warning.pressed,
      ink: alert.warning.ink,
      glyphOnLevel03: alert.warning.glyphOnLevel03,
    ),
    (
      name: 'info',
      defaultColor: alert.info.defaultColor,
      hover: alert.info.hover,
      pressed: alert.info.pressed,
      ink: alert.info.ink,
      glyphOnLevel03: alert.info.glyphOnLevel03,
    ),
  ];
}

/// The surfaces an alert colour legitimately lands on: the page and the cards
/// and sheets stacked on it.
///
/// `background.level03` is deliberately excluded. It is a mid-grey chip and
/// panel *fill*, and in dark theme no step of the error ramp can reach AA
/// against it — pure white tops out at 7.7:1 there, and a red light enough to
/// clear 4.5:1 has stopped reading as an error. Alert-toned content on
/// level03 needs a different treatment, not a different ramp step.
List<({String name, Color color})> _alertSurfaces(DsTokens tokens) => [
  (name: 'background.level01', color: tokens.colors.background.level01),
  (name: 'background.level02', color: tokens.colors.background.level02),
];

void main() {
  // Nothing in the build pipeline checks the palette the Figma export emits,
  // so a light-theme ramp anchored for vibrancy shipped three families below
  // the 1.4.11 floor (warning at 2.15:1 on level02) and stayed there until a
  // reviewer read the token file by hand. These assertions are the check that
  // was missing.
  // `level03` is the surface the ramp above deliberately leaves out: no
  // error step reaches AA on it in dark, and the surface ink stops at 2.9:1.
  // A static glyph there — the missed-day cross on a habit square — has its
  // own step, guaranteed here rather than borrowed from an interaction state.
  group('alert glyphOnLevel03', () {
    const themes = [
      (name: 'light', tokens: dsTokensLight),
      (name: 'dark', tokens: dsTokensDark),
    ];
    for (final theme in themes) {
      final level03 = theme.tokens.colors.background.level03;
      for (final family in _alertFamilies(theme.tokens)) {
        final label = '${theme.name} alert.${family.name}.glyphOnLevel03';
        test('$label clears the non-text floor on level03', () {
          final ratio = contrastRatio(family.glyphOnLevel03, level03);
          expect(
            ratio,
            greaterThanOrEqualTo(_uiComponent),
            reason:
                '$label ${family.glyphOnLevel03} measures '
                '${ratio.toStringAsFixed(2)}:1 on level03, below '
                '$_uiComponent:1',
          );
        });
        test('$label is a step of its own ramp, not a fifth hue', () {
          expect(
            family.glyphOnLevel03,
            isIn([family.defaultColor, family.hover, family.pressed]),
          );
        });
      }
    }
  });

  group('alert palette contrast', () {
    const themes = [
      (name: 'light', tokens: dsTokensLight),
      (name: 'dark', tokens: dsTokensDark),
    ];

    for (final theme in themes) {
      for (final family in _alertFamilies(theme.tokens)) {
        for (final surface in _alertSurfaces(theme.tokens)) {
          final label = '${theme.name} alert.${family.name} on ${surface.name}';

          test('$label clears its WCAG floor', () {
            final inkRatio = contrastRatio(family.ink, surface.color);
            expect(
              inkRatio,
              greaterThanOrEqualTo(_aaText),
              reason:
                  '$label: ink ${family.ink} measures '
                  '${inkRatio.toStringAsFixed(2)}:1, below AA text $_aaText:1',
            );

            final defaultRatio = contrastRatio(
              family.defaultColor,
              surface.color,
            );
            expect(
              defaultRatio,
              greaterThanOrEqualTo(_uiComponent),
              reason:
                  '$label: default ${family.defaultColor} measures '
                  '${defaultRatio.toStringAsFixed(2)}:1, below the '
                  'non-text floor $_uiComponent:1',
            );
          });

          test('$label keeps ink at least as strong as default', () {
            // The invariant that makes `ink` the always-safe binding: a caller
            // moving text off `defaultColor` can never lose contrast by it.
            expect(
              contrastRatio(family.ink, surface.color),
              greaterThanOrEqualTo(
                contrastRatio(
                  family.defaultColor,
                  surface.color,
                ),
              ),
              reason: '$label: ink is weaker than default',
            );
          });
        }
      }
    }
  });

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
