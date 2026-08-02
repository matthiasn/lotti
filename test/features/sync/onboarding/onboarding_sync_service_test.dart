import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/onboarding/onboarding_sync_service.dart';

void main() {
  late SyncDatabase db;
  late List<SyncMessage> enqueued;
  late Clock serviceClock;
  late OnboardingSyncService service;
  final beginEnqueued = <String, Completer<SyncOnboardingSnapshotBegin>>{};

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    enqueued = [];
    serviceClock = Clock.fixed(DateTime(2024, 3, 15, 12));
    service = OnboardingSyncService(
      syncDatabase: db,
      enqueueMessage: (message) async {
        enqueued.add(message);
        if (message case final SyncOnboardingSnapshotBegin begin) {
          beginEnqueued[begin.roundId]?.complete(begin);
        }
      },
      getHostId: () async => 'local-host',
      getSnapshotCoverage: () async => {
        'local-host': 12,
        'peer-host': 7,
      },
      getLocalUserId: () => '@sync:example.org',
      getLocalDeviceId: () => 'DESKTOP',
      serviceClock: serviceClock,
      roundIdFactory: () => 'round-1',
    );
  });

  tearDown(() async {
    beginEnqueued.clear();
    await db.close();
  });

  test(
    'waits for target acceptance before snapshot staging can start',
    () async {
      await db.applyAuthoritativeBurnedCounters(
        hostId: 'local-host',
        counters: const [2, 3, 4, 8],
        now: serviceClock.now(),
      );
      final beginReady = Completer<SyncOnboardingSnapshotBegin>();
      beginEnqueued['round-1'] = beginReady;

      final pendingRound = service.beginOutbound(
        const OnboardingSyncTarget(
          userId: '@sync:example.org',
          deviceId: 'PHONE',
        ),
      );
      final begin = await beginReady.future;

      expect(begin.coverageUpperBounds, {
        'local-host': 12,
        'peer-host': 7,
      });
      expect(begin.recipientDeviceId, 'PHONE');
      expect(enqueued, [begin]);

      await service.handleMessage(
        const SyncMessage.onboardingSnapshotAccepted(
          protocolVersion: onboardingSyncProtocolVersion,
          roundId: 'round-1',
          senderHostId: 'local-host',
          senderUserId: '@sync:example.org',
          senderDeviceId: 'DESKTOP',
          recipientHostId: 'phone-host',
          recipientDeviceId: 'PHONE',
        ),
      );
      final round = await pendingRound;

      expect(round.coverageUpperBounds, {
        'local-host': 12,
        'peer-host': 7,
      });
      expect(
        enqueued.whereType<SyncOnboardingTerminalCounters>().single.ranges,
        const [
          SyncCounterRange(start: 2, end: 4),
          SyncCounterRange(start: 8, end: 8),
        ],
      );
      expect(
        await service.activeOutboundCoverageForRequester('phone-host'),
        {'local-host': 12, 'peer-host': 7},
      );

      await service.completeOutbound(round);
      expect((await db.onboardingSyncRound('round-1'))?.state, 'ending');
      expect(
        await service.activeOutboundCoverageForRequester('phone-host'),
        {'local-host': 12, 'peer-host': 7},
        reason: 'the sender remains protected while the end barrier drains',
      );
      await service.handleMessage(
        enqueued.whereType<SyncOnboardingSnapshotEnd>().single,
      );
      expect((await db.onboardingSyncRound('round-1'))?.state, 'completed');
      expect(
        await service.activeOutboundCoverageForRequester('phone-host'),
        isEmpty,
      );
    },
  );

  test(
    'target installs a durable bounded lease before acknowledging',
    () async {
      service = OnboardingSyncService(
        syncDatabase: db,
        enqueueMessage: (message) async => enqueued.add(message),
        getHostId: () async => 'phone-host',
        getSnapshotCoverage: () async => const {},
        getLocalUserId: () => '@sync:example.org',
        getLocalDeviceId: () => 'PHONE',
        serviceClock: serviceClock,
      );

      await service.handleMessage(_beginMessage());

      final stored = await db.onboardingSyncRound('round-1');
      expect(stored?.state, 'active');
      expect(stored?.direction, 'inbound');
      expect(stored?.expiresAt, serviceClock.now().add(onboardingSyncLease));
      expect(await service.activeInboundCoverage(), {
        'desktop-host': 12,
        'older-phone-host': 9,
      });
      expect(
        enqueued.single,
        const SyncMessage.onboardingSnapshotAccepted(
          protocolVersion: onboardingSyncProtocolVersion,
          roundId: 'round-1',
          senderHostId: 'desktop-host',
          senderUserId: '@sync:example.org',
          senderDeviceId: 'DESKTOP',
          recipientHostId: 'phone-host',
          recipientDeviceId: 'PHONE',
        ),
      );
    },
  );

  test(
    'terminal counters close real gaps without replacing received data',
    () async {
      service = _phoneService(db, enqueued, serviceClock);
      await service.handleMessage(_beginMessage());
      await db.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('desktop-host'),
          counter: const Value(3),
          entryId: const Value('entry-3'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(serviceClock.now()),
          updatedAt: Value(serviceClock.now()),
        ),
      );

      await service.handleMessage(
        const SyncMessage.onboardingTerminalCounters(
          protocolVersion: onboardingSyncProtocolVersion,
          roundId: 'round-1',
          senderHostId: 'desktop-host',
          recipientUserId: '@sync:example.org',
          recipientDeviceId: 'PHONE',
          ranges: [
            SyncCounterRange(start: 2, end: 4),
            SyncCounterRange(start: 20, end: 30),
          ],
        ),
      );

      final received = await db.getEntryByHostAndCounter('desktop-host', 3);
      expect(received?.status, SyncSequenceStatus.received.index);
      expect(received?.entryId, 'entry-3');
      expect(
        (await db.getEntryByHostAndCounter('desktop-host', 2))?.status,
        SyncSequenceStatus.burned.index,
      );
      expect(await db.getEntryByHostAndCounter('desktop-host', 20), isNull);
    },
  );

  test(
    'matching end releases suppression and nudges residual repair',
    () async {
      var nudges = 0;
      service = _phoneService(db, enqueued, serviceClock)
        ..onInboundSuppressionEnded = () => nudges++;
      await service.handleMessage(_beginMessage());

      await service.handleMessage(
        const SyncMessage.onboardingSnapshotEnd(
          protocolVersion: onboardingSyncProtocolVersion,
          roundId: 'round-1',
          senderHostId: 'desktop-host',
          recipientUserId: '@sync:example.org',
          recipientDeviceId: 'PHONE',
          reason: OnboardingSyncEndReason.complete,
        ),
      );

      expect(await service.activeInboundCoverage(), isEmpty);
      expect((await db.onboardingSyncRound('round-1'))?.state, 'completed');
      expect(nudges, 1);

      await service.handleMessage(_beginMessage());
      expect((await db.onboardingSyncRound('round-1'))?.state, 'completed');
      expect(
        enqueued.whereType<SyncOnboardingSnapshotAccepted>(),
        hasLength(1),
      );
    },
  );

  test('aborted end keeps the original one-hour cooldown', () async {
    var nudges = 0;
    service = _phoneService(db, enqueued, serviceClock)
      ..onInboundSuppressionEnded = () => nudges++;
    await service.handleMessage(_beginMessage());

    await service.handleMessage(
      const SyncMessage.onboardingSnapshotEnd(
        protocolVersion: onboardingSyncProtocolVersion,
        roundId: 'round-1',
        senderHostId: 'desktop-host',
        recipientUserId: '@sync:example.org',
        recipientDeviceId: 'PHONE',
        reason: OnboardingSyncEndReason.aborted,
      ),
    );

    expect((await db.onboardingSyncRound('round-1'))?.state, 'aborted');
    expect(await service.activeInboundCoverage(), {
      'desktop-host': 12,
      'older-phone-host': 9,
    });
    expect(nudges, 0);

    final afterExpiry = _phoneService(
      db,
      enqueued,
      Clock.fixed(serviceClock.now().add(onboardingSyncLease)),
    );
    expect(await afterExpiry.activeInboundCoverage(), isEmpty);
  });

  test('restart preserves the lease and expiry releases it', () async {
    service = _phoneService(db, enqueued, serviceClock);
    await service.handleMessage(_beginMessage());

    final restarted = _phoneService(
      db,
      enqueued,
      Clock.fixed(serviceClock.now().add(const Duration(minutes: 59))),
    );
    expect(await restarted.activeInboundCoverage(), {
      'desktop-host': 12,
      'older-phone-host': 9,
    });
    await restarted.handleMessage(_beginMessage());
    expect(
      (await db.onboardingSyncRound('round-1'))?.expiresAt,
      serviceClock.now().add(onboardingSyncLease),
      reason: 'a replay after restart must not renew the bounded lease',
    );

    final afterExpiry = _phoneService(
      db,
      enqueued,
      Clock.fixed(serviceClock.now().add(const Duration(hours: 1))),
    );
    expect(await afterExpiry.activeInboundCoverage(), isEmpty);
  });

  test('overlapping rounds merge coverage and finish independently', () async {
    service = _phoneService(db, enqueued, serviceClock);
    await service.handleMessage(_beginMessage());
    await service.handleMessage(
      _beginMessage().copyWith(
        roundId: 'round-2',
        coverageUpperBounds: const {
          'desktop-host': 15,
          'second-desktop-host': 8,
        },
      ),
    );

    expect(await service.activeInboundCoverage(), {
      'desktop-host': 15,
      'older-phone-host': 9,
      'second-desktop-host': 8,
    });

    await service.handleMessage(
      const SyncMessage.onboardingSnapshotEnd(
        protocolVersion: onboardingSyncProtocolVersion,
        roundId: 'round-2',
        senderHostId: 'desktop-host',
        recipientUserId: '@sync:example.org',
        recipientDeviceId: 'PHONE',
        reason: OnboardingSyncEndReason.complete,
      ),
    );
    expect(await service.activeInboundCoverage(), {
      'desktop-host': 12,
      'older-phone-host': 9,
    });

    await service.handleMessage(
      const SyncMessage.onboardingSnapshotEnd(
        protocolVersion: onboardingSyncProtocolVersion,
        roundId: 'round-1',
        senderHostId: 'desktop-host',
        recipientUserId: '@sync:example.org',
        recipientDeviceId: 'PHONE',
        reason: OnboardingSyncEndReason.complete,
      ),
    );
    expect(await service.activeInboundCoverage(), isEmpty);
  });

  test('broadcasts for another device do not mutate local state', () async {
    service = _phoneService(db, enqueued, serviceClock);

    await service.handleMessage(
      _beginMessage().copyWith(recipientDeviceId: 'OTHER_PHONE'),
    );

    expect(await db.onboardingSyncRound('round-1'), isNull);
    expect(enqueued, isEmpty);
  });

  test(
    'rejects onboarding when the local sync identity is unavailable',
    () async {
      service = OnboardingSyncService(
        syncDatabase: db,
        enqueueMessage: (message) async => enqueued.add(message),
        getHostId: () async => null,
        getSnapshotCoverage: () async => const {},
        getLocalUserId: () => '@sync:example.org',
        getLocalDeviceId: () => 'DESKTOP',
        serviceClock: serviceClock,
      );

      await expectLater(
        service.beginOutbound(
          const OnboardingSyncTarget(
            userId: '@sync:example.org',
            deviceId: 'PHONE',
          ),
        ),
        throwsStateError,
      );
      expect(enqueued, isEmpty);
    },
  );

  test('a failed begin emits an aborted end barrier', () async {
    service = OnboardingSyncService(
      syncDatabase: db,
      enqueueMessage: (message) async {
        if (message is SyncOnboardingSnapshotBegin) {
          throw StateError('begin enqueue failed');
        }
        enqueued.add(message);
      },
      getHostId: () async => 'local-host',
      getSnapshotCoverage: () async => const {'local-host': 12},
      getLocalUserId: () => '@sync:example.org',
      getLocalDeviceId: () => 'DESKTOP',
      serviceClock: serviceClock,
      roundIdFactory: () => 'failed-round',
    );

    await expectLater(
      service.beginOutbound(
        const OnboardingSyncTarget(
          userId: '@sync:example.org',
          deviceId: 'PHONE',
        ),
      ),
      throwsStateError,
    );

    final end = enqueued.single as SyncOnboardingSnapshotEnd;
    expect(end.roundId, 'failed-round');
    expect(end.reason, OnboardingSyncEndReason.aborted);
    expect((await db.onboardingSyncRound('failed-round'))?.state, 'ending');
  });

  test('active outbound rounds merge coverage by the highest bound', () async {
    for (final (roundId, coverage) in [
      ('round-a', '{"local-host":12,"peer-host":4}'),
      ('round-b', '{"local-host":15,"second-peer":8}'),
    ]) {
      await db.upsertOnboardingSyncRound(
        OnboardingSyncRoundsCompanion.insert(
          roundId: roundId,
          direction: 'outbound',
          state: 'active',
          senderHostId: 'local-host',
          recipientHostId: const Value('phone-host'),
          recipientUserId: '@sync:example.org',
          recipientDeviceId: 'PHONE',
          coverageUpperBoundsJson: coverage,
          startedAt: serviceClock.now(),
          updatedAt: serviceClock.now(),
          expiresAt: serviceClock.now().add(onboardingSyncLease),
        ),
      );
    }

    expect(await service.activeOutboundCoverageForRequester('phone-host'), {
      'local-host': 15,
      'peer-host': 4,
      'second-peer': 8,
    });
  });

  test('malformed persisted coverage cannot suppress backfill', () async {
    await db.upsertOnboardingSyncRound(
      OnboardingSyncRoundsCompanion.insert(
        roundId: 'malformed-round',
        direction: 'inbound',
        state: 'active',
        senderHostId: 'desktop-host',
        recipientUserId: '@sync:example.org',
        recipientDeviceId: 'PHONE',
        coverageUpperBoundsJson: '{not-json',
        startedAt: serviceClock.now(),
        updatedAt: serviceClock.now(),
        expiresAt: serviceClock.now().add(onboardingSyncLease),
      ),
    );

    expect(await service.activeInboundCoverage(), isEmpty);
  });

  test('counter range helpers reject non-positive chunk limits', () {
    expect(
      () => chunkCounterRanges(const [1], maxCountersPerChunk: 0),
      throwsArgumentError,
    );
    expect(
      () => expandCounterRanges(
        const [SyncCounterRange(start: 1, end: 1)],
        upperBound: 1,
        maxCounters: 0,
      ),
      throwsArgumentError,
    );
  });

  glados.Glados<List<int>>(
    glados.any.listWithLengthInRange(0, 600, glados.any.intInRange(-20, 800)),
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'counter range chunks round-trip sorted unique non-negative counters',
    (counters) {
      final chunks = chunkCounterRanges(counters);
      final expanded = [
        for (final chunk in chunks)
          ...expandCounterRanges(chunk, upperBound: 1000),
      ];
      final expected =
          counters.where((counter) => counter >= 0).toSet().toList()..sort();

      expect(expanded, expected);
      for (final chunk in chunks) {
        expect(
          expandCounterRanges(chunk, upperBound: 1000).length,
          lessThanOrEqualTo(250),
        );
      }
    },
    tags: 'glados',
  );
}

SyncOnboardingSnapshotBegin _beginMessage() {
  return const SyncMessage.onboardingSnapshotBegin(
        protocolVersion: onboardingSyncProtocolVersion,
        roundId: 'round-1',
        senderHostId: 'desktop-host',
        senderUserId: '@sync:example.org',
        senderDeviceId: 'DESKTOP',
        recipientUserId: '@sync:example.org',
        recipientDeviceId: 'PHONE',
        coverageUpperBounds: {
          'desktop-host': 12,
          'older-phone-host': 9,
        },
        leaseSeconds: 3600,
      )
      as SyncOnboardingSnapshotBegin;
}

OnboardingSyncService _phoneService(
  SyncDatabase db,
  List<SyncMessage> enqueued,
  Clock serviceClock,
) {
  return OnboardingSyncService(
    syncDatabase: db,
    enqueueMessage: (message) async => enqueued.add(message),
    getHostId: () async => 'phone-host',
    getSnapshotCoverage: () async => const {},
    getLocalUserId: () => '@sync:example.org',
    getLocalDeviceId: () => 'PHONE',
    serviceClock: serviceClock,
  );
}
