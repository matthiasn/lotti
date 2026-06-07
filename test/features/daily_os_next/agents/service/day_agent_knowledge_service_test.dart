import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_knowledge_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockDomainLogger domainLogger;
  late DayAgentKnowledgeService service;
  late List<AgentDomainEntity> upserts;
  late List<String> changed;

  const agentId = 'daily_os_planner';
  final now = DateTime(2026, 5, 25, 8);

  PlannerKnowledgeEntity knowledge({
    required String id,
    required String key,
    KnowledgeStatus status = KnowledgeStatus.confirmed,
    DateTime? updatedAt,
  }) {
    final at = updatedAt ?? now;
    return AgentDomainEntity.plannerKnowledge(
          id: id,
          agentId: agentId,
          key: key,
          hook: 'hook',
          statementText: 'statement',
          source: KnowledgeSource.userStated,
          status: status,
          createdAt: at,
          updatedAt: at,
          vectorClock: null,
        )
        as PlannerKnowledgeEntity;
  }

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    domainLogger = MockDomainLogger();
    upserts = [];
    changed = [];

    when(
      () => domainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.single as AgentDomainEntity);
    });
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.plannerKnowledge,
      ),
    ).thenAnswer((_) async => []);

    service = DayAgentKnowledgeService(
      agentRepository: repository,
      syncService: syncService,
      domainLogger: domainLogger,
      onPersistedStateChanged: changed.add,
    );
  });

  group('propose', () {
    test('a user-stated instruction is confirmed immediately', () async {
      final entry = await withClock(
        Clock.fixed(now),
        () => service.propose(
          agentId: agentId,
          key: 'deep-work',
          hook: 'no deep work before 10',
          statement: 'Never schedule deep work before 10:00.',
          source: KnowledgeSource.userStated,
        ),
      );

      expect(entry.status, KnowledgeStatus.confirmed);
      expect(entry.confirmedAt, now);
      expect(entry.supersedesId, isNull);
      expect(upserts.single, isA<PlannerKnowledgeEntity>());
      expect(changed, [agentId]);
    });

    test('an agent-inferred entry lands proposed, awaiting the gate', () async {
      final entry = await service.propose(
        agentId: agentId,
        key: 'k',
        hook: 'h',
        statement: 's',
      );
      expect(entry.status, KnowledgeStatus.proposed);
      expect(entry.confirmedAt, isNull);
    });

    test('records supersedesId when a confirmed entry exists for the key', () {
      when(
        () => repository.getEntitiesByAgentId(
          agentId,
          type: AgentEntityTypes.plannerKnowledge,
        ),
      ).thenAnswer((_) async => [knowledge(id: 'prior', key: 'deep-work')]);

      return service
          .propose(
            agentId: agentId,
            key: 'deep-work',
            hook: 'h',
            statement: 'updated',
            source: KnowledgeSource.userStated,
          )
          .then((entry) {
            expect(entry.supersedesId, 'prior');
          });
    });
  });

  group('executeTool propose_knowledge', () {
    test('requires key, hook, and statement', () async {
      final result = await service.executeTool(
        agentId: agentId,
        toolName: DayAgentToolNames.proposeKnowledge,
        args: const {'key': 'k'},
      );
      expect(result.success, isFalse);
      expect(result.output, contains('non-empty string'));
    });

    test('persists a confirmed entry for a userStated source', () async {
      final result = await service.executeTool(
        agentId: agentId,
        toolName: DayAgentToolNames.proposeKnowledge,
        args: const {
          'key': 'deep-work',
          'hook': 'no deep work before 10',
          'statement': 'Never schedule deep work before 10:00.',
          'source': 'userStated',
        },
      );
      expect(result.success, isTrue);
      final stored = upserts.single as PlannerKnowledgeEntity;
      expect(stored.status, KnowledgeStatus.confirmed);
      expect(stored.key, 'deep-work');
    });

    test('rejects an unknown tool name', () async {
      final result = await service.executeTool(
        agentId: agentId,
        toolName: 'not_a_tool',
        args: const {},
      );
      expect(result.success, isFalse);
    });
  });

  group('confirm / retract / edit', () {
    test('confirm promotes a proposed entry', () async {
      final proposed = knowledge(
        id: 'e1',
        key: 'k',
        status: KnowledgeStatus.proposed,
      );
      when(() => repository.getEntity('e1')).thenAnswer((_) async => proposed);

      final updated = await withClock(
        Clock.fixed(now),
        () => service.confirm('e1'),
      );

      expect(updated!.status, KnowledgeStatus.confirmed);
      expect(updated.confirmedAt, now);
    });

    test('retract removes an entry from the active Head set', () async {
      final confirmed = knowledge(id: 'e2', key: 'k');
      when(() => repository.getEntity('e2')).thenAnswer((_) async => confirmed);

      final updated = await service.retract('e2');

      expect(updated!.status, KnowledgeStatus.retracted);
      expect(updated.retractedAt, isNotNull);
    });

    test('edit updates the statement and re-confirms', () async {
      final stale = knowledge(id: 'e3', key: 'k');
      when(() => repository.getEntity('e3')).thenAnswer((_) async => stale);

      final updated = await service.editStatement(
        'e3',
        hook: 'new hook',
        statement: 'new statement',
      );

      expect(updated!.hook, 'new hook');
      expect(updated.statementText, 'new statement');
      expect(updated.status, KnowledgeStatus.confirmed);
    });

    test('confirm of a missing entry returns null without writing', () async {
      when(() => repository.getEntity('gone')).thenAnswer((_) async => null);
      expect(await service.confirm('gone'), isNull);
      expect(upserts, isEmpty);
    });
  });

  group('activeFor', () {
    test('returns the Head set (most recent confirmed per key)', () async {
      when(
        () => repository.getEntitiesByAgentId(
          agentId,
          type: AgentEntityTypes.plannerKnowledge,
        ),
      ).thenAnswer(
        (_) async => [
          knowledge(id: 'old', key: 'k', updatedAt: DateTime(2026, 5, 20)),
          knowledge(id: 'new', key: 'k', updatedAt: DateTime(2026, 5, 24)),
          knowledge(id: 'r', key: 'gone', status: KnowledgeStatus.retracted),
        ],
      );

      final active = await service.activeFor(agentId);
      expect(active.map((e) => e.id), ['new']);
    });
  });
}
