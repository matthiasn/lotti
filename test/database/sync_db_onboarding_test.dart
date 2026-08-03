import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';

import 'sync_db_test_utils.dart';

void main() {
  late SyncDatabase db;

  setUpAll(() {
    db = SyncDatabase(inMemoryDatabase: true);
  });

  setUp(() => clearAllSyncTables(db));

  tearDownAll(() => db.close());

  test('returns only unexpired active inbound suppression rounds', () async {
    final now = DateTime(2024, 3, 15, 12);

    Future<void> insertRound({
      required String roundId,
      required String direction,
      required String state,
      required DateTime expiresAt,
    }) {
      return db.upsertOnboardingSyncRound(
        OnboardingSyncRoundsCompanion.insert(
          roundId: roundId,
          direction: direction,
          state: state,
          senderHostId: 'desktop-host',
          recipientUserId: '@sync:example.org',
          recipientDeviceId: 'PHONE',
          coverageUpperBoundsJson: '{"desktop-host":100}',
          startedAt: now.subtract(const Duration(minutes: 10)),
          updatedAt: now.subtract(const Duration(minutes: 5)),
          expiresAt: expiresAt,
        ),
      );
    }

    await insertRound(
      roundId: 'active-inbound',
      direction: 'inbound',
      state: 'active',
      expiresAt: now.add(const Duration(minutes: 50)),
    );
    await insertRound(
      roundId: 'expired-inbound',
      direction: 'inbound',
      state: 'active',
      expiresAt: now.subtract(const Duration(seconds: 1)),
    );
    await insertRound(
      roundId: 'completed-inbound',
      direction: 'inbound',
      state: 'completed',
      expiresAt: now.add(const Duration(minutes: 50)),
    );
    await insertRound(
      roundId: 'active-outbound',
      direction: 'outbound',
      state: 'active',
      expiresAt: now.add(const Duration(minutes: 50)),
    );

    final active = await db.activeInboundOnboardingSyncRounds(now: now);

    expect(active.map((round) => round.roundId), ['active-inbound']);
  });

  test(
    'preflight remains active until adoption, cancellation, or expiry',
    () async {
      final now = DateTime(2024, 3, 15, 12);

      Future<void> insertPreflight({
        required String roundId,
        required String userId,
        required DateTime expiresAt,
      }) {
        return db.upsertOnboardingSyncRound(
          OnboardingSyncRoundsCompanion.insert(
            roundId: roundId,
            direction: 'inbound',
            state: 'awaitingBegin',
            senderHostId: '',
            recipientUserId: userId,
            recipientDeviceId: '',
            coverageUpperBoundsJson: '{}',
            startedAt: now,
            updatedAt: now,
            expiresAt: expiresAt,
          ),
        );
      }

      await insertPreflight(
        roundId: 'matching-preflight',
        userId: '@sync:example.org',
        expiresAt: now.add(const Duration(hours: 1)),
      );
      await insertPreflight(
        roundId: 'other-user-preflight',
        userId: '@other:example.org',
        expiresAt: now.add(const Duration(hours: 1)),
      );
      await insertPreflight(
        roundId: 'expired-preflight',
        userId: '@sync:example.org',
        expiresAt: now,
      );

      expect(
        await db.hasActiveInboundOnboardingSyncPreflight(now: now),
        isTrue,
      );

      await db.adoptInboundOnboardingSyncPreflights(
        recipientUserId: '@sync:example.org',
        now: now,
      );

      expect(
        (await db.onboardingSyncRound('matching-preflight'))?.state,
        'adopted',
      );
      expect(
        (await db.onboardingSyncRound('expired-preflight'))?.state,
        'awaitingBegin',
        reason: 'an expired historical row does not need mutation',
      );
      expect(
        await db.hasActiveInboundOnboardingSyncPreflight(now: now),
        isTrue,
        reason: 'another account still has an independent active preflight',
      );

      await db.updateOnboardingSyncRound(
        'other-user-preflight',
        OnboardingSyncRoundsCompanion(
          state: const Value('cancelled'),
          updatedAt: Value(now),
        ),
      );
      expect(
        await db.hasActiveInboundOnboardingSyncPreflight(now: now),
        isFalse,
      );
    },
  );

  test('bulk burned coverage preserves payload-backed terminal rows', () async {
    final now = DateTime(2024, 3, 15, 12);
    const hostId = 'desktop-host';

    await db.batchInsertSequenceEntries([
      SyncSequenceLogCompanion(
        hostId: const Value(hostId),
        counter: const Value(1),
        entryId: const Value('entry-1'),
        status: Value(SyncSequenceStatus.received.index),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      SyncSequenceLogCompanion(
        hostId: const Value(hostId),
        counter: const Value(2),
        status: Value(SyncSequenceStatus.missing.index),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      SyncSequenceLogCompanion(
        hostId: const Value(hostId),
        counter: const Value(3),
        status: Value(SyncSequenceStatus.requested.index),
        requestCount: const Value(2),
        lastRequestedAt: Value(now.subtract(const Duration(minutes: 5))),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    ]);

    await db.applyAuthoritativeBurnedCounters(
      hostId: hostId,
      counters: const [1, 2, 3, 4],
      now: now.add(const Duration(minutes: 1)),
    );

    final rows =
        await (db.select(db.syncSequenceLog)
              ..where((t) => t.hostId.equals(hostId))
              ..orderBy([(t) => OrderingTerm(expression: t.counter)]))
            .get();
    expect(rows.map((row) => row.counter), [1, 2, 3, 4]);
    expect(rows.first.status, SyncSequenceStatus.received.index);
    expect(rows.first.entryId, 'entry-1');
    expect(
      rows.skip(1).map((row) => row.status),
      everyElement(SyncSequenceStatus.burned.index),
    );
    expect(rows.skip(1).map((row) => row.entryId), everyElement(isNull));
    expect(await db.getLastCounterForHost(hostId), 4);
  });

  test('snapshot coverage contains every host with resolved history', () async {
    final now = DateTime(2024, 3, 15, 12);
    await db.batchInsertSequenceEntries([
      for (final (hostId, counter, status) in [
        ('desktop-host', 4, SyncSequenceStatus.received),
        ('desktop-host', 9, SyncSequenceStatus.backfilled),
        ('old-phone-host', 2, SyncSequenceStatus.deleted),
        ('old-phone-host', 7, SyncSequenceStatus.burned),
        ('missing-only-host', 20, SyncSequenceStatus.missing),
        ('requested-only-host', 21, SyncSequenceStatus.requested),
      ])
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          status: Value(status.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
    ]);

    expect(await db.resolvedSequenceUpperBounds(), {
      'desktop-host': 9,
      'old-phone-host': 7,
    });
  });

  test('loads only burned counters inside the announced snapshot', () async {
    final now = DateTime(2024, 3, 15, 12);
    const hostId = 'desktop-host';

    await db.batchInsertSequenceEntries([
      for (final (counter, status) in [
        (1, SyncSequenceStatus.burned),
        (2, SyncSequenceStatus.received),
        (4, SyncSequenceStatus.burned),
        (8, SyncSequenceStatus.burned),
      ])
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: Value(counter),
          status: Value(status.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
    ]);

    final counters = await db.burnedSequenceCountersForHost(
      hostId: hostId,
      upperBound: 4,
    );

    expect(counters, [1, 4]);
  });

  test('default timestamps keep live rounds and burned rows current', () async {
    final oldTimestamp = DateTime.utc(2000);
    final farFuture = DateTime.utc(2100);
    for (final (roundId, direction, recipientHostId) in [
      ('inbound-round', 'inbound', null),
      ('outbound-round', 'outbound', 'phone-host'),
    ]) {
      await db.upsertOnboardingSyncRound(
        OnboardingSyncRoundsCompanion.insert(
          roundId: roundId,
          direction: direction,
          state: 'active',
          senderHostId: 'desktop-host',
          recipientHostId: Value(recipientHostId),
          recipientUserId: '@sync:example.org',
          recipientDeviceId: 'PHONE',
          coverageUpperBoundsJson: '{"desktop-host":4}',
          startedAt: oldTimestamp,
          updatedAt: oldTimestamp,
          expiresAt: farFuture,
        ),
      );
    }
    await db.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: const Value('desktop-host'),
        counter: const Value(4),
        status: Value(SyncSequenceStatus.missing.index),
        createdAt: Value(oldTimestamp),
        updatedAt: Value(oldTimestamp),
      ),
    );

    expect(
      (await db.activeInboundOnboardingSyncRounds()).single.roundId,
      'inbound-round',
    );
    expect(
      (await db.activeOutboundOnboardingSyncRounds(
        recipientHostId: 'phone-host',
      )).single.roundId,
      'outbound-round',
    );

    await db.applyAuthoritativeBurnedCounters(
      hostId: 'desktop-host',
      counters: const [4],
    );
    final burned = await db.getEntryByHostAndCounter('desktop-host', 4);
    expect(burned?.status, SyncSequenceStatus.burned.index);
    expect(burned?.updatedAt, isNot(oldTimestamp));
  });
}
