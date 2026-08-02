import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/transcript_attribution_coordinator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockAiAttributionService service;
  late MockAiAttributionIdentityResolver identity;
  late TranscriptAttributionCoordinator coordinator;
  late AiAttributionSession session;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    service = MockAiAttributionService();
    identity = MockAiAttributionIdentityResolver();
    coordinator = TranscriptAttributionCoordinator(service, identity);
    session = AiAttributionSession(
      id: 'attribution-1',
      workType: AiWorkType.audioTranscription,
      initiator: makeAiActor(),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
      startedAt: DateTime.utc(2026, 7, 19, 10),
      taskId: 'task-1',
      categoryId: 'category-1',
    );
    when(identity.humanInitiator).thenAnswer((_) async => makeAiActor());
    when(() => service.begin(any())).thenAnswer((_) async => session);
    when(
      () => service.recordInteraction(
        attributionId: any(named: 'attributionId'),
        event: any(named: 'event'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
      ),
    ).thenAnswer((_) async => makeAiWorkAttribution());
    when(() => service.finalize(any())).thenAnswer((_) async {});
  });

  TranscriptAttributionSession runningSession() => TranscriptAttributionSession(
    transcriptId: 'transcript-1',
    pending: session,
    providerName: 'Mistral',
    modelId: 'voxtral',
    providerType: InferenceProviderType.mistral,
    interactionKind: AiInteractionKind.audioTranscription,
    startedAt: DateTime.utc(2026, 7, 19, 10),
  );

  test('creates a transcript session with the human creator', () async {
    final result = await coordinator.begin(
      providerName: 'Mistral',
      modelId: 'voxtral',
      providerType: InferenceProviderType.mistral,
      interactionKind: AiInteractionKind.audioTranscription,
      taskId: 'task-1',
    );

    expect(result.pending, session);
    expect(result.transcriptId, isNotEmpty);
    final command =
        verify(() => service.begin(captureAny())).captured.single
            as AiAttributionStart;
    expect(command.initiator.displayName, 'Ada');
    expect(command.workType, AiWorkType.audioTranscription);
  });

  test(
    'records transcript digests and prepares the output attribution',
    () async {
      final running = runningSession();

      await coordinator.recordInteraction(
        session: running,
        audioEntryId: 'audio-1',
        transcript: 'hello world',
        usage: const {'total_tokens': 12},
      );
      final prepared = await coordinator.prepareOutput(
        session: running,
        audioEntryId: 'audio-1',
      );

      expect(prepared.transcriptId, 'transcript-1');
      final event =
          verify(
                () => service.recordInteraction(
                  attributionId: session.id,
                  event: captureAny(named: 'event'),
                ),
              ).captured.single
              as AiConsumptionEvent;
      expect(event.totalTokens, 12);
      expect(event.requestDigest, isNotNull);
      expect(event.responseDigest, isNotNull);
      final outputs =
          verify(
                () => service.prepareCompletion(
                  attributionId: session.id,
                  outputs: captureAny(named: 'outputs'),
                ),
              ).captured.single
              as List<AiArtifactReference>;
      expect(outputs.single.id, 'audio-1');
      expect(outputs.single.subId, 'transcript-1');
    },
  );

  test('records realtime fallback interactions as partial', () async {
    await coordinator.recordInteraction(
      session: runningSession(),
      audioEntryId: 'audio-1',
      transcript: 'verified fallback',
      interactionStatus: AiInteractionStatus.partial,
      errorCode: 'realtime_completion_fallback',
    );

    final event =
        verify(
              () => service.recordInteraction(
                attributionId: session.id,
                event: captureAny(named: 'event'),
              ),
            ).captured.single
            as AiConsumptionEvent;
    expect(event.interactionStatus, AiInteractionStatus.partial);
    expect(event.errorCode, 'realtime_completion_fallback');
  });

  test('failure records and finalizes without a carrier', () async {
    when(
      () => service.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
        status: any(named: 'status'),
        errorCode: any(named: 'errorCode'),
      ),
    ).thenAnswer((_) async => makeAiWorkAttribution());

    await coordinator.fail(
      session: runningSession(),
      error: StateError('provider failed'),
    );

    final event =
        verify(
              () => service.recordInteraction(
                attributionId: session.id,
                event: captureAny(named: 'event'),
              ),
            ).captured.single
            as AiConsumptionEvent;
    expect(event.interactionStatus, AiInteractionStatus.failed);
    expect(event.errorCode, 'StateError');
    expect(event.responseDigest, isNotEmpty);
    verify(
      () => service.prepareCompletion(
        attributionId: session.id,
        outputs: const [],
        status: AiWorkStatus.failed,
        errorCode: 'StateError',
      ),
    ).called(1);
    verify(() => service.finalize(any())).called(1);
  });

  test('failOutput finalizes a failed carrier-less attribution', () async {
    when(
      () => service.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
        status: any(named: 'status'),
        errorCode: any(named: 'errorCode'),
      ),
    ).thenAnswer((_) async => makeAiWorkAttribution());

    await coordinator.failOutput(
      session: runningSession(),
      errorCode: 'transcript_persistence_failed',
    );

    verify(
      () => service.prepareCompletion(
        attributionId: session.id,
        outputs: const [],
        status: AiWorkStatus.failed,
        errorCode: 'transcript_persistence_failed',
      ),
    ).called(1);
    verify(() => service.finalize(any())).called(1);
    verifyNever(
      () => service.recordInteraction(
        attributionId: any(named: 'attributionId'),
        event: any(named: 'event'),
      ),
    );
  });

  test('finalize projects the attribution after carrier persistence', () async {
    final attribution = makeAiWorkAttribution();
    final prepared = PreparedTranscriptAttribution(
      transcriptId: 'transcript-1',
      attribution: attribution,
    );

    await coordinator.finalize(prepared);

    verify(() => service.finalize(attribution)).called(1);
  });
}
