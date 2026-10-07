import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(() {
    registerSyncProcessorFallbacks();
    registerFallbackValue(testLabelDefinition1);
  });
  setUp(setUpProcessorMocks);

  const incomingClock = VectorClock({'remote': 4});
  final label = testLabelDefinition1.copyWith(vectorClock: incomingClock);

  late MockSyncSequenceLogService sequenceLog;
  late MockDefinitionClockStamper stamper;

  void receive(
    EntityDefinition definition, {
    String? originatingHostId = 'remote-host',
  }) {
    when(() => event.text).thenReturn(
      encodeMessage(
        SyncMessage.entityDefinition(
          entityDefinition: definition,
          status: SyncEntryStatus.update,
          originatingHostId: originatingHostId,
        ),
      ),
    );
  }

  void journalAnswers(int linesAffected, {VectorClock? storedClock}) {
    when(
      () => journalDb.upsertEntityDefinition(any()),
    ).thenAnswer((_) async => linesAffected);
    when(() => journalDb.definitionStamp(any())).thenAnswer(
      (_) async => (updatedAt: DateTime(2024), vectorClock: storedClock),
    );
  }

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
    stamper = MockDefinitionClockStamper();
    when(
      () => stamper.stamp(any(), over: any(named: 'over')),
    ).thenAnswer((_) async => null);
    processor = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      savedTaskFiltersRepository: savedTaskFiltersRepository,
      settingsDb: settingsDb,
      journalEntityLoader: journalEntityLoader,
      sequenceLogService: sequenceLog,
    )..definitionClockStamper = stamper;
  });

  void verifyRecorded() => verify(
    () => sequenceLog.recordReceivedEntry(
      entryId: label.id,
      vectorClock: incomingClock,
      originatingHostId: 'remote-host',
      payloadType: SyncSequencePayloadType.entityDefinition,
    ),
  ).called(1);

  void verifyNothingRecorded() => verifyNever(
    () => sequenceLog.recordReceivedEntry(
      entryId: any(named: 'entryId'),
      vectorClock: any(named: 'vectorClock'),
      originatingHostId: any(named: 'originatingHostId'),
      coveredVectorClocks: any(named: 'coveredVectorClocks'),
      payloadType: any(named: 'payloadType'),
    ),
  );

  test(
    'a written definition is announced and its counters recorded',
    () async {
      journalAnswers(1);
      receive(label);

      await processor.process(event: event, journalDb: journalDb);

      verify(() => journalDb.upsertEntityDefinition(label)).called(1);
      verify(
        () => updateNotifications.notify(
          {label.id, labelsNotification},
          fromSync: true,
        ),
      ).called(1);
      verifyRecorded();
      verifyNever(() => stamper.stamp(any(), over: any(named: 'over')));
    },
  );

  // Its counters are received all the same: the kept version supersedes or
  // joins them, so they are no gap to ask for.
  test('a kept copy is not announced, but its counters are recorded', () async {
    journalAnswers(0, storedClock: const VectorClock({'remote': 5}));
    receive(label);

    await processor.process(event: event, journalDb: journalDb);

    verifyNever(
      () => updateNotifications.notify(any(), fromSync: any(named: 'fromSync')),
    );
    verify(
      () => loggingService.log(
        LogDomain.sync,
        'Kept stored definition ${label.id}',
        subDomain: 'processor.apply.entityDefinition.skipped',
      ),
    ).called(1);
    verifyRecorded();
    verifyNever(() => stamper.stamp(any(), over: any(named: 'over')));
  });

  // DefinitionClocks.tla, StampsBeaten.
  test(
    'a clockless row that kept its place against a clocked copy is stamped '
    'on top of that copy',
    () async {
      journalAnswers(0);
      receive(label);

      await processor.process(event: event, journalDb: journalDb);

      verify(() => stamper.stamp(label.id, over: incomingClock)).called(1);
      verifyRecorded();
    },
  );

  test('a clockless copy kept out of a row stamps nothing', () async {
    journalAnswers(0);
    receive(label.copyWith(vectorClock: null));

    await processor.process(event: event, journalDb: journalDb);

    verifyNever(() => stamper.stamp(any(), over: any(named: 'over')));
    verifyNothingRecorded();
  });

  test('a failed stamp is logged, and the copy still recorded', () async {
    journalAnswers(0);
    when(
      () => stamper.stamp(any(), over: any(named: 'over')),
    ).thenThrow(StateError('outbox closed'));
    receive(label);

    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace', that: isNotNull),
        subDomain: 'processor.apply.entityDefinition.stamp',
      ),
    ).called(1);
    verifyRecorded();
  });

  test(
    'without a stamper a kept clockless row waits for the migration',
    () async {
      processor.definitionClockStamper = null;
      journalAnswers(0);
      receive(label);

      await processor.process(event: event, journalDb: journalDb);

      verifyNever(() => stamper.stamp(any(), over: any(named: 'over')));
      verifyRecorded();
    },
  );

  test(
    "this device's own definition echoing back is skipped, not rewritten, "
    'announced or recorded again',
    () async {
      final vectorClockService = MockVectorClockService();
      when(vectorClockService.getHost).thenAnswer((_) async => 'host-self');
      processor = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        savedTaskFiltersRepository: savedTaskFiltersRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: sequenceLog,
        vectorClockService: vectorClockService,
      );
      journalAnswers(1);
      receive(label, originatingHostId: 'host-self');

      await processor.process(event: event, journalDb: journalDb);

      verifyNever(() => journalDb.upsertEntityDefinition(any()));
      verifyNever(
        () => updateNotifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
      verifyNothingRecorded();
    },
  );

  test('a copy that names no sending host is not recorded', () async {
    journalAnswers(1);
    receive(label, originatingHostId: null);

    await processor.process(event: event, journalDb: journalDb);

    verifyNothingRecorded();
  });

  test('a sequence-log failure is logged and fails the apply', () async {
    journalAnswers(1);
    when(
      () => sequenceLog.recordReceivedEntry(
        entryId: any(named: 'entryId'),
        vectorClock: any(named: 'vectorClock'),
        originatingHostId: any(named: 'originatingHostId'),
        coveredVectorClocks: any(named: 'coveredVectorClocks'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenThrow(StateError('sync db locked'));
    receive(label);

    await expectLater(
      processor.process(event: event, journalDb: journalDb),
      throwsStateError,
    );

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'processor.recordReceivedEntityDefinition',
      ),
    ).called(1);
  });

  test('gaps the copy reveals are recorded like any other', () async {
    journalAnswers(1);
    when(
      () => sequenceLog.recordReceivedEntry(
        entryId: any(named: 'entryId'),
        vectorClock: any(named: 'vectorClock'),
        originatingHostId: any(named: 'originatingHostId'),
        coveredVectorClocks: any(named: 'coveredVectorClocks'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenAnswer((_) async => [(hostId: 'remote', counter: 3)]);
    receive(label);

    await processor.process(event: event, journalDb: journalDb);

    verifyRecorded();
  });
}
