// Tests for the retire/reset lifecycle of stuck sequence-log rows
// (`lib/database/sync_db_lifecycle.dart`).
// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';

enum _GeneratedSequenceLifecycleOperation {
  resetKnown,
  resetAll,
  retireExhausted,
  retireAgedOut,
}

enum _GeneratedSequenceLifecycleStatus {
  absent,
  received,
  missing,
  requested,
  backfilled,
  deleted,
  unresolvable,
  reserved,
  burnPending,
}

enum _GeneratedRequestTimestamp { absent, fresh, atCutoff, old }

enum _GeneratedUpdatedTimestamp { fresh, atCutoff, old }

enum _GeneratedReservationOutcome { stillReserved, boundReceived, burnPending }

class _ReservationLifecycleScenario {
  const _ReservationLifecycleScenario({
    required this.outcomes,
  });

  static const hostId = 'generated-reservation-host';
  static final start = DateTime(2026, 5, 24, 11);

  final List<_GeneratedReservationOutcome> outcomes;

  List<int> get expectedReservedCounters => [
    for (var index = 0; index < outcomes.length; index++)
      if (outcomes[index] == _GeneratedReservationOutcome.stillReserved)
        index + 1,
  ];

  List<int> get expectedBurnPendingCounters => [
    for (var index = 0; index < outcomes.length; index++)
      if (outcomes[index] == _GeneratedReservationOutcome.burnPending)
        index + 1,
  ];

  int? get expectedWatermark {
    if (outcomes.isEmpty) return null;

    var prefix = 0;
    for (final outcome in outcomes) {
      if (outcome != _GeneratedReservationOutcome.boundReceived) break;
      prefix++;
    }
    return prefix;
  }

  SyncSequenceStatus expectedStatus(int counter) {
    return switch (outcomes[counter - 1]) {
      _GeneratedReservationOutcome.stillReserved => SyncSequenceStatus.reserved,
      _GeneratedReservationOutcome.boundReceived => SyncSequenceStatus.received,
      _GeneratedReservationOutcome.burnPending =>
        SyncSequenceStatus.burnPending,
    };
  }
}

class _SequenceLifecycleRowSpec {
  const _SequenceLifecycleRowSpec({
    required this.status,
    required this.payloadType,
    required this.hasEntryId,
    required this.requestCount,
    required this.lastRequestedAt,
    required this.updatedAt,
  });

  final _GeneratedSequenceLifecycleStatus status;
  final SyncSequencePayloadType payloadType;
  final bool hasEntryId;
  final int requestCount;
  final _GeneratedRequestTimestamp lastRequestedAt;
  final _GeneratedUpdatedTimestamp updatedAt;

  bool get isStored => status != _GeneratedSequenceLifecycleStatus.absent;

  bool get isMissingOrRequested =>
      status == _GeneratedSequenceLifecycleStatus.missing ||
      status == _GeneratedSequenceLifecycleStatus.requested;

  bool get isResolvedWatermark =>
      status == _GeneratedSequenceLifecycleStatus.received ||
      status == _GeneratedSequenceLifecycleStatus.backfilled ||
      status == _GeneratedSequenceLifecycleStatus.deleted ||
      status == _GeneratedSequenceLifecycleStatus.unresolvable;

  SyncSequenceStatus get syncStatus {
    return switch (status) {
      _GeneratedSequenceLifecycleStatus.received => SyncSequenceStatus.received,
      _GeneratedSequenceLifecycleStatus.missing => SyncSequenceStatus.missing,
      _GeneratedSequenceLifecycleStatus.requested =>
        SyncSequenceStatus.requested,
      _GeneratedSequenceLifecycleStatus.backfilled =>
        SyncSequenceStatus.backfilled,
      _GeneratedSequenceLifecycleStatus.deleted => SyncSequenceStatus.deleted,
      _GeneratedSequenceLifecycleStatus.unresolvable =>
        SyncSequenceStatus.unresolvable,
      _GeneratedSequenceLifecycleStatus.reserved => SyncSequenceStatus.reserved,
      _GeneratedSequenceLifecycleStatus.burnPending =>
        SyncSequenceStatus.burnPending,
      _GeneratedSequenceLifecycleStatus.absent => throw StateError(
        'Absent lifecycle rows do not have a sync status',
      ),
    };
  }

  String? entryId(int counter) =>
      isStored && hasEntryId ? 'generated-lifecycle-entry-$counter' : null;

  DateTime createdAt(DateTime now) => now.subtract(const Duration(days: 30));

  DateTime updatedAtValue(DateTime now) {
    return switch (updatedAt) {
      _GeneratedUpdatedTimestamp.fresh => now.subtract(
        const Duration(days: 1),
      ),
      _GeneratedUpdatedTimestamp.atCutoff => now.subtract(
        _SequenceLifecycleScenario.amnestyWindow,
      ),
      _GeneratedUpdatedTimestamp.old => now.subtract(
        const Duration(days: 10),
      ),
    };
  }

  DateTime? lastRequestedAtValue(DateTime now) {
    return switch (lastRequestedAt) {
      _GeneratedRequestTimestamp.absent => null,
      _GeneratedRequestTimestamp.fresh => now.subtract(
        const Duration(minutes: 1),
      ),
      _GeneratedRequestTimestamp.atCutoff => now.subtract(
        _SequenceLifecycleScenario.grace,
      ),
      _GeneratedRequestTimestamp.old => now.subtract(
        const Duration(minutes: 10),
      ),
    };
  }

