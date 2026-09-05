import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('CategoryIcon', () {
    group('iconData', () {
      test('should return correct IconData for all enum values', () {
        // Verify that all enum values have corresponding IconData
        for (final icon in CategoryIcon.values) {
          expect(icon.iconData, isA<IconData>());
        }
      });

      test('every category shows a different picture', () {
        // This is a *picker*: two choices that draw the same glyph are
        // indistinguishable to the person choosing, no matter how different
        // their names are. Material kept several of these apart only by
        // spelling — `menu_book` vs `book`, `restaurant` vs `local_dining`,
        // `self_improvement` vs `psychology` vs `mdi:headHeart` — and Lucide
        // has one glyph for each of those pairs, so the migration collapsed
        // eleven choices into look-alikes. (One pair, heartHealth and
        // relationships, was already identical before it.)
        final byGlyph = <int, List<CategoryIcon>>{};
        for (final icon in CategoryIcon.values) {
          byGlyph.putIfAbsent(icon.iconData.codePoint, () => []).add(icon);
        }
        final collisions = byGlyph.values.where((v) => v.length > 1).toList();

        expect(
          collisions,
          isEmpty,
          reason: 'these categories are drawn identically: $collisions',
        );
      });

      test('should return specific icons for known values', () {
        expect(CategoryIcon.fitness.iconData, equals(LottiIcons.fitness));
        expect(CategoryIcon.running.iconData, equals(LottiIcons.running));
        expect(CategoryIcon.yoga.iconData, equals(LucideIcons.accessibility));
        expect(CategoryIcon.home.iconData, equals(LottiIcons.home));
        expect(CategoryIcon.reading.iconData, equals(LucideIcons.bookOpen));
      });

      test('should return correct icons for new category icons', () {
        expect(CategoryIcon.cycling.iconData, equals(LottiIcons.cycling));
        expect(CategoryIcon.hiking.iconData, equals(LucideIcons.mountain));
        expect(CategoryIcon.pets.iconData, equals(LucideIcons.pawPrint));
        expect(CategoryIcon.coffee.iconData, equals(LucideIcons.coffee));
        expect(CategoryIcon.email.iconData, equals(LucideIcons.mail));
        expect(CategoryIcon.movie.iconData, equals(LucideIcons.clapperboard));
        expect(CategoryIcon.podcast.iconData, equals(LucideIcons.podcast));
        expect(CategoryIcon.coding.iconData, equals(LottiIcons.code));
        expect(CategoryIcon.banking.iconData, equals(LucideIcons.landmark));
        expect(CategoryIcon.celebration.iconData, equals(LottiIcons.celebrate));
        expect(CategoryIcon.science.iconData, equals(LottiIcons.science));
        expect(CategoryIcon.spa.iconData, equals(LucideIcons.flower2));
        expect(CategoryIcon.nature.iconData, equals(LucideIcons.trees));
        expect(
          CategoryIcon.volunteer.iconData,
          equals(LucideIcons.handHelping),
        );
        expect(CategoryIcon.camping.iconData, equals(LucideIcons.tent));
        expect(CategoryIcon.cooking.iconData, equals(LucideIcons.chefHat));
        expect(
          CategoryIcon.prayer.iconData,
          equals(LucideIcons.handHeart),
        );
        expect(
          CategoryIcon.gratitude.iconData,
          equals(LucideIcons.sparkles),
        );
      });
    });

    group('displayName', () {
      test('should return human-readable names for all enum values', () {
        // Verify that all enum values have display names
        for (final icon in CategoryIcon.values) {
          expect(icon.displayName, isNotEmpty);
          expect(icon.displayName, isA<String>());
        }
      });

      test('should return specific display names for known values', () {
        expect(CategoryIcon.fitness.displayName, equals('Fitness'));
        expect(CategoryIcon.heartHealth.displayName, equals('Heart Health'));
        expect(CategoryIcon.laptop.displayName, equals('Computer Work'));
        expect(CategoryIcon.mentalHealth.displayName, equals('Mental Health'));
      });

      test('should return correct display names for new icons', () {
        expect(CategoryIcon.cycling.displayName, equals('Cycling'));
        expect(CategoryIcon.hiking.displayName, equals('Hiking'));
        expect(CategoryIcon.pets.displayName, equals('Pets'));
        expect(CategoryIcon.cooking.displayName, equals('Cooking'));
        expect(CategoryIcon.coffee.displayName, equals('Coffee'));
        expect(CategoryIcon.movie.displayName, equals('Movies'));
        expect(CategoryIcon.podcast.displayName, equals('Podcast'));
        expect(CategoryIcon.coding.displayName, equals('Coding'));
        expect(CategoryIcon.videoCall.displayName, equals('Video Call'));
        expect(CategoryIcon.prayer.displayName, equals('Prayer'));
        expect(CategoryIcon.gratitude.displayName, equals('Gratitude'));
        expect(CategoryIcon.spa.displayName, equals('Self-Care'));
        expect(CategoryIcon.cake.displayName, equals('Birthday'));
        expect(CategoryIcon.volunteer.displayName, equals('Volunteering'));
        expect(CategoryIcon.recycling.displayName, equals('Recycling'));
      });

      test('should have unique display names', () {
        final displayNames = CategoryIcon.values
            .map((e) => e.displayName)
            .toSet();
        expect(displayNames.length, equals(CategoryIcon.values.length));
      });
    });

    group('JSON serialization', () {
      test('toJson should return enum name', () {
        expect(CategoryIcon.fitness.toJson(), equals('fitness'));
        expect(CategoryIcon.heartHealth.toJson(), equals('heartHealth'));
        expect(CategoryIcon.mentalHealth.toJson(), equals('mentalHealth'));
      });

      test('fromJson should parse valid enum names', () {
        expect(
          CategoryIconExtension.fromJson('fitness'),
          equals(CategoryIcon.fitness),
        );
        expect(
          CategoryIconExtension.fromJson('heartHealth'),
          equals(CategoryIcon.heartHealth),
        );
        expect(
          CategoryIconExtension.fromJson('mentalHealth'),
          equals(CategoryIcon.mentalHealth),
        );
      });

      test('fromJson should return null for null input', () {
        expect(CategoryIconExtension.fromJson(null), isNull);
      });

      test('fromJson should return null for empty input', () {
        expect(CategoryIconExtension.fromJson(''), isNull);
        expect(CategoryIconExtension.fromJson('   '), isNull);
      });

      test('fromJson should return null for invalid input', () {
        expect(CategoryIconExtension.fromJson('invalid_icon'), isNull);
        expect(CategoryIconExtension.fromJson('xyz123'), isNull);
      });

      test('fromJson should handle whitespace', () {
        expect(
          CategoryIconExtension.fromJson('  fitness  '),
          equals(CategoryIcon.fitness),
        );
        expect(
          CategoryIconExtension.fromJson('\theartHealth\n'),
          equals(CategoryIcon.heartHealth),
        );
      });

      test('roundtrip serialization should work', () {
        for (final icon in CategoryIcon.values) {
          final json = icon.toJson();
          final restored = CategoryIconExtension.fromJson(json);
          expect(restored, equals(icon));
        }
      });
    });
  });

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
      expect('Choose icon', isNotEmpty);
      expect('Icon', isNotEmpty);
      expect('Tap to select a different icon', isNotEmpty);
      expect('Tap to select an icon', isNotEmpty);
      expect('Choose an icon', isNotEmpty);
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
  _runCategoryIconGladosTests();
}

