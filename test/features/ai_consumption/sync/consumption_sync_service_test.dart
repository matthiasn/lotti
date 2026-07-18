import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  late ConsumptionDatabase db;
  late ConsumptionRepository repo;
  late MockOutboxService outbox;
  late MockVectorClockService vcService;
  late MockSyncSequenceLogService sequenceLog;
  late MockUpdateNotifications updateNotifications;
  late ConsumptionSyncService service;

  const stamped = VectorClock({'host-a': 5});

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    // Register a mock DomainLogger so the swallowed post-write failure paths
    // can log without blowing up on an unregistered GetIt lookup (mirrors
    // agent_sync_service_test.dart).
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(MockDomainLogger());
      },
    );

    db = ConsumptionDatabase(inMemoryDatabase: true);
    repo = ConsumptionRepository(db);
    outbox = MockOutboxService();
    vcService = MockVectorClockService();
    sequenceLog = MockSyncSequenceLogService();
    updateNotifications = MockUpdateNotifications();
    service = ConsumptionSyncService(
      repository: repo,
      outboxService: outbox,
      vectorClockService: vcService,
      sequenceLogService: sequenceLog,
      updateNotifications: updateNotifications,
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
    await tearDownTestGetIt();
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
        final logger = getIt<DomainLogger>() as MockDomainLogger;
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
        final logger = getIt<DomainLogger>() as MockDomainLogger;
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

  group('UI notifications', () {
    test('local write fires notifyUiOnly with task, category, and the '
        'consumption key', () async {
      await service.recordEvent(makeConsumptionEvent(id: 'e3'));

      verify(
        () => updateNotifications.notifyUiOnly({
          'task-1',
          'cat-1',
          aiConsumptionNotification,
        }),
      ).called(1);
      // Never plain notify: a regular notification would feed back into the
      // wake orchestrator mid-wake.
      verifyNever(
        () => updateNotifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });

    test('event without task or category notifies with only the '
        'consumption key', () async {
      await service.recordEvent(
        makeConsumptionEvent(id: 'e4', taskId: null, categoryId: null),
      );

      verify(
        () => updateNotifications.notifyUiOnly({aiConsumptionNotification}),
      ).called(1);
    });

    test('fromSync write also fires the UI-only notification', () async {
      await service.recordEvent(
        makeConsumptionEvent(
          id: 'e5',
          vectorClock: const VectorClock({'host-b': 7}),
        ),
        fromSync: true,
      );

      verify(
        () => updateNotifications.notifyUiOnly({
          'task-1',
          'cat-1',
          aiConsumptionNotification,
        }),
      ).called(1);
      verifyNever(
        () => updateNotifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });
  });

  group('get_it fallbacks', () {
    test('exposes the repository and resolves sequence log + notifications '
        'from get_it when not injected', () async {
      getIt.registerSingleton<SyncSequenceLogService>(sequenceLog);
      final bare = ConsumptionSyncService(
        repository: repo,
        outboxService: outbox,
        vectorClockService: vcService,
      );
      expect(bare.repository, same(repo));

      await bare.recordEvent(makeConsumptionEvent(id: 'e6'));

      verify(
        () => sequenceLog.recordSentEntry(
          entryId: 'e6',
          vectorClock: stamped,
          payloadType: SyncSequencePayloadType.consumptionEvent,
        ),
      ).called(1);
      // The get_it-registered UpdateNotifications received the UI-only ping.
      final getItNotifications =
          getIt<UpdateNotifications>() as MockUpdateNotifications;
      verify(
        () => getItNotifications.notifyUiOnly({
          'task-1',
          'cat-1',
          aiConsumptionNotification,
        }),
      ).called(1);
    });
  });

  group('post-write failure handling', () {
    test('sequence-log failure is swallowed and logged; the message is '
        'still enqueued', () async {
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenThrow(StateError('sequence ledger boom'));

      await service.recordEvent(makeConsumptionEvent(id: 'e7'));

      // The DB write committed and the outbox enqueue still happened.
      expect(await repo.getEvent('e7'), isNotNull);
      verify(() => outbox.enqueueMessage(any())).called(1);
      final logger = getIt<DomainLogger>() as MockDomainLogger;
      verify(
        () => logger.error(
          LogDomain.sync,
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'consumptionSync.record',
        ),
      ).called(1);
    });

    test('outbox enqueue failure is swallowed and logged; the write still '
        'commits', () async {
      when(
        () => outbox.enqueueMessage(any()),
      ).thenThrow(Exception('outbox boom'));

      await service.recordEvent(makeConsumptionEvent(id: 'e8'));

      expect(await repo.getEvent('e8'), isNotNull);
      final logger = getIt<DomainLogger>() as MockDomainLogger;
      verify(
        () => logger.error(
          LogDomain.sync,
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'consumptionSync.enqueue',
        ),
      ).called(1);
    });
  });

  group('attribution publication barrier', () {
    test('returns the exact stamped event after durable enqueue', () async {
      final result = await service.recordEventForPublication(
        makeConsumptionEvent(id: 'publication-success'),
      );

      expect(result.published, isTrue);
      expect(result.event.id, 'publication-success');
      expect(result.event.vectorClock, stamped);
      expect(await repo.getEvent(result.event.id), result.event);
      verify(
        () => sequenceLog.recordSentEntry(
          entryId: result.event.id,
          vectorClock: stamped,
          payloadType: SyncSequencePayloadType.consumptionEvent,
        ),
      ).called(1);
      verify(() => outbox.enqueueMessage(any())).called(1);
    });

    test(
      'reports a failed enqueue while preserving stamped evidence',
      () async {
        when(
          () => outbox.enqueueMessage(any()),
        ).thenThrow(Exception('outbox unavailable'));

        final result = await service.recordEventForPublication(
          makeConsumptionEvent(id: 'publication-durable'),
        );

        expect(result.published, isFalse);
        expect(result.event.vectorClock, stamped);
        expect(await repo.getEvent(result.event.id), result.event);
      },
    );

    test(
      'retry enqueues an already-stamped event without another write',
      () async {
        final event = makeConsumptionEvent(
          id: 'publication-retry',
          vectorClock: stamped,
        );

        expect(await service.retryEventPublication(event), isTrue);

        final message =
            verify(
                  () => outbox.enqueueMessage(captureAny()),
                ).captured.single
                as SyncConsumptionEvent;
        expect(message.event, event);
        expect(await repo.getEvent(event.id), isNull);
        verifyNever(
          () => vcService.getNextVectorClock(previous: any(named: 'previous')),
        );
      },
    );
  });
}
