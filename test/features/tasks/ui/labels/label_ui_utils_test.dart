import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/ui/labels/label_ui_utils.dart';

LabelDefinition _label(
  String id, {
  String? name,
  String? description,
}) {
  return LabelDefinition(
    id: id,
    name: name ?? id,
    color: '#FF0000',
    description: description,
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    vectorClock: const VectorClock(<String, int>{}),
    private: false,
  );
}

void main() {
  group('buildUnionLabels', () {
    test('merges available and assigned labels without duplicates', () {
      final union = buildUnionLabels(
        [_label('a'), _label('b')],
        [_label('b'), _label('c')],
      );

      expect(union.map((l) => l.id).toSet(), {'a', 'b', 'c'});
      expect(union, hasLength(3));
    });

    test('assigned definitions win over available ones for the same id', () {
      final union = buildUnionLabels(
        [_label('a', name: 'Available name')],
        [_label('a', name: 'Assigned name')],
      );

      expect(union.single.name, 'Assigned name');
    });
  });

  group('buildLabelSubtitleText', () {
    test('joins the out-of-category note and the description', () {
      expect(
        buildLabelSubtitleText(
          _label('a', description: 'A label'),
          outOfCategory: true,
        ),
        'Out of category • A label',
      );
    });

    test('returns just the note when there is no description', () {
      expect(
        buildLabelSubtitleText(_label('a'), outOfCategory: true),
        'Out of category',
      );
      // Whitespace-only descriptions count as absent.
      expect(
        buildLabelSubtitleText(
          _label('a', description: '   '),
          outOfCategory: true,
        ),
        'Out of category',
      );
    });

    test('returns just the description when in category', () {
      expect(
        buildLabelSubtitleText(
          _label('a', description: 'A label'),
          outOfCategory: false,
        ),
        'A label',
      );
    });

    test('returns null with neither note nor description', () {
      expect(buildLabelSubtitleText(_label('a'), outOfCategory: false), isNull);
      expect(
        buildLabelSubtitleText(
          _label('a', description: ''),
          outOfCategory: false,
        ),
        isNull,
      );
    });
  });

  group('buildSelectorLabelList', () {
    test('empty search keeps the full union sorted A–Z by name', () {
      final result = buildSelectorLabelList(
        available: [
          _label('1', name: 'zebra'),
          _label('2', name: 'Apple'),
        ],
        assignedDefs: [_label('3', name: 'mango')],
        selectedIds: {'3'},
        searchLower: '',
      );

      expect(result.items.map((l) => l.name), ['Apple', 'mango', 'zebra']);
      // availableIds reflects only the available list, not assigned extras.
      expect(result.availableIds, {'1', '2'});
    });

    test('filters by name or description, case-insensitively', () {
      final result = buildSelectorLabelList(
        available: [
          _label('1', name: 'Urgent'),
          _label('2', name: 'Backlog', description: 'urgently needed'),
          _label('3', name: 'Misc'),
        ],
        assignedDefs: const [],
        selectedIds: const {},
        searchLower: 'urgent',
      );

      expect(result.items.map((l) => l.id), {'1', '2'});
    });

    test('sorting ignores selection state and letter case', () {
      final result = buildSelectorLabelList(
        available: [
          _label('1', name: 'beta'),
          _label('2', name: 'Alpha'),
        ],
        assignedDefs: [_label('3', name: 'aardvark')],
        selectedIds: {'1'},
        searchLower: '',
      );

      expect(result.items.map((l) => l.name), ['aardvark', 'Alpha', 'beta']);
    });
  });

  group('buildSelectorLabelList properties', () {
    glados.Glados2(
      glados.any.labelSpecList,
      glados.any.searchTerm,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'filtered list is a sorted subset of the union matching the search',
      (specs, searchLower) {
        final available = [
          for (final (i, spec) in specs.indexed)
            if (i.isEven) spec.toLabel(i),
        ];
        final assigned = [
          for (final (i, spec) in specs.indexed)
            if (i.isOdd) spec.toLabel(i),
        ];

        final result = buildSelectorLabelList(
          available: available,
          assignedDefs: assigned,
          selectedIds: {for (final l in assigned) l.id},
          searchLower: searchLower,
        );

        final union = buildUnionLabels(available, assigned);
        final unionIds = union.map((l) => l.id).toSet();
        final reason = 'specs=$specs search="$searchLower"';

        // availableIds mirrors exactly the available list.
        expect(
          result.availableIds,
          available.map((l) => l.id).toSet(),
          reason: reason,
        );

        // Every produced item comes from the union and matches the search.
        for (final item in result.items) {
          expect(unionIds, contains(item.id), reason: reason);
          expect(
            item.name.toLowerCase().contains(searchLower) ||
                (item.description?.toLowerCase().contains(searchLower) ??
                    false),
            isTrue,
            reason: '$reason item=${item.id}',
          );
        }

        // Nothing matching was dropped.
        final expectedMatchCount = union
            .where(
              (l) =>
                  l.name.toLowerCase().contains(searchLower) ||
                  (l.description?.toLowerCase().contains(searchLower) ?? false),
            )
            .length;
        expect(result.items, hasLength(expectedMatchCount), reason: reason);

        // Strict A-Z ordering, independent of selection state.
        for (var i = 1; i < result.items.length; i++) {
          expect(
            compareAsciiLowerCase(
              result.items[i - 1].name,
              result.items[i].name,
            ),
            lessThanOrEqualTo(0),
            reason: reason,
          );
        }
      },
      tags: 'glados',
    );
  });
}

class _GeneratedLabelSpec {
  const _GeneratedLabelSpec({required this.name, this.description});

  final String name;
  final String? description;

  LabelDefinition toLabel(int index) =>
      _label('id-$index', name: name, description: description);

  @override
  String toString() =>
      '_GeneratedLabelSpec(name: $name, description: $description)';
}

extension _AnyLabelSpec on glados.Any {
  glados.Generator<String> get _word =>
      glados.StringAnys(this).stringOf('abuz');

  glados.Generator<_GeneratedLabelSpec> get labelSpec =>
      glados.CombinableAny(this).combine2(
        _word,
        _word,
        (String name, String desc) => _GeneratedLabelSpec(
          name: name.isEmpty ? 'x' : name,
          description: desc.isEmpty ? null : desc,
        ),
      );

  glados.Generator<List<_GeneratedLabelSpec>> get labelSpecList =>
      glados.ListAnys(this).listWithLengthInRange(0, 8, labelSpec);

  glados.Generator<String> get searchTerm =>
      glados.StringAnys(this).stringOf('abuz');
}
