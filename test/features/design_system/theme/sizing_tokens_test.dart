import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/sizing_tokens.dart';

// The sizing set exists because call sites used to borrow `spacing.stepN` as a
// control, glyph or container dimension — which type-checks, but resized the
// control whenever the *gap* scale was retuned. The values themselves are
// arbitrary-by-design; what is not arbitrary is the geometry they promise each
// other, and that is what is pinned here.

void main() {
  group('IconSizes', () {
    test('the ramp is strictly ascending', () {
      // Callers pick a tier by role and rely on the next tier being larger.
      const ramp = <double>[
        IconSizes.xs,
        IconSizes.s,
        IconSizes.m,
        IconSizes.l,
        IconSizes.xl,
        IconSizes.xxl,
        IconSizes.xxxl,
      ];
      for (var i = 1; i < ramp.length; i++) {
        expect(
          ramp[i],
          greaterThan(ramp[i - 1]),
          reason: 'tier $i (${ramp[i]}) does not exceed ${ramp[i - 1]}',
        );
      }
    });
  });

  group('ControlSizes icon chips', () {
    test('the compact chip is actually smaller than the standard one', () {
      // Two tiers only earn their keep while they are visibly different; if
      // they converge, one of them should be deleted rather than kept as a
      // second name for the same tile.
      expect(ControlSizes.iconChipCompact, lessThan(ControlSizes.iconChip));
    });

    test('each chip can contain the glyph tier it is documented to hold', () {
      // `device_card` centres an IconSizes.l glyph in the standard chip and
      // `backfill_settings_recovery` centres an IconSizes.s glyph in the
      // compact one. A chip smaller than its glyph would clip it.
      expect(ControlSizes.iconChip, greaterThanOrEqualTo(IconSizes.l));
      expect(ControlSizes.iconChipCompact, greaterThanOrEqualTo(IconSizes.s));
    });

    test('each chip leaves a whole-pixel inset around its glyph', () {
      // The glyph is centred, so the leftover space is split in two. An odd
      // remainder lands the icon on a half pixel and blurs it.
      expect(
        (ControlSizes.iconChip - IconSizes.l) % 2,
        0,
        reason: 'IconSizes.l does not centre cleanly in the standard chip',
      );
      expect(
        (ControlSizes.iconChipCompact - IconSizes.s) % 2,
        0,
        reason: 'IconSizes.s does not centre cleanly in the compact chip',
      );
    });

    test('neither chip claims to be a tap target', () {
      // These are decorative tiles behind a glyph. If one ever grew to the
      // interaction minimum it would read as pressable, and the row it leads
      // would owe the user a hit response it does not have.
      expect(ControlSizes.iconChip, lessThan(TapTargets.minimum));
      expect(ControlSizes.iconChipCompact, lessThan(TapTargets.minimum));
    });
  });

  group('BorderWidths', () {
    test('the emphasis stroke reads as heavier than the hairline', () {
      expect(BorderWidths.emphasis, greaterThan(BorderWidths.hairline));
    });
  });
}
