import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/consumption/ai_consumption_recorder.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockConsumptionSyncService syncService;
  late MockDomainLogger logger;
  late AiConsumptionRecorder recorder;

  setUpAll(() {
    registerFallbackValue(fallbackAiConsumptionEvent);
  });

  setUp(() {
    syncService = MockConsumptionSyncService();
    logger = MockDomainLogger();
    recorder = AiConsumptionRecorder(syncService: syncService, logger: logger);
  });

  test('record delegates the exact event to the sync service', () async {
    final event = makeConsumptionEvent(id: 'evt-record-1');
    when(() => syncService.recordEvent(any())).thenAnswer((_) async {});

    await recorder.record(event);

    // The very same event instance is forwarded, unmodified.
    verify(() => syncService.recordEvent(event)).called(1);
    verifyNever(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    );
  });

  test('record never throws when the sync service fails — it logs', () async {
    final event = makeConsumptionEvent(id: 'evt-record-2');
    final failure = Exception('sync write exploded');
    when(() => syncService.recordEvent(any())).thenThrow(failure);

    // Recording is a diagnostics side-effect: the caller must never see the
    // failure.
    await expectLater(recorder.record(event), completes);

    final captured = verify(
      () => logger.error(
        LogDomain.ai,
        captureAny<Object>(),
        stackTrace: captureAny(named: 'stackTrace'),
        subDomain: 'aiConsumptionRecorder.record',
      ),
    ).captured;
    expect(captured[0], failure);
    expect(captured[1], isA<StackTrace>());
  });

  test('compatibility adapter attributes every legacy response type', () async {
    final database = ConsumptionDatabase(inMemoryDatabase: true);
    addTearDown(database.close);
    final repository = ConsumptionRepository(database);
    final attributionService = AiAttributionService(repository, syncService);
    final identityResolver = MockAiAttributionIdentityResolver();
    const human = AiActorSnapshot(
      type: AiActorType.human,
      id: 'user-1',
      displayName: 'Ada',
      humanPrincipalId: 'user-1',
    );
    const executor = AiExecutorSnapshot(
      hostId: 'host-1',
      displayName: 'Ada’s Mac',
    );
    when(identityResolver.humanInitiator).thenAnswer((_) async => human);
    when(identityResolver.executor).thenAnswer((_) async => executor);
    when(() => syncService.recordEventForPublication(any())).thenAnswer((
      invocation,
    ) async {
      final event = invocation.positionalArguments.single as AiConsumptionEvent;
      await repository.upsertEvent(event);
      return ConsumptionPublicationResult(event: event, published: true);
    });
    final attributedRecorder = AiConsumptionRecorder(
      syncService: syncService,
      logger: logger,
      attributionService: attributionService,
      identityResolver: identityResolver,
    );
    final cases =
        <
          (
            AiConsumptionResponseType,
            AiWorkType,
            AiInteractionKind,
          )
        >[
          (
            AiConsumptionResponseType.agentTurn,
            AiWorkType.agentReport,
            AiInteractionKind.chatCompletion,
          ),
          (
            AiConsumptionResponseType.textGeneration,
            AiWorkType.textGeneration,
            AiInteractionKind.textGeneration,
          ),
          (
            AiConsumptionResponseType.audioTranscription,
            AiWorkType.audioTranscription,
            AiInteractionKind.audioTranscription,
          ),
          (
            AiConsumptionResponseType.imageAnalysis,
            AiWorkType.imageAnalysis,
            AiInteractionKind.imageAnalysis,
          ),
          (
            AiConsumptionResponseType.imageGeneration,
            AiWorkType.imageGeneration,
            AiInteractionKind.imageGeneration,
          ),
          (
            AiConsumptionResponseType.promptGeneration,
            AiWorkType.codingPrompt,
            AiInteractionKind.textGeneration,
          ),
          (
            AiConsumptionResponseType.embeddingIndexing,
            AiWorkType.embeddingIndexing,
            AiInteractionKind.embedding,
          ),
        ];

    for (final (responseType, workType, interactionKind) in cases) {
      final id = 'legacy-${responseType.name}';
      final isAgent = responseType == AiConsumptionResponseType.agentTurn;
      final event = makeConsumptionEvent(
        id: id,
        responseType: responseType,
        agentId: isAgent ? 'agent-1' : null,
        wakeRunKey: isAgent ? 'wake-1' : null,
      );

      await attributedRecorder.record(event);

      final stored = await repository.getEvent(id);
      expect(stored?.interactionKind, interactionKind);
      expect(stored?.completedAt, isNotNull);
      final pending = await repository.getPendingAttribution(
        stored!.attributionId!,
      );
      final terminal = await repository.getAttribution(stored.attributionId!);
      if (isAgent) {
        expect(pending?.workType, workType);
        expect(terminal, isNull);
      } else {
        expect(pending, isNull);
        expect(terminal?.workType, workType);
        expect(terminal?.status, AiWorkStatus.partial);
        expect(terminal?.errorCode, 'legacy_output_carrier_unavailable');
      }
      if (responseType == AiConsumptionResponseType.embeddingIndexing) {
        expect(terminal?.initiator.type, AiActorType.system);
      }
    }
  });

  test('compatibility adapter leaves durable evidence pending', () async {
    final database = ConsumptionDatabase(inMemoryDatabase: true);
    addTearDown(database.close);
    final repository = ConsumptionRepository(database);
    final attributionService = AiAttributionService(repository, syncService);
    final identityResolver = MockAiAttributionIdentityResolver();
    when(identityResolver.humanInitiator).thenAnswer(
      (_) async => makeAiActor(),
    );
    when(identityResolver.executor).thenAnswer(
      (_) async => makeAiExecutor(),
    );
    when(() => syncService.recordEventForPublication(any())).thenAnswer((
      invocation,
    ) async {
      final event = invocation.positionalArguments.single as AiConsumptionEvent;
      await repository.upsertEvent(event);
      return ConsumptionPublicationResult(event: event, published: false);
    });
    final attributedRecorder = AiConsumptionRecorder(
      syncService: syncService,
      logger: logger,
      attributionService: attributionService,
      identityResolver: identityResolver,
    );

    await attributedRecorder.record(
      makeConsumptionEvent(
        id: 'durable-only',
        responseType: AiConsumptionResponseType.imageAnalysis,
      ),
    );

    final stored = await repository.getEvent('durable-only');
    expect(
      (await repository.getPendingAttribution(stored!.attributionId!))?.phase,
      AiAttributionPendingPhase.evidenceDurable,
    );
    expect(await repository.getAttribution(stored.attributionId!), isNull);
  });
}
