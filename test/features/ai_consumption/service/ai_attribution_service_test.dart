import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockConsumptionRepository repository;
  late MockConsumptionSyncService syncService;
  late AiAttributionService service;

  setUpAll(() {
    registerFallbackValue(makeConsumptionEvent());
    registerFallbackValue(makeAiWorkAttribution());
  });

  setUp(() {
    repository = MockConsumptionRepository();
    syncService = MockConsumptionSyncService();
    service = AiAttributionService(repository, syncService);
  });

  test('builds a compact attribution from an in-memory session', () async {
    final startedAt = DateTime.utc(2026, 7, 19, 10);
    final completedAt = DateTime.utc(2026, 7, 19, 10, 0, 2);

    final attribution = await withClock(
      Clock.fixed(startedAt),
      () async {
        final session = await service.begin(makeAiAttributionStart());
        return withClock(
          Clock.fixed(completedAt),
          () => service.prepareCompletion(
            attributionId: session.id,
            outputs: session.intendedOutputs,
          ),
        );
      },
    );

    expect(attribution.initiator.displayName, 'Ada');
    expect(attribution.startedAt, startedAt);
    expect(attribution.completedAt, completedAt);
    expect(attribution.primaryOutput, makeAiArtifact());
  });

  test(
    'uses intended outputs when completion supplies no replacement',
    () async {
      final session = await service.begin(makeAiAttributionStart());

      final attribution = await service.prepareCompletion(
        attributionId: session.id,
        outputs: const [],
      );

      expect(attribution.primaryOutput, session.intendedOutputs.first);
    },
  );

  test('records interaction independently of output persistence', () async {
    when(() => syncService.recordEvent(any())).thenAnswer((_) async {});
    final event = makeConsumptionEvent(id: 'call-1');

    await service.recordInteraction(
      attributionId: 'attribution-1',
      event: event,
    );

    final captured = verify(
      () => syncService.recordEvent(captureAny()),
    ).captured;
    expect(captured.single, isA<AiConsumptionEvent>());
    expect(
      (captured.single as AiConsumptionEvent).attributionId,
      'attribution-1',
    );
  });

  test('finalize projects attribution and releases the session', () async {
    when(() => repository.upsertAttribution(any())).thenAnswer((_) async {});
    final session = await service.begin(makeAiAttributionStart());
    final attribution = await service.prepareCompletion(
      attributionId: session.id,
      outputs: session.intendedOutputs,
    );

    await service.finalize(attribution);

    verify(() => repository.upsertAttribution(attribution)).called(1);
    await expectLater(
      service.prepareCompletion(
        attributionId: session.id,
        outputs: const <AiArtifactReference>[],
      ),
      throwsStateError,
    );
  });
}
