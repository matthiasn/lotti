import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/model/goal_measurable_record_offer.dart';
import 'package:lotti/features/goals/service/goal_measurable_capture_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService syncService;
  late MockPersistenceLogic persistenceLogic;
  late List<AgentDomainEntity> upserts;
  late List<MeasurementData> measurements;
  late GoalMeasurableCaptureService service;

  const offer = GoalMeasurableRecordOffer(
    sourceMessageId: 'source-message',
    dataTypeId: 'pages',
    measurableName: 'Pages read',
    unitName: 'pages',
    items: [],
  );

  setUp(() {
    syncService = MockAgentSyncService();
    persistenceLogic = MockPersistenceLogic();
    upserts = [];
    measurements = [];
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(
      () => persistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        private: any(named: 'private'),
        comment: any(named: 'comment'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data]! as MeasurementData;
      measurements.add(data);
      final id = 'measurement-${measurements.length}';
      return MeasurementEntry(
        meta: Metadata(
          id: id,
          createdAt: data.dateFrom,
          updatedAt: data.dateFrom,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          private: true,
        ),
        data: data,
      );
    });
    service = GoalMeasurableCaptureService(syncService, persistenceLogic);
  });

  test(
    'records accepted rows in the measurement store and durable log',
    () async {
      final now = DateTime(2026, 8, 12, 21, 30);
      final ids = await withClock(
        Clock.fixed(now),
        () => service.record(
          agentId: 'goal-1',
          agentName: 'Juno',
          offer: offer,
          items: [
            GoalMeasurableRecordItem(
              day: DateTime.utc(2026, 8, 10),
              value: 20,
              estimated: true,
            ),
            GoalMeasurableRecordItem(
              day: DateTime.utc(2026, 8, 11),
              value: 25,
              estimated: false,
            ),
          ],
          private: true,
          provenanceComment: 'Said by you; recorded by Juno.',
        ),
      );

      expect(ids, ['measurement-1', 'measurement-2']);
      expect(measurements.map((entry) => entry.value), [20, 25]);
      expect(measurements.first.dateFrom, DateTime(2026, 8, 10, 12));
      expect(measurements.last.dataTypeId, 'pages');
      final payload = upserts.first as AgentMessagePayloadEntity;
      final action = upserts.last as AgentMessageEntity;
      expect(payload.content['sourceMessageId'], 'source-message');
      expect(payload.content['agentName'], 'Juno');
      expect(payload.content['entryIds'], ids);
      expect(action.metadata.toolName, GoalMeasurableCaptureToolNames.recorded);
      expect(action.contentEntryId, payload.id);
      expect(action.createdAt, now);
    },
  );

  test('dismissal is durable without creating a measurement', () async {
    await service.dismiss(agentId: 'goal-1', offer: offer);

    verifyNever(
      () => persistenceLogic.createMeasurementEntry(
        data: any(named: 'data'),
        private: any(named: 'private'),
        comment: any(named: 'comment'),
      ),
    );
    final payload = upserts.first as AgentMessagePayloadEntity;
    final action = upserts.last as AgentMessageEntity;
    expect(payload.content['sourceMessageId'], 'source-message');
    expect(action.metadata.toolName, GoalMeasurableCaptureToolNames.dismissed);
  });
}
