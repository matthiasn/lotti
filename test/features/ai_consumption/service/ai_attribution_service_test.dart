import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
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
}
