import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/state/conflict_resolution_service.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../ui/widgets/conflicts/conflict_test_entities.dart';

void main() {
  late MockPersistenceLogic persistence;
  late MockJournalDb journalDb;
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
            () => persistence.updateJournalEntity(
              captureAny(),
              any(),
              precondition: any(named: 'precondition'),
            ),
          ).captured.single
          as JournalEntity;

  /// The precondition the resolution's write was made under.
  Future<bool> Function() capturedPrecondition() =>
      verify(
            () => persistence.updateJournalEntity(
              any(),
              any(),
              precondition: captureAny(named: 'precondition'),
            ),
          ).captured.single
          as Future<bool> Function();

  setUpAll(registerAllFallbackValues);

  setUp(() {
    persistence = MockPersistenceLogic();
    journalDb = MockJournalDb();
    service = ConflictResolutionService(
      persistenceLogic: persistence,
      journalDb: journalDb,
      // Entry conflicts never reach the checklist repository.
      checklistRepository: () => throw StateError('no checklist repository'),
    );
    when(
      () => persistence.updateJournalEntity(
        any(),
        any(),
        precondition: any(named: 'precondition'),
      ),
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

  // A resolution is built on the sides the page showed, and applies only
  // while the stored row is still the local one: a version stored since —
  // the task agent setting a field — is not replaced by the merged clock
  // (`specs/tla/TaskFieldWrites.tla`, ResolveOnStored).
  group('the write is made only over the local side shown', () {
    final pair = ConflictPair(local: local, remote: remote);

    for (final (name, resolve) in [
      (
        'keepSide',
        () => service.keepSide(pair, ConflictSide.remote),
      ),
      (
        'combine',
        () => service.combine(
          pair,
          baseSide: ConflictSide.local,
          choices: const {},
        ),
      ),
    ]) {
      test('$name: holds while the stored row is the local side', () async {
        when(
          () => journalDb.journalEntityByIdIncludingDeleted(local.id),
        ).thenAnswer((_) async => local);

        await resolve();

        expect(await capturedPrecondition()(), isTrue);
      });

      test('$name: fails once this device stored another version', () async {
        when(
          () => journalDb.journalEntityByIdIncludingDeleted(local.id),
        ).thenAnswer(
          (_) async => local.copyWith(
            meta: local.meta.copyWith(
              vectorClock: const VectorClock({'a': 3}),
            ),
          ),
        );

        await resolve();

        expect(await capturedPrecondition()(), isFalse);
      });
    }

    test('a local side deleted here is the stored row, deleted', () async {
      final deleted = local.copyWith(
        meta: local.meta.copyWith(deletedAt: DateTime(2024, 3, 15)),
      );
      when(
        () => journalDb.journalEntityByIdIncludingDeleted(local.id),
      ).thenAnswer((_) async => deleted);

      await service.keepSide(
        ConflictPair(local: deleted, remote: remote),
        ConflictSide.remote,
      );

      expect(await capturedPrecondition()(), isTrue);
    });

    test('a refused write answers false', () async {
      when(
        () => persistence.updateJournalEntity(
          any(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async => false);

      expect(await service.keepSide(pair, ConflictSide.local), isFalse);
    });
  });

  group('a checklist (ADR 0105)', () {
    late MockChecklistRepository checklists;

    Checklist checklistOf(String title, VectorClock clock) => Checklist(
      meta: Metadata(
        id: 'checklist-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        vectorClock: clock,
      ),
      data: ChecklistData(
        title: title,
        linkedChecklistItems: const [],
        linkedTasks: const ['task-1'],
      ),
    );

    setUp(() {
      checklists = MockChecklistRepository();
      when(() => checklists.resolveConflict(any(), any())).thenAnswer(
        (invocation) =>
            (invocation.positionalArguments[1] as Future<bool> Function())(),
      );
      service = ConflictResolutionService(
        persistenceLogic: persistence,
        checklistRepository: () => checklists,
        journalDb: journalDb,
      );
    });

    test(
      'is written through ChecklistRepository.resolveConflict, which lists a '
      'kept checklist on its task',
      () async {
        final ok = await service.keepSide(
          ConflictPair(
            local: checklistOf('local', const VectorClock({'a': 2})),
            remote: checklistOf('remote', const VectorClock({'b': 3})),
          ),
          ConflictSide.remote,
        );

        expect(ok, isTrue);
        final resolved =
            verify(
                  () => checklists.resolveConflict(captureAny(), any()),
                ).captured.single
                as Checklist;
        expect(resolved.data.title, 'remote');
        expect(capturedWrite(), resolved);
      },
    );

    test('a combined one too', () async {
      await service.combine(
        ConflictPair(
          local: checklistOf('local', const VectorClock({'a': 2})),
          remote: checklistOf('remote', const VectorClock({'b': 3})),
        ),
        baseSide: ConflictSide.local,
        choices: const {},
      );

      verify(() => checklists.resolveConflict(any(), any())).called(1);
    });

    test('any other entry is written directly', () async {
      await service.keepSide(
        ConflictPair(local: local, remote: remote),
        ConflictSide.local,
      );

      verifyNever(() => checklists.resolveConflict(any(), any()));
      capturedWrite();
    });
  });
}
