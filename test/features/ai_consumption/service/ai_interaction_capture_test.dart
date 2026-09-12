import 'dart:async';

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
  late MockAiAttributionService service;
  late MockAiAttributionIdentityResolver identity;
  late AiInteractionCapture capture;
  late AiAttributionSession session;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    service = MockAiAttributionService();
    identity = MockAiAttributionIdentityResolver();
    capture = AiInteractionCapture(service, identity);
    session = AiAttributionSession(
      id: 'attribution-1',
      workType: AiWorkType.textGeneration,
      initiator: makeAiActor(),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
      startedAt: DateTime.utc(2026, 7, 19, 10),
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
        status: any(named: 'status'),
        errorCode: any(named: 'errorCode'),
      ),
    ).thenAnswer((_) async => makeAiWorkAttribution());
    when(() => service.finalize(any())).thenAnswer((_) async {});
  });

  group('stream lifecycle', () {
    late AiInteractionCaptureTestBench bench;
    setUp(() => bench = AiInteractionCaptureTestBench.create());

    Stream<String> captureSource(Stream<String> Function() invoke) =>
        bench.capture.captureStream(
          workType: AiWorkType.textGeneration,
          interactionKind: AiInteractionKind.chatCompletion,
          responseType: AiConsumptionResponseType.textGeneration,
          providerType: InferenceProviderType.melious,
          modelId: 'synthetic-model',
          requestText: 'synthetic request',
          invoke: invoke,
          responseText: (chunk) => chunk,
          usageForChunk: (chunk) => chunk == 'two'
              ? const AiCapturedUsage(inputTokens: 12, outputTokens: 2)
              : null,
        );

    test('cancellation reaches a provider that has not emitted', () async {
      final listening = Completer<void>();
      var providerCancelled = false;
      final source = StreamController<String>(
        onListen: listening.complete,
        onCancel: () => providerCancelled = true,
      );
      final received = <String>[];
      final subscription = captureSource(
        () => source.stream,
      ).listen(received.add);
      await listening.future;
      final stopped = subscription.cancel();
      try {
        await Future<void>.value();
        expect(providerCancelled, isTrue);
      } finally {
        await source.close();
        await stopped;
      }
      expect(received, isEmpty);
      final event = bench.recordedInteractions.single;
      expect(event.interactionStatus, AiInteractionStatus.cancelled);
      expect(event.errorCode, 'cancelled');
      expect(event.inputTokens, isNull);
    });

    test('cancelling during attribution prevents the provider call', () async {
      final identityPending = Completer<AiActorSnapshot>();
      final resolving = Completer<void>();
      when(bench.identity.humanInitiator).thenAnswer((_) {
        resolving.complete();
        return identityPending.future;
      });
      var invoked = false;
      final subscription = captureSource(() {
        invoked = true;
        return Stream.value('unexpected');
      }).listen((_) => fail('Cancelled capture must not emit'));
      await resolving.future;
      final stopped = subscription.cancel();
      identityPending.complete(makeAiActor());
      await stopped;
      expect(invoked, isFalse);
      expect(
        bench.recordedInteractions.single.interactionStatus,
        AiInteractionStatus.cancelled,
      );
    });

    test(
      'normal completion retains streamed content and provider usage',
      () async {
        expect(
          await captureSource(() => Stream.fromIterable(['one', 'two'])).join(),
          'onetwo',
        );
        final event = bench.recordedInteractions.single;
        expect(event.interactionStatus, AiInteractionStatus.succeeded);
        expect(event.inputTokens, 12);
        expect(event.outputTokens, 2);
        expect(event.responseDigest, isNot('onetwo'));
      },
    );

    test('provider failure is recorded once and reaches the caller', () async {
      await expectLater(
        captureSource(() => Stream.error(StateError('synthetic'))).toList(),
        throwsStateError,
      );
      final event = bench.recordedInteractions.single;
      expect(event.interactionStatus, AiInteractionStatus.failed);
      expect(event.errorCode, 'StateError');
      expect(event.errorSummary, isNull);
    });

    test(
      'provider subscription failure is recorded and reaches the caller',
      () async {
        final source = StreamController<String>();
        final existingListener = source.stream.listen((_) {});
        try {
          // Reusing a single-subscription stream throws from listen itself,
          // rather than delivering an error event after subscription succeeds.
          await expectLater(
            captureSource(() => source.stream).toList(),
            throwsStateError,
          );
          final event = bench.recordedInteractions.single;
          expect(event.interactionStatus, AiInteractionStatus.failed);
          expect(event.errorCode, 'StateError');
          expect(event.errorSummary, isNull);
        } finally {
          await existingListener.cancel();
          await source.close();
        }
      },
    );
  });

  test('starts attribution before invoking the provider', () async {
    var began = false;
    when(() => service.begin(any())).thenAnswer((_) async {
      began = true;
      return session;
    });

    final result = await capture.captureUnary(
      workType: AiWorkType.textGeneration,
      interactionKind: AiInteractionKind.chatCompletion,
      responseType: AiConsumptionResponseType.textGeneration,
      providerType: InferenceProviderType.openAi,
      modelId: 'gpt-5',
      requestText: 'request',
      invoke: () async {
        expect(began, isTrue);
        return 'response';
      },
      responseText: (value) => value,
    );

    expect(result, 'response');
    verify(
      () => service.recordInteraction(
        attributionId: session.id,
        event: any(named: 'event'),
      ),
    ).called(1);
  });

  test(
    'records exact Melious cost and environmental impact on the event',
    () async {
      await capture.captureUnary(
        workType: AiWorkType.imageGeneration,
        interactionKind: AiInteractionKind.imageGeneration,
        responseType: AiConsumptionResponseType.imageGeneration,
        providerType: InferenceProviderType.melious,
        modelId: 'image-model',
        requestText: 'request',
        invoke: () async => 'response',
        responseText: (value) => value,
        impact: () => const MeliousCallImpact(
          costCredits: 0.125,
          costCreditsDecimal: '0.125000000',
          energyKwh: 0.5,
          carbonGCo2: 12,
          waterLiters: 0.75,
          renewablePercent: 80,
          pue: 1.2,
          dataCenter: 'FI',
          providerId: 'upstream-1',
        ),
        existingSession: session,
        terminalizeSuccess: false,
      );

      final event =
          verify(
                () => service.recordInteraction(
                  attributionId: session.id,
                  event: captureAny(named: 'event'),
                ),
              ).captured.single
              as AiConsumptionEvent;
      expect(event.credits, 0.125);
      expect(event.costCreditsDecimal, '0.125000000');
      expect(event.energyKwh, 0.5);
      expect(event.carbonGCo2, 12);
      expect(event.waterLiters, 0.75);
      expect(event.renewablePercent, 80);
      expect(event.pue, 1.2);
      expect(event.dataCenter, 'FI');
      expect(event.upstreamProviderId, 'upstream-1');
      expect(event.requestDigest, isNot('request'));
      expect(event.responseDigest, isNot('response'));
    },
  );

  test('records failed interaction before rethrowing provider error', () async {
    await expectLater(
      capture.captureUnary<String>(
        workType: AiWorkType.textGeneration,
        interactionKind: AiInteractionKind.chatCompletion,
        responseType: AiConsumptionResponseType.textGeneration,
        providerType: InferenceProviderType.openAi,
        modelId: 'gpt-5',
        requestText: 'request',
        invoke: () => Future.error(StateError('failed')),
        responseText: (value) => value,
      ),
      throwsStateError,
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
  });

  test('automatic sessions use the default automation identity', () async {
    final automation = makeAiActor().copyWith(
      type: AiActorType.automation,
      id: 'automation:embeddingIndexing',
      displayName: 'embeddingIndexing',
    );
    when(
      () => identity.automationInitiator(
        id: 'automation:embeddingIndexing',
        displayName: 'embeddingIndexing',
      ),
    ).thenAnswer((_) async => automation);

    await capture.beginSession(
      workType: AiWorkType.embeddingIndexing,
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
    );

    final start =
        verify(() => service.begin(captureAny())).captured.single
            as AiAttributionStart;
    expect(start.initiator, automation);
    expect(start.trigger.type, AiTriggerType.automatic);
  });
}
