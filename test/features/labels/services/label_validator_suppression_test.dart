import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  test('validateForTask separates suppressed from invalid/valid', () async {
    final db = MockJournalDb();
    final validator = LabelValidator(db: db);

    // Labels: a (global), e1 (engineering), d1 (design, out-of-scope), z (deleted)
    when(() => db.getLabelDefinitionById('a'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'a',
              name: 'Alpha',
              color: '#000',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));
    when(() => db.getLabelDefinitionById('e1'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'e1',
              name: 'Engineering',
              color: '#000',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
              applicableCategoryIds: const ['engineering'],
            ));
    when(() => db.getLabelDefinitionById('d1'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'd1',
              name: 'Design',
              color: '#000',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
              applicableCategoryIds: const ['design'],
            ));
    when(() => db.getLabelDefinitionById('z'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'z',
              name: 'Zed',
              color: '#000',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
              deletedAt: DateTime.now(),
            ));

    final res = await validator.validateForTask(
      const ['a', 'e1', 'd1', 'z'],
      categoryId: 'engineering',
      suppressedIds: const {'e1'},
    );

    expect(res.valid.toSet(), {'a'});
    expect(res.suppressed.toSet(), {'e1'});
    expect(res.invalid.toSet(), {'d1', 'z'});
  });

  test('deleted label in suppressed set is treated as invalid (deletion wins)',
      () async {
    final db = MockJournalDb();
    final validator = LabelValidator(db: db);

    // z is deleted and also in suppression set
    when(() => db.getLabelDefinitionById('z'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'z',
              name: 'Zed',
              color: '#000',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
              deletedAt: DateTime.now(),
            ));

    final res = await validator.validateForTask(
      const ['z'],
      categoryId: 'engineering',
      suppressedIds: const {'z'},
    );

    // Deleted takes precedence over suppression
    expect(res.invalid, contains('z'));
    expect(res.suppressed, isEmpty);
    expect(res.valid, isEmpty);
  });
}
