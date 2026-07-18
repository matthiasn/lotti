import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart'
    hide AiInteractionCost, AiInteractionPayload;
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late ConsumptionDatabase database;
  late ConsumptionRepository repository;
  late MockConsumptionSyncService syncService;
  late AiAttributionService service;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    database = ConsumptionDatabase(inMemoryDatabase: true);
    repository = ConsumptionRepository(database);
    syncService = MockConsumptionSyncService();
    service = AiAttributionService(repository, syncService);
  });

  tearDown(() => database.close());

  test(
    'publishes evidence before producing and projecting terminal output',
    () async {
      final source = makeAiArtifact(
        type: AiArtifactType.journalEntry,
        id: 'source-1',
      );
      final context = makeAiArtifact(
        type: AiArtifactType.journalImage,
        id: 'context-1',
      );
      final pending = await withClock(
        Clock.fixed(DateTime.utc(2026, 3, 15, 12)),
        () => service.begin(
          makeAiAttributionStart(sources: [source], context: [context]),
        ),
      );

      when(() => syncService.recordEventForPublication(any())).thenAnswer((
        call,
      ) async {
        final event = call.positionalArguments.single as AiConsumptionEvent;
        await repository.upsertEvent(event);
        return ConsumptionPublicationResult(event: event, published: true);
      });

      final result = await service.recordInteraction(
        attributionId: pending.id,
        event: makeConsumptionEvent(id: 'call-1'),
      );
      expect(result.published, isTrue);
      expect(result.event.recoveryCapsule?.attributionId, pending.id);

      final output = makeAiArtifact();
      final envelope = await service.prepareCompletion(
        attributionId: pending.id,
        outputs: [output],
      );
      await service.finalize(envelope);

      final attribution = await repository.getAttribution(pending.id);
      expect(attribution?.status, AiWorkStatus.succeeded);
      expect(
        attribution?.links.map((link) => link.role),
        containsAll(<AiAttributionLinkRole>[
          AiAttributionLinkRole.output,
          AiAttributionLinkRole.source,
          AiAttributionLinkRole.context,
        ]),
      );
      expect(await repository.getPendingAttribution(pending.id), isNull);
    },
  );

  test(
    'blocks output publication when evidence enqueue did not succeed',
    () async {
      final pending = await service.begin(makeAiAttributionStart());
      when(() => syncService.recordEventForPublication(any())).thenAnswer((
        call,
      ) async {
        final event = call.positionalArguments.single as AiConsumptionEvent;
        await repository.upsertEvent(event);
        return ConsumptionPublicationResult(event: event, published: false);
      });

      await service.recordInteraction(
        attributionId: pending.id,
        event: makeConsumptionEvent(id: 'call-1'),
      );

      expect(
        () => service.prepareCompletion(
          attributionId: pending.id,
          outputs: [makeAiArtifact()],
        ),
        throwsA(isA<AiAttributionPublicationException>()),
      );
      expect(
        (await repository.getPendingAttribution(pending.id))?.phase,
        AiAttributionPendingPhase.evidenceDurable,
      );
    },
  );

  test('stable ids and publication exceptions remain diagnosable', () {
    expect(agentWakeAttributionId('wake-1'), agentWakeAttributionId('wake-1'));
    expect(
      agentWakeAttributionId('wake-1'),
      isNot(agentWakeAttributionId('wake-2')),
    );
    expect(kAiAttributionDigestAlgorithm, 'sha256-v1');
    expect(kAiAttributionInlineEvidenceMaxBytes, 64 * 1024);
    expect(
      const AiAttributionPublicationException('failed').toString(),
      'AiAttributionPublicationException: failed',
    );
  });

  test('begin is idempotent for an explicit attribution id', () async {
    final command = AiAttributionStart(
      workType: AiWorkType.imageGeneration,
      initiator: makeAiActor(),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
      executor: makeAiExecutor(),
      privacyClassification: AiPrivacyClassification.private,
      attributionId: 'stable-attribution',
    );

    final first = await service.begin(command);
    final second = await service.begin(command);

    expect(second, first);
    expect(await repository.pendingAttributions(), [first]);
  });

  test(
    'retryPublication validates ownership and preserves failed retry',
    () async {
      final pending = await service.begin(
        AiAttributionStart(
          workType: AiWorkType.textGeneration,
          initiator: makeAiActor(),
          trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
          executor: makeAiExecutor(),
          privacyClassification: AiPrivacyClassification.standard,
          attributionId: 'retry-attribution',
        ),
      );

      await expectLater(
        service.retryPublication(
          attributionId: pending.id,
          interactionId: 'missing',
        ),
        throwsA(isA<AiAttributionPublicationException>()),
      );

      final wrongOwner = makeConsumptionEvent(
        id: 'wrong-owner',
      ).copyWith(attributionId: 'different');
      await repository.upsertEvent(wrongOwner);
      await expectLater(
        service.retryPublication(
          attributionId: pending.id,
          interactionId: wrongOwner.id,
        ),
        throwsA(isA<AiAttributionPublicationException>()),
      );

      final event = makeConsumptionEvent(
        id: 'retry-event',
      ).copyWith(attributionId: pending.id);
      await repository.upsertEvent(event);
      when(
        () => syncService.retryEventPublication(event),
      ).thenAnswer((_) async => false);

      expect(
        await service.retryPublication(
          attributionId: pending.id,
          interactionId: event.id,
        ),
        pending,
      );
    },
  );

  test(
    'recoverStale retries evidence and terminalizes interrupted work',
    () async {
      final now = DateTime.utc(2026, 3, 15, 12);
      AiAttributionPendingSession pending({
        required String id,
        required AiAttributionPendingPhase phase,
        List<String> interactionIds = const [],
        DateTime? updatedAt,
      }) => AiAttributionPendingSession(
        id: id,
        attributionId: id,
        workType: AiWorkType.codingPrompt,
        initiator: makeAiActor(),
        trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
        executor: makeAiExecutor(),
        privacyClassification: AiPrivacyClassification.standard,
        phase: phase,
        startedAt: now.subtract(const Duration(hours: 2)),
        lastUpdatedAt: updatedAt ?? now.subtract(const Duration(hours: 2)),
        intendedOutputs: [makeAiArtifact(id: '$id-output')],
        interactionIds: interactionIds,
      );

      final durable = pending(
        id: 'durable',
        phase: AiAttributionPendingPhase.evidenceDurable,
        interactionIds: const ['durable-event'],
      );
      final interrupted = pending(
        id: 'interrupted',
        phase: AiAttributionPendingPhase.prepared,
      );
      final fresh = pending(
        id: 'fresh',
        phase: AiAttributionPendingPhase.prepared,
        updatedAt: now,
      );
      await repository.upsertPendingAttribution(durable);
      await repository.upsertPendingAttribution(interrupted);
      await repository.upsertPendingAttribution(fresh);
      final event = makeConsumptionEvent(
        id: 'durable-event',
      ).copyWith(attributionId: durable.id);
      await repository.upsertEvent(event);
      when(
        () => syncService.retryEventPublication(event),
      ).thenAnswer((_) async => true);

      final recovered = await withClock(
        Clock.fixed(now),
        () => service.recoverStale(threshold: const Duration(hours: 1)),
      );

      expect(recovered.map((item) => item.id).toSet(), {
        'durable',
        'interrupted',
      });
      expect(
        recovered.singleWhere((item) => item.id == 'durable').status,
        AiWorkStatus.partial,
      );
      expect(
        recovered.singleWhere((item) => item.id == 'durable').errorCode,
        'output_missing',
      );
      expect(
        recovered.singleWhere((item) => item.id == 'interrupted').status,
        AiWorkStatus.abandoned,
      );
      expect(
        recovered.singleWhere((item) => item.id == 'interrupted').errorCode,
        'execution_interrupted',
      );
      expect(await repository.getPendingAttribution('fresh'), fresh);
    },
  );

  test('recoverStale keeps durable work when retry still fails', () async {
    final now = DateTime.utc(2026, 3, 15, 12);
    final pending = AiAttributionPendingSession(
      id: 'retry-later',
      attributionId: 'retry-later',
      workType: AiWorkType.codingPrompt,
      initiator: makeAiActor(),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
      executor: makeAiExecutor(),
      privacyClassification: AiPrivacyClassification.standard,
      phase: AiAttributionPendingPhase.evidenceDurable,
      startedAt: now.subtract(const Duration(hours: 2)),
      lastUpdatedAt: now.subtract(const Duration(hours: 2)),
      intendedOutputs: const [],
      interactionIds: const ['retry-later-event'],
    );
    final event = makeConsumptionEvent(
      id: 'retry-later-event',
    ).copyWith(attributionId: pending.id);
    await repository.upsertPendingAttribution(pending);
    await repository.upsertEvent(event);
    when(
      () => syncService.retryEventPublication(event),
    ).thenAnswer((_) async => false);

    final recovered = await withClock(
      Clock.fixed(now),
      () => service.recoverStale(threshold: const Duration(hours: 1)),
    );

    expect(recovered, isEmpty);
    expect(await repository.getPendingAttribution(pending.id), pending);
  });

  test('recoverStale continues after one pending session fails', () async {
    final now = DateTime.utc(2026, 3, 15, 12);
    AiAttributionPendingSession pending({
      required String id,
      required DateTime startedAt,
      required AiAttributionPendingPhase phase,
      List<String> interactionIds = const [],
    }) => AiAttributionPendingSession(
      id: id,
      attributionId: id,
      workType: AiWorkType.codingPrompt,
      initiator: makeAiActor(),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
      executor: makeAiExecutor(),
      privacyClassification: AiPrivacyClassification.standard,
      phase: phase,
      startedAt: startedAt,
      lastUpdatedAt: startedAt,
      intendedOutputs: [makeAiArtifact(id: '$id-output')],
      interactionIds: interactionIds,
    );
    final broken = pending(
      id: 'broken',
      startedAt: now.subtract(const Duration(hours: 3)),
      phase: AiAttributionPendingPhase.evidenceDurable,
      interactionIds: const ['missing-event'],
    );
    final recoverable = pending(
      id: 'recoverable',
      startedAt: now.subtract(const Duration(hours: 2)),
      phase: AiAttributionPendingPhase.prepared,
    );
    await repository.upsertPendingAttribution(broken);
    await repository.upsertPendingAttribution(recoverable);

    final recovered = await withClock(
      Clock.fixed(now),
      () => service.recoverStale(threshold: const Duration(hours: 1)),
    );

    expect(recovered.map((item) => item.id), ['recoverable']);
    expect(await repository.getPendingAttribution('broken'), broken);
    expect(await repository.getPendingAttribution('recoverable'), isNull);
  });

  test('missing pending sessions fail every operation explicitly', () async {
    await expectLater(
      service.recordInteraction(
        attributionId: 'missing',
        event: makeConsumptionEvent(),
      ),
      throwsA(isA<AiAttributionPublicationException>()),
    );
    await expectLater(
      service.prepareCompletion(attributionId: 'missing', outputs: const []),
      throwsA(isA<AiAttributionPublicationException>()),
    );
  });

  test(
    'interaction evidence rejects mismatched and full-text payloads',
    () async {
      AiInteractionPayload payload({
        required String interactionId,
        required AiPayloadCapturePolicy policy,
      }) => AiInteractionPayload(
        id: 'payload-$interactionId-${policy.name}',
        interactionId: interactionId,
        request: const [],
        response: const [],
        parameters: const {},
        requestDigest: 'request',
        responseDigest: 'response',
        capturePolicy: policy,
        privacyClassification: AiPrivacyClassification.standard,
        createdAt: DateTime(2026, 3, 15),
      );
      final events = [
        makeConsumptionEvent(id: 'payload-mismatch').copyWith(
          payload: payload(
            interactionId: 'different',
            policy: AiPayloadCapturePolicy.metadataOnly,
          ),
        ),
        makeConsumptionEvent(id: 'cost-mismatch').copyWith(
          cost: AiInteractionCost(
            id: 'cost-1',
            interactionId: 'different',
            source: AiCostSource.unknown,
            assessedAt: DateTime(2026, 3, 15),
          ),
        ),
        makeConsumptionEvent(id: 'full-text').copyWith(
          payload: payload(
            interactionId: 'full-text',
            policy: AiPayloadCapturePolicy.fullText,
          ),
        ),
      ];

      for (final event in events) {
        final pending = await service.begin(
          AiAttributionStart(
            workType: AiWorkType.textGeneration,
            initiator: makeAiActor(),
            trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
            executor: makeAiExecutor(),
            privacyClassification: AiPrivacyClassification.standard,
            attributionId: 'attribution-${event.id}',
          ),
        );

        await expectLater(
          service.recordInteraction(attributionId: pending.id, event: event),
          throwsA(
            anyOf(
              isA<ArgumentError>(),
              isA<AiAttributionPublicationException>(),
            ),
          ),
        );
      }
      verifyNever(() => syncService.recordEventForPublication(any()));
    },
  );
}
