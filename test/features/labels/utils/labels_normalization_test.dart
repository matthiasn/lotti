import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/utils/labels_normalization.dart';

import '../../categories/test_utils.dart';

/// Known categories the lookup can resolve, with names chosen so that the
/// by-name sort order differs from the by-id order.
final Map<String, CategoryDefinition> _knownCategories = {
  'cat-1': CategoryTestUtils.createTestCategory(id: 'cat-1', name: 'Zebra'),
  'cat-2': CategoryTestUtils.createTestCategory(id: 'cat-2', name: 'apple'),
  'cat-3': CategoryTestUtils.createTestCategory(id: 'cat-3', name: 'Mango'),
};

CategoryDefinition? _lookup(String id) => _knownCategories[id];

/// Token pool: valid IDs, unknown IDs, empties/whitespace, and padded
/// variants of valid IDs (trim must make them valid).
const _tokenPool = <String>[
  'cat-1',
  'cat-2',
  'cat-3',
  'unknown-1',
  'unknown-2',
  '',
  '   ',
  ' cat-1 ',
  '\tcat-2',
];

extension _AnyNormalizationInput on glados.Any {
  glados.Generator<List<String>> get categoryIdTokens =>
      glados.ListAnys(this).listWithLengthInRange(
        0,
        12,
        glados.AnyUtils(this).choose(_tokenPool),
      );
}

void main() {
  group('normalizeLabelCategoryIds — properties', () {
    glados.Glados<List<String>>(
      glados.any.categoryIdTokens,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output equals the trim/dedup/validate/sort-by-name oracle',
      (tokens) {
        final result = normalizeLabelCategoryIds(
          tokens,
          lookupCategory: _lookup,
        );

        // Oracle: independent re-implementation.
        final seen = <String>{};
        final expected = <String>[];
        for (final token in tokens) {
          final id = token.trim();
          if (id.isEmpty || !seen.add(id)) continue;
          if (_knownCategories.containsKey(id)) expected.add(id);
        }
        expected.sort(
          (a, b) => _knownCategories[a]!.name.toLowerCase().compareTo(
            _knownCategories[b]!.name.toLowerCase(),
          ),
        );

        expect(result, expected, reason: 'tokens=$tokens');

        // Structural invariants from the review item.
        expect(result.length, lessThanOrEqualTo(tokens.length));
        expect(result.toSet(), hasLength(result.length), reason: 'no dupes');
        for (final id in result) {
          expect(_knownCategories.containsKey(id), isTrue);
        }

        // Idempotence: normalizing an already-normalized list is a no-op.
        expect(
          normalizeLabelCategoryIds(result, lookupCategory: _lookup),
          result,
        );
      },
      tags: 'glados',
    );

    test('null input yields an empty list', () {
      expect(normalizeLabelCategoryIds(null, lookupCategory: _lookup), isEmpty);
    });

    test('sorts by category name, not by id', () {
      // cat-2 (apple) < cat-3 (Mango) < cat-1 (Zebra) by lower-cased name.
      expect(
        normalizeLabelCategoryIds(
          ['cat-1', 'cat-2', 'cat-3'],
          lookupCategory: _lookup,
        ),
        ['cat-2', 'cat-3', 'cat-1'],
      );
    });
  });
}
