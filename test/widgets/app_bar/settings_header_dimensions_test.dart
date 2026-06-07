import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/widgets/app_bar/settings_header_dimensions.dart';

extension _AnyHeaderDims on glados.Any {
  /// Header heights across a generous range, deliberately including negative
  /// values and orderings where collapsed >= expanded.
  glados.Generator<double> get headerHeight =>
      glados.DoubleAnys(this).doubleInRange(-200, 2000);

  /// Pane widths from degenerate zero up to ultra-wide desktop.
  glados.Generator<double> get paneWidth =>
      glados.DoubleAnys(this).doubleInRange(0, 4000);
}

void main() {
  group('SettingsHeaderDimensions', () {
    test('collapseProgress calculates correctly and clamps', () {
      expect(
        SettingsHeaderDimensions.collapseProgress(100, 50, 100),
        0,
      );
      expect(
        SettingsHeaderDimensions.collapseProgress(100, 50, 75),
        closeTo(0.5, 1e-9),
      );
      expect(
        SettingsHeaderDimensions.collapseProgress(100, 50, 50),
        1,
      );
      // Clamp beyond expanded range
      expect(
        SettingsHeaderDimensions.collapseProgress(100, 50, 120),
        0,
      );
      // Clamp beyond collapsed range
      expect(
        SettingsHeaderDimensions.collapseProgress(100, 50, -10),
        1,
      );
      // No available delta → treated as fully collapsed
      expect(
        SettingsHeaderDimensions.collapseProgress(100, 100, 50),
        1,
      );
    });

    test('horizontalPadding breakpoints return expected values', () {
      double hp(double w) => SettingsHeaderDimensions.horizontalPadding(w);
      expect(hp(0), 20);
      expect(hp(419), 20);
      expect(hp(420), 28);
      expect(hp(539), 28);
      expect(hp(540), 36);
      expect(hp(719), 36);
      expect(hp(720), 56);
      expect(hp(991), 56);
      expect(hp(992), 88);
      expect(hp(1199), 88);
      expect(hp(1200), 120);
      expect(hp(1599), 120);
      expect(hp(1600), 160);
      expect(hp(2600), 160);
    });

    test('titleFontSize respects width and wide flag', () {
      double t({required double w, required bool wide}) =>
          SettingsHeaderDimensions.titleFontSize(width: w, wide: wide);

      // Below all thresholds
      expect(t(w: 360, wide: false), 22);
      // Phone
      expect(t(w: 420, wide: false), 24);
      expect(t(w: 600, wide: false), 26);
      // Tablet/desktop mid-range
      expect(t(w: 840, wide: true), 28);
      expect(t(w: 992, wide: false), 30);
      // Large desktop
      expect(t(w: 1200, wide: false), 32);
      expect(t(w: 1600, wide: false), 36);
    });
  });

  // ---------------------------------------------------------------------------
  // Glados property tests — collapseProgress and horizontalPadding are pure
  // math helpers with invariants that hold for ANY input, not just the
  // hand-picked values above.
  // ---------------------------------------------------------------------------
  group('collapseProgress — properties', () {
    glados.Glados3(
      glados.any.headerHeight,
      glados.any.headerHeight,
      glados.any.headerHeight,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is always within [0, 1] for any height triple',
      (expanded, collapsed, current) {
        final progress = SettingsHeaderDimensions.collapseProgress(
          expanded,
          collapsed,
          current,
        );
        expect(
          progress,
          inInclusiveRange(0, 1),
          reason: 'expanded=$expanded collapsed=$collapsed current=$current',
        );
      },
      tags: 'glados',
    );

    glados.Glados3(
      glados.any.headerHeight,
      glados.any.headerHeight,
      glados.any.headerHeight,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'is non-increasing as currentHeight grows',
      (expanded, collapsed, current) {
        final atCurrent = SettingsHeaderDimensions.collapseProgress(
          expanded,
          collapsed,
          current,
        );
        final atTaller = SettingsHeaderDimensions.collapseProgress(
          expanded,
          collapsed,
          current + 25,
        );
        expect(
          atTaller,
          lessThanOrEqualTo(atCurrent),
          reason: 'expanded=$expanded collapsed=$collapsed current=$current',
        );
      },
      tags: 'glados',
    );
  });

  group('horizontalPadding — properties', () {
    glados.Glados2(
      glados.any.paneWidth,
      glados.any.paneWidth,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'stays within [20, 160] and is non-decreasing with width',
      (a, b) {
        final narrow = math.min(a, b);
        final wide = math.max(a, b);
        final atNarrow = SettingsHeaderDimensions.horizontalPadding(narrow);
        final atWide = SettingsHeaderDimensions.horizontalPadding(wide);

        expect(atNarrow, inInclusiveRange(20, 160), reason: 'width=$narrow');
        expect(atWide, inInclusiveRange(20, 160), reason: 'width=$wide');
        expect(
          atWide,
          greaterThanOrEqualTo(atNarrow),
          reason: 'padding must not shrink from width $narrow to $wide',
        );
      },
      tags: 'glados',
    );
  });
}
