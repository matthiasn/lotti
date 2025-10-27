// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  late MockJournalDb mockDb;

  setUp(() {
    mockDb = MockJournalDb();
  });

  LabelDefinition makeLabel(String id, {bool deleted = false}) =>
      LabelDefinition(
        id: id,
        name: id,
        color: '#000',
        description: null,
        sortOrder: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        deletedAt: deleted ? DateTime.now() : null,
      );

  test('validates labels: valid vs invalid and deleted treated as invalid',
      () async {
    when(() => mockDb.getLabelDefinitionById('valid'))
        .thenAnswer((_) async => makeLabel('valid'));
    when(() => mockDb.getLabelDefinitionById('deleted'))
        .thenAnswer((_) async => makeLabel('deleted', deleted: true));
    when(() => mockDb.getLabelDefinitionById('missing'))
        .thenAnswer((_) async => null);
    when(() => mockDb.getLabelDefinitionById('')).thenAnswer((_) async => null);

    final validator = LabelValidator(db: mockDb);
    final res = await validator.validate([
      'valid',
      'deleted',
      'missing',
      '',
    ]);

    expect(res.valid, equals(['valid']));
    expect(res.invalid, containsAll(['deleted', 'missing', '']));
  });

  test('handles concurrent validation requests reliably', () async {
    // Simulate slow DB responses
    when(() => mockDb.getLabelDefinitionById(any()))
        .thenAnswer((invocation) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final id = invocation.positionalArguments.first as String;
      return makeLabel(id);
    });

    final validator = LabelValidator(db: mockDb);
    final futures = List.generate(
      8,
      (i) => validator.validate(['label-$i']),
    );

    final results = await Future.wait(futures);
    expect(results.length, 8);
    for (final r in results) {
      expect(r.valid.length, 1);
      expect(r.invalid, isEmpty);
    }
  });
}
