import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../agents/test_data/entity_factories.dart';

const _agentId = 'day-agent-001';
const _dayId = 'dayplan-2026-05-25';
const _planEntityId = 'day_agent_plan:$_dayId';
final _now = DateTime(2026, 5, 25, 9);

void main() {
  late MockAgentRepository agentRepository;
  late Map<String, AgentDomainEntity> entities;

  DayAgentPlanReads createReads() =>
      DayAgentPlanReads(agentRepository: agentRepository);

  setUp(() {
    agentRepository = MockAgentRepository();
    entities = <String, AgentDomainEntity>{};
    when(() => agentRepository.getEntity(any())).thenAnswer((invocation) async {
      return entities[invocation.positionalArguments.single as String];
    });
  });

  group('draftPlanForDay', () {
    test('returns the active plan owned by the agent', () async {
      entities[_planEntityId] = makeTestDayPlan(
        id: _planEntityId,
        agentId: _agentId,
      );

      final plan = await createReads().draftPlanForDay(
        agentId: _agentId,
        dayId: _dayId,
      );

      expect(plan, isNotNull);
      expect(plan!.id, _planEntityId);
    });

    test('returns null when the plan is owned by a different agent', () async {
      entities[_planEntityId] = makeTestDayPlan(
        id: _planEntityId,
        agentId: 'other-agent',
      );

      final plan = await createReads().draftPlanForDay(
        agentId: _agentId,
        dayId: _dayId,
      );

      expect(plan, isNull);
    });

    test('returns null when the plan is soft-deleted', () async {
      entities[_planEntityId] = makeTestDayPlan(
        id: _planEntityId,
        agentId: _agentId,
      ).copyWith(deletedAt: _now);

      final plan = await createReads().draftPlanForDay(
        agentId: _agentId,
        dayId: _dayId,
      );

      expect(plan, isNull);
    });

    test('returns null when no entity exists for the day', () async {
      final plan = await createReads().draftPlanForDay(
        agentId: _agentId,
        dayId: _dayId,
      );

      expect(plan, isNull);
    });
  });

  group('requireIdentity', () {
    test('returns the live identity entity', () async {
      entities[_agentId] = makeTestIdentity(id: _agentId, agentId: _agentId);

      final identity = await createReads().requireIdentity(_agentId);

      expect(identity.id, _agentId);
    });

    test('throws when the identity is missing', () async {
      expect(
        () => createReads().requireIdentity(_agentId),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('throws when the identity is soft-deleted', () async {
      entities[_agentId] = makeTestIdentity(
        id: _agentId,
        agentId: _agentId,
      ).copyWith(deletedAt: _now);

      expect(
        () => createReads().requireIdentity(_agentId),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
  });

  group('captureOrNull', () {
    test('returns the capture entity when present', () async {
      entities['capture-001'] = makeTestCapture(
        agentId: _agentId,
        capturedAt: _now,
        createdAt: _now,
      );

      final capture = await createReads().captureOrNull('capture-001');

      expect(capture, isNotNull);
      expect(capture!.id, 'capture-001');
    });

    test('returns null when the entity is not a capture', () async {
      entities[_agentId] = makeTestIdentity(id: _agentId, agentId: _agentId);

      final capture = await createReads().captureOrNull(_agentId);

      expect(capture, isNull);
    });

    test('returns null when the entity is missing', () async {
      final capture = await createReads().captureOrNull('missing');

      expect(capture, isNull);
    });
  });
}
