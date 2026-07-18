// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';
import 'sync_event_processor_test_helpers.dart';

/// Stubs the inbound consumption-event message on the shared [event] mock.
void _stubIncomingEvent(
  AiConsumptionEvent payload, {
  String? originatingHostId = 'remote-host',
}) {
  when(() => event.text).thenReturn(
    encodeMessage(
      SyncMessage.consumptionEvent(
        event: payload,
        status: SyncEntryStatus.update,
        originatingHostId: originatingHostId,
      ),
    ),
  );
}

AiAttributionRecoveryCapsule _capsule({
  String executorHostId = 'remote-host',
}) => AiAttributionRecoveryCapsule(
  id: 'capsule-1',
  attributionId: 'attribution-1',
  workType: AiWorkType.imageAnalysis,
  initiator: makeAiActor(),
  trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
  executor: makeAiExecutor(hostId: executorHostId),
  privacyClassification: AiPrivacyClassification.standard,
  startedAt: DateTime(2026, 3, 15, 12),
  intendedOutputs: [makeAiArtifact()],
);

void main() {
  setUpAll(registerSyncProcessorFallbacks);
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
      _stubIncomingEvent(payload);

      await processor.process(event: event, journalDb: journalDb);

      verifyNever(() => repo.upsertEvent(any()));
    });

    test('projects an authentic recovery capsule on a fresh event', () async {
      final payload =
          makeConsumptionEvent(
            id: 'evt-recovery',
            vectorClock: const VectorClock({'remote-host': 4}),
          ).copyWith(
            attributionId: 'attribution-1',
            recoveryCapsule: _capsule(),
          );
      when(
        () => repo.projectRecoveryCapsule(
          capsule: any(named: 'capsule'),
          event: any(named: 'event'),
        ),
      ).thenAnswer((_) async {});
      _stubIncomingEvent(payload);

      await processor.process(event: event, journalDb: journalDb);

      verify(() => repo.upsertEvent(payload)).called(1);
      verify(
        () => repo.projectRecoveryCapsule(
          capsule: payload.recoveryCapsule!,
          event: payload,
        ),
      ).called(1);
    });

    test('rejects a recovery capsule from a different executor host', () async {
      final payload =
          makeConsumptionEvent(
            id: 'evt-forged-recovery',
            vectorClock: const VectorClock({'remote-host': 4}),
          ).copyWith(
            attributionId: 'attribution-1',
            recoveryCapsule: _capsule(executorHostId: 'other-host'),
          );
      _stubIncomingEvent(payload);

      await processor.process(event: event, journalDb: journalDb);

      verify(
        () => repo.upsertEvent(payload.copyWith(recoveryCapsule: null)),
      ).called(1);
      verifyNever(
        () => repo.projectRecoveryCapsule(
          capsule: any(named: 'capsule'),
          event: any(named: 'event'),
        ),
      );
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(that: contains('recoveryCapsuleRejected')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
    });

    test(
      'projects recovery evidence even when the event is a replay',
      () async {
        final payload =
            makeConsumptionEvent(
              id: 'evt-recovery-replay',
              vectorClock: const VectorClock({'remote-host': 4}),
            ).copyWith(
              attributionId: 'attribution-1',
              recoveryCapsule: _capsule(),
            );
        when(
          () => repo.getVectorClock(payload.id),
        ).thenAnswer((_) async => const VectorClock({'remote-host': 5}));
        when(
          () => repo.projectRecoveryCapsule(
            capsule: any(named: 'capsule'),
            event: any(named: 'event'),
          ),
        ).thenAnswer((_) async {});
        _stubIncomingEvent(payload);

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => repo.upsertEvent(any()));
        verify(
          () => repo.projectRecoveryCapsule(
            capsule: payload.recoveryCapsule!,
            event: payload,
          ),
        ).called(1);
      },
    );

    test('applies when the local clock is concurrent with the incoming '
        'one — append-only rows must never be dropped on a tie', () async {
      final payload = makeConsumptionEvent(
        id: 'evt-conc',
        vectorClock: const VectorClock({'remote': 4}),
      );
      when(
        () => repo.getVectorClock('evt-conc'),
      ).thenAnswer((_) async => const VectorClock({'other-host': 9}));
      _stubIncomingEvent(payload);

      await processor.process(event: event, journalDb: journalDb);

      verify(() => repo.upsertEvent(payload)).called(1);
    });

    test('notifies only the global consumption key when the event has no '
        'task or category owner', () async {
      final payload = makeConsumptionEvent(
        id: 'evt-bare',
        taskId: null,
        categoryId: null,
        vectorClock: const VectorClock({'remote': 4}),
      );
      _stubIncomingEvent(payload);

      await processor.process(event: event, journalDb: journalDb);

      verify(() => repo.upsertEvent(payload)).called(1);
      verify(
        () => updateNotifications.notify(
          {'AI_CONSUMPTION_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test('ignores the event when no consumption repository is wired', () async {
      processor.consumptionRepository = null;
      _stubIncomingEvent(
        makeConsumptionEvent(vectorClock: const VectorClock({'remote': 4})),
      );

      await processor.process(event: event, journalDb: journalDb);

      verifyNever(() => repo.upsertEvent(any()));
      verifyNever(
        () => updateNotifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(that: contains('consumptionEvent.ignored no repository')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
    });

    group('sequence-log recording', () {
      late MockSyncSequenceLogService sequenceLog;

      setUp(() {
        sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async => const <({String hostId, int counter})>[]);
        // Rebuild the shared processor with the sequence log wired — the
        // helper's default construction omits it, which short-circuits the
        // recording path under test.
        processor = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: sequenceLog,
        )..consumptionRepository = repo;
      });

      test(
        'records the applied event under the consumption payload type',
        () async {
          const vc = VectorClock({'remote': 4});
          final payload = makeConsumptionEvent(id: 'evt-1', vectorClock: vc);
          _stubIncomingEvent(payload);

          await processor.process(event: event, journalDb: journalDb);

          verify(() => repo.upsertEvent(payload)).called(1);
          verify(
            () => sequenceLog.recordReceivedEntry(
              entryId: 'evt-1',
              vectorClock: vc,
              originatingHostId: 'remote-host',
              coveredVectorClocks: null,
              payloadType: SyncSequencePayloadType.consumptionEvent,
            ),
          ).called(1);
        },
      );

      test(
        'skips recording when the vector clock or origin host is missing',
        () async {
          // Two shapes hit the two guard legs: (a) no event clock,
          // (b) no originating host. Both still apply the event itself.
          final clocklessPayload = makeConsumptionEvent(id: 'evt-novc');
          _stubIncomingEvent(clocklessPayload);
          await processor.process(event: event, journalDb: journalDb);

          final hostlessPayload = makeConsumptionEvent(
            id: 'evt-nohost',
            vectorClock: const VectorClock({'remote': 4}),
          );
          _stubIncomingEvent(hostlessPayload, originatingHostId: null);
          await processor.process(event: event, journalDb: journalDb);

          verify(() => repo.upsertEvent(clocklessPayload)).called(1);
          verify(() => repo.upsertEvent(hostlessPayload)).called(1);
          verifyNever(
            () => sequenceLog.recordReceivedEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              originatingHostId: any(named: 'originatingHostId'),
              coveredVectorClocks: any(named: 'coveredVectorClocks'),
              payloadType: any(named: 'payloadType'),
            ),
          );
        },
      );

      test('records a dominated replay without re-applying it', () async {
        const vc = VectorClock({'remote': 4});
        final payload = makeConsumptionEvent(id: 'evt-replay', vectorClock: vc);
        when(
          () => repo.getVectorClock('evt-replay'),
        ).thenAnswer((_) async => const VectorClock({'remote': 5}));
        _stubIncomingEvent(payload);

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => repo.upsertEvent(any()));
        verify(
          () => sequenceLog.recordReceivedEntry(
            entryId: 'evt-replay',
            vectorClock: vc,
            originatingHostId: 'remote-host',
            coveredVectorClocks: null,
            payloadType: SyncSequencePayloadType.consumptionEvent,
          ),
        ).called(1);
      });

      test('traces detected sequence gaps', () async {
        when(
          () => sequenceLog.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer(
          (_) async => const [(hostId: 'remote', counter: 2)],
        );
        _stubIncomingEvent(
          makeConsumptionEvent(
            id: 'evt-gap',
            vectorClock: const VectorClock({'remote': 4}),
          ),
        );

        await processor.process(event: event, journalDb: journalDb);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any(
              that: contains(
                'apply.consumptionEvent.gapsDetected count=1 for '
                'event=evt-gap',
              ),
            ),
            subDomain: 'processor.gapDetection',
          ),
        ).called(1);
      });

      test('logs and swallows sequence-recording failures — the applied '
          'event must not be rolled back by bookkeeping errors', () async {
        when(
          () => sequenceLog.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(StateError('sequence log down'));
        final payload = makeConsumptionEvent(
          id: 'evt-err',
          vectorClock: const VectorClock({'remote': 4}),
        );
        _stubIncomingEvent(payload);

        await processor.process(event: event, journalDb: journalDb);

        verify(() => repo.upsertEvent(payload)).called(1);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'processor.recordReceivedConsumptionEvent',
          ),
        ).called(1);
      });
    });
  });
}