  @override
  String toString() {
    return '_SequenceLifecycleRowSpec('
        'status: $status, '
        'payloadType: $payloadType, '
        'hasEntryId: $hasEntryId, '
        'requestCount: $requestCount, '
        'lastRequestedAt: $lastRequestedAt, '
        'updatedAt: $updatedAt'
        ')';
  }
}

class _SequenceLifecycleExpectedRow {
  const _SequenceLifecycleExpectedRow({
    required this.status,
    required this.entryId,
    required this.requestCount,
    required this.lastRequestedCleared,
    required this.payloadType,
  });

  final SyncSequenceStatus? status;
  final String? entryId;
  final int? requestCount;
  final bool lastRequestedCleared;
  final SyncSequencePayloadType? payloadType;
}

class _SequenceLifecycleScenario {
  const _SequenceLifecycleScenario({
    required this.operation,
    required this.rows,
  });

  static final now = DateTime(2026, 5, 6, 12);
  static const hostId = 'generated-lifecycle-host';
  static const maxRequestCount = 5;
  static const grace = Duration(minutes: 5);
  static const amnestyWindow = Duration(days: 7);

  final _GeneratedSequenceLifecycleOperation operation;
  final List<_SequenceLifecycleRowSpec> rows;

  int get expectedAffectedCount {
    return [
      for (var index = 0; index < rows.length; index++)
        if (_changesRow(rows[index], index + 1)) rows[index],
    ].length;
  }

  _SequenceLifecycleExpectedRow expectedRow(int counter) {
    final row = rows[counter - 1];
    if (!row.isStored) {
      return const _SequenceLifecycleExpectedRow(
        status: null,
        entryId: null,
        requestCount: null,
        lastRequestedCleared: false,
        payloadType: null,
      );
    }

    final changes = _changesRow(row, counter);
    final status = changes
        ? switch (operation) {
            _GeneratedSequenceLifecycleOperation.resetKnown ||
            _GeneratedSequenceLifecycleOperation.resetAll =>
              SyncSequenceStatus.missing,
            _GeneratedSequenceLifecycleOperation.retireExhausted ||
            _GeneratedSequenceLifecycleOperation.retireAgedOut =>
              SyncSequenceStatus.unresolvable,
          }
        : row.syncStatus;

    return _SequenceLifecycleExpectedRow(
      status: status,
      entryId: row.entryId(counter),
      requestCount:
          changes &&
              (operation == _GeneratedSequenceLifecycleOperation.resetKnown ||
                  operation == _GeneratedSequenceLifecycleOperation.resetAll)
          ? 0
          : row.requestCount,
      lastRequestedCleared:
          changes &&
          (operation == _GeneratedSequenceLifecycleOperation.resetKnown ||
              operation == _GeneratedSequenceLifecycleOperation.resetAll),
      payloadType: row.payloadType,
    );
  }

  int? get expectedWatermark {
    if (!rows.any((row) => row.isStored)) return null;

    var prefix = 0;
    for (var counter = 1; counter <= rows.length; counter++) {
      final expected = expectedRow(counter);
      if (expected.status == null || !expected.status!.isResolvedWatermark) {
        break;
      }
      prefix++;
    }
    return prefix;
  }

  bool _changesRow(_SequenceLifecycleRowSpec row, int counter) {
    if (!row.isStored) return false;

    return switch (operation) {
      _GeneratedSequenceLifecycleOperation.resetKnown =>
        row.status == _GeneratedSequenceLifecycleStatus.unresolvable &&
            row.entryId(counter) != null,
      _GeneratedSequenceLifecycleOperation.resetAll =>
        row.status == _GeneratedSequenceLifecycleStatus.unresolvable,
      _GeneratedSequenceLifecycleOperation.retireExhausted =>
        row.isMissingOrRequested &&
            row.requestCount >= maxRequestCount &&
            row.lastRequestedAtValue(now) != null &&
            row
                .lastRequestedAtValue(
                  now,
                )!
                .isBefore(now.subtract(grace)),
      _GeneratedSequenceLifecycleOperation.retireAgedOut =>
        row.isMissingOrRequested &&
            row.updatedAtValue(now).isBefore(now.subtract(amnestyWindow)),
    };
  }

  @override
  String toString() {
    return '_SequenceLifecycleScenario('
        'operation: $operation, '
        'rows: $rows'
        ')';
  }
}

extension _SyncSequenceStatusModelX on SyncSequenceStatus {
  bool get isResolvedWatermark =>
      this == SyncSequenceStatus.received ||
      this == SyncSequenceStatus.backfilled ||
      this == SyncSequenceStatus.deleted ||
      this == SyncSequenceStatus.unresolvable ||
      this == SyncSequenceStatus.burned;
}

extension _AnySequenceLifecycleScenario on Any {
  Generator<SyncSequencePayloadType> get generatedPayloadType =>
      choose(SyncSequencePayloadType.values);

  Generator<_GeneratedSequenceLifecycleOperation>
  get generatedSequenceLifecycleOperation =>
      choose(_GeneratedSequenceLifecycleOperation.values);

