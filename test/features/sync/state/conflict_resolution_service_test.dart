import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/state/conflict_resolution_service.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../ui/widgets/conflicts/conflict_test_entities.dart';

void main() {
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

  JournalEntity capturedWrite() =>
      verify(
            () => persistence.updateJournalEntity(captureAny(), any()),
          ).captured.single
          as JournalEntity;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    persistence = MockPersistenceLogic();
    service = ConflictResolutionService(persistenceLogic: persistence);
    when(
      () => persistence.updateJournalEntity(any(), any()),
    ).thenAnswer((_) async => true);
  });

  group('resolution', () {
    late ConflictPair pair;
    setUp(() {
      pair = ConflictPair(
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
