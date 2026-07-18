import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
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
    expect(attribution?.workType, AiWorkType.audioTranscription);
    expect(attribution?.primaryOutput?.id, 'audio-1');
  });
}