  Generator<_GeneratedSequenceLifecycleStatus>
  get generatedSequenceLifecycleStatus =>
      choose(_GeneratedSequenceLifecycleStatus.values);

  Generator<_GeneratedRequestTimestamp> get generatedRequestTimestamp =>
      choose(_GeneratedRequestTimestamp.values);

  Generator<_GeneratedUpdatedTimestamp> get generatedUpdatedTimestamp =>
      choose(_GeneratedUpdatedTimestamp.values);

  Generator<_GeneratedReservationOutcome> get generatedReservationOutcome =>
      choose(_GeneratedReservationOutcome.values);

  Generator<_ReservationLifecycleScenario> get reservationLifecycleScenario =>
      listWithLengthInRange(
        0,
        14,
        generatedReservationOutcome,
      ).map((outcomes) => _ReservationLifecycleScenario(outcomes: outcomes));

  Generator<_SequenceLifecycleRowSpec> get sequenceLifecycleRowSpec => combine6(
    generatedSequenceLifecycleStatus,
    generatedPayloadType,
    any.bool,
    intInRange(0, 8),
    generatedRequestTimestamp,
    generatedUpdatedTimestamp,
    (
      _GeneratedSequenceLifecycleStatus status,
      SyncSequencePayloadType payloadType,
      bool hasEntryId,
      int requestCount,
      _GeneratedRequestTimestamp lastRequestedAt,
      _GeneratedUpdatedTimestamp updatedAt,
    ) => _SequenceLifecycleRowSpec(
      status: status,
      payloadType: payloadType,
      hasEntryId: hasEntryId,
      requestCount: requestCount,
      lastRequestedAt: lastRequestedAt,
      updatedAt: updatedAt,
    ),
  );

  Generator<_SequenceLifecycleScenario> get sequenceLifecycleScenario =>
      combine2(
        generatedSequenceLifecycleOperation,
        listWithLengthInRange(0, 14, sequenceLifecycleRowSpec),
        (
          _GeneratedSequenceLifecycleOperation operation,
          List<_SequenceLifecycleRowSpec> rows,
        ) => _SequenceLifecycleScenario(
          operation: operation,
          rows: rows,
        ),
      );
}

