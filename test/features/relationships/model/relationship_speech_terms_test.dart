import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/model/relationship_speech_terms.dart';

import '../../../test_data/test_data.dart';

RelationshipEntry _person(
  String id,
  String title, {
  String? nickname,
  List<String> knownTerms = const [],
  String? categoryId = 'penguin-operations',
  bool private = false,
  bool deleted = false,
}) => testRelationship.copyWith(
  meta: testRelationship.meta.copyWith(
    id: id,
    categoryId: categoryId,
    private: private,
    deletedAt: deleted ? DateTime(2026, 9) : null,
  ),
  data: testRelationship.data.copyWith(
    title: title,
    nickname: nickname,
    knownTerms: knownTerms,
  ),
);

void main() {
  final frida = _person(
    'frida',
    'Frida Kjellsen',
    nickname: 'Fri',
    knownTerms: const ['Wanja', 'Waddle One'],
  );

  test('lists the person, their own names, then their category', () {
    final terms = relationshipKnownTerms(
      person: frida,
      people: [
        frida,
        _person('pingo', 'Pingo Floe', nickname: 'Captain'),
        _person('sula', 'Sula Drift'),
      ],
    );

    expect(terms, [
      'Frida Kjellsen',
      'Fri',
      'Wanja',
      'Waddle One',
      'Pingo Floe',
      'Captain',
      'Sula Drift',
    ]);
  });

  test('leaves out other categories, private and deleted people', () {
    final terms = relationshipKnownTerms(
      person: frida,
      people: [
        _person('other', 'Mission Control', categoryId: 'fish-diplomacy'),
        _person('secret', 'Quiet Pebble', private: true),
        _person('gone', 'Old Floe', deleted: true),
      ],
    );

    expect(terms, ['Frida Kjellsen', 'Fri', 'Wanja', 'Waddle One']);
  });

  test('keeps a private person their own names', () {
    final private = _person('solo', 'Quiet Pebble', private: true);

    expect(
      relationshipKnownTerms(person: private, people: [private]),
      ['Quiet Pebble'],
    );
  });

  test('borrows no one else when the person has no category', () {
    final uncategorised = _person('loner', 'Iceberg Ida', categoryId: null);

    expect(
      relationshipKnownTerms(
        person: uncategorised,
        people: [_person('x', 'Sula Drift', categoryId: null)],
      ),
      ['Iceberg Ida'],
    );
  });
}
