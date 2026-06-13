import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/workflow/task_agent_context_builder.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockAgentRepository agentRepository;
  late MockAgentSyncService syncService;
  late MockAiInputRepository aiInputRepository;
  late MockJournalDb journalDb;
  late MockTimeService timeService;
  late List<({String message, Object? error})> loggedErrors;
  late TaskAgentContextBuilder builder;

  final clockNow = DateTime(2024, 3, 15, 10);

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    agentRepository = MockAgentRepository();
    syncService = MockAgentSyncService();
    aiInputRepository = MockAiInputRepository();
    journalDb = MockJournalDb();
    timeService = MockTimeService();
    loggedErrors = [];
    builder = TaskAgentContextBuilder(
      agentRepository: agentRepository,
      syncService: syncService,
      aiInputRepository: aiInputRepository,
      journalDb: journalDb,
      logError: (message, {error, stackTrace}) =>
          loggedErrors.add((message: message, error: error)),
    );
  });

  Task taskEntity({
    String id = 'task-001',
    String title = 'My Task',
    TaskStatus? status,
  }) {
    final now = DateTime(2024, 3, 15);
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: 'cat-1',
      ),
      data: TaskData(
        title: title,
        status:
            status ?? TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
      ),
    );
  }

  AttentionRequestEntity attentionRequest({
    String id = 'ar-1',
    String agentId = 'agent-self',
  }) {
    return AgentDomainEntity.attentionRequest(
          id: id,
          agentId: agentId,
          kind: AttentionRequestKind.task,
          title: 'Block time',
          categoryId: 'cat-1',
          requestedMinutes: 60,
          impact: 5,
          urgency: 4,
          energyFit: AttentionEnergyFit.high,
          evidenceRefs: const [],
          scopeKind: AttentionClaimScopeKind.dateRange,
          targetId: 'task-001',
          targetKind: 'task',
          rationale: 'Needs a focus block.',
          createdAt: DateTime(2024, 3, 14),
          vectorClock: null,
        )
        as AttentionRequestEntity;
  }

  AiLinkedTaskContext linkedContext({
    String id = 'linked-1',
    String title = 'Linked',
  }) {
    return AiLinkedTaskContext(
      id: id,
      title: title,
      status: 'open',
      statusSince: DateTime(2024, 3),
      priority: 'P2',
      estimate: '1h',
      timeSpent: '0m',
      createdAt: DateTime(2024, 3),
      labels: const [],
    );
  }

  group('attentionClaimsForTask', () {
    test('returns claims from the repository', () async {
      final claim = attentionRequest();
      when(
        () => agentRepository.getAttentionClaimsForTarget(
          targetKind: 'task',
          targetId: 'task-001',
          limit: 20,
        ),
      ).thenAnswer((_) async => [claim]);

      final result = await builder.attentionClaimsForTask('task-001');

      expect(result, [claim]);
    });

    test('swallows repository errors and logs', () async {
      when(
        () => agentRepository.getAttentionClaimsForTarget(
          targetKind: any(named: 'targetKind'),
          targetId: any(named: 'targetId'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(Exception('db'));

      final result = await builder.attentionClaimsForTask('task-001');

      expect(result, isEmpty);
      expect(
        loggedErrors.map((e) => e.message),
        contains('failed to load task attention requests'),
      );
    });
  });

  group('maintainAndLoadAttentionClaims', () {
    test(
      'resolves the task from the db when not provided and returns claims',
      () async {
        final task = taskEntity();
        final claim = attentionRequest();
        when(
          () => journalDb.journalEntityById('task-001'),
        ).thenAnswer((_) async => task);
        when(
          () => agentRepository.getAttentionClaimsForTarget(
            targetKind: 'task',
            targetId: 'task-001',
            limit: 20,
          ),
        ).thenAnswer((_) async => [claim]);

        final result = await builder.maintainAndLoadAttentionClaims(
          agentId: 'agent-self',
          taskId: 'task-001',
        );

        expect(result.task, task);
        expect(result.claims, [claim]);
      },
    );

    test('still loads claims when maintenance throws', () async {
      when(
        () => journalDb.journalEntityById('task-001'),
      ).thenThrow(Exception('boom'));
      when(
        () => agentRepository.getAttentionClaimsForTarget(
          targetKind: 'task',
          targetId: 'task-001',
          limit: 20,
        ),
      ).thenAnswer((_) async => const []);

      final result = await builder.maintainAndLoadAttentionClaims(
        agentId: 'agent-self',
        taskId: 'task-001',
      );

      expect(result.task, isNull);
      expect(result.claims, isEmpty);
      expect(
        loggedErrors.map((e) => e.message),
        contains('failed to maintain task attention requests'),
      );
    });
  });

  group('buildLinkedTasksContextJson', () {
    test('returns empty object when there are no linked tasks', () async {
      when(
        () => aiInputRepository.buildLinkedFromContext('task-001'),
      ).thenAnswer((_) async => const []);
      when(
        () => aiInputRepository.buildLinkedToContext('task-001'),
      ).thenAnswer((_) async => const []);

      final json = await builder.buildLinkedTasksContextJson('task-001');

      expect(json, '{}');
    });

    test('marks rows without a report as summaryStatus none', () async {
      when(
        () => aiInputRepository.buildLinkedFromContext('task-001'),
      ).thenAnswer((_) async => [linkedContext(id: 'child-1')]);
      when(
        () => aiInputRepository.buildLinkedToContext('task-001'),
      ).thenAnswer((_) async => const []);
      when(
        () => agentRepository.getLinksToMultiple(
          any(),
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer((_) async => const {});

      final json = await builder.buildLinkedTasksContextJson('task-001');
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final row =
          (decoded['linked_from'] as List<dynamic>).first
              as Map<String, dynamic>;

      expect(row['summaryStatus'], 'none');
      expect(row.containsKey('latestSummary'), isFalse);
    });

    test('embeds the latest agent report summary for a linked task', () async {
      when(
        () => aiInputRepository.buildLinkedFromContext('task-001'),
      ).thenAnswer((_) async => [linkedContext(id: 'child-1')]);
      when(
        () => aiInputRepository.buildLinkedToContext('task-001'),
      ).thenAnswer((_) async => const []);
      when(
        () => agentRepository.getLinksToMultiple(
          any(),
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => {
          'child-1': [
            makeTestAgentTaskLink(fromId: 'agent-child', toId: 'child-1'),
          ],
        },
      );
      when(
        () => agentRepository.getLatestReportsByAgentIds(
          any(),
          AgentReportScopes.current,
        ),
      ).thenAnswer(
        (_) async => {
          'agent-child': makeTestReport(
            agentId: 'agent-child',
            content: 'Body.',
            oneLiner: 'On track.',
            tldr: 'Done with phase 1.',
          ),
        },
      );

      final json = await builder.buildLinkedTasksContextJson('task-001');
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final row =
          (decoded['linked_from'] as List<dynamic>).first
              as Map<String, dynamic>;

      expect(row['summaryStatus'], 'present');
      expect(row['taskAgentId'], 'agent-child');
      expect(row['latestTaskAgentReportOneLiner'], 'On track.');
      expect(row['latestTaskAgentReportTldr'], 'Done with phase 1.');
    });
  });

  group('buildToolDefinitions', () {
    test('maps enabled task tools to function tools', () {
      final tools = builder.buildToolDefinitions();

      expect(tools, isNotEmpty);
      for (final tool in tools) {
        expect(tool.type, ChatCompletionToolType.function);
      }
      final names = tools.map((t) => t.function.name).toSet();
      expect(names, contains('update_report'));
    });
  });

  group('extractFinalAssistantContent', () {
    test('returns null when manager is null', () {
      expect(builder.extractFinalAssistantContent(null), isNull);
    });

    test('returns the last assistant message with text content', () {
      final manager = MockConversationManager();
      when(() => manager.messages).thenReturn([
        const ChatCompletionMessage.assistant(content: 'first'),
        const ChatCompletionMessage.assistant(content: 'final answer'),
      ]);

      expect(builder.extractFinalAssistantContent(manager), 'final answer');
    });
  });

  group('buildUserMessage', () {
    Future<({String text, int? logStart, int? logEnd})> build({
      bool hasReport = true,
      List<AgentMessageEntity> journalObservations = const [],
      String taskDetails = '{"title":"My Task"}',
      String projectContextJson = '{}',
      String linkedTasksJson = '{}',
      Set<String> triggerTokens = const {},
      ProposalLedger ledger = const ProposalLedger.empty(),
      List<AttentionRequestEntity> attentionClaims = const [],
      Task? task,
      String? compactedTaskLog,
    }) {
      return withClock(Clock.fixed(clockNow), () {
        when(() => timeService.getCurrent()).thenReturn(null);
        when(
          () => journalDb.getLinkedEntities('task-001'),
        ).thenAnswer((_) async => const []);
        return builder.buildUserMessage(
          agentId: 'agent-self',
          hasReport: hasReport,
          journalObservations: journalObservations,
          taskDetails: taskDetails,
          projectContextJson: projectContextJson,
          linkedTasksJson: linkedTasksJson,
          triggerTokens: triggerTokens,
          taskId: 'task-001',
          ledger: ledger,
          attentionClaims: attentionClaims,
          task: task ?? taskEntity(),
          timeService: timeService,
          compactedTaskLog: compactedTaskLog,
        );
      });
    }

    test(
      'uses inline task context and no log offsets without a compacted log',
      () async {
        final result = await build();

        expect(result.logStart, isNull);
        expect(result.logEnd, isNull);
        expect(result.text, contains('## Current Task Context'));
        expect(result.text, isNot(contains('## Task Log')));
      },
    );

    test('records log offsets bracketing the compacted task log', () async {
      const log = 'event A\nevent B';
      final result = await build(compactedTaskLog: log);

      final start = result.logStart;
      final end = result.logEnd;
      expect(start, isNotNull);
      expect(end, isNotNull);
      expect(result.text.substring(start!, end), log);
      expect(result.text, contains('## Task Log'));
    });

    test('includes project and linked-task blocks when present', () async {
      final result = await build(
        projectContextJson: '{"id":"p1"}',
        linkedTasksJson: '{"linked_from":[]}',
      );

      expect(result.text, contains('## Parent Project Context'));
      expect(result.text, contains('"id":"p1"'));
      expect(result.text, contains('## Linked Tasks'));
    });

    test('adds first-wake notice and trigger tokens', () async {
      final result = await build(
        hasReport: false,
        triggerTokens: const {'tok-1'},
      );

      expect(result.text, contains('## First Wake'));
      expect(result.text, contains('## Changed Since Last Wake'));
      expect(result.text, contains('tok-1'));
    });

    test('renders open proposals and the open-proposal guard', () async {
      final ledger = makeProposalLedger(
        open: [makeLedgerEntry(humanSummary: 'Bump priority to P1')],
      );

      final result = await build(ledger: ledger);

      expect(result.text, contains('## Proposal Ledger'));
      expect(result.text, contains('Bump priority to P1'));
      expect(result.text, contains('## Open Proposal Guard'));
    });

    test('surfaces prior critical grievance observations', () async {
      final observation = makeTestMessage(contentEntryId: 'p1');
      final payload = makeTestMessagePayload(
        id: 'p1',
        content: const {
          'text': 'User was frustrated by the delay.',
          'priority': 'critical',
          'category': 'grievance',
        },
      );
      when(
        () => agentRepository.getEntitiesByIds(any()),
      ).thenAnswer((_) async => {'p1': payload});

      final result = await build(journalObservations: [observation]);

      expect(
        result.text,
        contains('## Prior Critical Observations (Self-Review)'),
      );
      expect(result.text, contains('### Grievances'));
      expect(result.text, contains('User was frustrated by the delay.'));
    });

    test('renders the attention requests section', () async {
      final result = await build(attentionClaims: [attentionRequest()]);

      expect(result.text, contains('## Attention Requests For This Task'));
      expect(result.text, contains('Block time'));
    });

    test('renders the active running timer for the same task', () async {
      final timerEntry = JournalEntry(
        meta: Metadata(
          id: 'timer-1',
          createdAt: clockNow.subtract(const Duration(minutes: 30)),
          updatedAt: clockNow,
          dateFrom: clockNow.subtract(const Duration(minutes: 30)),
          dateTo: clockNow.subtract(const Duration(minutes: 30)),
        ),
        entryText: const EntryText(plainText: 'Working on it'),
      );
      final result = await withClock(Clock.fixed(clockNow), () {
        when(() => timeService.getCurrent()).thenReturn(timerEntry);
        when(() => timeService.linkedFrom).thenReturn(taskEntity());
        when(
          () => journalDb.getLinkedEntities('task-001'),
        ).thenAnswer((_) async => const []);
        return builder.buildUserMessage(
          agentId: 'agent-self',
          hasReport: true,
          journalObservations: const [],
          taskDetails: '{"title":"My Task"}',
          projectContextJson: '{}',
          linkedTasksJson: '{}',
          triggerTokens: const {},
          taskId: 'task-001',
          task: taskEntity(),
          timeService: timeService,
        );
      });

      expect(result.text, contains('## Active Running Timer'));
      expect(result.text, contains('timerId: timer-1'));
      expect(result.text, contains('current text: "Working on it"'));
    });
  });
}
