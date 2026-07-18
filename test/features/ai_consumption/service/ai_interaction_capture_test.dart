import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(AiWorkStatus.succeeded);
  });

  late MockAiAttributionService service;
  late MockAiAttributionIdentityResolver identity;
  late AiInteractionCapture capture;
  late AiAttributionPendingSession pending;
  late AiTerminalAttributionEnvelope envelope;

  setUp(() {
    service = MockAiAttributionService();
    identity = MockAiAttributionIdentityResolver();
    capture = AiInteractionCapture(service, identity);
    pending = AiAttributionPendingSession(
      id: 'attribution-1',
      attributionId: 'attribution-1',
      workType: AiWorkType.textGeneration,
      initiator: makeAiActor(),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
      executor: makeAiExecutor(),
      privacyClassification: AiPrivacyClassification.standard,
      phase: AiAttributionPendingPhase.prepared,
      startedAt: DateTime(2026, 3, 15, 12),
      lastUpdatedAt: DateTime(2026, 3, 15, 12),
      intendedOutputs: const [],
    );
    envelope = makeAiTerminalEnvelope(attributionId: pending.id);
    when(identity.humanInitiator).thenAnswer((_) async => makeAiActor());
    when(identity.executor).thenAnswer((_) async => makeAiExecutor());
    when(() => service.begin(any())).thenAnswer((_) async => pending);
    when(
      () => service.recordInteraction(
        attributionId: pending.id,
        event: any(named: 'event'),
      ),
    ).thenAnswer((invocation) async {
      final event = invocation.namedArguments[#event] as AiConsumptionEvent;
      return AiAttributedInteractionResult(
        session: pending,
        event: event,
        published: true,
      );
    });
    when(
      () => service.prepareCompletion(
        attributionId: pending.id,
        outputs: any(named: 'outputs'),
        status: any(named: 'status'),
        errorCode: any(named: 'errorCode'),
      ),
    ).thenAnswer((_) async => envelope);
    when(() => service.finalize(envelope)).thenAnswer((_) async {});
  });

  test(
    'stream capture begins before invocation and terminalizes evidence',
    () async {
      var beganBeforeInvoke = false;
      when(() => service.begin(any())).thenAnswer((_) async {
        beganBeforeInvoke = true;
        return pending;
      });

      final values = await capture
          .captureStream<int>(
            workType: AiWorkType.textGeneration,
            interactionKind: AiInteractionKind.chatCompletion,
            responseType: AiConsumptionResponseType.textGeneration,
            providerType: InferenceProviderType.openAi,
            modelId: 'gpt-5',
            requestText: 'request',
            invoke: () {
              expect(beganBeforeInvoke, isTrue);
              return Stream.fromIterable([1, 2]);
            },
            responseText: (chunk) => '$chunk',
          )
          .toList();

      expect(values, [1, 2]);
      final event =
          verify(
                () => service.recordInteraction(
                  attributionId: pending.id,
                  event: captureAny(named: 'event'),
                ),
              ).captured.single
              as AiConsumptionEvent;
      expect(event.interactionStatus, AiInteractionStatus.succeeded);
      expect(event.providerModelId, 'gpt-5');
      expect(event.payload?.requestDigest, isNot('request'));
      verify(
        () => service.prepareCompletion(
          attributionId: pending.id,
          outputs: const [],
          status: AiWorkStatus.partial,
          errorCode: 'output_carrier_unavailable',
        ),
      ).called(1);
      verify(() => service.finalize(envelope)).called(1);
    },
  );

  test('failed provider streams still publish failed evidence', () async {
    await expectLater(
      capture
          .captureStream<int>(
            workType: AiWorkType.textGeneration,
            interactionKind: AiInteractionKind.chatCompletion,
            responseType: AiConsumptionResponseType.textGeneration,
            providerType: InferenceProviderType.openAi,
            modelId: 'gpt-5',
            requestText: 'request',
            invoke: () => Stream.error(StateError('provider failed')),
            responseText: (chunk) => '$chunk',
          )
          .drain<void>(),
      throwsA(isA<StateError>()),
    );

    final event =
        verify(
              () => service.recordInteraction(
                attributionId: pending.id,
                event: captureAny(named: 'event'),
              ),
            ).captured.single
            as AiConsumptionEvent;
    expect(event.interactionStatus, AiInteractionStatus.failed);
    expect(event.errorCode, 'StateError');
    verify(
      () => service.prepareCompletion(
        attributionId: pending.id,
        outputs: const [],
        status: AiWorkStatus.failed,
        errorCode: 'StateError',
      ),
    ).called(1);
  });

  test(
    'existing sessions retain usage and exact cost without terminalizing',
    () async {
      final values = await capture
          .captureStream<int>(
            workType: AiWorkType.audioTranscription,
            interactionKind: AiInteractionKind.audioTranscription,
            responseType: AiConsumptionResponseType.audioTranscription,
            providerType: InferenceProviderType.melious,
            modelId: 'voxtral',
            requestText: 'audio digest input',
            invoke: () => Stream.fromIterable([1, 2]),
            responseText: (chunk) => '$chunk',
            usageForChunk: (chunk) => chunk == 2
                ? const AiCapturedUsage(
                    inputTokens: 10,
                    outputTokens: 4,
                    totalTokens: 14,
                  )
                : null,
            impact: () => const MeliousCallImpact(
              costCredits: 0.123456789,
              costCreditsDecimal: '0.123456789',
            ),
            existingSession: pending,
            terminalizeSuccess: false,
          )
          .toList();

      expect(values, [1, 2]);
      final event =
          verify(
                () => service.recordInteraction(
                  attributionId: pending.id,
                  event: captureAny(named: 'event'),
                ),
              ).captured.single
              as AiConsumptionEvent;
      expect(event.inputTokens, 10);
      expect(event.outputTokens, 4);
      expect(event.totalTokens, 14);
      expect(event.cost?.source, AiCostSource.providerReported);
      expect(event.cost?.originalAmountDecimal, '0.123456789');
      expect(event.cost?.reportingAmountMicros, 123457);
      verifyNever(() => service.begin(any()));
      verifyNever(
        () => service.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
        ),
      );
      verifyNever(() => service.finalize(any()));
    },
  );

  test(
    'nonfatal child-call failures stay inside the existing session',
    () async {
      await expectLater(
        capture
            .captureStream<int>(
              workType: AiWorkType.audioTranscription,
              interactionKind: AiInteractionKind.audioTranscription,
              responseType: AiConsumptionResponseType.audioTranscription,
              providerType: InferenceProviderType.mistral,
              modelId: 'verification-model',
              requestText: 'verification',
              invoke: () => Stream.error(StateError('verification failed')),
              responseText: (chunk) => '$chunk',
              existingSession: pending,
              terminalizeSuccess: false,
              terminalizeFailure: false,
            )
            .drain<void>(),
        throwsA(isA<StateError>()),
      );

      final event =
          verify(
                () => service.recordInteraction(
                  attributionId: pending.id,
                  event: captureAny(named: 'event'),
                ),
              ).captured.single
              as AiConsumptionEvent;
      expect(event.interactionStatus, AiInteractionStatus.failed);
      verifyNever(
        () => service.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
        ),
      );
    },
  );
}
