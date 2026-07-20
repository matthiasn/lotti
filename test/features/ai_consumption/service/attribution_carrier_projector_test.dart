import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/attribution_carrier_projector.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final createdAt = DateTime(2026, 3, 15, 12);

  Metadata metadata(String id) => Metadata(
    id: id,
    createdAt: createdAt,
    updatedAt: createdAt,
    dateFrom: createdAt,
    dateTo: createdAt,
  );

  test('extracts attribution from an AI response carrier', () {
    final attribution = makeAiWorkAttribution();
    final entity = JournalEntity.aiResponse(
      meta: metadata('output-1'),
      data: AiResponseData(
        model: 'model',
        systemMessage: 'system',
        prompt: 'prompt',
        thoughts: '',
        response: 'response',
        aiAttribution: attribution,
      ),
    );

    expect(attributionsFromJournalEntity(entity), [attribution]);
  });

  test('extracts independently attributed transcripts from audio', () {
    final first = makeAiWorkAttribution(attributionId: 'first');
    final second = makeAiWorkAttribution(attributionId: 'second');
    final entity = JournalEntity.journalAudio(
      meta: metadata('audio-1'),
      data: AudioData(
        dateFrom: createdAt,
        dateTo: createdAt,
        audioFile: 'audio.m4a',
        audioDirectory: '/audio',
        duration: const Duration(seconds: 2),
        transcripts: [
          AudioTranscript(
            created: createdAt,
            library: 'provider',
            model: 'model',
            detectedLanguage: 'en',
            transcript: 'one',
            aiAttribution: first,
          ),
          AudioTranscript(
            created: createdAt,
            library: 'provider',
            model: 'model',
            detectedLanguage: 'en',
            transcript: 'two',
            aiAttribution: second,
          ),
        ],
      ),
    );

    expect(attributionsFromJournalEntity(entity), [first, second]);
  });

  test('extracts an image carrier and ignores unrelated journal entities', () {
    final attribution = makeAiWorkAttribution(attributionId: 'image');
    final image = JournalEntity.journalImage(
      meta: metadata('image-1'),
      data: ImageData(
        imageId: 'image-1',
        imageFile: 'image.jpg',
        imageDirectory: '/images',
        capturedAt: createdAt,
        aiAttribution: attribution,
      ),
    );
    final entry = JournalEntity.journalEntry(meta: metadata('entry-1'));

    expect(attributionsFromJournalEntity(image), [attribution]);
    expect(attributionsFromJournalEntity(entry), isEmpty);
  });

  test('decodes persisted agent carriers and rejects malformed provenance', () {
    final attribution = makeAiWorkAttribution(attributionId: 'agent');
    AgentReportEntity report(Map<String, Object?> provenance) =>
        AgentReportEntity(
          id: 'report-1',
          agentId: 'agent-1',
          scope: 'current',
          createdAt: createdAt,
          vectorClock: null,
          provenance: provenance,
        );
    final normalized =
        jsonDecode(jsonEncode(attribution.toJson())) as Map<String, dynamic>;

    expect(
      attributionFromAgentEntity(
        report({aiAttributionProvenanceKey: normalized}),
      ),
      attribution,
    );
    expect(
      attributionFromAgentEntity(
        report({aiAttributionProvenanceKey: 'invalid'}),
      ),
      isNull,
    );
    expect(
      attributionFromAgentEntity(
        report({
          aiAttributionProvenanceKey: const {'bad': true},
        }),
      ),
      isNull,
    );
    expect(
      attributionFromAgentEntity(
        AgentDomainEntity.agentReportHead(
          id: 'head-1',
          agentId: 'agent-1',
          scope: 'current',
          reportId: 'report-1',
          updatedAt: createdAt,
          vectorClock: null,
        ),
      ),
      isNull,
    );
  });

  test('projector persists journal and agent attribution carriers', () async {
    final repository = MockConsumptionRepository();
    final projector = AttributionCarrierProjector(repository);
    final journalEnvelope = makeAiWorkAttribution(
      attributionId: 'journal-project',
    );
    final agentEnvelope = makeAiWorkAttribution(
      attributionId: 'agent-project',
    );
    when(
      () => repository.upsertAttribution(any()),
    ).thenAnswer((_) async {});
    final journal = JournalEntity.aiResponse(
      meta: metadata('journal-output'),
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
      id: 'agent-output',
      agentId: 'agent-1',
      scope: 'current',
      createdAt: createdAt,
      vectorClock: null,
      provenance: {
        aiAttributionProvenanceKey:
            jsonDecode(jsonEncode(agentEnvelope.toJson())) as Object,
      },
    );

    await projector.projectJournalEntity(journal);
    await projector.projectAgentEntity(agent);
    await projector.projectAgentEntity(
      AgentDomainEntity.agentReportHead(
        id: 'head-1',
        agentId: 'agent-1',
        scope: 'current',
        reportId: agent.id,
        updatedAt: createdAt,
        vectorClock: null,
      ),
    );

    verify(
      () => repository.upsertAttribution(journalEnvelope),
    ).called(1);
    verify(
      () => repository.upsertAttribution(agentEnvelope),
    ).called(1);
  });
}
