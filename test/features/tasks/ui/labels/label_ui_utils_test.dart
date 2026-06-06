import 'package:flutter_test/flutter_test.dart';
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
}
