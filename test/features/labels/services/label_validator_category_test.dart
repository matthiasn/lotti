import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  group('LabelValidator.validateForCategory', () {
    test('validates global vs scoped-to-category correctly', () async {
      final db = MockJournalDb();
      final now = DateTime(2025, 11, 4);

      final global = LabelDefinition(
        id: 'global',
        name: 'Global',
        color: '#999999',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      );
      final scoped = LabelDefinition(
        id: 'scoped',
        name: 'Scoped',
        color: '#ff00ff',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
        applicableCategoryIds: const ['cat1'],
      );
      final deleted = scoped.copyWith(id: 'deleted', deletedAt: now);

      when(() => db.getLabelDefinitionById('global'))
          .thenAnswer((_) async => global);
      when(() => db.getLabelDefinitionById('scoped'))
          .thenAnswer((_) async => scoped);
      when(() => db.getLabelDefinitionById('deleted'))
          .thenAnswer((_) async => deleted);
      when(() => db.getLabelDefinitionById('unknown'))
          .thenAnswer((_) async => null);

      final validator = LabelValidator(db: db);

      // Category cat1 accepts global + scoped
      final resCat1 = await validator
          .validateForCategory(['global', 'scoped'], categoryId: 'cat1');
      expect(resCat1.valid, ['global', 'scoped']);
      expect(resCat1.invalid, isEmpty);

      // Category cat2 accepts only global; scoped becomes invalid (out of scope)
      final resCat2 = await validator
          .validateForCategory(['global', 'scoped'], categoryId: 'cat2');
      expect(resCat2.valid, ['global']);
      expect(resCat2.invalid, ['scoped']);

      // Deleted and unknown become invalid
      final resDeleted = await validator
          .validateForCategory(['deleted', 'unknown'], categoryId: 'cat1');
      expect(resDeleted.valid, isEmpty);
      expect(resDeleted.invalid, ['deleted', 'unknown']);
    });
  });
}
