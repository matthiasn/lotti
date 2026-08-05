// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_sequence_log_service_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncDatabase mockDb;
  late MockDomainLogger mockLogging;
  late SyncSequenceLogService service;

  const myHostId = 'my-host-uuid';
  const aliceHostId = 'alice-host-uuid';
  const bobHostId = 'bob-host-uuid';

  setUpAll(registerSyncSequenceLogFallbackValues);

  setUp(() {
    final bench = SyncSequenceLogServiceTestBench.create(
      myHostId: myHostId,
      aliceHostId: aliceHostId,
      bobHostId: bobHostId,
    );
    mockDb = bench.mockDb;
    mockLogging = bench.mockLogging;
    service = bench.service;
  });

  group('getEntryByHostAndCounter', () {
    test('delegates to database and returns result', () async {
      final item = createLogItem(aliceHostId, 5);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => item);

      final result = await service.getEntryByHostAndCounter(aliceHostId, 5);

      expect(result, item);
      verify(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).called(1);
    });

    test('returns null when entry does not exist', () async {
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 99),
      ).thenAnswer((_) async => null);

      final result = await service.getEntryByHostAndCounter(aliceHostId, 99);

      expect(result, isNull);
    });
  });

  group('populateFromJournal', () {
    test('populates sequence log for ALL hosts in vector clock', () async {
      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final entries = [
        // Entry with 2 hosts in VC = 2 sequence log entries
        (id: 'entry-1', vectorClock: {myHostId: 10, aliceHostId: 5}),
        // Entry with 1 host = 1 sequence log entry
        (id: 'entry-2', vectorClock: {myHostId: 20}),
      ];

      final count = await service.populateFromJournal(
        entryStream: Stream.value(entries),
        getTotalCount: () async => 2,
      );

      // 2 entries from entry-1 + 1 entry from entry-2 = 3 total
      expect(count, 3);
      verify(() => mockDb.batchInsertSequenceEntries(any())).called(1);
    });

    test('skips entries that already exist in log', () async {
      when(
        () => mockDb.getCountersForHost(myHostId),
      ).thenAnswer((_) async => {10}); // Counter 10 already exists
      when(
        () => mockDb.getCountersForHost(aliceHostId),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final entries = [
        (id: 'entry-1', vectorClock: {myHostId: 10, aliceHostId: 5}),
      ];

      final count = await service.populateFromJournal(
        entryStream: Stream.value(entries),
        getTotalCount: () async => 1,
      );

      // myHostId:10 exists, but aliceHostId:5 doesn't = 1 new entry
      expect(count, 1);
      verify(() => mockDb.batchInsertSequenceEntries(any())).called(1);
    });

    test('skips entries with null or empty vectorClock', () async {
      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});

      final entries = [
        (id: 'entry-1', vectorClock: <String, int>{}), // Empty
        (id: 'entry-2', vectorClock: null), // Null
      ];

      final count = await service.populateFromJournal(
        entryStream: Stream.value(entries),
        getTotalCount: () async => 2,
      );

      expect(count, 0);
      verifyNever(() => mockDb.batchInsertSequenceEntries(any()));
    });

    test('works even when host is not set', () async {
      // populateFromJournal no longer requires myHost
      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final entries = [
        (id: 'entry-1', vectorClock: {aliceHostId: 5}),
      ];

      final count = await service.populateFromJournal(
        entryStream: Stream.value(entries),
        getTotalCount: () async => 1,
      );

      expect(count, 1);
    });

    test('reports progress after each batch', () async {
      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final batch1 = [
        (id: 'entry-1', vectorClock: {myHostId: 10}),
        (id: 'entry-2', vectorClock: {myHostId: 20}),
      ];
      final batch2 = [
        (id: 'entry-3', vectorClock: {myHostId: 30}),
      ];

      final progressValues = <double>[];

      await service.populateFromJournal(
        entryStream: Stream.fromIterable([batch1, batch2]),
        getTotalCount: () async => 3,
        onProgress: progressValues.add,
      );

      expect(progressValues.length, 2);
      expect(progressValues[0], closeTo(2 / 3, 0.01));
      expect(progressValues[1], closeTo(1.0, 0.01));
    });
  });

  group('getBackfillStats', () {
    test('delegates to database', () async {
      final mockStats = BackfillStats.fromHostStats([
        const BackfillHostStats(
          receivedCount: 10,
          missingCount: 2,
          requestedCount: 1,
          backfilledCount: 3,
          deletedCount: 0,
          unresolvableCount: 0,
          burnedCount: 4,
        ),
      ]);

      when(() => mockDb.getBackfillStats()).thenAnswer((_) async => mockStats);

      final result = await service.getBackfillStats();

      expect(result, mockStats);
      verify(() => mockDb.getBackfillStats()).called(1);
    });
  });

  group('watchBackfillMissingCount', () {
    test('delegates to database', () async {
      final counts = Stream<int>.fromIterable(const [12, 6, 0]);
      when(mockDb.watchBackfillMissingCount).thenAnswer((_) => counts);

      expect(await service.watchBackfillMissingCount().toList(), const [
        12,
        6,
        0,
      ]);
      verify(mockDb.watchBackfillMissingCount).called(1);
    });
  });

  group('getRequestedEntries', () {
    test('delegates to database with default limit', () async {
      when(
        () => mockDb.getRequestedEntries(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => []);

      await service.getRequestedEntries();

      verify(() => mockDb.getRequestedEntries(limit: 50, offset: 0)).called(1);
    });

    test('passes custom limit', () async {
      when(
        () => mockDb.getRequestedEntries(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => []);

      await service.getRequestedEntries(limit: 25, offset: 7);

      verify(() => mockDb.getRequestedEntries(limit: 25, offset: 7)).called(1);
    });

    test('returns requested entries from database', () async {
      final entries = [
        createLogItem(aliceHostId, 1, status: SyncSequenceStatus.requested),
        createLogItem(aliceHostId, 2, status: SyncSequenceStatus.requested),
      ];

      when(
        () => mockDb.getRequestedEntries(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await service.getRequestedEntries();

      expect(result, entries);
      expect(result.length, 2);
    });
  });

  group('resetRequestCounts', () {
    test('delegates to database', () async {
      when(() => mockDb.resetRequestCounts(any())).thenAnswer((_) async {});

      final entries = [
        (hostId: aliceHostId, counter: 1),
        (hostId: aliceHostId, counter: 2),
        (hostId: bobHostId, counter: 3),
      ];

      await service.resetRequestCounts(entries);

      verify(() => mockDb.resetRequestCounts(entries)).called(1);
    });

    test('handles empty list', () async {
      when(() => mockDb.resetRequestCounts(any())).thenAnswer((_) async {});

      await service.resetRequestCounts([]);

      verify(() => mockDb.resetRequestCounts([])).called(1);
    });

    test('logs the reset operation', () async {
      when(() => mockDb.resetRequestCounts(any())).thenAnswer((_) async {});

      final entries = [
        (hostId: aliceHostId, counter: 1),
        (hostId: aliceHostId, counter: 2),
      ];

      await service.resetRequestCounts(entries);

      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('reset 2 entries')),
          subDomain: 'sequence.reRequest',
        ),
      ).called(1);
    });
  });

  group('getMissingEntriesWithLimits', () {
    // Stubs and verifies must mirror the exact parameter shape of the
    // service's call site (which passes everything except `now` explicitly):
    // noSuchMethod forwarders for mixin-declared methods do not reliably fill
    // in omitted optional parameters, so a stub that omits a parameter the
    // production call passes never matches.
    test('delegates to database with default parameters', () async {
      when(
        () => mockDb.getMissingEntriesWithLimits(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
          maxAge: any(named: 'maxAge'),
          minAge: any(named: 'minAge'),
          requestedMinAge: any(named: 'requestedMinAge'),
          maxPerHost: any(named: 'maxPerHost'),
          suppressedCoverage: any(named: 'suppressedCoverage'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntriesWithLimits();

      verify(
        () => mockDb.getMissingEntriesWithLimits(
          limit: 50,
          maxRequestCount: 10,
          maxAge: null,
          minAge: Duration.zero,
          requestedMinAge: null,
          maxPerHost: null,
          suppressedCoverage: const {},
          offset: 0,
        ),
      ).called(1);
    });

    test('passes custom parameters', () async {
      when(
        () => mockDb.getMissingEntriesWithLimits(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
          maxAge: any(named: 'maxAge'),
          minAge: any(named: 'minAge'),
          requestedMinAge: any(named: 'requestedMinAge'),
          maxPerHost: any(named: 'maxPerHost'),
          suppressedCoverage: any(named: 'suppressedCoverage'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntriesWithLimits(
        limit: 25,
        maxRequestCount: 5,
        maxAge: const Duration(hours: 12),
        minAge: const Duration(minutes: 3),
        requestedMinAge: const Duration(hours: 1),
        maxPerHost: 100,
        suppressedCoverage: const {'alice': 99},
        offset: 9,
      );

      verify(
        () => mockDb.getMissingEntriesWithLimits(
          limit: 25,
          maxRequestCount: 5,
          maxAge: const Duration(hours: 12),
          minAge: const Duration(minutes: 3),
          requestedMinAge: const Duration(hours: 1),
          maxPerHost: 100,
          suppressedCoverage: const {'alice': 99},
          offset: 9,
        ),
      ).called(1);
    });

    test('returns missing entries', () async {
      final entries = [
        createLogItem(aliceHostId, 1),
        createLogItem(aliceHostId, 2),
      ];

      when(
        () => mockDb.getMissingEntriesWithLimits(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
          maxAge: any(named: 'maxAge'),
          minAge: any(named: 'minAge'),
          requestedMinAge: any(named: 'requestedMinAge'),
          maxPerHost: any(named: 'maxPerHost'),
          suppressedCoverage: any(named: 'suppressedCoverage'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await service.getMissingEntriesWithLimits();

      expect(result, entries);
      expect(result.length, 2);
    });
  });

  group('recordReceivedEntryLink', () {
    test('records entry link with correct payload type', () async {
      const vectorClock = VectorClock({aliceHostId: 1});
      const linkId = 'link-1';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 1),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntryLink(
        linkId: linkId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final record = captured[0] as SyncSequenceLogCompanion;
      expect(record.entryId.value, linkId);
      expect(record.payloadType.value, SyncSequencePayloadType.entryLink.index);
    });

    test('detects gaps when link counter jumps', () async {
      // Alice counter was 2, now we get link counter 5 - missing 3 and 4
      const vectorClock = VectorClock({aliceHostId: 5});
      const linkId = 'link-5';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntryLink(
        linkId: linkId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps.length, 2);
      expect(gaps[0], (hostId: aliceHostId, counter: 3));
      expect(gaps[1], (hostId: aliceHostId, counter: 4));

      verify(() => mockDb.batchInsertSequenceEntries(any())).called(1);
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });
  });

  group('EntryLink resolves ghost missing rows', () {
    test(
      'receiving entry link resolves previously missing journal counter',
      () async {
        // Scenario: A journal entry created a gap at counter 3, but counter 3
        // was actually an entry link operation. When the link arrives, it should
        // resolve the "ghost missing" row.

        const vectorClock = VectorClock({aliceHostId: 3});
        const linkId = 'link-3';

        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 2);
        // Counter 3 already exists as missing (created by journal gap detection)
        when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
          (_) async => createLogItem(
            aliceHostId,
            3,
            status: SyncSequenceStatus.missing,
          ),
        );
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        final gaps = await service.recordReceivedEntryLink(
          linkId: linkId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        expect(gaps, isEmpty);

        // The missing row should be updated to received with the link ID
        final captured = verify(
          () => mockDb.recordSequenceEntry(captureAny()),
        ).captured;

        expect(captured.length, 1);
        final record = captured[0] as SyncSequenceLogCompanion;
        expect(record.entryId.value, linkId);
        expect(record.status.value, SyncSequenceStatus.received.index);
        expect(
          record.payloadType.value,
          SyncSequencePayloadType.entryLink.index,
        );
      },
    );

    test(
      'receiving journal entry resolves missing row created by link gap',
      () async {
        // Scenario: An entry link operation created a gap at counter 5, but
        // counter 5 was actually a journal entry. When the journal entry arrives,
        // it should resolve the "ghost missing" row.

        const vectorClock = VectorClock({aliceHostId: 5});
        const entryId = 'entry-5';

        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 4);
        // Counter 5 already exists as missing (created by link gap detection)
        when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
          (_) async => createLogItem(
            aliceHostId,
            5,
            status: SyncSequenceStatus.missing,
          ),
        );
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        final gaps = await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        expect(gaps, isEmpty);

        // The missing row should be updated to received with journal entry ID
        final captured = verify(
          () => mockDb.recordSequenceEntry(captureAny()),
        ).captured;

        expect(captured.length, 1);
        final record = captured[0] as SyncSequenceLogCompanion;
        expect(record.entryId.value, entryId);
        expect(record.status.value, SyncSequenceStatus.received.index);
        expect(
          record.payloadType.value,
          SyncSequencePayloadType.journalEntity.index,
        );
      },
    );
  });

  group('Interleaved link/journal operations', () {
    test('interleaved operations do not create permanent missing gaps', () async {
      // Scenario: Operations happen in order journal:1, link:2, journal:3
      // We receive them in order 1, 3, then 2 - no permanent gaps should remain

      // Step 1: Receive journal entry at counter 1
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 1),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      var gaps = await service.recordReceivedEntry(
        entryId: 'journal-1',
        vectorClock: const VectorClock({aliceHostId: 1}),
        originatingHostId: aliceHostId,
      );
      expect(gaps, isEmpty);

      // Step 2: Receive journal entry at counter 3 (creates gap at 2)
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 1);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 2),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer((_) async => null);

      gaps = await service.recordReceivedEntry(
        entryId: 'journal-3',
        vectorClock: const VectorClock({aliceHostId: 3}),
        originatingHostId: aliceHostId,
      );
      expect(gaps.length, 1);
      expect(gaps[0], (hostId: aliceHostId, counter: 2));

      // Step 3: Receive entry link at counter 2 (resolves the gap)
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 3);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 2)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 2, status: SyncSequenceStatus.missing),
      );

      gaps = await service.recordReceivedEntryLink(
        linkId: 'link-2',
        vectorClock: const VectorClock({aliceHostId: 2}),
        originatingHostId: aliceHostId,
      );
      expect(gaps, isEmpty);

      // Verify the link was recorded with correct type
      final lastCaptured =
          verify(() => mockDb.recordSequenceEntry(captureAny())).captured.last
              as SyncSequenceLogCompanion;
      expect(lastCaptured.entryId.value, 'link-2');
      expect(
        lastCaptured.payloadType.value,
        SyncSequencePayloadType.entryLink.index,
      );
      expect(lastCaptured.status.value, SyncSequenceStatus.received.index);
    });

    test(
      'multi-host VC with mixed payload types tracks all counters',
      () async {
        // Scenario: Entry with VC {alice:5, bob:3} where alice's counter was
        // from a journal edit and bob's was from a link creation
        const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
        const entryId = 'journal-entry';

        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 4);
        when(
          () => mockDb.getLastCounterForHost(bobHostId),
        ).thenAnswer((_) async => 2);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(bobHostId, 3),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        final gaps = await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        expect(gaps, isEmpty);

        // Both hosts should be recorded with the same entryId
        final captured = verify(
          () => mockDb.recordSequenceEntry(captureAny()),
        ).captured;
        expect(captured.length, 2);

        for (final record in captured.cast<SyncSequenceLogCompanion>()) {
          expect(record.entryId.value, entryId);
          // Default payload type for recordReceivedEntry is journalEntity
          expect(
            record.payloadType.value,
            SyncSequencePayloadType.journalEntity.index,
          );
        }
      },
    );
  });

  group('populateFromEntryLinks', () {
    test('populates sequence log from entry links stream', () async {
      final linkStream = Stream.fromIterable([
        [
          (id: 'link-1', vectorClock: <String, int>{aliceHostId: 1}),
          (id: 'link-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      var progressCalled = false;
      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 2,
        onProgress: (progress) {
          progressCalled = true;
        },
      );

      expect(populated, 2);
      expect(progressCalled, true);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 2);

      // All entries should have entryLink payload type
      for (final entry in entries) {
        expect(
          entry.payloadType.value,
          SyncSequencePayloadType.entryLink.index,
        );
      }
    });

    test('skips existing counters', () async {
      final linkStream = Stream.fromIterable([
        [
          (id: 'link-1', vectorClock: <String, int>{aliceHostId: 1}),
          (id: 'link-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      // Counter 1 already exists
      when(
        () => mockDb.getCountersForHost(aliceHostId),
      ).thenAnswer((_) async => {1});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 2,
      );

      // Only counter 2 should be inserted
      expect(populated, 1);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 1);
      expect(entries[0].counter.value, 2);
    });

    test('handles multi-host vector clocks', () async {
      final linkStream = Stream.fromIterable([
        [
          (
            id: 'link-1',
            vectorClock: <String, int>{aliceHostId: 5, bobHostId: 3},
          ),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 1,
      );

      // Should insert 2 entries (one for each host in the VC)
      expect(populated, 2);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 2);

      final aliceEntry = entries.firstWhere(
        (e) => e.hostId.value == aliceHostId,
      );
      final bobEntry = entries.firstWhere((e) => e.hostId.value == bobHostId);

      expect(aliceEntry.counter.value, 5);
      expect(bobEntry.counter.value, 3);
      expect(aliceEntry.entryId.value, 'link-1');
      expect(bobEntry.entryId.value, 'link-1');
    });

    test('returns zero when stream is empty', () async {
      const linkStream =
          Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();

      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 0,
      );

      expect(populated, 0);
      verifyNever(() => mockDb.batchInsertSequenceEntries(any()));
    });

    test('skips links with null vector clock', () async {
      final linkStream = Stream.fromIterable([
        [
          (id: 'link-1', vectorClock: null),
          (id: 'link-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 2,
      );

      // Only link-2 should be inserted
      expect(populated, 1);
    });
  });

  group('populateFromAgentEntities', () {
    test('populates sequence log from agent entities stream', () async {
      final entityStream = Stream.fromIterable([
        [
          (id: 'entity-1', vectorClock: <String, int>{aliceHostId: 1}),
          (id: 'entity-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      var progressCalled = false;
      final populated = await service.populateFromAgentEntities(
        entityStream: entityStream,
        getTotalCount: () async => 2,
        onProgress: (progress) {
          progressCalled = true;
        },
      );

      expect(populated, 2);
      expect(progressCalled, true);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 2);

      // All entries should have agentEntity payload type
      for (final entry in entries) {
        expect(
          entry.payloadType.value,
          SyncSequencePayloadType.agentEntity.index,
        );
      }
    });

    test('skips existing counters', () async {
      final entityStream = Stream.fromIterable([
        [
          (id: 'entity-1', vectorClock: <String, int>{aliceHostId: 1}),
          (id: 'entity-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(aliceHostId),
      ).thenAnswer((_) async => {1});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final populated = await service.populateFromAgentEntities(
        entityStream: entityStream,
        getTotalCount: () async => 2,
      );

      expect(populated, 1);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 1);
      expect(entries[0].counter.value, 2);
    });

    test('returns zero when stream is empty', () async {
      const entityStream =
          Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();

      final populated = await service.populateFromAgentEntities(
        entityStream: entityStream,
        getTotalCount: () async => 0,
      );

      expect(populated, 0);
      verifyNever(() => mockDb.batchInsertSequenceEntries(any()));
    });

    test('skips entities with null vector clock', () async {
      final entityStream = Stream.fromIterable([
        [
          (id: 'entity-1', vectorClock: null),
          (id: 'entity-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final populated = await service.populateFromAgentEntities(
        entityStream: entityStream,
        getTotalCount: () async => 2,
      );

      expect(populated, 1);
    });

    test(
      'breaks a tied max counter deterministically by lexicographically '
      'smallest host id, regardless of vector-clock insertion order',
      () async {
        // bob and alice share the max counter (5). The originating host is the
        // one with the highest counter; on a tie `_populateFromStream` sorts VC
        // entries by host id and keeps the first to reach the max via a strict
        // `>`, so the lexicographically smallest host id wins. bob is listed
        // first in the VC to prove the choice comes from the sort, not from map
        // insertion order.
        final entityStream = Stream.fromIterable([
          [
            (
              id: 'tie-entity',
              vectorClock: <String, int>{bobHostId: 5, aliceHostId: 5},
            ),
          ],
        ]);

        when(
          () => mockDb.getCountersForHost(any()),
        ).thenAnswer((_) async => <int>{});
        when(
          () => mockDb.batchInsertSequenceEntries(any()),
        ).thenAnswer((_) async {});

        final populated = await service.populateFromAgentEntities(
          entityStream: entityStream,
          getTotalCount: () async => 1,
        );

        expect(populated, 2);

        final entries =
            verify(
                  () => mockDb.batchInsertSequenceEntries(captureAny()),
                ).captured.single
                as List<SyncSequenceLogCompanion>;

        // Both rows attribute the same originating host: alice ('alice-...' <
        // 'bob-...'), even though bob was iterated first in the source VC.
        expect(entries.map((e) => e.originatingHostId.value).toSet(), {
          aliceHostId,
        });
        // Sanity: both hosts' counters are still recorded as separate rows.
        expect(entries.map((e) => e.hostId.value).toSet(), {
          aliceHostId,
          bobHostId,
        });
      },
    );
  });

  group('populateFromAgentLinks', () {
    test('populates sequence log from agent links stream', () async {
      final linkStream = Stream.fromIterable([
        [
          (id: 'alink-1', vectorClock: <String, int>{aliceHostId: 1}),
          (id: 'alink-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      var progressCalled = false;
      final populated = await service.populateFromAgentLinks(
        linkStream: linkStream,
        getTotalCount: () async => 2,
        onProgress: (progress) {
          progressCalled = true;
        },
      );

      expect(populated, 2);
      expect(progressCalled, true);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 2);

      // All entries should have agentLink payload type
      for (final entry in entries) {
        expect(
          entry.payloadType.value,
          SyncSequencePayloadType.agentLink.index,
        );
      }
    });

    test('handles multi-host vector clocks', () async {
      final linkStream = Stream.fromIterable([
        [
          (
            id: 'alink-1',
            vectorClock: <String, int>{aliceHostId: 5, bobHostId: 3},
          ),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final populated = await service.populateFromAgentLinks(
        linkStream: linkStream,
        getTotalCount: () async => 1,
      );

      expect(populated, 2);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 2);

      final aliceEntry = entries.firstWhere(
        (e) => e.hostId.value == aliceHostId,
      );
      final bobEntry = entries.firstWhere((e) => e.hostId.value == bobHostId);

      expect(aliceEntry.counter.value, 5);
      expect(bobEntry.counter.value, 3);
      expect(aliceEntry.entryId.value, 'alink-1');
      expect(bobEntry.entryId.value, 'alink-1');
    });

    test('returns zero when stream is empty', () async {
      const linkStream =
          Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();

      final populated = await service.populateFromAgentLinks(
        linkStream: linkStream,
        getTotalCount: () async => 0,
      );

      expect(populated, 0);
      verifyNever(() => mockDb.batchInsertSequenceEntries(any()));
    });

    test('skips links with null vector clock', () async {
      final linkStream = Stream.fromIterable([
        [
          (id: 'alink-1', vectorClock: null),
          (id: 'alink-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(
        () => mockDb.getCountersForHost(any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final populated = await service.populateFromAgentLinks(
        linkStream: linkStream,
        getTotalCount: () async => 2,
      );

      expect(populated, 1);
    });
  });

  group('getNearestCoveringEntry', () {
    test(
      'delegates with hostId/counter and returns the covering row',
      () async {
        final covering = createLogItem(
          aliceHostId,
          12,
          entryId: 'covering-entry',
          status: SyncSequenceStatus.received,
        );
        when(
          () => mockDb.getNearestCoveringEntry(aliceHostId, 9),
        ).thenAnswer((_) async => covering);

        final result = await service.getNearestCoveringEntry(aliceHostId, 9);

        expect(result, same(covering));
        verify(() => mockDb.getNearestCoveringEntry(aliceHostId, 9)).called(1);
      },
    );

    test('returns null when no covering entry exists', () async {
      when(
        () => mockDb.getNearestCoveringEntry(aliceHostId, 99),
      ).thenAnswer((_) async => null);

      final result = await service.getNearestCoveringEntry(aliceHostId, 99);

      expect(result, isNull);
      verify(() => mockDb.getNearestCoveringEntry(aliceHostId, 99)).called(1);
    });
  });
}
