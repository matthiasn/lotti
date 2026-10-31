import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/providers/service_providers.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';

/// Counts the reads and answers each with an empty snapshot.
class _CountingAccess extends QuerySourceAccess {
  _CountingAccess()
    : super(
        journal: MockJournalDb(),
        readLockdown: () => LockdownState.inactive,
      );

  final reads = <Set<String>>[];

  /// Completes on the second read: a reread after a change.
  final reread = Completer<void>();

  @override
  Future<QueryAccessSnapshot> load(Iterable<String> sourceIds) async {
    reads.add(sourceIds.toSet());
    if (reads.length == 2) reread.complete();
    return const QueryAccessSnapshot(
      showPrivate: false,
      categories: {},
      entries: {},
    );
  }
}

/// Holds its first read open until [release] completes.
class _SlowFirstAccess extends _CountingAccess {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<QueryAccessSnapshot> load(Iterable<String> sourceIds) async {
    if (reads.isEmpty) {
      started.complete();
      await release.future;
    }
    return super.load(sourceIds);
  }
}

/// Fails its second read: a reread that breaks.
class _FlakyAccess extends _CountingAccess {
  @override
  Future<QueryAccessSnapshot> load(Iterable<String> sourceIds) async {
    final snapshot = await super.load(sourceIds);
    if (reads.length == 2) throw Exception('reread failed');
    return snapshot;
  }
}

void main() {
  const cited = QuerySourceRef(
    id: 'feeder-note',
    private: false,
    categoryPrivate: false,
  );

  FrontDoorEntry door(int index, FrontDoorOutcome outcome) => FrontDoorEntry(
    doorId: 'd:door:$index',
    record: FrontDoorRecord(
      segmentIndex: index,
      text: 'How is the garden?',
      kind: FrontDestinationKind.journal,
      status: FrontDoorStatus.done,
      claimedAt: DateTime.utc(2026, 10, 31),
      outcome: outcome,
    ),
  );

  final thread = FrontChatThread(
    messages: const [],
    doorsByMessageId: {
      'm-1': [
        door(
          0,
          const FrontDoorAnswer(
            text: 'After the feeder repair [1].',
            summaryBased: false,
            incomplete: false,
            fromJournal: true,
            dependencies: [cited],
          ),
        ),
        // An owner's answer cites nothing here.
        door(
          1,
          const FrontDoorAnswer(
            text: 'The seam walk is next.',
            summaryBased: true,
            incomplete: false,
            dependencies: [
              QuerySourceRef(
                id: 'owner-note',
                private: false,
                categoryPrivate: false,
              ),
            ],
          ),
        ),
        door(2, const FrontDoorInbox()),
      ],
    },
  );

  test('collects only what journal answers cite', () {
    expect(frontJournalSourceIds(thread), {'feeder-note'});
    expect(frontJournalSourceIds(null), isEmpty);
    expect(frontJournalSourceIds(FrontChatThread.empty), isEmpty);
  });

  test('reads the cited sources, and again when the journal changes', () async {
    final db = JournalDb(inMemoryDatabase: true);
    addTearDown(db.close);
    final access = _CountingAccess();
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        journalDbProvider.overrideWithValue(db),
        querySourceAccessProvider.overrideWithValue(access),
        frontChatThreadProvider.overrideWith((ref) async => thread),
      ]),
    );
    addTearDown(container.dispose);
    final sub = container.listen(frontJournalAccessProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(frontChatThreadProvider.future);

    final first = await container.read(frontJournalAccessProvider.future);
    expect(first, isNotNull);
    expect(access.reads, [
      {'feeder-note'},
    ]);

    // Private mode is a config flag: switching it rereads.
    await db.upsertConfigFlag(
      const ConfigFlag(name: 'private', description: 'Private', status: true),
    );
    await access.reread.future;

    expect(access.reads.last, {'feeder-note'});
  });

  test(
    'a failed reread is reported, and the next change reads again',
    () async {
      final db = JournalDb(inMemoryDatabase: true);
      addTearDown(db.close);
      final access = _FlakyAccess();
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          journalDbProvider.overrideWithValue(db),
          querySourceAccessProvider.overrideWithValue(access),
          frontChatThreadProvider.overrideWith((ref) async => thread),
        ]),
      );
      addTearDown(container.dispose);
      final errors = <Object>[];
      final recovered = Completer<QueryAccessSnapshot?>();
      final sub = container.listen(frontJournalAccessProvider, (_, next) {
        if (next.hasError) {
          errors.add(next.error!);
        } else if (errors.isNotEmpty && !recovered.isCompleted) {
          recovered.complete(next.value);
        }
      });
      addTearDown(sub.close);
      await container.read(frontChatThreadProvider.future);
      await container.read(frontJournalAccessProvider.future);

      await db.upsertConfigFlag(
        const ConfigFlag(name: 'private', description: 'Private', status: true),
      );
      await access.reread.future;
      await db.upsertConfigFlag(
        const ConfigFlag(
          name: 'private',
          description: 'Private',
          status: false,
        ),
      );

      expect(await recovered.future, isNotNull);
      expect(errors.single, isA<Exception>());
      expect(access.reads, hasLength(3));
    },
  );

  test('a change while the first read runs is read again, not lost', () async {
    final db = JournalDb(inMemoryDatabase: true);
    addTearDown(db.close);
    final access = _SlowFirstAccess();
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        journalDbProvider.overrideWithValue(db),
        querySourceAccessProvider.overrideWithValue(access),
        frontChatThreadProvider.overrideWith((ref) async => thread),
      ]),
    );
    addTearDown(container.dispose);
    final sub = container.listen(frontJournalAccessProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(frontChatThreadProvider.future);
    await access.started.future;

    // The source turns private while the first read is still out.
    await db.upsertConfigFlag(
      const ConfigFlag(name: 'private', description: 'Private', status: true),
    );
    access.release.complete();
    await access.reread.future;

    expect(access.reads, hasLength(2));
  });

  test('without a journal answer there is nothing to check', () async {
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        frontChatThreadProvider.overrideWith(
          (ref) async => FrontChatThread.empty,
        ),
      ]),
    );
    addTearDown(container.dispose);
    final sub = container.listen(frontJournalAccessProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(frontChatThreadProvider.future);

    expect(await container.read(frontJournalAccessProvider.future), isNull);
  });
}
