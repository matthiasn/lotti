import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/utils/assigned_labels_util.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

LabelDefinition _label(String id, String name) => LabelDefinition(
  id: id,
  name: name,
  color: '#FF0000',
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  vectorClock: const VectorClock(<String, int>{}),
  private: false,
);

void main() {
  late MockJournalDb db;

  setUp(() {
    db = MockJournalDb();
  });

  group('buildAssignedLabelTuples', () {
    test('short-circuits to an empty list without touching the DB', () async {
      final tuples = await buildAssignedLabelTuples(db: db, ids: const []);

      expect(tuples, isEmpty);
      verifyNever(() => db.getAllLabelDefinitions());
    });

    test('resolves names from the label definitions', () async {
      when(() => db.getAllLabelDefinitions()).thenAnswer(
        (_) async => [_label('l1', 'Urgent'), _label('l2', 'Backlog')],
      );

      final tuples = await buildAssignedLabelTuples(
        db: db,
        ids: const ['l2', 'l1'],
      );

      expect(tuples, [
        {'id': 'l2', 'name': 'Backlog'},
        {'id': 'l1', 'name': 'Urgent'},
      ]);
    });

    test('falls back to the raw id when a definition is missing', () async {
      when(() => db.getAllLabelDefinitions()).thenAnswer(
        (_) async => [_label('l1', 'Urgent')],
      );

      final tuples = await buildAssignedLabelTuples(
        db: db,
        ids: const ['l1', 'ghost-id'],
      );

      expect(tuples, [
        {'id': 'l1', 'name': 'Urgent'},
        {'id': 'ghost-id', 'name': 'ghost-id'},
      ]);
    });
  });
}
