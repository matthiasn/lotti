import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_backfill_responder.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

SyncSequenceLogItem _logItem({
  required String hostId,
  required int counter,
  required int status,
  String? entryId,
}) => SyncSequenceLogItem(
  hostId: hostId,
  counter: counter,
  entryId: entryId,
  payloadType: SyncSequencePayloadType.journalEntity.index,
  originatingHostId: hostId,
  status: status,
  createdAt: DateTime(2024, 3, 15, 10),
  updatedAt: DateTime(2024, 3, 15, 10),
  requestCount: 0,
);

void main() {
  setUpAll(() {
    registerFallbackValue(LogDomain.sync);
    registerFallbackValue(SyncSequenceStatus.received);
    registerFallbackValue(SyncSequencePayloadType.journalEntity);
    registerFallbackValue(
      SyncSequenceLogCompanion(
        hostId: const Value(''),
        counter: const Value(0),
        status: const Value(0),
        createdAt: Value(DateTime(2024)),
        updatedAt: Value(DateTime(2024)),
      ),
    );
  });

  late MockSyncDatabase db;
  late MockDomainLogger logging;
  late SyncSequenceCache cache;
  late SyncSequenceBackfillResponder responder;

  const hostId = 'host-a';

  setUp(() {
    db = MockSyncDatabase();
    logging = MockDomainLogger();
    when(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(() => db.recordSequenceEntry(any())).thenAnswer((_) async => 1);
    cache = SyncSequenceCache(db);
    responder = SyncSequenceBackfillResponder(
      syncDatabase: db,
      cache: cache,
      tracer: SyncSequenceTracer(loggingService: logging),
    );
  });

  group('handleBackfillResponse', () {
    test('deleted marks the row deleted when not already resolved', () async {
      when(
        () => db.getEntryByHostAndCounter(hostId, 5),
      ).thenAnswer((_) async => null);
      when(
        () => db.updateSequenceStatus(any(), any(), any()),
      ).thenAnswer((_) async => 1);

      await responder.handleBackfillResponse(
        hostId: hostId,
        counter: 5,
        deleted: true,
      );

      verify(
        () => db.updateSequenceStatus(hostId, 5, SyncSequenceStatus.deleted),
      ).called(1);
    });

    test('deleted is ignored when the row is already received', () async {
      when(() => db.getEntryByHostAndCounter(hostId, 5)).thenAnswer(
        (_) async => _logItem(
          hostId: hostId,
          counter: 5,
          status: SyncSequenceStatus.received.index,
        ),
      );

      await responder.handleBackfillResponse(
        hostId: hostId,
        counter: 5,
        deleted: true,
      );

      verifyNever(() => db.updateSequenceStatus(any(), any(), any()));
    });

    test(
      'unresolvable upserts a burned row when nothing authoritative exists',
      () async {
        when(
          () => db.getEntryByHostAndCounter(hostId, 5),
        ).thenAnswer((_) async => null);

        await responder.handleBackfillResponse(
          hostId: hostId,
          counter: 5,
          deleted: false,
          unresolvable: true,
        );

        final captured =
            verify(
                  () => db.recordSequenceEntry(captureAny()),
                ).captured.single
                as SyncSequenceLogCompanion;
        expect(captured.status.value, SyncSequenceStatus.burned.index);
        expect(captured.entryId.value, isNull);
      },
    );

    test('a fresh hint inserts a requested row', () async {
      when(
        () => db.getEntryByHostAndCounter(hostId, 5),
      ).thenAnswer((_) async => null);

      await responder.handleBackfillResponse(
        hostId: hostId,
        counter: 5,
        deleted: false,
        entryId: 'e1',
      );

      final captured =
          verify(
                () => db.recordSequenceEntry(captureAny()),
              ).captured.single
              as SyncSequenceLogCompanion;
      expect(captured.status.value, SyncSequenceStatus.requested.index);
      expect(captured.entryId.value, 'e1');
    });

    test('a hint reopens an unresolvable row back to requested', () async {
      when(() => db.getEntryByHostAndCounter(hostId, 5)).thenAnswer(
        (_) async => _logItem(
          hostId: hostId,
          counter: 5,
          status: SyncSequenceStatus.unresolvable.index,
        ),
      );

      await responder.handleBackfillResponse(
        hostId: hostId,
        counter: 5,
        deleted: false,
        entryId: 'e1',
      );

      final captured =
          verify(
                () => db.recordSequenceEntry(captureAny()),
              ).captured.single
              as SyncSequenceLogCompanion;
      expect(captured.status.value, SyncSequenceStatus.requested.index);
    });

    test('a hint never reopens a burned row', () async {
      when(() => db.getEntryByHostAndCounter(hostId, 5)).thenAnswer(
        (_) async => _logItem(
          hostId: hostId,
          counter: 5,
          status: SyncSequenceStatus.burned.index,
        ),
      );

      await responder.handleBackfillResponse(
        hostId: hostId,
        counter: 5,
        deleted: false,
        entryId: 'e1',
      );

      verifyNever(() => db.recordSequenceEntry(any()));
    });
  });

  group('verifyAndMarkBackfilled', () {
    test('returns false when the VC does not cover the counter', () async {
      final result = await responder.verifyAndMarkBackfilled(
        hostId: hostId,
        counter: 5,
        entryId: 'e1',
        entryVectorClock: const VectorClock({hostId: 3}),
      );

      expect(result, isFalse);
      verifyNever(() => db.getEntryByHostAndCounter(any(), any()));
    });

    test('marks a requested row backfilled and preserves createdAt', () async {
      final created = DateTime(2024, 3, 10, 8);
      when(() => db.getEntryByHostAndCounter(hostId, 5)).thenAnswer(
        (_) async => SyncSequenceLogItem(
          hostId: hostId,
          counter: 5,
          entryId: 'e1',
          payloadType: SyncSequencePayloadType.journalEntity.index,
          originatingHostId: hostId,
          status: SyncSequenceStatus.requested.index,
          createdAt: created,
          updatedAt: created,
          requestCount: 1,
        ),
      );

      final result = await responder.verifyAndMarkBackfilled(
        hostId: hostId,
        counter: 5,
        entryId: 'e1',
        entryVectorClock: const VectorClock({hostId: 5}),
      );

      expect(result, isTrue);
      final captured =
          verify(
                () => db.recordSequenceEntry(captureAny()),
              ).captured.single
              as SyncSequenceLogCompanion;
      expect(captured.status.value, SyncSequenceStatus.backfilled.index);
      expect(captured.createdAt.value, created);
    });
  });

  group('resolvePendingHints', () {
    test('verifies each pending entry and counts those resolved', () async {
      when(
        () => db.getPendingEntriesByPayloadId(
          payloadType: any(named: 'payloadType'),
          payloadId: any(named: 'payloadId'),
        ),
      ).thenAnswer(
        (_) async => [
          _logItem(
            hostId: hostId,
            counter: 5,
            status: SyncSequenceStatus.requested.index,
          ),
        ],
      );
      when(() => db.getEntryByHostAndCounter(hostId, 5)).thenAnswer(
        (_) async => _logItem(
          hostId: hostId,
          counter: 5,
          status: SyncSequenceStatus.requested.index,
        ),
      );

      final resolved = await responder.resolvePendingHints(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: 'e1',
        payloadVectorClock: const VectorClock({hostId: 5}),
      );

      expect(resolved, 1);
    });
  });

  group('reset paths clear the shared cache', () {
    test(
      'resetUnresolvableEntries clears watermark + materialized bound when rows reset',
      () async {
        cache.setMaterializedUpperBound(hostId, 42);
        when(() => db.getLastCounterForHost(hostId)).thenAnswer((_) async => 4);
        await cache.getCachedLastCounterForHost(hostId);
        when(
          () => db.resetUnresolvableWithKnownPayload(),
        ).thenAnswer((_) async => 3);

        final count = await responder.resetUnresolvableEntries();

        expect(count, 3);
        expect(cache.containsLastCounter(hostId), isFalse);
        expect(cache.getMaterializedUpperBound(hostId), isNull);
      },
    );

    test(
      'resetAllUnresolvableEntries leaves the cache untouched when nothing reset',
      () async {
        cache.setMaterializedUpperBound(hostId, 42);
        when(
          () => db.resetAllUnresolvableEntries(),
        ).thenAnswer((_) async => 0);

        final count = await responder.resetAllUnresolvableEntries();

        expect(count, 0);
        expect(cache.getMaterializedUpperBound(hostId), 42);
      },
    );
  });
}
