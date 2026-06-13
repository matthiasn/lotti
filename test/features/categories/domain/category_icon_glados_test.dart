import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'category_icon_test_helpers.dart';

void main() {
  group('CategoryIconConstants', () {
    // These are compile-time `const` values, so they cannot drift at runtime.
    // The single test below therefore asserts the call-site *contracts* the
    // constants must satisfy to be safe — not arbitrary ranges. A future edit
    // that breaks one of these contracts (e.g. an alpha > 1 fed into
    // Color.withValues, or a size multiplier >= 1 that would scale icons *up*
    // instead of down) would silently misbehave in the UI; this guards that.
    test('values satisfy their call-site contracts', () {
      // Size *multipliers* scale a base size down — they are applied as
      // `size * multiplier` in category_icon_display/compact. A value outside
      // (0, 1) would enlarge instead of shrink the glyph/text.
      for (final multiplier in <double>[
        CategoryIconConstants.iconSizeMultiplier,
        CategoryIconConstants.textSizeMultiplier,
        CategoryIconConstants.fallbackIconSizeMultiplier,
      ]) {
        expect(multiplier, greaterThan(0));
        expect(multiplier, lessThan(1));
      }

      // Alpha and luminance feed Color.withValues(alpha:) / computeLuminance(),
      // both of which require a normalized [0, 1] fraction.
      for (final fraction in <double>[
        CategoryIconConstants.selectedBackgroundAlpha,
        CategoryIconConstants.luminanceThreshold,
      ]) {
        expect(fraction, inInclusiveRange(0, 1));
      }

      // modalMaxHeightRatio caps a modal at a fraction of the screen height
      // (size.height * ratio in category_create_modal) — must be (0, 1].
      expect(
        CategoryIconConstants.modalMaxHeightRatio,
        greaterThan(0),
      );
      expect(
        CategoryIconConstants.modalMaxHeightRatio,
        lessThanOrEqualTo(1),
      );

      // Pixel dimensions and counts used for layout must be strictly positive.
      for (final dimension in <num>[
        CategoryIconConstants.defaultIconSize,
        CategoryIconConstants.borderWidth,
        CategoryIconConstants.pickerGridColumns,
        CategoryIconConstants.pickerMaxWidth,
      ]) {
        expect(dimension, greaterThan(0));
      }
    });
  });

  group('CategoryIconStrings', () {
    test('should have non-empty string constants', () {
      expect(CategoryIconStrings.fallbackCharacter, isNotEmpty);
      expect(CategoryIconStrings.invalidIconWarning, isNotEmpty);
    });

    test('fallback character should be a single character', () {
      expect(CategoryIconStrings.fallbackCharacter.length, equals(1));
    });
  });

  group('Performance optimization', () {
    test('should use O(1) map lookup for fromJson', () {
      // Test that the static map works correctly for all enum values
      for (final icon in CategoryIcon.values) {
        final json = icon.toJson();
        expect(CategoryIconExtension.fromJson(json), equals(icon));
      }

      // Test edge cases that should use the map efficiently
      expect(
        CategoryIconExtension.fromJson('fitness'),
        equals(CategoryIcon.fitness),
      );
      expect(
        CategoryIconExtension.fromJson('  medical  '),
        equals(CategoryIcon.medical),
      );
      expect(CategoryIconExtension.fromJson('invalidValue'), isNull);
    });

    test('should handle the static map initialization correctly', () {
      // Verify that all enum values are present in the internal map
      // by checking a sample of different icons
      const testIcons = [
        CategoryIcon.fitness,
        CategoryIcon.medical,
        CategoryIcon.school,
        CategoryIcon.work,
        CategoryIcon.home,
      ];

      for (final icon in testIcons) {
        final json = icon.name;
        final result = CategoryIconExtension.fromJson(json);
        expect(
          result,
          equals(icon),
          reason: 'Map lookup failed for ${icon.name}',
        );
      }
    });
  });

  // Additive Glados property groups — appended, no existing tests modified.
  hRunCategoryIconGladosTests();
}
