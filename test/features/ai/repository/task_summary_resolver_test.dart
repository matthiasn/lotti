import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:mocktail/mocktail.dart';

class _MockAgentRepository extends Mock implements AgentRepository {}

AgentLink _link({
  required String id,
  required String fromId,
  required String toId,
  required DateTime createdAt,
}) => AgentLink.agentTask(
  id: id,
  fromId: fromId,
  toId: toId,
  createdAt: createdAt,
  updatedAt: createdAt,
  vectorClock: null,
);

AgentReportEntity _report({
  required String id,
  required String agentId,
  required String content,
  String? tldr,
  DateTime? createdAt,
}) => AgentReportEntity(
  id: id,
  agentId: agentId,
  scope: AgentReportScopes.current,
  createdAt: createdAt ?? DateTime(2026, 4),
  vectorClock: null,
  content: content,
  tldr: tldr,
);

AiResponseEntry _aiResponseEntry({
  required String id,
  required String response,
  required DateTime dateFrom,
  // ignore: deprecated_member_use_from_same_package
  AiResponseType type = AiResponseType.taskSummary,
}) =>
    JournalEntity.aiResponse(
          meta: Metadata(
            id: id,
            dateFrom: dateFrom,
            dateTo: dateFrom,
            createdAt: dateFrom,
            updatedAt: dateFrom,
          ),
          data: AiResponseData(
            model: 'm',
            systemMessage: 'sys',
            prompt: 'p',
            thoughts: '',
            response: response,
            type: type,
          ),
        )
        as AiResponseEntry;

