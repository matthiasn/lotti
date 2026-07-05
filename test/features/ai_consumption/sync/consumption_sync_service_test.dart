import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late ConsumptionDatabase db;
  late ConsumptionRepository repo;
  late MockOutboxService outbox;
  late MockVectorClockService vcService;
  late MockSyncSequenceLogService sequenceLog;
  late ConsumptionSyncService service;

  const stamped = VectorClock({'host-a': 5});

  setUpAll(() {
    registerFallbackValue(fallbackSyncMessage);
    registerFallbackValue(const VectorClock({'fallback': 0}));
    registerFallbackValue(SyncSequencePayloadType.consumptionEvent);
  });

  setUp(() {
    db = ConsumptionDatabase(inMemoryDatabase: true);
    repo = ConsumptionRepository(db);
    outbox = MockOutboxService();
    vcService = MockVectorClockService();
    sequenceLog = MockSyncSequenceLogService();
    service = ConsumptionSyncService(
      repository: repo,
      outboxService: outbox,
      vectorClockService: vcService,
      sequenceLogService: sequenceLog,
    );

    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    when(
      () => vcService.getNextVectorClock(previous: any(named: 'previous')),
    ).thenAnswer((_) async => stamped);
    when(
      () => sequenceLog.recordSentEntry(
        entryId: any(named: 'entryId'),
        vectorClock: any(named: 'vectorClock'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'recordEvent stamps the VC, persists, and enqueues one message',
    () async {
      await service.recordEvent(makeConsumptionEvent(id: 'e1'));

      // Persisted with the stamped clock.
      final stored = await repo.getEvent('e1');
      expect(stored, isNotNull);
      expect(stored!.vectorClock, stamped);

      // Enqueued exactly one consumptionEvent carrying the stamped event.
      final captured = verify(
        () => outbox.enqueueMessage(captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      final message = captured.single as SyncMessage;
      expect(message, isA<SyncConsumptionEvent>());
      final typed = message as SyncConsumptionEvent;
      expect(typed.event.id, 'e1');
      expect(typed.event.vectorClock, stamped);
      expect(typed.status, SyncEntryStatus.update);

      // Recorded in the sequence log for gap detection/backfill.
      verify(
        () => sequenceLog.recordSentEntry(
          entryId: 'e1',
          vectorClock: stamped,
          payloadType: SyncSequencePayloadType.consumptionEvent,
        ),
      ).called(1);
    },
  );

  test('fromSync writes the repository directly without enqueuing', () async {
    await service.recordEvent(
      makeConsumptionEvent(
        id: 'e2',
        vectorClock: const VectorClock({'host-b': 3}),
      ),
      fromSync: true,
    );

    final stored = await repo.getEvent('e2');
    expect(stored!.vectorClock, const VectorClock({'host-b': 3}));
    verifyNever(() => outbox.enqueueMessage(any()));
    verifyNever(
      () => vcService.getNextVectorClock(previous: any(named: 'previous')),
    );
  });

  group('getIt fallbacks and post-write failure logging', () {
    /// Service with no injected sequence log — exercises the getIt fallback.
    ConsumptionSyncService serviceWithoutSequenceLog() =>
        ConsumptionSyncService(
          repository: repo,
          outboxService: outbox,
          vectorClockService: vcService,
        );

    test('repository getter exposes the wrapped repository', () {
      expect(service.repository, same(repo));
    });

    test(
      'falls back to the getIt sequence log when none is injected',
      () async {
        getIt.registerSingleton<SyncSequenceLogService>(sequenceLog);
        addTearDown(() => getIt.unregister<SyncSequenceLogService>());

        await serviceWithoutSequenceLog().recordEvent(
          makeConsumptionEvent(id: 'e-getit'),
        );

        verify(
          () => sequenceLog.recordSentEntry(
            entryId: 'e-getit',
            vectorClock: stamped,
            payloadType: SyncSequencePayloadType.consumptionEvent,
          ),
        ).called(1);
      },
    );

    test(
      'skips the sequence log when neither injected nor registered — the '
      'write and enqueue still land',
      () async {
        await serviceWithoutSequenceLog().recordEvent(
          makeConsumptionEvent(id: 'e-nolog'),
        );

        expect((await repo.getEvent('e-nolog'))!.vectorClock, stamped);
        verify(() => outbox.enqueueMessage(any())).called(1);
        verifyNever(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        );
      },
    );

    test(
      'a sequence-log failure is logged and swallowed — the stamped write '
      'commits and the message is still enqueued',
      () async {
        final logger = MockDomainLogger();
        getIt.registerSingleton<DomainLogger>(logger);
        addTearDown(() => getIt.unregister<DomainLogger>());
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(Exception('sequence log down'));

        await service.recordEvent(makeConsumptionEvent(id: 'e-seqfail'));

        expect((await repo.getEvent('e-seqfail'))!.vectorClock, stamped);
        verify(() => outbox.enqueueMessage(any())).called(1);
        verify(
          () => logger.error(
            LogDomain.sync,
            any<Object>(),
            message: any(named: 'message'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'consumptionSync.record',
          ),
        ).called(1);
      },
    );

    test(
      'an outbox-enqueue failure is logged and swallowed — the stamped '
      'write stays committed',
      () async {
        final logger = MockDomainLogger();
        getIt.registerSingleton<DomainLogger>(logger);
        addTearDown(() => getIt.unregister<DomainLogger>());
        when(
          () => outbox.enqueueMessage(any()),
        ).thenThrow(Exception('outbox down'));

        await service.recordEvent(makeConsumptionEvent(id: 'e-outfail'));

        expect((await repo.getEvent('e-outfail'))!.vectorClock, stamped);
        verify(
          () => logger.error(
            LogDomain.sync,
            any<Object>(),
            message: any(named: 'message'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'consumptionSync.enqueue',
          ),
        ).called(1);
      },
    );
  });
}
