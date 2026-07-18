import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_backfill_service.dart';

import '../test_utils.dart';

void main() {
  late ConsumptionDatabase database;
  late ConsumptionRepository repository;
  late AiAttributionBackfillService service;
  final createdAt = DateTime(2024, 3, 15, 12);

  setUp(() {
    database = ConsumptionDatabase(inMemoryDatabase: true);
    repository = ConsumptionRepository(database);
    service = AiAttributionBackfillService(repository);
  });

  tearDown(() => database.close());

  test(
    'projects a legacy AI response without inventing creator or cost',
    () async {
      final entity = JournalEntity.aiResponse(
        meta: Metadata(
          id: 'response-1',
          createdAt: createdAt,
          updatedAt: createdAt,
          dateFrom: createdAt,
          dateTo: createdAt,
        ),
        data: const AiResponseData(
          model: 'model',
          systemMessage: 'system',
          prompt: 'prompt',
          thoughts: '',
          response: 'response',
          type: AiResponseType.promptGeneration,
        ),
      );

      final first = await service.backfill(journalEntities: [entity]);
      await service.backfill(journalEntities: [entity]);

      final attribution = await repository.getAttributionForArtifact(
        const AiArtifactReference(
          type: AiArtifactType.journalAiResponse,
          id: 'response-1',
        ),
      );
      expect(first.createdLegacyAttributions, 1);
      expect(attribution?.workType, AiWorkType.codingPrompt);
      expect(attribution?.status, AiWorkStatus.partial);
      expect(attribution?.initiator.id, 'legacy:unknown');
      expect(attribution?.errorCode, 'legacy_evidence_incomplete');
    },
  );

  test('migrates legacy interaction metadata and reported credits', () async {
    final event = makeConsumptionEvent(
      id: 'legacy-event',
      responseType: AiConsumptionResponseType.audioTranscription,
      entryId: 'audio-1',
      credits: 0.25,
    );

    final result = await service.backfill(consumptionEvents: [event]);
    final migrated = await repository.getEvent(event.id);
    final attribution = await repository.getAttribution(
      migrated!.attributionId!,
    );

    expect(result.migratedConsumptionEvents, 1);
    expect(
      migrated.payload?.capturePolicy,
      AiPayloadCapturePolicy.metadataOnly,
    );
    expect(migrated.cost?.source, AiCostSource.legacyReported);
    expect(migrated.cost?.originalAmountDecimal, '0.25');
    expect(migrated.cost?.originalUnit, 'meliousCredit');
    expect(migrated.cost?.reportingAmountMicros, 250000);
    expect(migrated.cost?.reportingCurrency, 'EUR');
    expect(attribution?.workType, AiWorkType.audioTranscription);
    expect(attribution?.primaryOutput?.id, 'audio-1');
  });

  test(
    'projects terminal carriers instead of creating legacy records',
    () async {
      final journalEnvelope = makeAiTerminalEnvelope(
        attributionId: 'journal-terminal',
      );
      final agentEnvelope = makeAiTerminalEnvelope(
        attributionId: 'agent-terminal',
      );
      final journal = JournalEntity.aiResponse(
        meta: Metadata(
          id: 'journal-terminal-output',
          createdAt: createdAt,
          updatedAt: createdAt,
          dateFrom: createdAt,
          dateTo: createdAt,
        ),
        data: AiResponseData(
          model: 'model',
          systemMessage: 'system',
          prompt: 'prompt',
          thoughts: '',
          response: 'response',
          aiAttribution: journalEnvelope,
        ),
      );
      final agent = AgentReportEntity(
        id: 'agent-terminal-output',
        agentId: 'agent-1',
        scope: AgentReportScopes.current,
        createdAt: createdAt,
        vectorClock: null,
        content: 'report',
        provenance: {
          aiAttributionProvenanceKey:
              jsonDecode(jsonEncode(agentEnvelope.toJson())) as Object,
        },
      );

      final result = await service.backfill(
        journalEntities: [journal],
        agentEntities: [agent],
      );

      expect(result.projectedCarriers, 2);
      expect(result.createdLegacyAttributions, 0);
      expect(
        await repository.getAttribution(journalEnvelope.attribution.id),
        journalEnvelope.attribution,
      );
      expect(
        await repository.getAttribution(agentEnvelope.attribution.id),
        agentEnvelope.attribution,
      );
    },
  );

  test('backfills carrier-less transcripts beside terminal carriers', () async {
    final envelope = makeAiTerminalEnvelope(
      attributionId: 'terminal-transcript',
      output: const AiArtifactReference(
        type: AiArtifactType.journalAudio,
        id: 'mixed-audio',
        subId: 'new-transcript',
      ),
    );
    final audio = JournalEntity.journalAudio(
      meta: Metadata(
        id: 'mixed-audio',
        createdAt: createdAt,
        updatedAt: createdAt,
        dateFrom: createdAt,
        dateTo: createdAt,
      ),
      data: AudioData(
        dateFrom: createdAt,
        dateTo: createdAt,
        audioFile: 'audio.m4a',
        audioDirectory: '/audio',
        duration: const Duration(seconds: 5),
        transcripts: [
          AudioTranscript(
            id: 'new-transcript',
            created: createdAt,
            library: 'provider',
            model: 'model',
            detectedLanguage: 'en',
            transcript: 'new',
            aiAttribution: envelope,
          ),
          AudioTranscript(
            id: 'legacy-transcript',
            created: createdAt,
            library: 'provider',
            model: 'model',
            detectedLanguage: 'en',
            transcript: 'legacy',
          ),
        ],
      ),
    );

    final result = await service.backfill(journalEntities: [audio]);

    expect(result.projectedCarriers, 1);
    expect(result.createdLegacyAttributions, 1);
    expect(
      await repository.getAttributionForArtifact(
        const AiArtifactReference(
          type: AiArtifactType.journalAudio,
          id: 'mixed-audio',
          subId: 'legacy-transcript',
        ),
      ),
      isNotNull,
    );
  });

  test('stable transcript IDs are independent of list order', () async {
    AudioTranscript transcript(String id) => AudioTranscript(
      id: id,
      created: createdAt,
      library: 'provider',
      model: 'model',
      detectedLanguage: 'en',
      transcript: id,
    );
    JournalAudio audio(List<AudioTranscript> transcripts) =>
        JournalEntity.journalAudio(
              meta: Metadata(
                id: 'reordered-audio',
                createdAt: createdAt,
                updatedAt: createdAt,
                dateFrom: createdAt,
                dateTo: createdAt,
              ),
              data: AudioData(
                dateFrom: createdAt,
                dateTo: createdAt,
                audioFile: 'audio.m4a',
                audioDirectory: '/audio',
                duration: const Duration(seconds: 5),
                transcripts: transcripts,
              ),
            )
            as JournalAudio;
    final first = transcript('first');
    final second = transcript('second');
    await service.backfill(
      journalEntities: [
        audio([first, second]),
      ],
    );
    const artifact = AiArtifactReference(
      type: AiArtifactType.journalAudio,
      id: 'reordered-audio',
      subId: 'first',
    );
    final originalId = (await repository.getAttributionForArtifact(
      artifact,
    ))!.id;

    await service.backfill(
      journalEntities: [
        audio([second, first]),
      ],
    );

    expect(
      (await repository.getAttributionForArtifact(artifact))?.id,
      originalId,
    );
  });

  test(
    'creates conservative legacy records for transcripts and reports',
    () async {
      final audio = JournalEntity.journalAudio(
        meta: Metadata(
          id: 'audio-legacy',
          createdAt: createdAt,
          updatedAt: createdAt,
          dateFrom: createdAt,
          dateTo: createdAt,
          categoryId: 'cat-audio',
        ),
        data: AudioData(
          dateFrom: createdAt,
          dateTo: createdAt,
          audioFile: 'audio.m4a',
          audioDirectory: '/audio',
          duration: const Duration(seconds: 5),
          transcripts: [
            AudioTranscript(
              id: 'transcript-1',
              created: createdAt,
              library: 'provider',
              model: 'model',
              detectedLanguage: 'en',
              transcript: 'hello',
            ),
            AudioTranscript(
              created: createdAt.add(const Duration(seconds: 1)),
              library: 'provider',
              model: 'model',
              detectedLanguage: 'en',
              transcript: 'world',
            ),
          ],
        ),
      );
      final report = AgentReportEntity(
        id: 'legacy-report',
        agentId: 'agent-1',
        scope: AgentReportScopes.current,
        createdAt: createdAt,
        vectorClock: null,
        content: 'report',
      );

      final result = await service.backfill(
        journalEntities: [audio],
        agentEntities: [report],
      );

      expect(result.createdLegacyAttributions, 3);
      final transcript = await repository.getAttributionForArtifact(
        const AiArtifactReference(
          type: AiArtifactType.journalAudio,
          id: 'audio-legacy',
          subId: 'transcript-1',
        ),
      );
      expect(transcript?.workType, AiWorkType.audioTranscription);
      expect(transcript?.categoryId, 'cat-audio');
      final reportAttribution = await repository.getAttributionForArtifact(
        const AiArtifactReference(
          type: AiArtifactType.agentReport,
          id: 'legacy-report',
        ),
      );
      expect(reportAttribution?.workType, AiWorkType.agentReport);
    },
  );

  test('maps every legacy response type without inventing evidence', () async {
    final responseCases = <(AiResponseType?, AiWorkType)>[
      (AiResponseType.promptGeneration, AiWorkType.codingPrompt),
      (AiResponseType.imagePromptGeneration, AiWorkType.textGeneration),
      (AiResponseType.imageGeneration, AiWorkType.imageGeneration),
      (AiResponseType.imageAnalysis, AiWorkType.imageAnalysis),
      (AiResponseType.audioTranscription, AiWorkType.audioTranscription),
      // ignore: deprecated_member_use_from_same_package
      (AiResponseType.taskSummary, AiWorkType.textGeneration),
      // ignore: deprecated_member_use_from_same_package
      (AiResponseType.checklistUpdates, AiWorkType.textGeneration),
      (null, AiWorkType.textGeneration),
    ];
    final entities = <JournalEntity>[];
    for (var index = 0; index < responseCases.length; index++) {
      final (type, _) = responseCases[index];
      entities.add(
        JournalEntity.aiResponse(
          meta: Metadata(
            id: 'response-$index',
            createdAt: createdAt,
            updatedAt: createdAt,
            dateFrom: createdAt,
            dateTo: createdAt,
          ),
          data: AiResponseData(
            model: 'model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: '',
            response: 'response',
            type: type,
          ),
        ),
      );
    }

    final result = await service.backfill(journalEntities: entities);

    expect(result.createdLegacyAttributions, responseCases.length);
    for (var index = 0; index < responseCases.length; index++) {
      final attribution = await repository.getAttributionForArtifact(
        AiArtifactReference(
          type: AiArtifactType.journalAiResponse,
          id: 'response-$index',
        ),
      );
      expect(attribution?.workType, responseCases[index].$2);
    }
  });

  test(
    'maps every consumption response type and skips attributed rows',
    () async {
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
      final events = <AiConsumptionEvent>[];
      for (final (responseType, _, _) in cases) {
        events.add(
          makeConsumptionEvent(
            id: 'event-${responseType.name}',
            responseType: responseType,
            entryId: switch (responseType) {
              AiConsumptionResponseType.audioTranscription => 'audio-output',
              AiConsumptionResponseType.imageAnalysis => 'image-output',
              _ => null,
            },
            credits: responseType == AiConsumptionResponseType.agentTurn
                ? null
                : 0.1,
          ),
        );
      }
      events.add(
        makeConsumptionEvent(
          id: 'already-attributed',
        ).copyWith(attributionId: 'existing-attribution'),
      );

      final result = await service.backfill(consumptionEvents: events);

      expect(result.migratedConsumptionEvents, cases.length);
      expect(await repository.getEvent('already-attributed'), isNull);
      for (final (responseType, workType, interactionKind) in cases) {
        final migrated = await repository.getEvent(
          'event-${responseType.name}',
        );
        final attribution = await repository.getAttribution(
          migrated!.attributionId!,
        );
        expect(migrated.interactionKind, interactionKind);
        expect(attribution?.workType, workType);
      }
      final agentEvent = await repository.getEvent('event-agentTurn');
      expect(agentEvent?.cost?.source, AiCostSource.unknown);
      expect(agentEvent?.cost?.originalAmountDecimal, isNull);
    },
  );
}