// ---------------------------------------------------------------------------
// Generators and Glados property tests for CategoryIconExtension pure methods.
// These groups are appended additive-only; no existing test logic is modified.
// ---------------------------------------------------------------------------

extension _AnyCategoryIconEnum on glados.Any {
  /// Generates any valid [CategoryIcon] enum value.
  glados.Generator<CategoryIcon> get categoryIcon =>
      glados.AnyUtils(this).choose(CategoryIcon.values);

  /// Generates a nullable arbitrary string that may or may not be a valid
  /// icon name.  Used to probe `fromJson` defensively.
  glados.Generator<String?> get maybeIconString =>
      glados.AnyUtils(this).choose(<String?>[
        null,
        '',
        '  ',
        'fitness',
        'running',
        'yoga',
        'heartHealth',
        'checklist',
        'garbage',
        'YOGA',
        '123_invalid',
        'recycling',
      ]);
}

void _runCategoryIconGladosTests() {
  group('CategoryIconExtension — fromJson/toJson Glados roundtrip', () {
    glados.Glados<CategoryIcon>(
      glados.any.categoryIcon,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'toJson then fromJson returns the original icon for every enum value',
      (icon) {
        final json = icon.toJson();
        final restored = CategoryIconExtension.fromJson(json);
        expect(
          restored,
          equals(icon),
          reason: 'roundtrip failed for ${icon.name}',
        );
      },
      tags: 'glados',
    );

    test(
      '_byName map is complete and collision-free: every enum value '
      'round-trips through the O(1) lookup (exhaustive)',
      () {
        // No duplicate names: a collision would make the map smaller than
        // the enum, silently shadowing one icon in fromJson.
        final names = CategoryIcon.values.map((e) => e.name).toSet();
        expect(names, hasLength(CategoryIcon.values.length));

        // Every value resolves back to itself through the map-backed lookup.
        for (final icon in CategoryIcon.values) {
          expect(
            CategoryIconExtension.fromJson(icon.name),
            icon,
            reason: '${icon.name} must round-trip through _byName',
          );
        }
      },
    );

    glados.Glados<CategoryIcon>(
      glados.any.categoryIcon,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'toJson result is always equal to the enum name',
      (icon) {
        expect(icon.toJson(), equals(icon.name));
      },
      tags: 'glados',
    );

    glados.Glados<String?>(
      glados.any.maybeIconString,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'fromJson returns non-null iff trimmed input is an exact enum name',
      (input) {
        final result = CategoryIconExtension.fromJson(input);
        final trimmed = input?.trim() ?? '';
        final isValidName = CategoryIcon.values.any(
          (icon) => icon.name == trimmed,
        );
        if (isValidName) {
          expect(
            result,
            isNotNull,
            reason: '"$input" should parse to a CategoryIcon',
          );
        } else {
          expect(
            result,
            isNull,
            reason: '"$input" should not parse to any CategoryIcon',
          );
        }
      },
      tags: 'glados',
    );
  });

  group('fromJson/toJson properties', () {
    glados.Glados(
      glados.any.categoryIconJsonScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'fromJson resolves iff the trimmed input is an exact name; '
      'roundtrip is identity',
      (scenario) {
        final parsed = CategoryIconExtension.fromJson(scenario.json);

        final trimmed = scenario.json?.trim();
        final exact = CategoryIcon.values
            .where((i) => i.name == trimmed)
            .firstOrNull;
        expect(parsed, exact, reason: '"${scenario.json}"');

        // Roundtrip identity for the real value backing the scenario.
        expect(
          CategoryIconExtension.fromJson(scenario.icon.toJson()),
          scenario.icon,
        );
      },
      tags: 'glados',
    );
  });
}

/// Deterministic (icon, json) scenario mixing exact names, padded names,
/// case mutations, unknown strings, empty and null inputs.
class _CategoryIconJsonScenario {
  _CategoryIconJsonScenario(int iconPick, int mutation) {
    icon = CategoryIcon.values[iconPick % CategoryIcon.values.length];
    json = switch (mutation % 6) {
      0 => icon.name,
      1 => '  ${icon.name}  ',
      2 => icon.name.toUpperCase(),
      3 => 'not-an-icon-$mutation',
      4 => '',
      _ => null,
    };
  }

  late final CategoryIcon icon;
  late final String? json;
}

extension _AnyCategoryIconJson on glados.Any {
  glados.Generator<_CategoryIconJsonScenario> get categoryIconJsonScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 1 << 12),
        glados.IntAnys(this).intInRange(0, 1 << 12),
        _CategoryIconJsonScenario.new,
      );
}