void main() {
  group('resetUnresolvableWithKnownPayload', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test('resets unresolvable entries with known entryId to missing', () async {
      final now = DateTime(2024, 3, 15);

      // Insert an unresolvable entry WITH entryId (should be reset)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(5),
          entryId: const Value('known-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.unresolvable.index),
          createdAt: Value(now),
          updatedAt: Value(now),
          requestCount: const Value(3),
        ),
      );

      // Insert an unresolvable entry WITHOUT entryId (should NOT be reset)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(6),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.unresolvable.index),
          createdAt: Value(now),
          updatedAt: Value(now),
          requestCount: const Value(2),
        ),
      );

      // Insert a received entry (should NOT be affected)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(7),
          entryId: const Value('another-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final resetCount = await database.resetUnresolvableWithKnownPayload();

      expect(resetCount, 1);

      // Verify the reset entry
      final resetEntry = await database.getEntryByHostAndCounter('host-a', 5);
      expect(resetEntry, isNotNull);
      expect(resetEntry!.status, SyncSequenceStatus.missing.index);
      expect(resetEntry.requestCount, 0);

      // Verify the unresolvable without entryId was NOT reset
      final unchanged = await database.getEntryByHostAndCounter('host-a', 6);
      expect(unchanged, isNotNull);
      expect(unchanged!.status, SyncSequenceStatus.unresolvable.index);

      // Verify the received entry was NOT affected
      final received = await database.getEntryByHostAndCounter('host-a', 7);
      expect(received, isNotNull);
      expect(received!.status, SyncSequenceStatus.received.index);
    });

    test('returns 0 when no unresolvable entries exist', () async {
      final database = SyncDatabase(inMemoryDatabase: true);
      addTearDown(database.close);

      final resetCount = await database.resetUnresolvableWithKnownPayload();
      expect(resetCount, 0);
    });
  });

  group('resetAllUnresolvableEntries', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'resets every unresolvable entry back to missing, including rows '
      'without entryId — the key case where the originating host is dead '
      'but currently-alive peers may still have the payload',
      () async {
        final now = DateTime(2026, 4, 22);
        final old = now.subtract(const Duration(days: 30));

        // Unresolvable WITHOUT entryId — resetUnresolvableWithKnownPayload
        // skips this; this method must flip it.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('dead-host'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.unresolvable.index),
            createdAt: Value(old),
            updatedAt: Value(old),
            requestCount: const Value(2),
            lastRequestedAt: Value(old),
          ),
        );

        // Unresolvable WITH entryId — also flipped (for completeness;
        // this is the superset of resetUnresolvableWithKnownPayload).
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('dead-host'),
            counter: const Value(2),
            entryId: const Value('known-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.unresolvable.index),
            createdAt: Value(old),
            updatedAt: Value(old),
            requestCount: const Value(5),
          ),
        );

        // Received entry must NOT be touched.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('dead-host'),
            counter: const Value(3),
            entryId: const Value('received-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(old),
            updatedAt: Value(old),
          ),
        );

        final reset = await database.resetAllUnresolvableEntries();
        expect(reset, 2);

        final r1 = await database.getEntryByHostAndCounter('dead-host', 1);
        expect(r1!.status, SyncSequenceStatus.missing.index);
        expect(r1.requestCount, 0);
        expect(r1.lastRequestedAt, isNull);

        final r2 = await database.getEntryByHostAndCounter('dead-host', 2);
        expect(r2!.status, SyncSequenceStatus.missing.index);
        expect(r2.requestCount, 0);

        final r3 = await database.getEntryByHostAndCounter('dead-host', 3);
        expect(r3!.status, SyncSequenceStatus.received.index);
      },
    );

    test('returns 0 when no unresolvable rows exist', () async {
      final reset = await database.resetAllUnresolvableEntries();
      expect(reset, 0);
    });
  });

  group('retireExhaustedRequestedEntries', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'retires missing and requested rows at or above the request-count cap '
      'whose last backfill request is older than the grace window, and '
      'leaves other statuses untouched',
      () async {
        final now = DateTime(2024, 3, 15);
        final longAgo = now.subtract(const Duration(hours: 1));

        // Missing at the cap, last request comfortably past the grace
        // window — should retire.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(10),
            lastRequestedAt: Value(longAgo),
          ),
        );

        // Requested above the cap — should retire.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(2),
            entryId: const Value('hint-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(15),
            lastRequestedAt: Value(longAgo),
          ),
        );

        // Missing but below the cap — must stay missing.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(3),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(4),
            lastRequestedAt: Value(longAgo),
          ),
        );

        // Received row at/above the cap — must not be touched.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(4),
            entryId: const Value('received-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(20),
            lastRequestedAt: Value(longAgo),
          ),
        );

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
        );

        expect(retired, 2);
        expect(
          (await database.getEntryByHostAndCounter('host-a', 1))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 2))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 3))!.status,
          SyncSequenceStatus.missing.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 4))!.status,
          SyncSequenceStatus.received.index,
        );
      },
    );

    test(
      'does not retire a row whose last backfill request is still within '
      'the grace window — the in-flight response deserves a chance to land',
      () async {
        final now = DateTime(2024, 3, 15);

        // At the cap but requested 30s ago, well inside the 5-minute grace.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-grace'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(10),
            lastRequestedAt: Value(
              now.subtract(const Duration(seconds: 30)),
            ),
          ),
        );

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
        );

        expect(retired, 0);
        expect(
          (await database.getEntryByHostAndCounter('host-grace', 1))!.status,
          SyncSequenceStatus.requested.index,
        );
      },
    );

    test(
      'retires rows whose last_requested_at was set by '
      'batchIncrementRequestCounts (end-to-end timestamp-encoding regression)',
      () async {
        // Regression for the ms/seconds encoding mismatch:
        // `batchIncrementRequestCounts` used to write raw
        // `millisecondsSinceEpoch`, while `retireExhaustedRequestedEntries`
        // compares against Drift's default seconds-encoded DateTime. The two
        // silently disagreed by a factor of 1000, so rows requested via the
        // real production path could never qualify for retirement regardless
        // of how old they were.
        const hostId = 'host-ms-regression';
        const counter = 1;
        // Seed a missing row that we then drive through the real request
        // path `batchIncrementRequestCounts` exactly as the backfill service
        // does.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(counter),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2020)),
            updatedAt: Value(DateTime(2020)),
            requestCount: const Value(9),
          ),
        );

        // Bump to request_count == 10 via the production path and stamp
        // last_requested_at with DateTime.now() (the method's own clock).
        await database.batchIncrementRequestCounts([
          (hostId: hostId, counter: counter),
        ]);

        final afterIncrement = await database.getEntryByHostAndCounter(
          hostId,
          counter,
        );
        expect(afterIncrement!.requestCount, 10);
        expect(afterIncrement.status, SyncSequenceStatus.requested.index);
        expect(afterIncrement.lastRequestedAt, isNotNull);
        // The roundtripped value must be readable as a sane 2020-or-later
        // DateTime — if encoding was in ms, Drift's seconds-decoded column
        // would report a year ~53700.
        expect(
          afterIncrement.lastRequestedAt!.year,
          inInclusiveRange(2020, 2100),
        );

        // Advance the caller's clock past the grace window and run retire.
        final futureNow = afterIncrement.lastRequestedAt!.add(
          const Duration(hours: 2),
        );
        final retired = await database.retireExhaustedRequestedEntries(
          now: futureNow,
        );
        expect(retired, 1);
        expect(
          (await database.getEntryByHostAndCounter(hostId, counter))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
      },
    );

    test(
      'does not retire a row with no recorded last_requested_at — we have '
      'no evidence a request ever reached the outbox',
      () async {
        final now = DateTime(2024, 3, 15);

        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-null'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(12),
          ),
        );

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
        );
        expect(retired, 0);
        expect(
          (await database.getEntryByHostAndCounter('host-null', 1))!.status,
          SyncSequenceStatus.missing.index,
        );
      },
    );

    test(
      'advances the contiguous watermark by retiring pre-history gaps',
      () async {
        final now = DateTime(2024, 3, 15);
        const hostId = 'host-b';

        // Contiguous resolved prefix: counters 1..10 all received.
        for (var i = 1; i <= 10; i++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(i),
              entryId: Value('entry-$i'),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
        // Permanently stuck missing range 11..15, each at the request cap
        // and with a `lastRequestedAt` older than the grace window.
        final longAgo = now.subtract(const Duration(hours: 1));
        for (var i = 11; i <= 15; i++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(i),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.missing.index),
              createdAt: Value(now),
              updatedAt: Value(now),
              requestCount: const Value(10),
              lastRequestedAt: Value(longAgo),
            ),
          );
        }
        // Row beyond the gap, received.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(16),
            entryId: const Value('entry-16'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        expect(await database.getLastCounterForHost(hostId), 10);

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
        );
        expect(retired, 5);

        // With the stuck missing range flipped to `unresolvable` (a terminal
        // status included in the contiguous-prefix computation), the watermark
        // should now advance all the way past the retired range.
        expect(await database.getLastCounterForHost(hostId), 16);
      },
    );

    test('returns 0 when there is nothing to retire', () async {
      final retired = await database.retireExhaustedRequestedEntries();
      expect(retired, 0);
    });

    test(
      'retires backlogs larger than pageSize across multiple pages — '
      'capping per-transaction lock hold without losing rows',
      () async {
        final now = DateTime(2024, 3, 15);
        final longAgo = now.subtract(const Duration(hours: 1));
        const totalRows = 17;
        for (var counter = 1; counter <= totalRows; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value('host-bulk'),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.missing.index),
              createdAt: Value(now),
              updatedAt: Value(now),
              requestCount: const Value(10),
              lastRequestedAt: Value(longAgo),
            ),
          );
        }

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
          pageSize: 5,
        );

        expect(retired, totalRows);
        for (var counter = 1; counter <= totalRows; counter++) {
          expect(
            (await database.getEntryByHostAndCounter(
              'host-bulk',
              counter,
            ))!.status,
            SyncSequenceStatus.unresolvable.index,
            reason: 'row $counter should have been retired',
          );
        }
      },
    );
  });

  group('retireAgedOutRequestedEntries', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'retires missing/requested rows older than amnestyWindow regardless of '
      'request_count, leaving fresh rows and other statuses untouched',
      () async {
        final now = DateTime(2026, 4, 22);
        final longAgo = now.subtract(const Duration(days: 14));
        final recent = now.subtract(const Duration(hours: 6));

        // Aged-out `missing` row with request_count=0 — exactly the case
        // that the exhausted-retire refuses (last_requested_at IS NULL,
        // request_count below cap) and that
        // `getMissingEntriesWithLimits` also ignores (older than
        // maxAge). Must retire here.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
          ),
        );

        // Aged-out `requested` row born via backfill-response-hint path
        // (request_count > 0 but last_requested_at never set). This
        // reproduces the exact stuck-row profile observed on both
        // desktop and mobile sync DBs.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(2),
            entryId: const Value('hint-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
            requestCount: const Value(3),
          ),
        );

        // Recent `missing` row — still inside amnesty window, must NOT
        // retire; let the normal backfill sweep handle it.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(3),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(recent),
            updatedAt: Value(recent),
          ),
        );

        // Aged-out `received` row — must not be touched, ever.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(4),
            entryId: const Value('received-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
          ),
        );

        // Aged-out `backfilled` row — must not be touched.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(5),
            entryId: const Value('backfilled-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.backfilled.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
          ),
        );

        final retired = await database.retireAgedOutRequestedEntries(
          amnestyWindow: const Duration(days: 7),
          now: now,
        );

        expect(retired, 2);
        expect(
          (await database.getEntryByHostAndCounter('host-a', 1))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 2))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 3))!.status,
          SyncSequenceStatus.missing.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 4))!.status,
          SyncSequenceStatus.received.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 5))!.status,
          SyncSequenceStatus.backfilled.index,
        );
      },
    );

    test(
      'unblocks the watermark so getLastCounterForHost advances past the '
      'retired range — the load-bearing reason for this retire path',
      () async {
        final now = DateTime(2026, 4, 22);
        final longAgo = now.subtract(const Duration(days: 14));

        const hostId = 'host-stuck';
        // Counters 1..5 received — contiguous prefix starts here.
        for (var counter = 1; counter <= 5; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(longAgo),
              updatedAt: Value(longAgo),
            ),
          );
        }
        // Counters 6..8 stuck in `requested` — the watermark-blocking
        // rows observed in the real DBs.
        for (var counter = 6; counter <= 8; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.requested.index),
              createdAt: Value(longAgo),
              updatedAt: Value(longAgo),
              requestCount: const Value(3),
            ),
          );
        }
        // Counters 9..12 received — watermark cannot reach these
        // until 6..8 are retired.
        for (var counter = 9; counter <= 12; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(longAgo),
              updatedAt: Value(longAgo),
            ),
          );
        }

        expect(await database.getLastCounterForHost(hostId), 5);

        final retired = await database.retireAgedOutRequestedEntries(
          amnestyWindow: const Duration(days: 7),
          now: now,
        );
        expect(retired, 3);

        // Watermark now advances through the retired `unresolvable`
        // range (6..8) and onward through the contiguous received prefix
        // (9..12), unblocking gap detection for this host.
        expect(await database.getLastCounterForHost(hostId), 12);
      },
    );

    test(
      'uses updated_at (not created_at) so a row just reopened by '
      'resetAllUnresolvableEntries survives the next retire sweep — '
      'without this the reset→retire cycle races',
      () async {
        final now = DateTime(2026, 4, 22);
        final longAgo = now.subtract(const Duration(days: 30));
        final justReopened = now.subtract(const Duration(hours: 1));

        // Row created 30 days ago but `updated_at` just refreshed
        // (simulating resetAllUnresolvableEntries flipping it back to
        // missing). Must NOT be retired.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(longAgo),
            updatedAt: Value(justReopened),
          ),
        );

        // Control: row created AND last-updated 30 days ago — must retire.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(2),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
          ),
        );

        final retired = await database.retireAgedOutRequestedEntries(
          amnestyWindow: const Duration(days: 7),
          now: now,
        );
        expect(retired, 1);

        final reopened = await database.getEntryByHostAndCounter('host-a', 1);
        expect(reopened!.status, SyncSequenceStatus.missing.index);

        final oldRow = await database.getEntryByHostAndCounter('host-a', 2);
        expect(oldRow!.status, SyncSequenceStatus.unresolvable.index);
      },
    );

    test('returns 0 when there is nothing to retire', () async {
      final retired = await database.retireAgedOutRequestedEntries();
      expect(retired, 0);
    });

    test(
      'retires backlogs larger than pageSize across multiple pages — '
      'capping per-transaction lock hold without losing rows',
      () async {
        final now = DateTime(2026, 4, 22);
        final longAgo = now.subtract(const Duration(days: 14));
        const totalRows = 13;
        for (var counter = 1; counter <= totalRows; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value('host-bulk'),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.missing.index),
              createdAt: Value(longAgo),
              updatedAt: Value(longAgo),
            ),
          );
        }

        final retired = await database.retireAgedOutRequestedEntries(
          amnestyWindow: const Duration(days: 7),
          now: now,
          pageSize: 4,
        );

        expect(retired, totalRows);
        for (var counter = 1; counter <= totalRows; counter++) {
          expect(
            (await database.getEntryByHostAndCounter(
              'host-bulk',
              counter,
            ))!.status,
            SyncSequenceStatus.unresolvable.index,
            reason: 'row $counter should have been retired',
          );
        }
      },
    );
  });

  group('generated sequence lifecycle operations', () {
    test(
      'markReservedSequenceCounterBurnPending does not overwrite an '
      'already-bound row',
      () async {
        final database = SyncDatabase(inMemoryDatabase: true);
        addTearDown(database.close);
        final createdAt = DateTime(2026, 5, 24, 11);
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('burn-conflict-host'),
            counter: const Value(1),
            entryId: const Value('bound-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ),
        );

        await database.markReservedSequenceCounterBurnPending(
          hostId: 'burn-conflict-host',
          counter: 1,
          now: createdAt.add(const Duration(minutes: 1)),
        );

        final row = await database.getEntryByHostAndCounter(
          'burn-conflict-host',
          1,
        );
        expect(row, isNotNull);
        expect(row!.status, SyncSequenceStatus.received.index);
        expect(row.entryId, 'bound-entry');
        expect(
          await database.burnPendingSequenceCountersForHost(
            hostId: 'burn-conflict-host',
          ),
          isEmpty,
        );
      },
    );

    test(
      'recordOwnUnresolvableSequenceCounter inserts absent counters as '
      'burned with no payload mapping',
      () async {
        final database = SyncDatabase(inMemoryDatabase: true);
        addTearDown(database.close);
        final now = DateTime(2026, 5, 24, 12);

        final recorded = await database.recordOwnUnresolvableSequenceCounter(
          hostId: 'own-burn-host',
          counter: 1,
          now: now,
        );

        expect(recorded, isTrue);
        final row = await database.getEntryByHostAndCounter(
          'own-burn-host',
          1,
        );
        expect(row, isNotNull);
        expect(row!.status, SyncSequenceStatus.burned.index);
        expect(row.entryId, isNull);
        expect(row.payloadType, SyncSequencePayloadType.journalEntity.index);
        expect(await database.getLastCounterForHost('own-burn-host'), 1);
      },
    );

    test(
      'recordOwnUnresolvableSequenceCounter converts non-authoritative rows '
      'and clears stale payload mappings',
      () async {
        final database = SyncDatabase(inMemoryDatabase: true);
        addTearDown(database.close);
        final createdAt = DateTime(2026, 5, 24, 12);
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('own-burn-update-host'),
            counter: const Value(1),
            entryId: const Value('stale-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ),
        );

        final recorded = await database.recordOwnUnresolvableSequenceCounter(
          hostId: 'own-burn-update-host',
          counter: 1,
          payloadType: SyncSequencePayloadType.entryLink,
          now: createdAt.add(const Duration(minutes: 1)),
        );

        expect(recorded, isTrue);
        final row = await database.getEntryByHostAndCounter(
          'own-burn-update-host',
          1,
        );
        expect(row, isNotNull);
        expect(row!.status, SyncSequenceStatus.burned.index);
        expect(row.entryId, isNull);
        expect(row.payloadType, SyncSequencePayloadType.entryLink.index);
        expect(
          row.updatedAt,
          createdAt.add(const Duration(minutes: 1)),
        );
      },
    );

    test(
      'recordOwnUnresolvableSequenceCounter does not overwrite '
      'authoritative payload mappings',
      () async {
        final database = SyncDatabase(inMemoryDatabase: true);
        addTearDown(database.close);
        final createdAt = DateTime(2026, 5, 24, 12);
        final statuses = [
          SyncSequenceStatus.received,
          SyncSequenceStatus.backfilled,
          SyncSequenceStatus.deleted,
        ];

        for (final status in statuses) {
          final counter = status.index + 1;
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value('own-burn-authoritative-host'),
              counter: Value(counter),
              entryId: Value('entry-$counter'),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(status.index),
              createdAt: Value(createdAt),
              updatedAt: Value(createdAt),
            ),
          );

          final recorded = await database.recordOwnUnresolvableSequenceCounter(
            hostId: 'own-burn-authoritative-host',
            counter: counter,
            payloadType: SyncSequencePayloadType.entryLink,
            now: createdAt.add(const Duration(minutes: 1)),
          );

          expect(recorded, isFalse, reason: '$status');
          final row = await database.getEntryByHostAndCounter(
            'own-burn-authoritative-host',
            counter,
          );
          expect(row, isNotNull);
          expect(row!.status, status.index, reason: '$status');
          expect(row.entryId, 'entry-$counter', reason: '$status');
          expect(
            row.payloadType,
            SyncSequencePayloadType.journalEntity.index,
            reason: '$status',
          );
          expect(row.updatedAt, createdAt, reason: '$status');
        }
      },
    );

    test(
      'recordOwnUnresolvableSequenceCounter is idempotent on an already-burned '
      'row — a repeat burn does not rewrite the row or churn updated_at',
      () async {
        final database = SyncDatabase(inMemoryDatabase: true);
        addTearDown(database.close);
        final now = DateTime(2026, 5, 24, 12);
        final first = await database.recordOwnUnresolvableSequenceCounter(
          hostId: 'own-burn-idempotent-host',
          counter: 1,
          now: now,
        );
        expect(first, isTrue);

        final second = await database.recordOwnUnresolvableSequenceCounter(
          hostId: 'own-burn-idempotent-host',
          counter: 1,
          now: now.add(const Duration(minutes: 5)),
        );
        // burned is in the isNotIn guard, so the repeat finds nothing to
        // update and nothing to insert.
        expect(second, isFalse);

        final row = await database.getEntryByHostAndCounter(
          'own-burn-idempotent-host',
          1,
        );
        expect(row!.status, SyncSequenceStatus.burned.index);
        expect(row.updatedAt, now);
      },
    );

    Glados(
      any.generatedSequenceLifecycleStatus,
      ExploreConfig(numRuns: 80),
    ).test(
      'only transitions absent, reserved, or burnPending rows to burnPending',
      (status) async {
        final database = SyncDatabase(inMemoryDatabase: true);
        const hostId = 'generated-burn-pending-guard-host';
        const counter = 1;
        final createdAt = DateTime(2026, 5, 24, 12);
        addTearDown(database.close);
        final shouldTransition =
            status == _GeneratedSequenceLifecycleStatus.absent ||
            status == _GeneratedSequenceLifecycleStatus.reserved ||
            status == _GeneratedSequenceLifecycleStatus.burnPending;
        final seedEntryId = shouldTransition ? null : 'original-entry';

        if (status != _GeneratedSequenceLifecycleStatus.absent) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: const Value(counter),
              entryId: seedEntryId == null
                  ? const Value.absent()
                  : Value(seedEntryId),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(
                _SequenceLifecycleRowSpec(
                  status: status,
                  payloadType: SyncSequencePayloadType.journalEntity,
                  hasEntryId: seedEntryId != null,
                  requestCount: 0,
                  lastRequestedAt: _GeneratedRequestTimestamp.absent,
                  updatedAt: _GeneratedUpdatedTimestamp.fresh,
                ).syncStatus.index,
              ),
              createdAt: Value(createdAt),
              updatedAt: Value(createdAt),
            ),
          );
        }

        await database.markReservedSequenceCounterBurnPending(
          hostId: hostId,
          counter: counter,
          now: createdAt.add(const Duration(minutes: 1)),
        );

        final row = await database.getEntryByHostAndCounter(hostId, counter);
        expect(row, isNotNull, reason: '$status');

        if (shouldTransition) {
          expect(
            row!.status,
            SyncSequenceStatus.burnPending.index,
            reason: '$status',
          );
          expect(row.entryId, isNull, reason: '$status');
        } else {
          expect(
            row!.status,
            _SequenceLifecycleRowSpec(
              status: status,
              payloadType: SyncSequencePayloadType.journalEntity,
              hasEntryId: seedEntryId != null,
              requestCount: 0,
              lastRequestedAt: _GeneratedRequestTimestamp.absent,
              updatedAt: _GeneratedUpdatedTimestamp.fresh,
            ).syncStatus.index,
            reason: '$status',
          );
          expect(row.entryId, seedEntryId, reason: '$status');
        }
      },
      tags: 'glados',
    );

    Glados(any.reservationLifecycleScenario, ExploreConfig(numRuns: 100)).test(
      'preserve the reservation lifecycle invariants',
      (scenario) async {
        final database = SyncDatabase(inMemoryDatabase: true);
        addTearDown(database.close);
        for (var index = 0; index < scenario.outcomes.length; index++) {
          final counter = index + 1;
          await database.recordReservedSequenceCounter(
            hostId: _ReservationLifecycleScenario.hostId,
            counter: counter,
            now: _ReservationLifecycleScenario.start.add(
              Duration(minutes: counter),
            ),
          );

          switch (scenario.outcomes[index]) {
            case _GeneratedReservationOutcome.stillReserved:
              break;
            case _GeneratedReservationOutcome.boundReceived:
              await database.recordSequenceEntry(
                SyncSequenceLogCompanion(
                  hostId: const Value(_ReservationLifecycleScenario.hostId),
                  counter: Value(counter),
                  entryId: Value('reservation-entry-$counter'),
                  payloadType: Value(
                    SyncSequencePayloadType.journalEntity.index,
                  ),
                  status: Value(SyncSequenceStatus.received.index),
                  createdAt: Value(
                    _ReservationLifecycleScenario.start.add(
                      Duration(minutes: counter),
                    ),
                  ),
                  updatedAt: Value(
                    _ReservationLifecycleScenario.start.add(
                      Duration(minutes: counter, seconds: 1),
                    ),
                  ),
                ),
              );
            case _GeneratedReservationOutcome.burnPending:
              await database.markReservedSequenceCounterBurnPending(
                hostId: _ReservationLifecycleScenario.hostId,
                counter: counter,
                now: _ReservationLifecycleScenario.start.add(
                  Duration(minutes: counter, seconds: 2),
                ),
              );
          }
        }

        expect(
          await database.reservedSequenceCountersForHost(
            hostId: _ReservationLifecycleScenario.hostId,
          ),
          scenario.expectedReservedCounters,
        );
        expect(
          await database.burnPendingSequenceCountersForHost(
            hostId: _ReservationLifecycleScenario.hostId,
          ),
          scenario.expectedBurnPendingCounters,
        );
        expect(
          await database.getLastCounterForHost(
            _ReservationLifecycleScenario.hostId,
          ),
          scenario.expectedWatermark,
        );

        for (var counter = 1; counter <= scenario.outcomes.length; counter++) {
          final row = await database.getEntryByHostAndCounter(
            _ReservationLifecycleScenario.hostId,
            counter,
          );
          expect(row, isNotNull, reason: 'counter $counter');
          expect(
            row!.status,
            scenario.expectedStatus(counter).index,
            reason: 'counter $counter',
          );
        }
      },
      tags: 'glados',
    );

    Glados(any.sequenceLifecycleScenario, ExploreConfig(numRuns: 180)).test(
      'match the generated reset and retirement model',
      (scenario) async {
        final database = SyncDatabase(inMemoryDatabase: true);
        addTearDown(database.close);
        for (var index = 0; index < scenario.rows.length; index++) {
          final counter = index + 1;
          final row = scenario.rows[index];
          if (!row.isStored) continue;

          final entryId = row.entryId(counter);
          final lastRequestedAt = row.lastRequestedAtValue(
            _SequenceLifecycleScenario.now,
          );
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(_SequenceLifecycleScenario.hostId),
              counter: Value(counter),
              entryId: entryId == null ? const Value.absent() : Value(entryId),
              payloadType: Value(row.payloadType.index),
              status: Value(row.syncStatus.index),
              createdAt: Value(
                row.createdAt(_SequenceLifecycleScenario.now),
              ),
              updatedAt: Value(
                row.updatedAtValue(_SequenceLifecycleScenario.now),
              ),
              requestCount: Value(row.requestCount),
              lastRequestedAt: lastRequestedAt == null
                  ? const Value.absent()
                  : Value(lastRequestedAt),
            ),
          );
        }

        final affected = switch (scenario.operation) {
          _GeneratedSequenceLifecycleOperation.resetKnown =>
            await database.resetUnresolvableWithKnownPayload(),
          _GeneratedSequenceLifecycleOperation.resetAll =>
            await database.resetAllUnresolvableEntries(),
          _GeneratedSequenceLifecycleOperation.retireExhausted =>
            await database.retireExhaustedRequestedEntries(
              maxRequestCount: _SequenceLifecycleScenario.maxRequestCount,
              grace: _SequenceLifecycleScenario.grace,
              now: _SequenceLifecycleScenario.now,
              pageSize: 3,
            ),
          _GeneratedSequenceLifecycleOperation.retireAgedOut =>
            await database.retireAgedOutRequestedEntries(
              amnestyWindow: _SequenceLifecycleScenario.amnestyWindow,
              now: _SequenceLifecycleScenario.now,
              pageSize: 3,
            ),
        };

        expect(affected, scenario.expectedAffectedCount);

        for (var counter = 1; counter <= scenario.rows.length; counter++) {
          final entry = await database.getEntryByHostAndCounter(
            _SequenceLifecycleScenario.hostId,
            counter,
          );
          final expected = scenario.expectedRow(counter);
          if (expected.status == null) {
            expect(entry, isNull, reason: 'counter $counter');
            continue;
          }

          expect(entry, isNotNull, reason: 'counter $counter');
          expect(entry!.status, expected.status!.index);
          expect(entry.entryId, expected.entryId);
          expect(entry.payloadType, expected.payloadType!.index);
          expect(entry.requestCount, expected.requestCount);
          if (expected.lastRequestedCleared) {
            expect(entry.lastRequestedAt, isNull);
          }
        }

        expect(
          await database.getLastCounterForHost(
            _SequenceLifecycleScenario.hostId,
          ),
          scenario.expectedWatermark,
        );
      },
      tags: 'glados',
    );
  });
}
