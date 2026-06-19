import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/state/conflict_resolution_service.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../ui/widgets/conflicts/conflict_test_entities.dart';

void main() {
  late MockJournalDb db;
  late MockPersistenceLogic persistence;
  late ConflictResolutionService service;

  final local = entryOf(
    text: 'local body',
    categoryId: 'cat-l',
    vectorClock: const VectorClock({'a': 2}),
  );
  final remote = entryOf(
    text: 'remote body',
    categoryId: 'cat-r',
    vectorClock: const VectorClock({'b': 3}),
  );

  Conflict conflictRow() => Conflict(
    id: 'e1',
    createdAt: DateTime(2024, 3, 15, 14),
    updatedAt: DateTime(2024, 3, 15, 15),
    serialized: jsonEncode(remote.toJson()),
    schemaVersion: 1,
    status: ConflictStatus.unresolved.index,
  );

  JournalEntity capturedWrite() =>
      verify(
            () => persistence.updateJournalEntity(captureAny(), any()),
          ).captured.single
          as JournalEntity;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    db = MockJournalDb();
    persistence = MockPersistenceLogic();
    service = ConflictResolutionService(db: db, persistenceLogic: persistence);
    when(
      () => persistence.updateJournalEntity(any(), any()),
    ).thenAnswer((_) async => true);
  });

  group('loadPair', () {
    test(
      'returns both versions and a diff when conflict + entry exist',
      () async {
        when(
          () => db.conflictById('e1'),
        ).thenAnswer((_) async => conflictRow());
        when(() => db.journalEntityById('e1')).thenAnswer((_) async => local);

        final pair = await service.loadPair('e1');

        expect(pair, isNotNull);
        expect(pair!.local.entryText?.plainText, 'local body');
        expect(pair.remote.entryText?.plainText, 'remote body');
        expect(pair.diff.fields.map((f) => f.field), contains(EntryField.body));
        expect(
          pair.diff.fields.map((f) => f.field),
          contains(EntryField.category),
        );
      },
    );

    test('returns null when the conflict row is gone', () async {
      when(() => db.conflictById('e1')).thenAnswer((_) async => null);
      expect(await service.loadPair('e1'), isNull);
      verifyNever(() => db.journalEntityById(any()));
    });

    test('returns null when the serialized payload is malformed', () async {
      final badConflict = Conflict(
        id: 'e1',
        createdAt: DateTime(2024, 3, 15, 14),
        updatedAt: DateTime(2024, 3, 15, 15),
        serialized: 'not-json',
        schemaVersion: 1,
        status: ConflictStatus.unresolved.index,
      );
      when(() => db.conflictById('e1')).thenAnswer((_) async => badConflict);
      when(() => db.journalEntityById('e1')).thenAnswer((_) async => local);
      expect(await service.loadPair('e1'), isNull);
    });

    test('returns null when the local entry is gone', () async {
      when(() => db.conflictById('e1')).thenAnswer((_) async => conflictRow());
      when(() => db.journalEntityById('e1')).thenAnswer((_) async => null);
      expect(await service.loadPair('e1'), isNull);
    });
  });

  group('resolution', () {
    late ConflictPair pair;
    setUp(() {
      pair = ConflictPair(
        conflict: conflictRow(),
        local: local,
        remote: remote,
      );
    });

    test(
      'keepSide(local) writes the local side with the merged clock',
      () async {
        final ok = await service.keepSide(pair, ConflictSide.local);

        expect(ok, isTrue);
        final written = capturedWrite();
        expect(written.entryText?.plainText, 'local body');
        expect(written.meta.vectorClock, const VectorClock({'a': 2, 'b': 3}));
      },
    );

    test('keepSide(remote) writes the remote side', () async {
      await service.keepSide(pair, ConflictSide.remote);
      expect(capturedWrite().entryText?.plainText, 'remote body');
    });

    test('combine writes the per-field merge of both sides', () async {
      await service.combine(
        pair,
        baseSide: ConflictSide.local,
        choices: {EntryField.category: ConflictSide.remote},
      );

      final written = capturedWrite();
      // Body follows the base (local); category was pulled from remote.
      expect(written.entryText?.plainText, 'local body');
      expect(written.meta.categoryId, 'cat-r');
    });
  });
}