void main() {
  group('TaskSummaryResolver', () {
    late _MockAgentRepository repo;

    setUp(() {
      repo = _MockAgentRepository();
    });

    test('returns null when both sources are empty and repo is null', () async {
      final resolver = TaskSummaryResolver(null);
      final summary = await resolver.resolve('task-1');
      expect(summary, isNull);
    });

    test('falls back to legacy summary when repo is null', () async {
      final resolver = TaskSummaryResolver(null);
      final earlier = _aiResponseEntry(
        id: 'r1',
        response: 'older',
        dateFrom: DateTime(2026, 4),
      );
      final later = _aiResponseEntry(
        id: 'r2',
        response: 'latest summary',
        dateFrom: DateTime(2026, 4, 10),
      );
      final summary = await resolver.resolve(
        'task-1',
        linkedEntities: [earlier, later],
      );
      expect(summary, 'latest summary');
    });

    test('ignores non-taskSummary AI response types', () async {
      final resolver = TaskSummaryResolver(null);
      final wrongType = _aiResponseEntry(
        id: 'r1',
        response: 'not a summary',
        dateFrom: DateTime(2026, 4, 5),
        type: AiResponseType.imageAnalysis,
      );
      final summary = await resolver.resolve(
        'task-1',
        linkedEntities: [wrongType],
      );
      expect(summary, isNull);
    });

    test(
      'returns null when there are no agent links and no entities',
      () async {
        when(
          () => repo.getLinksTo(any(), type: any(named: 'type')),
        ).thenAnswer((_) async => <AgentLink>[]);

        final resolver = TaskSummaryResolver(repo);
        final summary = await resolver.resolve('task-1');
        expect(summary, isNull);
      },
    );

    test('uses agent report content when tldr is null', () async {
      final link = _link(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2026, 4, 10),
      );
      when(
        () => repo.getLinksTo('task-1', type: AgentLinkTypes.agentTask),
      ).thenAnswer((_) async => [link]);
      when(
        () => repo.getLatestReport('agent-1', AgentReportScopes.current),
      ).thenAnswer(
        (_) async => _report(
          id: 'rep-1',
          agentId: 'agent-1',
          content: 'full report content',
        ),
      );

      final resolver = TaskSummaryResolver(repo);
      final summary = await resolver.resolve('task-1');
      expect(summary, 'full report content');
    });

    test('prefers tldr over content when tldr is non-empty', () async {
      final link = _link(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2026, 4, 10),
      );
      when(
        () => repo.getLinksTo('task-1', type: AgentLinkTypes.agentTask),
      ).thenAnswer((_) async => [link]);
      when(
        () => repo.getLatestReport('agent-1', AgentReportScopes.current),
      ).thenAnswer(
        (_) async => _report(
          id: 'rep-1',
          agentId: 'agent-1',
          content: 'long content',
          tldr: 'short tldr',
        ),
      );

      final resolver = TaskSummaryResolver(repo);
      final summary = await resolver.resolve('task-1');
      expect(summary, 'short tldr');
    });

    test('falls back to content when tldr is whitespace-only', () async {
      final link = _link(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2026, 4, 10),
      );
      when(
        () => repo.getLinksTo('task-1', type: AgentLinkTypes.agentTask),
      ).thenAnswer((_) async => [link]);
      when(
        () => repo.getLatestReport('agent-1', AgentReportScopes.current),
      ).thenAnswer(
        (_) async => _report(
          id: 'rep-1',
          agentId: 'agent-1',
          content: 'real content',
          tldr: '   ',
        ),
      );

      final resolver = TaskSummaryResolver(repo);
      final summary = await resolver.resolve('task-1');
      expect(summary, 'real content');
    });

    test('returns null when both tldr and content are empty', () async {
      final link = _link(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2026, 4, 10),
      );
      when(
        () => repo.getLinksTo('task-1', type: AgentLinkTypes.agentTask),
      ).thenAnswer((_) async => [link]);
      when(
        () => repo.getLatestReport('agent-1', AgentReportScopes.current),
      ).thenAnswer(
        (_) async => _report(
          id: 'rep-1',
          agentId: 'agent-1',
          content: '   ',
          tldr: '',
        ),
      );

      final resolver = TaskSummaryResolver(repo);
      final summary = await resolver.resolve('task-1');
      // Empty agent report → falls back to legacy summaries (none provided).
      expect(summary, isNull);
    });

    test('picks newest agent link when multiple exist', () async {
      final older = _link(
        id: 'l1',
        fromId: 'agent-old',
        toId: 'task-1',
        createdAt: DateTime(2026, 4),
      );
      final newer = _link(
        id: 'l2',
        fromId: 'agent-new',
        toId: 'task-1',
        createdAt: DateTime(2026, 4, 20),
      );
      when(
        () => repo.getLinksTo('task-1', type: AgentLinkTypes.agentTask),
      ).thenAnswer((_) async => [older, newer]);
      when(
        () => repo.getLatestReport('agent-new', AgentReportScopes.current),
      ).thenAnswer(
        (_) async => _report(
          id: 'rep',
          agentId: 'agent-new',
          content: 'newest report',
        ),
      );

      final resolver = TaskSummaryResolver(repo);
      final summary = await resolver.resolve('task-1');
      expect(summary, 'newest report');
      verifyNever(
        () => repo.getLatestReport('agent-old', AgentReportScopes.current),
      );
    });

    test('falls back to legacy summary when agent has no report', () async {
      final link = _link(
        id: 'l1',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2026, 4, 10),
      );
      when(
        () => repo.getLinksTo('task-1', type: AgentLinkTypes.agentTask),
      ).thenAnswer((_) async => [link]);
      when(
        () => repo.getLatestReport('agent-1', AgentReportScopes.current),
      ).thenAnswer((_) async => null);

      final legacy = _aiResponseEntry(
        id: 'r1',
        response: 'legacy summary',
        dateFrom: DateTime(2026, 4, 5),
      );

      final resolver = TaskSummaryResolver(repo);
      final summary = await resolver.resolve(
        'task-1',
        linkedEntities: [legacy],
      );
      expect(summary, 'legacy summary');
    });

    test('falls back to legacy when getLinksTo throws', () async {
      when(
        () => repo.getLinksTo(any(), type: any(named: 'type')),
      ).thenThrow(StateError('db down'));

      final legacy = _aiResponseEntry(
        id: 'r1',
        response: 'legacy summary',
        dateFrom: DateTime(2026, 4, 5),
      );

      final resolver = TaskSummaryResolver(repo);
      final summary = await resolver.resolve(
        'task-1',
        linkedEntities: [legacy],
      );
      expect(summary, 'legacy summary');
    });

    test('falls back to legacy when getLatestReport throws', () async {
      final link = _link(
        id: 'l1',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2026, 4, 10),
      );
      when(
        () => repo.getLinksTo('task-1', type: AgentLinkTypes.agentTask),
      ).thenAnswer((_) async => [link]);
      when(
        () => repo.getLatestReport(any(), any()),
      ).thenThrow(StateError('boom'));

      final legacy = _aiResponseEntry(
        id: 'r1',
        response: 'legacy summary',
        dateFrom: DateTime(2026, 4, 5),
      );

      final resolver = TaskSummaryResolver(repo);
      final summary = await resolver.resolve(
        'task-1',
        linkedEntities: [legacy],
      );
      expect(summary, 'legacy summary');
    });
  });
}
