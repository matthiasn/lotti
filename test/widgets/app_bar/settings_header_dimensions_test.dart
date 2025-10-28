import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/app_bar/settings_header_dimensions.dart';

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

    test('titleFontSize applies cap across widths and flags', () {
      double t({required double w, required bool wide}) =>
          SettingsHeaderDimensions.titleFontSize(width: w, wide: wide);
      const cap = SettingsHeaderDimensions.mobileMaxTitleSize;

      // All sizes should be clamped to the mobile max cap
      expect(t(w: 360, wide: false), cap);
      expect(t(w: 420, wide: false), cap);
      expect(t(w: 600, wide: false), cap);
      expect(t(w: 840, wide: true), cap);
      expect(t(w: 992, wide: false), cap);
      expect(t(w: 1200, wide: false), cap);
      expect(t(w: 1600, wide: false), cap);
    });
  });
}
