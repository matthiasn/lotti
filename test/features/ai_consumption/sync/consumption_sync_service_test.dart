import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
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
}
