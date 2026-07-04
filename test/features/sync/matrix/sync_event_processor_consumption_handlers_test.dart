// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(() {
    registerSyncProcessorFallbacks();
    registerFallbackValue(makeConsumptionEvent());
  });
  setUp(setUpProcessorMocks);

  group('SyncEventProcessor - consumption events', () {
    late MockConsumptionRepository repo;

    setUp(() {
      repo = MockConsumptionRepository();
      when(() => repo.upsertEvent(any())).thenAnswer((_) async {});
      when(() => repo.getVectorClock(any())).thenAnswer((_) async => null);
      processor.consumptionRepository = repo;
    });

    test('applies a fresh consumption event and notifies its owners', () async {
      final payload = makeConsumptionEvent(
        id: 'evt-1',
        taskId: 'task-1',
        categoryId: 'cat-1',
        vectorClock: const VectorClock({'remote': 4}),
      );
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.consumptionEvent(
            event: payload,
            status: SyncEntryStatus.update,
            originatingHostId: 'remote-host',
          ),
        ),
      );

      await processor.process(event: event, journalDb: journalDb);

      verify(() => repo.upsertEvent(payload)).called(1);
      verify(
        () => updateNotifications.notify(
          {'task-1', 'cat-1', 'AI_CONSUMPTION_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test('skips a replay whose local clock already dominates', () async {
      final payload = makeConsumptionEvent(
        id: 'evt-dup',
        vectorClock: const VectorClock({'remote': 4}),
      );
      // Local row already carries the same clock → replay → must not re-apply.
      when(
        () => repo.getVectorClock('evt-dup'),
      ).thenAnswer((_) async => const VectorClock({'remote': 4}));
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.consumptionEvent(
            event: payload,
            status: SyncEntryStatus.update,
            originatingHostId: 'remote-host',
          ),
        ),
      );

      await processor.process(event: event, journalDb: journalDb);

      verifyNever(() => repo.upsertEvent(any()));
    });
  });
}
