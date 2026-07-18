import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/transcript_attribution_coordinator.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late ConsumptionDatabase database;
  late ConsumptionRepository repository;
  late MockConsumptionSyncService syncService;
  late MockAiAttributionIdentityResolver identityResolver;
  late TranscriptAttributionCoordinator coordinator;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    database = ConsumptionDatabase(inMemoryDatabase: true);
    repository = ConsumptionRepository(database);
    syncService = MockConsumptionSyncService();
    identityResolver = MockAiAttributionIdentityResolver();
    coordinator = TranscriptAttributionCoordinator(
      AiAttributionService(repository, syncService),
      identityResolver,
    );
    when(
      () => identityResolver.humanInitiator(),
    ).thenAnswer((_) async => makeAiActor());
    when(
      () => identityResolver.executor(),
    ).thenAnswer((_) async => makeAiExecutor());
    when(() => syncService.recordEventForPublication(any())).thenAnswer((
      invocation,
    ) async {
      final event = invocation.positionalArguments.single as AiConsumptionEvent;
      await repository.upsertEvent(event);
      return ConsumptionPublicationResult(event: event, published: true);
    });
  });

  tearDown(() => database.close());

  test(
    'publishes reference-only evidence before transcript persistence',
    () async {
      const transcript = 'Sensitive spoken content';
      final prepared = await coordinator.prepare(
        audioEntryId: 'audio-1',
        transcript: transcript,
        providerName: 'Mistral',
        modelId: 'voxtral',
        providerType: InferenceProviderType.mistral,
        interactionKind: AiInteractionKind.realtimeTranscription,
        privacyClassification: AiPrivacyClassification.private,
        taskId: 'task-1',
        categoryId: 'category-1',
      );

      final interaction = (await repository.interactionsForAttribution(
        prepared.envelope.attribution.id,
      )).single;
      expect(interaction.payload?.response, isEmpty);
      expect(interaction.payload?.responseDigest, isNot(contains(transcript)));
      expect(interaction.cost?.source, AiCostSource.unknown);
      expect(
        interaction.payload?.privacyClassification,
        AiPrivacyClassification.private,
      );
      expect(
        prepared.envelope.attribution.privacyClassification,
        AiPrivacyClassification.private,
      );
      expect(
        prepared.envelope.attribution.primaryOutput?.subId,
        prepared.transcriptId,
      );
      expect(
        await repository.getPendingAttribution(
          prepared.envelope.attribution.id,
        ),
        isNotNull,
      );

      await coordinator.finalize(prepared);
      expect(
        await repository.getPendingAttribution(
          prepared.envelope.attribution.id,
        ),
        isNull,
      );
    },
  );

  test('pre-call sessions retain timing and realtime usage', () async {
    final session = await withClock(
      Clock.fixed(DateTime.utc(2026, 3, 15, 12)),
      () => coordinator.begin(
        providerName: 'Mistral',
        modelId: 'voxtral',
        providerType: InferenceProviderType.mistral,
        interactionKind: AiInteractionKind.realtimeTranscription,
        privacyClassification: AiPrivacyClassification.mixed,
      ),
    );

    final prepared = await withClock(
      Clock.fixed(DateTime.utc(2026, 3, 15, 12, 1)),
      () => coordinator.complete(
        session: session,
        audioEntryId: 'audio-usage',
        transcript: 'hello',
        usage: const {
          'input_tokens': 10,
          'output_tokens': 4,
          'total_tokens': 14,
        },
      ),
    );

    final interaction = (await repository.interactionsForAttribution(
      prepared.envelope.attribution.id,
    )).single;
    expect(interaction.createdAt, DateTime.utc(2026, 3, 15, 12));
    expect(interaction.completedAt, DateTime.utc(2026, 3, 15, 12, 1));
    expect(interaction.durationMs, 60000);
    expect(interaction.inputTokens, 10);
    expect(interaction.outputTokens, 4);
    expect(interaction.totalTokens, 14);
  });

  test('failure and cancellation terminalize without a carrier', () async {
    final cases =
        <
          ({
            AiWorkStatus workStatus,
            AiInteractionStatus interactionStatus,
            Future<void> Function(TranscriptAttributionSession) act,
          })
        >[
          (
            workStatus: AiWorkStatus.failed,
            interactionStatus: AiInteractionStatus.failed,
            act: (session) => coordinator.fail(
              session: session,
              error: StateError('provider failed'),
            ),
          ),
          (
            workStatus: AiWorkStatus.cancelled,
            interactionStatus: AiInteractionStatus.cancelled,
            act: coordinator.cancel,
          ),
        ];

    for (final testCase in cases) {
      final session = await coordinator.begin(
        providerName: 'Mistral',
        modelId: 'voxtral',
        providerType: InferenceProviderType.mistral,
        interactionKind: AiInteractionKind.realtimeTranscription,
        privacyClassification: AiPrivacyClassification.private,
      );

      await testCase.act(session);

      final attribution = await repository.getAttribution(session.pending.id);
      final interaction = (await repository.interactionsForAttribution(
        session.pending.id,
      )).single;
      expect(attribution?.status, testCase.workStatus);
      expect(interaction.interactionStatus, testCase.interactionStatus);
      expect(
        await repository.getPendingAttribution(session.pending.id),
        isNull,
      );
    }
  });
}
