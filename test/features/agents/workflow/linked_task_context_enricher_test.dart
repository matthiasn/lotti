import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/workflow/linked_task_context_enricher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('LinkedTaskContextEnricher', () {
    late MockAgentRepository mockRepository;
    late LinkedTaskContextEnricher enricher;

    setUp(() {
      mockRepository = MockAgentRepository();
      enricher = LinkedTaskContextEnricher(agentRepository: mockRepository);
    });

    test('passes through malformed JSON unchanged', () async {
      const rawJson = '{"linked":[{"id":"task-1"}]';

      final result = await enricher.enrich(rawJson);

      expect(result, rawJson);
      verifyNever(
        () => mockRepository.getLinksTo(any(), type: any(named: 'type')),
      );
    });

    test('handles repository errors without failing enrichment', () async {
      when(() => mockRepository.getLinksTo('task-2', type: 'agent_task'))
          .thenThrow(Exception('db lookup failed'));

      const rawJson =
          '{"linked":[{"id":"task-2","title":"Related","latestSummary":"old"}]}';

      final result = await enricher.enrich(rawJson);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final linkedRows = decoded['linked'] as List<dynamic>;
      final row = linkedRows.first as Map<String, dynamic>;

      expect(row['id'], 'task-2');
      expect(row['title'], 'Related');
      expect(row.containsKey('latestSummary'), isFalse);
      expect(row.containsKey('latestTaskAgentReport'), isFalse);
    });

    test('picks newest link with first non-empty report content', () async {
      final now = DateTime(2024, 6, 15, 12);
      final older = AgentLink.agentTask(
        id: 'link-old',
        fromId: 'agent-old',
        toId: 'task-3',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
        vectorClock: null,
      );
      final newer = AgentLink.agentTask(
        id: 'link-new',
        fromId: 'agent-new',
        toId: 'task-3',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        vectorClock: null,
      );
      when(() => mockRepository.getLinksTo('task-3', type: 'agent_task'))
          .thenAnswer((_) async => [older, newer]);

      final emptyNewReport = AgentDomainEntity.agentReport(
        id: 'r-new',
        agentId: 'agent-new',
        scope: 'current',
        createdAt: now.subtract(const Duration(days: 1)),
        vectorClock: null,
        content: '   ',
      ) as AgentReportEntity;
      when(() => mockRepository.getLatestReport('agent-new', 'current'))
          .thenAnswer((_) async => emptyNewReport);

      final olderReport = AgentDomainEntity.agentReport(
        id: 'r-old',
        agentId: 'agent-old',
        scope: 'current',
        createdAt: now.subtract(const Duration(days: 2)),
        vectorClock: null,
        content: '## Linked report from older agent',
      ) as AgentReportEntity;
      when(() => mockRepository.getLatestReport('agent-old', 'current'))
          .thenAnswer((_) async => olderReport);

      const rawJson =
          '{"linked":[{"id":"task-3","title":"Parent","latestSummary":"legacy"}]}';

      final result = await enricher.enrich(rawJson);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final linkedRows = decoded['linked'] as List<dynamic>;
      final row = linkedRows.first as Map<String, dynamic>;

      verifyInOrder([
        () => mockRepository.getLatestReport('agent-new', 'current'),
        () => mockRepository.getLatestReport('agent-old', 'current'),
      ]);
      expect(row['taskAgentId'], 'agent-old');
      expect(
        row['latestTaskAgentReport'],
        '## Linked report from older agent',
      );
      expect(row.containsKey('latestSummary'), isFalse);
    });

    test('uses link id as deterministic tie-breaker for equal createdAt',
        () async {
      final now = DateTime(2024, 6, 15, 12);
      final linkB = AgentLink.agentTask(
        id: 'link-b',
        fromId: 'agent-b',
        toId: 'task-4',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      );
      final linkA = AgentLink.agentTask(
        id: 'link-a',
        fromId: 'agent-a',
        toId: 'task-4',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      );
      when(() => mockRepository.getLinksTo('task-4', type: 'agent_task'))
          .thenAnswer((_) async => [linkB, linkA]);

      final reportA = AgentDomainEntity.agentReport(
        id: 'r-a',
        agentId: 'agent-a',
        scope: 'current',
        createdAt: now,
        vectorClock: null,
        content: 'report-a',
      ) as AgentReportEntity;
      when(() => mockRepository.getLatestReport('agent-a', 'current'))
          .thenAnswer((_) async => reportA);

      const rawJson = '{"linked":[{"id":"task-4","latestSummary":"legacy"}]}';

      final result = await enricher.enrich(rawJson);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final linkedRows = decoded['linked'] as List<dynamic>;
      final row = linkedRows.first as Map<String, dynamic>;

      verify(() => mockRepository.getLatestReport('agent-a', 'current'))
          .called(1);
      verifyNever(() => mockRepository.getLatestReport('agent-b', 'current'));
      expect(row['taskAgentId'], 'agent-a');
      expect(row['latestTaskAgentReport'], 'report-a');
      expect(row.containsKey('latestSummary'), isFalse);
    });
  });
}
