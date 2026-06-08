import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/categories/domain/category_icon.dart';

// ---------------------------------------------------------------------------
// Generators and Glados property tests for CategoryIconExtension pure methods.
// These groups are appended additive-only; no existing test logic is modified.
// ---------------------------------------------------------------------------

extension AnyCategoryIconEnum on glados.Any {
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

void hRunCategoryIconGladosTests() {
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

  group(
    'CategoryIconExtension — suggestFromName Glados structural invariants',
    () {
      glados.Glados<String?>(
        glados.any.maybeIconString,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'returns null for null, empty, or whitespace-only input',
        (input) {
          // Only assert the null/blank → null contract.
          final isBlank = input == null || input.trim().isEmpty;
          if (isBlank) {
            expect(
              CategoryIconExtension.suggestFromName(input),
              isNull,
              reason: '"$input" is blank and must return null',
            );
          }
        },
        tags: 'glados',
      );

      glados.Glados<CategoryIcon>(
        glados.any.categoryIcon,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'enum name used as category name always returns a non-null icon',
        (icon) {
          // Passing the exact enum name must hit the first match stage.
          final result = CategoryIconExtension.suggestFromName(icon.name);
          expect(
            result,
            isNotNull,
            reason: '${icon.name} should always match itself',
          );
        },
        tags: 'glados',
      );

      glados.Glados<CategoryIcon>(
        glados.any.categoryIcon,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'display name used as category name always returns a non-null icon',
        (icon) {
          // Passing the display name must hit the exact-display-name stage.
          final result = CategoryIconExtension.suggestFromName(
            icon.displayName,
          );
          expect(
            result,
            isNotNull,
            reason: '${icon.displayName} should always match something',
          );
        },
        tags: 'glados',
      );

      glados.Glados<CategoryIcon>(
        glados.any.categoryIcon,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'when a non-null result is returned it is always a valid CategoryIcon',
        (icon) {
          // Use the enum name as input — result must be a member of the enum.
          final result = CategoryIconExtension.suggestFromName(icon.name);
          if (result != null) {
            expect(
              CategoryIcon.values.contains(result),
              isTrue,
              reason: '$result is not a valid CategoryIcon',
            );
          }
        },
        tags: 'glados',
      );
    },
  );

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
class CategoryIconJsonScenario {
  CategoryIconJsonScenario(int iconPick, int mutation) {
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

extension AnyCategoryIconJson on glados.Any {
  glados.Generator<CategoryIconJsonScenario> get categoryIconJsonScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 1 << 12),
        glados.IntAnys(this).intInRange(0, 1 << 12),
        CategoryIconJsonScenario.new,
      );
}
