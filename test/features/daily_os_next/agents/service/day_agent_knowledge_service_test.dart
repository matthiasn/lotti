import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
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

    test('persists a proposed entry for a userStated source — the tool path '
        'never auto-confirms (ADR 0022 D10)', () async {
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
      expect(stored.status, KnowledgeStatus.proposed);
      expect(stored.confirmedAt, isNull);
      expect(stored.source, KnowledgeSource.userStated);
      expect(stored.key, 'deep-work');
    });

    test('passes through tags from the tool args', () async {
      final result = await service.executeTool(
        agentId: agentId,
        toolName: DayAgentToolNames.proposeKnowledge,
        args: const {
          'key': 'k',
          'hook': 'h',
          'statement': 's',
          'tags': ['mornings', 'deep-work'],
        },
      );
      expect(result.success, isTrue);
      final stored = upserts.single as PlannerKnowledgeEntity;
      expect(stored.tags, const ['mornings', 'deep-work']);
    });

    test('rejects an unknown tool name', () async {
      final result = await service.executeTool(
        agentId: agentId,
        toolName: 'not_a_tool',
        args: const {},
      );
      expect(result.success, isFalse);
    });

    test('rejects an unknown source value instead of downgrading', () async {
      final result = await service.executeTool(
        agentId: agentId,
        toolName: DayAgentToolNames.proposeKnowledge,
        args: const {
          'key': 'k',
          'hook': 'h',
          'statement': 's',
          'source': 'guessed',
        },
      );
      expect(result.success, isFalse);
      expect(result.output, contains('source'));
      expect(upserts, isEmpty);
    });

    test('surfaces an unexpected error as a tool failure', () async {
      when(
        () => domainLogger.error(
          any(),
          any<Object>(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenReturn(null);
      when(
        () => syncService.upsertEntity(any()),
      ).thenThrow(StateError('db down'));

      final result = await service.executeTool(
        agentId: agentId,
        toolName: DayAgentToolNames.proposeKnowledge,
        args: const {
          'key': 'k',
          'hook': 'h',
          'statement': 's',
          'source': 'userStated',
        },
      );
      expect(result.success, isFalse);
      expect(result.output, contains('db down'));
    });
  });

  group('scope validation', () {
    test('rejects a malformed scope', () async {
      final result = await service.executeTool(
        agentId: agentId,
        toolName: DayAgentToolNames.proposeKnowledge,
        args: const {
          'key': 'k',
          'hook': 'h',
          'statement': 's',
          'scope': 'focus', // missing category:/project: prefix
        },
      );
      expect(result.success, isFalse);
      expect(result.output, contains('scope'));
    });

    test('rejects an over-long hook', () async {
      final result = await service.executeTool(
        agentId: agentId,
        toolName: DayAgentToolNames.proposeKnowledge,
        args: {
          'key': 'k',
          'hook': 'x' * 200,
          'statement': 's',
        },
      );
      expect(result.success, isFalse);
      expect(result.output, contains('hook'));
    });
  });
}
