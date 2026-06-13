import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_sender.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(LogDomain.sync);
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
  late MockVectorClockService vc;
  late MockDomainLogger logging;
  late SyncSequenceCache cache;
  late SyncSequenceSender sender;

  const myHost = 'my-host';
  const otherHost = 'other-host';

  setUp(() {
    db = MockSyncDatabase();
    vc = MockVectorClockService();
    logging = MockDomainLogger();
    when(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(vc.getHost).thenAnswer((_) async => myHost);
    when(() => db.recordSequenceEntry(any())).thenAnswer((_) async => 1);
    cache = SyncSequenceCache(db);
    sender = SyncSequenceSender(
      syncDatabase: db,
      vectorClockService: vc,
      cache: cache,
      tracer: SyncSequenceTracer(loggingService: logging),
    );
  });

  test('records only our own host counter from a multi-host VC', () async {
    await sender.recordSentEntry(
      entryId: 'e1',
      vectorClock: const VectorClock({myHost: 4, otherHost: 9}),
    );

    final captured =
        verify(
              () => db.recordSequenceEntry(captureAny()),
            ).captured.single
            as SyncSequenceLogCompanion;
    expect(captured.hostId.value, myHost);
    expect(captured.counter.value, 4);
    expect(captured.entryId.value, 'e1');
    expect(captured.status.value, SyncSequenceStatus.received.index);
    // Only our host was written.
    verifyNever(() => db.recordSequenceEntry(any(that: _hasHost(otherHost))));
  });

  test(
    'primes the shared last-sent cache so a later lookup avoids the DB',
    () async {
      await sender.recordSentEntry(
        entryId: 'e1',
        vectorClock: const VectorClock({myHost: 4}),
      );

      final key = cache.lastSentCacheKey(myHost, 'e1');
      expect(cache.containsLastSent(key), isTrue);
      expect(cache.getLastSent(key), 4);
    },
  );

  test(
    'does not downgrade the cached counter when a lower one is re-recorded',
    () async {
      await sender.recordSentEntry(
        entryId: 'e1',
        vectorClock: const VectorClock({myHost: 7}),
      );
      await sender.recordSentEntry(
        entryId: 'e1',
        vectorClock: const VectorClock({myHost: 3}),
      );

      final key = cache.lastSentCacheKey(myHost, 'e1');
      expect(cache.getLastSent(key), 7);
    },
  );

  test(
    'recordSentEntryLink forwards the entryLink payload type and linkId',
    () async {
      await sender.recordSentEntryLink(
        linkId: 'link-1',
        vectorClock: const VectorClock({myHost: 2}),
      );

      final captured =
          verify(
                () => db.recordSequenceEntry(captureAny()),
              ).captured.single
              as SyncSequenceLogCompanion;
      expect(captured.entryId.value, 'link-1');
      expect(
        captured.payloadType.value,
        SyncSequencePayloadType.entryLink.index,
      );
    },
  );
}

Matcher _hasHost(String hostId) => predicate<SyncSequenceLogCompanion>(
  (c) => c.hostId.value == hostId,
);
