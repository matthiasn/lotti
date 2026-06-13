import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/workflow/project_agent_context_builder.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockAgentRepository agentRepository;
  late MockJournalRepository journalRepository;
  late List<({String message, Object? error})> loggedErrors;
  late ProjectAgentContextBuilder builder;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    agentRepository = MockAgentRepository();
    journalRepository = MockJournalRepository();
    loggedErrors = [];
    builder = ProjectAgentContextBuilder(
      agentRepository: agentRepository,
      journalRepository: journalRepository,
      logError: (message, {error, stackTrace}) =>
          loggedErrors.add((message: message, error: error)),
    );
  });

  JournalEntity projectEntity({
    String title = 'Test Project',
    String? description,
    ProjectStatus? status,
    DateTime? targetDate,
  }) {
    return JournalEntity.project(
      meta: Metadata(
        id: 'project-001',
        createdAt: DateTime(2024, 6, 15),
        updatedAt: DateTime(2024, 6, 15),
        dateFrom: DateTime(2024, 6, 15),
        dateTo: DateTime(2024, 6, 15),
      ),
      entryText: description == null
          ? null
          : EntryText(plainText: description, markdown: description),
      data: ProjectData(
        title: title,
        status:
            status ??
            ProjectStatus.active(
              id: 'status-001',
              createdAt: DateTime(2024, 6, 15),
              utcOffset: 0,
            ),
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 12, 31),
        targetDate: targetDate,
      ),
    );
  }

  Task taskEntity({
    String id = 'task-001',
    String title = 'Linked Task',
    TaskStatus? status,
  }) {
    final now = DateTime(2024, 6, 15);
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
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

  group('buildSystemPrompt', () {
    test('returns scaffold only when version is null', () {
      final prompt = builder.buildSystemPrompt(
        version: null,
        soulVersion: null,
      );

      expect(prompt, contains('You are a Project Agent'));
      expect(prompt, contains('## Health Assessment'));
      expect(prompt, isNot(contains('## Your Personality')));
      expect(prompt, isNot(contains('## Report Directive')));
    });

    test('appends legacy combined heading when only directives is set', () {
      final version = makeTestTemplateVersion(
        directives: 'Be terse and direct.',
      );

      final prompt = builder.buildSystemPrompt(
        version: version,
        soulVersion: null,
      );

      expect(prompt, contains('## Your Personality & Directives'));
      expect(prompt, contains('Be terse and direct.'));
    });

    test('renders report directive section when reportDirective is set', () {
      final version = makeTestTemplateVersion(
        reportDirective: 'Always include a risk table.',
        generalDirective: 'Stay focused on outcomes.',
      );

      final prompt = builder.buildSystemPrompt(
        version: version,
        soulVersion: null,
      );

      expect(prompt, contains('## Report Directive'));
      expect(prompt, contains('Always include a risk table.'));
      // No soul: general directive uses combined legacy heading.
      expect(prompt, contains('## Your Personality & Directives'));
      expect(prompt, contains('Stay focused on outcomes.'));
    });

    test('separates personality from directives when soul is assigned', () {
      final version = makeTestTemplateVersion(
        generalDirective: 'Prioritize blockers.',
        reportDirective: 'List achievements first.',
      );
      final soul = makeTestSoulDocumentVersion(
        voiceDirective: 'Speak with calm confidence.',
        toneBounds: 'Never condescending.',
      );

      final prompt = builder.buildSystemPrompt(
        version: version,
        soulVersion: soul,
      );

      expect(prompt, contains('## Your Personality'));
      expect(prompt, contains('Speak with calm confidence.'));
      expect(prompt, contains('Never condescending.'));
      expect(prompt, contains('## Your Operational Directives'));
      expect(prompt, contains('Prioritize blockers.'));
      // Soul path never emits the legacy combined heading.
      expect(prompt, isNot(contains('## Your Personality & Directives')));
    });

    test(
      'falls back to version.directives when generalDirective empty but '
      'reportDirective present and no soul',
      () {
        final version = makeTestTemplateVersion(
          directives: 'Legacy fallback text.',
          reportDirective: 'Report directive text.',
        );

        final prompt = builder.buildSystemPrompt(
          version: version,
          soulVersion: null,
        );

        expect(prompt, contains('Report directive text.'));
        expect(prompt, contains('## Your Personality & Directives'));
        expect(prompt, contains('Legacy fallback text.'));
      },
    );
  });

  group('buildUserMessage', () {
    test('omits project log block and offsets when compactedLog is null', () {
      final result = builder.buildUserMessage(
        projectEntity: projectEntity(),
        lastReport: null,
        observations: const [],
        observationPayloads: const {},
        linkedTasksContext: '{}',
        triggerTokens: const {},
      );

      expect(result.logStart, isNull);
      expect(result.logEnd, isNull);
      expect(result.text, isNot(contains('## Project Log')));
      expect(result.text, contains('## Project Context'));
      expect(result.text, contains('**Title**: Test Project'));
    });

    test('records project-log offsets that bracket the compacted log', () {
      const log = 'event one\nevent two';
      final result = builder.buildUserMessage(
        projectEntity: projectEntity(),
        lastReport: null,
        observations: const [],
        observationPayloads: const {},
        linkedTasksContext: '{}',
        triggerTokens: const {},
        compactedLog: log,
      );

      final logStart = result.logStart;
      final logEnd = result.logEnd;
      expect(logStart, isNotNull);
      expect(logEnd, isNotNull);
      expect(result.text.substring(logStart!, logEnd), log);
    });

    test('renders linked tasks, previous report and trigger tokens', () {
      final result = builder.buildUserMessage(
        projectEntity: projectEntity(),
        lastReport: makeTestReport(content: 'Prior body.'),
        observations: const [],
        observationPayloads: const {},
        linkedTasksContext: '{"linked_tasks": []}',
        triggerTokens: const {'tok-1', 'tok-2'},
      );

      expect(result.text, contains('## Linked Tasks'));
      expect(result.text, contains('"linked_tasks": []'));
      expect(result.text, contains('## Previous Report'));
      expect(result.text, contains('Prior body.'));
      expect(result.text, contains('## Trigger Tokens'));
      expect(result.text, contains('tok-1, tok-2'));
    });

    test('lists recent observations only when no compacted log is present', () {
      final observation = makeTestMessage(contentEntryId: 'payload-1');
      final payload = makeTestMessagePayload(
        id: 'payload-1',
        content: const {'text': 'Noticed a blocker.'},
      );

      final withoutLog = builder.buildUserMessage(
        projectEntity: projectEntity(),
        lastReport: null,
        observations: [observation],
        observationPayloads: {'payload-1': payload},
        linkedTasksContext: '{}',
        triggerTokens: const {},
      );
      expect(withoutLog.text, contains('## Recent Observations'));
      expect(withoutLog.text, contains('Noticed a blocker.'));

      // With a compacted log, observations live in the log tail and the
      // separate section is suppressed to avoid duplication.
      final withLog = builder.buildUserMessage(
        projectEntity: projectEntity(),
        lastReport: null,
        observations: [observation],
        observationPayloads: {'payload-1': payload},
        linkedTasksContext: '{}',
        triggerTokens: const {},
        compactedLog: 'folded log',
      );
      expect(withLog.text, isNot(contains('## Recent Observations')));
    });

    test('writes on-hold reason and description for project context', () {
      final result = builder.buildUserMessage(
        projectEntity: projectEntity(
          description: 'Migration project description.',
          status: ProjectStatus.onHold(
            id: 'status-onhold',
            createdAt: DateTime(2024, 6, 15),
            utcOffset: 0,
            reason: 'Waiting on vendor.',
          ),
          targetDate: DateTime(2024, 11, 30),
        ),
        lastReport: null,
        observations: const [],
        observationPayloads: const {},
        linkedTasksContext: '{}',
        triggerTokens: const {},
      );

      expect(result.text, contains('**On-hold reason**: Waiting on vendor.'));
      expect(result.text, contains('**Target date**: 2024-11-30'));
      expect(result.text, contains('### Description'));
      expect(result.text, contains('Migration project description.'));
    });

    test('writes raw entity string when entity is not a project', () {
      final result = builder.buildUserMessage(
        projectEntity: taskEntity(),
        lastReport: null,
        observations: const [],
        observationPayloads: const {},
        linkedTasksContext: '{}',
        triggerTokens: const {},
      );

      expect(result.text, contains('Project entity:'));
    });
  });

  group('buildToolDefinitions', () {
    test('maps every project tool to a function tool with matching name', () {
      final tools = builder.buildToolDefinitions();

      expect(tools, isNotEmpty);
      final names = tools.map((t) => t.function.name).toSet();
      expect(names, contains('update_project_report'));
      for (final tool in tools) {
        expect(tool.type, ChatCompletionToolType.function);
      }
    });
  });

  group('buildLinkedTasksContext', () {
    test('returns empty object when no tasks are linked', () async {
      when(
        () => journalRepository.getLinkedEntities(linkedTo: 'project-001'),
      ).thenAnswer((_) async => <JournalEntity>[]);

      final json = await builder.buildLinkedTasksContext('project-001');

      expect(json, '{}');
    });

    test('embeds latest task-agent report summary for linked task', () async {
      final task = taskEntity(
        status: TaskStatus.inProgress(
          id: 's',
          createdAt: DateTime(2024, 6, 15),
          utcOffset: 0,
        ),
      );
      when(
        () => journalRepository.getLinkedEntities(linkedTo: 'project-001'),
      ).thenAnswer((_) async => [task]);
      when(
        () => agentRepository.getLinksToMultiple(
          any(),
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => {
          'task-001': [
            makeTestAgentTaskLink(fromId: 'agent-9'),
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
          'agent-9': makeTestReport(
            agentId: 'agent-9',
            content: 'Real report body.',
            oneLiner: 'Halfway there.',
            tldr: 'Login done.',
          ),
        },
      );

      final json = await builder.buildLinkedTasksContext('project-001');
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final rows = decoded['linked_tasks'] as List<dynamic>;

      expect(rows, hasLength(1));
      final row = rows.first as Map<String, dynamic>;
      expect(row['id'], 'task-001');
      expect(row['status'], 'in_progress');
      expect(row['taskAgentId'], 'agent-9');
      expect(row['latestTaskAgentReportOneLiner'], 'Halfway there.');
      expect(row['latestTaskAgentReportTldr'], 'Login done.');
    });

    test(
      'skips empty-bodied reports and leaves the task summary absent',
      () async {
        final task = taskEntity();
        when(
          () => journalRepository.getLinkedEntities(linkedTo: 'project-001'),
        ).thenAnswer((_) async => [task]);
        when(
          () => agentRepository.getLinksToMultiple(
            any(),
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => {
            'task-001': [
              makeTestAgentTaskLink(fromId: 'agent-9'),
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
            'agent-9': makeTestReport(agentId: 'agent-9', content: '   '),
          },
        );

        final json = await builder.buildLinkedTasksContext('project-001');
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final row =
            (decoded['linked_tasks'] as List<dynamic>).first
                as Map<String, dynamic>;

        expect(row.containsKey('taskAgentId'), isFalse);
      },
    );

    test(
      'logs and returns empty object when linked-entity lookup throws',
      () async {
        when(
          () => journalRepository.getLinkedEntities(linkedTo: 'project-001'),
        ).thenThrow(Exception('db down'));

        final json = await builder.buildLinkedTasksContext('project-001');

        expect(json, '{}');
        expect(
          loggedErrors.map((e) => e.message),
          contains('failed to build linked tasks context'),
        );
      },
    );
  });

  group('resolveObservationPayloads', () {
    test('returns empty map when observations carry no payload ids', () async {
      final result = await builder.resolveObservationPayloads([
        makeTestMessage(),
      ]);

      expect(result, isEmpty);
      verifyNever(() => agentRepository.getEntitiesByIds(any()));
    });

    test('keeps only payload entities from the batch lookup', () async {
      final observation = makeTestMessage(contentEntryId: 'payload-1');
      final payload = makeTestMessagePayload(id: 'payload-1');
      final report = makeTestReport(id: 'report-x');
      when(() => agentRepository.getEntitiesByIds(any())).thenAnswer(
        (_) async => <String, AgentDomainEntity>{
          'payload-1': payload,
          'report-x': report,
        },
      );

      final result = await builder.resolveObservationPayloads([observation]);

      expect(result.keys, ['payload-1']);
      expect(result['payload-1'], payload);
    });

    test('returns empty map when the batch lookup throws', () async {
      final observation = makeTestMessage(contentEntryId: 'payload-1');
      when(
        () => agentRepository.getEntitiesByIds(any()),
      ).thenThrow(Exception('boom'));

      final result = await builder.resolveObservationPayloads([observation]);

      expect(result, isEmpty);
    });
  });

  group('extractPayloadText', () {
    test('returns placeholder for null payload', () {
      expect(
        ProjectAgentContextBuilder.extractPayloadText(null),
        '(no content)',
      );
    });

    test('returns the text field when present', () {
      final payload = makeTestMessagePayload(
        content: const {'text': 'hello world'},
      );
      expect(
        ProjectAgentContextBuilder.extractPayloadText(payload),
        'hello world',
      );
    });

    test('returns placeholder when text field is empty', () {
      final payload = makeTestMessagePayload(content: const {'text': ''});
      expect(
        ProjectAgentContextBuilder.extractPayloadText(payload),
        '(no content)',
      );
    });
  });

  group('extractFinalAssistantContent', () {
    test('returns null when manager is null', () {
      expect(builder.extractFinalAssistantContent(null), isNull);
    });
  });
}
