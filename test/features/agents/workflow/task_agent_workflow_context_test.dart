import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../categories/test_utils.dart';
import 'task_agent_workflow_test_helpers.dart';

void main() {
  late MockAgentRepository mockAgentRepository;
  late MockAgentSyncService mockSyncService;
  late MockConversationRepository mockConversationRepository;
  late MockAiInputRepository mockAiInputRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockJournalDb mockJournalDb;
  late MockConversationManager mockConversationManager;
  late TaskAgentWorkflow workflow;

  const agentId = taskAgentTestAgentId;
  const taskId = taskAgentTestTaskId;
  const runKey = taskAgentTestRunKey;
  const threadId = taskAgentTestThreadId;
  final testDate = taskAgentTestDate;
  final testAgentIdentity = taskAgentTestAgentIdentity;
  final testAgentState = taskAgentTestAgentState;
  final geminiProvider = taskAgentTestGeminiProvider;
  final geminiModel = taskAgentTestGeminiModel;

  setUpAll(setUpTaskAgentWorkflowTestGetIt);
  tearDownAll(tearDownTaskAgentWorkflowTestGetIt);

  setUp(() {
    final bench = createTaskAgentWorkflowTestBench();
    mockAgentRepository = bench.mockAgentRepository;
    mockSyncService = bench.mockSyncService;
    mockConversationRepository = bench.mockConversationRepository;
    mockAiInputRepository = bench.mockAiInputRepository;
    mockAiConfigRepository = bench.mockAiConfigRepository;
    mockJournalDb = bench.mockJournalDb;
    mockConversationManager = bench.mockConversationManager;
    workflow = bench.workflow;
  });

  group('TaskAgentWorkflow', () {
    group('_buildUserMessage context', () {
      // The stubs that never vary between tests in this group are applied once
      // per test here (the file-level setUp creates fresh mocks first), so the
      // executeAndCaptureMessage helper only sets up the parameter-dependent
      // stubs each call.
      setUp(() {
        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => testAgentState);
        when(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).thenAnswer((_) async => '{"title":"Test Task"}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(
          () => mockAgentRepository.getReportHead(agentId, 'current'),
        ).thenAnswer((_) async => null);
        when(() => mockConversationManager.messages).thenReturn([]);
      });

      /// Helper that sets up the per-test (parameter-dependent) stubs for a
      /// successful execute, and captures the user message string sent to the
      /// conversation. Invariant stubs live in the group's [setUp] above.
      Future<String?> executeAndCaptureMessage({
        AgentReportEntity? lastReport,
        List<AgentMessageEntity> observations = const [],
        String projectContextJson = '{}',
        String linkedTasksJson = '{}',
        Set<String> triggerTokens = const {},
        bool throwOnLinkedContextBuild = false,
        List<AttentionRequestEntity> attentionClaims = const [],
        bool throwOnAttentionLoad = false,
      }) async {
        List<AiLinkedTaskContext> parseLinkedTasks(dynamic rawRows) {
          if (rawRows is! List) return const <AiLinkedTaskContext>[];
          return rawRows.whereType<Map<String, dynamic>>().map((row) {
            final id = (row['id'] as String?) ?? 'linked-task';
            return AiLinkedTaskContext(
              id: id,
              title: (row['title'] as String?) ?? id,
              status: (row['status'] as String?) ?? 'OPEN',
              statusSince: DateTime(2024),
              priority: (row['priority'] as String?) ?? 'M',
              estimate: (row['estimate'] as String?) ?? '00:00',
              timeSpent: (row['timeSpent'] as String?) ?? '00:00',
              createdAt: DateTime(2024),
              labels: const <Map<String, String>>[],
              languageCode: row['languageCode'] as String?,
              latestSummary: row['latestSummary'] as String?,
            );
          }).toList();
        }

        final parsed = jsonDecode(linkedTasksJson);
        final linkedMap = parsed is Map<String, dynamic>
            ? parsed
            : <String, dynamic>{};
        final linkedFrom = parseLinkedTasks(linkedMap['linked_from']);
        final linkedTo = [
          ...parseLinkedTasks(linkedMap['linked_to']),
          ...parseLinkedTasks(linkedMap['linked']),
        ];

        when(
          () => mockAgentRepository.getLatestReport(agentId, 'current'),
        ).thenAnswer((_) async => lastReport);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => observations);
        when(
          () => mockAiInputRepository.buildProjectContextJsonForTask(taskId),
        ).thenAnswer((_) async => projectContextJson);
        if (throwOnLinkedContextBuild) {
          when(
            () => mockAiInputRepository.buildLinkedFromContext(taskId),
          ).thenThrow(Exception('linked context failed'));
        } else {
          when(
            () => mockAiInputRepository.buildLinkedFromContext(taskId),
          ).thenAnswer((_) async => linkedFrom);
        }
        when(
          () => mockAiInputRepository.buildLinkedToContext(taskId),
        ).thenAnswer((_) async => linkedTo);
        if (throwOnAttentionLoad) {
          when(
            () => mockAgentRepository.getAttentionClaimsForTarget(
              targetKind: any(named: 'targetKind'),
              targetId: any(named: 'targetId'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(Exception('attention load failed'));
        } else {
          when(
            () => mockAgentRepository.getAttentionClaimsForTarget(
              targetKind: any(named: 'targetKind'),
              targetId: any(named: 'targetId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => attentionClaims);
        }
        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              toolChoice,
              temperature = 0.7,
              strategy,
            }) async {
              capturedMessage = message;
              return null;
            };

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: triggerTokens,
          threadId: threadId,
        );

        return capturedMessage;
      }

      test(
        'injects label and correction-example context when available',
        () async {
          when(() => mockJournalDb.journalEntityById(taskId)).thenAnswer(
            (_) async => Task(
              data: TaskData(
                status: TaskStatus.open(
                  id: 'status_id',
                  createdAt: DateTime(2024, 3, 15),
                  utcOffset: 60,
                ),
                title: 'Labelled task',
                statusHistory: const [],
                dateTo: DateTime(2024, 3, 15),
                dateFrom: DateTime(2024, 3, 15),
              ),
              meta: Metadata(
                id: taskId,
                createdAt: DateTime(2024, 3, 15),
                dateFrom: DateTime(2024, 3, 15),
                dateTo: DateTime(2024, 3, 15),
                updatedAt: DateTime(2024, 3, 15),
                categoryId: 'cat-001',
              ),
            ),
          );
          when(() => mockJournalDb.getAllLabelDefinitions()).thenAnswer(
            (_) async => [
              LabelDefinition(
                id: 'lbl-bug',
                createdAt: DateTime(2024),
                updatedAt: DateTime(2024),
                name: 'Bug',
                color: '#FF0000',
                vectorClock: null,
                applicableCategoryIds: const ['cat-001'],
              ),
            ],
          );
          when(() => mockJournalDb.getCategoryById('cat-001')).thenAnswer(
            (_) async => CategoryTestUtils.createTestCategory(
              id: 'cat-001',
              correctionExamples: [
                ChecklistCorrectionExample(
                  before: 'mac OS',
                  after: 'macOS',
                  capturedAt: DateTime(2024, 5, 2),
                ),
              ],
            ),
          );

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          // Label-context branch: available labels injected.
          expect(message, contains('## Available Labels'));
          expect(message, contains('Bug'));
          // Correction-example branch: category examples injected.
          expect(message, contains('## Correction Examples'));
          expect(message, contains('macOS'));
        },
      );

      test(
        'never injects the prior report prose into the user message',
        () async {
          // The report is a projection of the log, not agent memory: re-reading
          // its own stale conclusions creates a feedback loop (a wrong
          // "learning" re-published verbatim every wake). With a report present,
          // neither the prose nor the first-wake bootstrap section appears.
          final report =
              AgentDomainEntity.agentReport(
                    id: 'rpt-1',
                    agentId: agentId,
                    scope: 'current',
                    createdAt: testDate,
                    vectorClock: null,
                    content: '# My Report\nAll good.',
                  )
                  as AgentReportEntity;

          final message = await executeAndCaptureMessage(lastReport: report);

          expect(message, isNotNull);
          expect(message, isNot(contains('## Current Report')));
          expect(message, isNot(contains('# My Report')));
          expect(message, isNot(contains('## First Wake')));
          // The closing instruction states the conditional-report contract.
          expect(message, contains('If the report would materially change'));
        },
      );

      test(
        'includes parent project context with project report tldr and full content',
        () async {
          final message = await executeAndCaptureMessage(
            projectContextJson: jsonEncode({
              'project': {
                'id': 'project-1',
                'title': 'Parent Project',
                'status': 'ACTIVE',
              },
              'latestProjectAgentReport': {
                'tldr': 'Project TLDR',
                'content': '## Project Report\nFull project report body.',
              },
            }),
          );

          expect(message, isNotNull);
          expect(message, contains('## Parent Project Context'));
          expect(message, contains('Parent Project'));
          expect(message, contains('Project TLDR'));
          expect(message, contains('Full project report body.'));
        },
      );

      test(
        'does not include a related-task directory section in the wake context',
        () async {
          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, isNot(contains('## Related Tasks In This Project')));
        },
      );

      test('includes first wake message when no report exists', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('First Wake'));
        expect(message, contains('No prior report exists'));
      });

      test('includes observation text in user message', () async {
        final obs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-1',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 15, 9),
                  vectorClock: null,
                  contentEntryId: 'payload-obs-1',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        final payload = AgentDomainEntity.agentMessagePayload(
          id: 'payload-obs-1',
          agentId: agentId,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          content: <String, Object?>{'text': 'Task needs refactoring'},
        );

        when(
          () => mockAgentRepository.getEntity('payload-obs-1'),
        ).thenAnswer((_) async => payload);

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        expect(message, contains('## Agent Journal'));
        expect(message, contains('Task needs refactoring'));
      });

      test(
        'shows "(no content)" for observation with missing payload',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-2',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 15, 9),
                    vectorClock: null,
                    contentEntryId: 'missing-payload',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          when(
            () => mockAgentRepository.getEntity('missing-payload'),
          ).thenAnswer((_) async => null);

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('(no content)'));
        },
      );

      test(
        'shows "(no content)" for observation with null contentEntryId',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-3',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 15, 9),
                    vectorClock: null,
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('(no content)'));
        },
      );

      test(
        'includes linked tasks and uses linked task-agent report instead of summary',
        () async {
          final linkedReport =
              AgentDomainEntity.agentReport(
                    id: 'linked-report-1',
                    agentId: 'linked-agent-1',
                    scope: 'current',
                    createdAt: DateTime(2024, 6, 14, 8),
                    vectorClock: null,
                    oneLiner: 'Linked task is on track.',
                    tldr: 'Linked task TLDR: integration nearly done.',
                    content: '## Linked Agent Report\nFrom task agent.',
                  )
                  as AgentReportEntity;
          final link = AgentLink.agentTask(
            id: 'link-1',
            fromId: 'linked-agent-1',
            toId: 't2',
            createdAt: DateTime(2024, 6, 14),
            updatedAt: DateTime(2024, 6, 14),
            vectorClock: null,
          );
          when(
            () => mockAgentRepository.getLinksTo('t2', type: 'agent_task'),
          ).thenAnswer((_) async => [link]);
          when(
            () => mockAgentRepository.getLatestReport(
              'linked-agent-1',
              'current',
            ),
          ).thenAnswer((_) async => linkedReport);

          final message = await executeAndCaptureMessage(
            linkedTasksJson:
                '{"linked":[{"id":"t2","title":"Related",'
                '"latestSummary":"Legacy summary"}]}',
          );

          expect(message, isNotNull);
          expect(message, contains('## Linked Tasks'));
          expect(message, contains('Related'));
          expect(message, contains('latestTaskAgentReportTldr'));
          // A resolved report is marked present (graph-5 freshness marker).
          expect(message, contains('"summaryStatus": "present"'));
          // Compact summary is embedded…
          expect(
            message,
            contains('Linked task TLDR: integration nearly done.'),
          );
          expect(message, contains('Linked task is on track.'));
          // …but the full report body is trimmed out to save prefill.
          expect(message, isNot(contains('From task agent.')));
          expect(message, isNot(contains('latestSummary')));
        },
      );

      test(
        'uses link id as deterministic tie-breaker for equal createdAt',
        () async {
          final now = DateTime(2024, 6, 14, 8);
          final linkB = AgentLink.agentTask(
            id: 'link-b',
            fromId: 'linked-agent-b',
            toId: 't2',
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          );
          final linkA = AgentLink.agentTask(
            id: 'link-a',
            fromId: 'linked-agent-a',
            toId: 't2',
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          );
          when(
            () => mockAgentRepository.getLinksTo('t2', type: 'agent_task'),
          ).thenAnswer((_) async => [linkB, linkA]);

          // With descending tie-breaking on ID, 'link-b' sorts before
          // 'link-a' in `orderedPrimaryFirst`, so the workflow picks
          // 'linked-agent-b's report when both exist with non-empty
          // content. Stub both reports; the assertion below verifies
          // that the workflow's deterministic tie-break still picks B.
          final reportB =
              AgentDomainEntity.agentReport(
                    id: 'linked-report-b',
                    agentId: 'linked-agent-b',
                    scope: 'current',
                    createdAt: now,
                    vectorClock: null,
                    tldr: 'Report B summary',
                    content: 'report-b',
                  )
                  as AgentReportEntity;
          final reportA =
              AgentDomainEntity.agentReport(
                    id: 'linked-report-a',
                    agentId: 'linked-agent-a',
                    scope: 'current',
                    createdAt: now,
                    vectorClock: null,
                    tldr: 'Report A summary',
                    content: 'report-a',
                  )
                  as AgentReportEntity;
          when(
            () => mockAgentRepository.getLatestReport(
              'linked-agent-b',
              'current',
            ),
          ).thenAnswer((_) async => reportB);
          when(
            () => mockAgentRepository.getLatestReport(
              'linked-agent-a',
              'current',
            ),
          ).thenAnswer((_) async => reportA);

          final message = await executeAndCaptureMessage(
            linkedTasksJson: '{"linked":[{"id":"t2","title":"Related"}]}',
          );

          // The 2026-05-12 N+1 rewrite moved from a per-link
          // `Future.wait(getLatestReport)` (which short-circuited on
          // the first non-empty report) to a bulk
          // `getLatestReportsByAgentIds` fetch followed by an
          // in-memory walk of the sorted links. Correctness contract
          // is the same — the first link in `orderedPrimaryFirst`
          // order whose report has non-empty content wins. Reports are
          // now embedded as their compact tldr (not the full body), so
          // the tie-break is asserted via the rendered summary:
          // report B's tldr must show up, report A's must NOT.
          expect(message, isNotNull);
          expect(message, contains('Report B summary'));
          expect(message, isNot(contains('Report A summary')));
        },
      );

      test(
        'falls back to empty linked-task context when build throws',
        () async {
          final message = await executeAndCaptureMessage(
            linkedTasksJson:
                '{"linked":[{"id":"t2","title":"Related",'
                '"latestSummary":"Legacy summary"}]}',
            throwOnLinkedContextBuild: true,
          );

          expect(message, isNotNull);
          expect(message, isNot(contains('## Linked Tasks')));
        },
      );

      test('tolerates a failing batch agent_task link lookup', () async {
        // getLinksToMultiple throwing must be caught: the linked-task
        // section still renders (the rows themselves came from the JSON),
        // but no per-task agent report is injected.
        when(
          () => mockAgentRepository.getLinksToMultiple(
            any(),
            type: any(named: 'type'),
          ),
        ).thenThrow(Exception('link batch failed'));

        final message = await executeAndCaptureMessage(
          linkedTasksJson: '{"linked":[{"id":"t2","title":"Related"}]}',
        );

        expect(message, isNotNull);
        // The section renders from the linked rows themselves.
        expect(message, contains('## Linked Tasks'));
        expect(message, contains('Related'));
        // No report enrichment happened because the lookup failed.
        expect(message, isNot(contains('latestTaskAgentReportTldr')));
        // …and the row is marked as having no published report (graph-5),
        // so the model can tell "no report" apart from "no work".
        expect(message, contains('"summaryStatus": "none"'));
      });

      test('tolerates a failing batch agent report lookup', () async {
        // Links resolve, so linkedAgentIds is non-empty and the report
        // batch fetch runs — but getLatestReportsByAgentIds throws. The
        // catch must swallow it: the section renders without a report.
        final link = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'linked-agent-1',
          toId: 't2',
          createdAt: DateTime(2024, 6, 14),
          updatedAt: DateTime(2024, 6, 14),
          vectorClock: null,
        );
        when(
          () => mockAgentRepository.getLinksToMultiple(
            any(),
            type: any(named: 'type'),
          ),
        ).thenAnswer(
          (_) async => {
            't2': [link],
          },
        );
        when(
          () => mockAgentRepository.getLatestReportsByAgentIds(any(), any()),
        ).thenThrow(Exception('report batch failed'));

        final message = await executeAndCaptureMessage(
          linkedTasksJson: '{"linked":[{"id":"t2","title":"Related"}]}',
        );

        expect(message, isNotNull);
        expect(message, contains('## Linked Tasks'));
        expect(message, contains('Related'));
        // The report lookup failed, so no tldr is injected.
        expect(message, isNot(contains('latestTaskAgentReportTldr')));
      });

      test('omits linked tasks section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Linked Tasks')));
      });

      test('omits parent project context section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Parent Project Context')));
      });

      test('omits related tasks section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Related Tasks In This Project')));
      });

      test('includes trigger tokens when non-empty', () async {
        final message = await executeAndCaptureMessage(
          triggerTokens: {'entity-x', 'entity-y'},
        );

        expect(message, isNotNull);
        expect(message, contains('## Changed Since Last Wake'));
        expect(message, contains('entity-x'));
        expect(message, contains('entity-y'));
      });

      test(
        'omits Active Running Timer section when no timer is active',
        () async {
          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, isNot(contains('## Active Running Timer')));
        },
      );

      test(
        'omits Editable Time Entries section when no entries exist',
        () async {
          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, isNot(contains('## Editable Time Entries')));
        },
      );

      test('includes linked JournalEntry rows in Editable Time Entries newest '
          'first', () async {
        final older = makeLinkedTimeEntry(
          id: 'entry-older',
          dateFrom: DateTime(2024, 6, 14, 9),
          dateTo: DateTime(2024, 6, 14, 10),
          text: 'Older workshop notes',
        );
        final newer = makeLinkedTimeEntry(
          id: 'entry-newer',
          dateFrom: DateTime(2024, 6, 15, 13),
          dateTo: DateTime(2024, 6, 15, 14, 30),
          text: 'Newer planning notes',
        );
        when(() => mockJournalDb.getLinkedEntities(taskId)).thenAnswer(
          (_) async => [older, makeWorkflowTestTask('linked-task'), newer],
        );

        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('## Editable Time Entries'));
        expect(message, contains('Only pass an `entryId` listed here'));
        expect(message, contains('id: entry-newer'));
        expect(message, contains('dateFrom: 2024-06-15T13:00:00.000'));
        expect(message, contains('"Newer planning notes"'));
        expect(message, contains('id: entry-older'));
        expect(
          message!.indexOf('id: entry-newer'),
          lessThan(message.indexOf('id: entry-older')),
        );
        expect(message, isNot(contains('id: linked-task')));
      });

      test(
        'lists every linked JournalEntry in Editable Time Entries',
        () async {
          final entries = List.generate(21, (index) {
            final id = index.toString().padLeft(2, '0');
            return makeLinkedTimeEntry(
              id: 'entry-$id',
              dateFrom: DateTime(2024, 6, 15, index),
              dateTo: DateTime(2024, 6, 15, index, 30),
              text: 'Entry $id notes',
            );
          });
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => entries);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect('- id:'.allMatches(message!).length, 21);
          expect(message, contains('id: entry-20'));
          expect(message, contains('id: entry-00'));
          expect(
            message.indexOf('id: entry-20'),
            lessThan(message.indexOf('id: entry-00')),
          );
        },
      );

      test('includes full editable time entry text', () async {
        final longText = 'x' * 205;
        when(() => mockJournalDb.getLinkedEntities(taskId)).thenAnswer(
          (_) async => [
            makeLinkedTimeEntry(
              id: 'entry-long',
              dateFrom: DateTime(2024, 6, 14, 9),
              dateTo: DateTime(2024, 6, 14, 10),
              text: longText,
            ),
          ],
        );

        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('id: entry-long'));
        expect(message, contains(jsonEncode(longText)));
      });

      test(
        'omits Editable Time Entries section when linked entry lookup fails',
        () async {
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenThrow(Exception('linked entries failed'));

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, isNot(contains('## Editable Time Entries')));
        },
      );

      test('includes full Active Running Timer details when timer is for THIS '
          'task', () async {
        final timeService = getIt<TimeService>();
        final task = Task(
          meta: Metadata(
            id: taskId,
            dateFrom: DateTime(2024, 6),
            dateTo: DateTime(2024, 6),
            createdAt: DateTime(2024, 6),
            updatedAt: DateTime(2024, 6),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: taskId,
              createdAt: DateTime(2024, 6),
              utcOffset: 0,
            ),
            dateFrom: DateTime(2024, 6),
            dateTo: DateTime(2024, 6),
            statusHistory: [],
            title: 'Active task',
          ),
        );
        final timerEntry = JournalEntry(
          meta: Metadata(
            id: 'timer-entry-007',
            dateFrom: DateTime(2024, 6, 14, 10),
            dateTo: DateTime(2024, 6, 14, 10, 5),
            createdAt: DateTime(2024, 6, 14, 10),
            updatedAt: DateTime(2024, 6, 14, 10),
          ),
          entryText: const EntryText(plainText: 'wip notes'),
        );
        await timeService.start(timerEntry, task);
        addTearDown(timeService.stop);

        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('## Active Running Timer'));
        expect(message, contains('running for THIS task'));
        expect(message, contains('timerId: timer-entry-007'));
        expect(message, contains('current text: "wip notes"'));
        expect(message, contains('update_running_timer'));
        // The end of the tracked range must be a live "now" timestamp, not
        // the stale `dateTo` carried on the in-memory entity (which
        // [TimeService] only updates on its broadcast stream, not on the
        // entity returned by [getCurrent]). The fixture's stale dateTo
        // (10:05 on a 2024 date) must not leak into the prompt.
        expect(message, isNot(contains('2024-06-14T10:05')));
      });

      test('excludes the active timer from Editable Time Entries', () async {
        final timeService = getIt<TimeService>();
        final task = makeWorkflowTestTask(taskId);
        final running = makeLinkedTimeEntry(
          id: 'running-entry',
          dateFrom: DateTime(2024, 6, 14, 10),
          dateTo: DateTime(2024, 6, 14, 10, 5),
          text: 'active timer text',
        );
        final historical = makeLinkedTimeEntry(
          id: 'historical-entry',
          dateFrom: DateTime(2024, 6, 13, 10),
          dateTo: DateTime(2024, 6, 13, 11),
          text: 'past work',
        );
        await timeService.start(running, task);
        addTearDown(timeService.stop);
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [running, historical]);

        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('## Editable Time Entries'));
        expect(message, contains('id: historical-entry'));
        expect('- id:'.allMatches(message!).length, 1);
      });

      test(
        'exposes only tracked range when timer belongs to a DIFFERENT task',
        () async {
          final timeService = getIt<TimeService>();
          final otherTask = Task(
            meta: Metadata(
              id: 'other-task-id',
              dateFrom: DateTime(2024, 6),
              dateTo: DateTime(2024, 6),
              createdAt: DateTime(2024, 6),
              updatedAt: DateTime(2024, 6),
            ),
            data: TaskData(
              status: TaskStatus.open(
                id: 'other-task-id',
                createdAt: DateTime(2024, 6),
                utcOffset: 0,
              ),
              dateFrom: DateTime(2024, 6),
              dateTo: DateTime(2024, 6),
              statusHistory: [],
              title: 'Other task',
            ),
          );
          final timerEntry = JournalEntry(
            meta: Metadata(
              id: 'other-timer-id',
              dateFrom: DateTime(2024, 6, 14, 9),
              dateTo: DateTime(2024, 6, 14, 9, 30),
              createdAt: DateTime(2024, 6, 14, 9),
              updatedAt: DateTime(2024, 6, 14, 9),
            ),
            entryText: const EntryText(plainText: 'secret notes'),
          );
          await timeService.start(timerEntry, otherTask);
          addTearDown(timeService.stop);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('## Active Running Timer'));
          expect(message, contains('DIFFERENT task'));
          expect(message, contains('tracked elsewhere:'));
          // Detail leakage guards: no other-task identity, no timer id, no
          // entry text, and update_running_timer is unavailable for this
          // wake.
          expect(message, isNot(contains('other-task-id')));
          expect(message, isNot(contains('other-timer-id')));
          expect(message, isNot(contains('secret notes')));
          expect(message, contains('update_running_timer` is NOT available'));
          // The cross-task overlap guard relies on a live tracked-end
          // timestamp; the stale fixture `dateTo` (09:30 on a 2024 date)
          // must not appear in the prompt or the agent could under-report
          // the interval already being tracked elsewhere.
          expect(message, isNot(contains('2024-06-14T09:30')));
        },
      );

      test('omits trigger section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Changed Since Last Wake')));
      });

      test(
        'shows "(no content)" for observation with empty string text payload',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-empty',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 15, 9),
                    vectorClock: null,
                    contentEntryId: 'payload-empty-text',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          final payload = AgentDomainEntity.agentMessagePayload(
            id: 'payload-empty-text',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 15, 9),
            vectorClock: null,
            content: <String, Object?>{'text': ''},
          );

          when(
            () => mockAgentRepository.getEntity('payload-empty-text'),
          ).thenAnswer((_) async => payload);

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('(no content)'));
        },
      );

      test(
        'shows "(no content)" for observation with non-string text payload',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-wrong-type',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 15, 9),
                    vectorClock: null,
                    contentEntryId: 'payload-wrong-type',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          final payload = AgentDomainEntity.agentMessagePayload(
            id: 'payload-wrong-type',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 15, 9),
            vectorClock: null,
            content: <String, Object?>{'text': 42},
          );

          when(
            () => mockAgentRepository.getEntity('payload-wrong-type'),
          ).thenAnswer((_) async => payload);

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('(no content)'));
        },
      );

      test('renders active attention requests into the user message', () async {
        final claim =
            AgentDomainEntity.attentionRequest(
                  id: 'attn-1',
                  agentId: agentId,
                  kind: AttentionRequestKind.task,
                  title: 'Finish tax packet',
                  categoryId: 'work',
                  requestedMinutes: 90,
                  impact: 5,
                  urgency: 4,
                  energyFit: AttentionEnergyFit.high,
                  evidenceRefs: const [
                    AttentionEvidenceRef(
                      kind: AttentionEvidenceKind.task,
                      id: 'task-9',
                      label: 'Tax packet',
                    ),
                  ],
                  scopeKind: AttentionClaimScopeKind.dateRange,
                  earliestStart: DateTime.utc(2026, 5, 25, 9),
                  latestEnd: DateTime.utc(2026, 5, 25, 17),
                  deadline: DateTime.utc(2026, 5, 26, 12),
                  targetId: taskId,
                  targetKind: 'task',
                  rationale: 'Due soon and still needs a focused block.',
                  createdAt: DateTime.utc(2026, 5, 24, 8),
                  vectorClock: null,
                )
                as AttentionRequestEntity;

        final message = await executeAndCaptureMessage(
          attentionClaims: [claim],
        );

        expect(message, isNotNull);
        expect(message, contains('## Attention Requests For This Task'));
        // Guidance lists every field the dedup handler matches on.
        expect(message, contains('amount, impact, urgency, energy fit, scope'));
        expect(message, contains('resolve_attention_request'));
        expect(message, contains('"id": "attn-1"'));
        expect(message, contains('"agentId": "$agentId"'));
        expect(message, contains('"ownedByThisAgent": true'));
        expect(message, contains('"requestedMinutes": 90'));
        expect(message, contains('"energyFit": "high"'));
        expect(message, contains('"scopeKind": "dateRange"'));
        expect(message, contains('"deadline": "2026-05-26T12:00:00.000Z"'));
      });

      test('satisfies own active attention requests for done tasks', () async {
        final now = DateTime(2026, 5, 26, 8);
        final claim =
            AgentDomainEntity.attentionRequest(
                  id: 'attn-done',
                  agentId: agentId,
                  kind: AttentionRequestKind.task,
                  title: 'Finish tax packet',
                  categoryId: 'work',
                  requestedMinutes: 90,
                  impact: 5,
                  urgency: 4,
                  energyFit: AttentionEnergyFit.high,
                  evidenceRefs: const [
                    AttentionEvidenceRef(
                      kind: AttentionEvidenceKind.task,
                      id: 'task-9',
                      label: 'Tax packet',
                    ),
                  ],
                  targetId: taskId,
                  targetKind: 'task',
                  rationale: 'Due soon and still needs a focused block.',
                  createdAt: DateTime.utc(2026, 5, 24, 8),
                  vectorClock: null,
                )
                as AttentionRequestEntity;
        final upserts = <AgentDomainEntity>[];
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((
          invocation,
        ) async {
          upserts.add(
            invocation.positionalArguments.single as AgentDomainEntity,
          );
        });
        when(() => mockJournalDb.journalEntityById(taskId)).thenAnswer(
          (_) async => Task(
            data: TaskData(
              status: TaskStatus.done(
                id: 'status-done',
                createdAt: now,
                utcOffset: 0,
              ),
              title: 'Tax packet',
              statusHistory: const [],
              dateTo: now,
              dateFrom: now,
            ),
            meta: Metadata(
              id: taskId,
              createdAt: now,
              dateFrom: now,
              dateTo: now,
              updatedAt: now,
              categoryId: 'work',
            ),
          ),
        );

        await withClock(Clock.fixed(now), () {
          return executeAndCaptureMessage(attentionClaims: [claim]);
        });

        final dispositions = upserts
            .whereType<AttentionClaimDispositionEntity>()
            .toList(growable: false);
        expect(dispositions, hasLength(1));
        expect(dispositions.single.requestId, 'attn-done');
        expect(dispositions.single.status, AttentionClaimStatus.satisfied);
        expect(dispositions.single.createdAt, now);
      });

      test('absorbs a failure loading attention requests', () async {
        final message = await executeAndCaptureMessage(
          throwOnAttentionLoad: true,
        );

        // The wake still produces a prompt, just without the attention
        // section — the load failure is swallowed.
        expect(message, isNotNull);
        expect(message, isNot(contains('## Attention Requests For This Task')));
      });

      group('proposal ledger', () {
        LedgerEntry openEntry({
          required String toolName,
          required Map<String, dynamic> args,
          required String humanSummary,
          DateTime? createdAt,
        }) {
          return LedgerEntry(
            changeSetId: 'cs-${toolName.hashCode}',
            itemIndex: 0,
            toolName: toolName,
            args: args,
            humanSummary: humanSummary,
            fingerprint: ChangeItem.fingerprintFromParts(toolName, args),
            status: ChangeItemStatus.pending,
            createdAt: createdAt ?? DateTime(2024, 6, 15, 10),
          );
        }

        LedgerEntry resolvedEntry({
          required String toolName,
          required Map<String, dynamic> args,
          required String humanSummary,
          required ChangeItemStatus status,
          required ChangeDecisionVerdict verdict,
          DecisionActor? resolvedBy = DecisionActor.user,
          String? reason,
        }) {
          return LedgerEntry(
            changeSetId: 'cs-${toolName.hashCode}',
            itemIndex: 0,
            toolName: toolName,
            args: args,
            humanSummary: humanSummary,
            fingerprint: ChangeItem.fingerprintFromParts(toolName, args),
            status: status,
            createdAt: DateTime(2024, 6, 15, 10),
            resolvedAt: DateTime(2024, 6, 15, 11),
            resolvedBy: resolvedBy,
            verdict: verdict,
            reason: reason,
          );
        }

        void stubLedger(ProposalLedger ledger) {
          when(
            () => mockAgentRepository.getProposalLedger(
              any(),
              taskId: any(named: 'taskId'),
              changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
              resolvedLimit: any(named: 'resolvedLimit'),
            ),
          ).thenAnswer((_) async => ledger);
        }

        test('renders open proposal details once with fingerprints', () async {
          stubLedger(
            ProposalLedger(
              open: [
                openEntry(
                  toolName: 'set_task_title',
                  args: const {'title': 'New Title'},
                  humanSummary: 'Rename task to "New Title"',
                ),
              ],
              resolved: const [],
            ),
          );

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('## Proposal Ledger'));
          // The unified section replaces the legacy split.
          expect(message, isNot(contains('## Recent User Decisions')));
          expect(message, isNot(contains('## Pending Proposals')));
          final expectedFingerprint = ChangeItem.fingerprintFromParts(
            'set_task_title',
            const {'title': 'New Title'},
          );
          expect(message, contains('[fp=$expectedFingerprint]'));
          expect(message, contains('### Open (1)'));
          expect(message, contains('See `## Open Proposal Guard` below'));
          final renderedOpenEntry =
              '- [fp=$expectedFingerprint] `set_task_title`: '
              'Rename task to "New Title"';
          expect(countOccurrences(message!, renderedOpenEntry), 1);
        });

        test(
          'renders open proposal guard immediately before final instruction',
          () async {
            stubLedger(
              ProposalLedger(
                open: [
                  openEntry(
                    toolName: 'update_checklist_item',
                    args: const {'id': 'item-1', 'isChecked': true},
                    humanSummary: 'Check off: "Address review comments"',
                  ),
                ],
                resolved: const [],
              ),
            );

            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, contains('## Open Proposal Guard'));
            expect(
              message,
              contains(
                'Do not propose the same user-facing action again '
                '(for `update_running_timer`, compare per `timerId`).',
              ),
            );
            expect(
              message,
              contains('for `update_running_timer`, compare per `timerId`'),
            );
            expect(
              message,
              contains(
                '`update_checklist_item`: '
                'Check off: "Address review comments"',
              ),
            );

            const guardHeader = '## Open Proposal Guard';
            const finalInstruction =
                'Analyze the current state, maintain any attention requests, '
                'and call tools if needed.';
            final guardIndex = message!.indexOf(guardHeader);
            final finalInstructionIndex = message.indexOf(finalInstruction);
            expect(guardIndex, greaterThanOrEqualTo(0));
            expect(finalInstructionIndex, greaterThan(guardIndex));
            final expectedFingerprint = ChangeItem.fingerprintFromParts(
              'update_checklist_item',
              const {'id': 'item-1', 'isChecked': true},
            );
            final guardEntry =
                '- [fp=$expectedFingerprint] `update_checklist_item`: '
                'Check off: "Address review comments"';
            expect(countOccurrences(message, guardEntry), 1);
            final guardEntryIndex = message.indexOf(guardEntry, guardIndex);
            expect(guardEntryIndex, greaterThan(guardIndex));
            expect(finalInstructionIndex, greaterThan(guardEntryIndex));
            expect(
              message
                  .substring(
                    guardEntryIndex + guardEntry.length,
                    finalInstructionIndex,
                  )
                  .trim(),
              isEmpty,
            );
          },
        );

        test(
          'omits the Proposal Ledger section when the ledger is empty',
          () async {
            // Default stub is an empty ledger; do not override.
            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, isNot(contains('## Proposal Ledger')));
            expect(message, isNot(contains('## Open Proposal Guard')));
          },
        );

        test(
          'renders resolved entries with verdict icon, actor, and reason',
          () async {
            stubLedger(
              ProposalLedger(
                open: const [],
                resolved: [
                  resolvedEntry(
                    toolName: 'set_task_title',
                    args: const {'title': 'Done'},
                    humanSummary: 'Rename task to "Done"',
                    status: ChangeItemStatus.confirmed,
                    verdict: ChangeDecisionVerdict.confirmed,
                  ),
                  resolvedEntry(
                    toolName: 'update_task_estimate',
                    args: const {'estimate': '2h'},
                    humanSummary: 'Set estimate to 2 hours',
                    status: ChangeItemStatus.rejected,
                    verdict: ChangeDecisionVerdict.rejected,
                    reason: 'Too high',
                  ),
                  resolvedEntry(
                    toolName: 'update_task_priority',
                    args: const {'priority': 'P1'},
                    humanSummary: 'Set priority to P1',
                    status: ChangeItemStatus.retracted,
                    verdict: ChangeDecisionVerdict.retracted,
                    resolvedBy: DecisionActor.agent,
                    reason: 'Already P1',
                  ),
                ],
              ),
            );

            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, contains('### Resolved (3, most recent)'));
            // Confirmed by user
            expect(message, contains('\u2713 `set_task_title`'));
            expect(message, contains('by user'));
            // Rejected with reason
            expect(message, contains('\u2717 `update_task_estimate`'));
            expect(message, contains('(reason: "Too high")'));
            // Retracted by agent with its own reason
            expect(message, contains('\u21ba `update_task_priority`'));
            expect(message, contains('by agent'));
            expect(message, contains('(reason: "Already P1")'));
          },
        );

        test('renders resolved entry with null verdict/actor using status '
            'fallback and circle icon', () async {
          // A resolved entry with no verdict and no actor: the formatter
          // must fall back to the status name for the label, the ○ circle
          // icon for the missing verdict, and an empty actor suffix (no
          // " by user"/" by agent").
          stubLedger(
            ProposalLedger(
              open: const [],
              resolved: [
                LedgerEntry(
                  changeSetId: 'cs-stale',
                  itemIndex: 0,
                  toolName: 'set_task_title',
                  args: const {'title': 'Stale'},
                  humanSummary: 'Rename task to "Stale"',
                  fingerprint: ChangeItem.fingerprintFromParts(
                    'set_task_title',
                    const {'title': 'Stale'},
                  ),
                  status: ChangeItemStatus.deferred,
                  createdAt: DateTime(2024, 6, 15, 10),
                  resolvedAt: DateTime(2024, 6, 15, 11),
                  // verdict and resolvedBy intentionally left null.
                ),
              ],
            ),
          );

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('### Resolved (1, most recent)'));
          // Circle icon for the null verdict branch.
          expect(message, contains('○ `set_task_title`'));
          // Verdict label falls back to the status name.
          expect(message, contains('— deferred'));
          // No actor suffix is appended for a null resolvedBy.
          expect(message, isNot(contains('deferred by user')));
          expect(message, isNot(contains('deferred by agent')));
        });

        test('renders both open and resolved groups side by side', () async {
          stubLedger(
            ProposalLedger(
              open: [
                openEntry(
                  toolName: 'add_checklist_item',
                  args: const {'text': 'Still waiting'},
                  humanSummary: 'Add checklist item: "Still waiting"',
                ),
              ],
              resolved: [
                resolvedEntry(
                  toolName: 'set_task_title',
                  args: const {'title': 'Already Done'},
                  humanSummary: 'Rename task to "Already Done"',
                  status: ChangeItemStatus.confirmed,
                  verdict: ChangeDecisionVerdict.confirmed,
                ),
              ],
            ),
          );

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('### Open (1)'));
          expect(message, contains('Add checklist item: "Still waiting"'));
          expect(message, contains('### Resolved (1, most recent)'));
          expect(message, contains('Rename task to "Already Done"'));
        });

        test(
          'Open group shows "(none)" when there are no open entries',
          () async {
            stubLedger(
              ProposalLedger(
                open: const [],
                resolved: [
                  resolvedEntry(
                    toolName: 'set_task_title',
                    args: const {'title': 'x'},
                    humanSummary: 'Rename task',
                    status: ChangeItemStatus.confirmed,
                    verdict: ChangeDecisionVerdict.confirmed,
                  ),
                ],
              ),
            );

            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, contains('### Open (0)'));
            expect(message, contains('- (none)'));
          },
        );
      });

      test('caps observations to 20 most recent', () async {
        // Create 25 observations ordered newest-first (as the DB returns).
        final observations = List.generate(25, (i) {
          // Index 0 = newest (hour 24), index 24 = oldest (hour 0).
          final hour = 24 - i;
          return AgentDomainEntity.agentMessage(
                id: 'obs-$hour',
                agentId: agentId,
                threadId: threadId,
                kind: AgentMessageKind.observation,
                createdAt: DateTime(2024, 6, 15, hour),
                vectorClock: null,
                contentEntryId: 'pay-$hour',
                metadata: const AgentMessageMetadata(runKey: runKey),
              )
              as AgentMessageEntity;
        });

        // Stub all payloads.
        for (var i = 0; i < 25; i++) {
          when(() => mockAgentRepository.getEntity('pay-$i')).thenAnswer((
            _,
          ) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-$i',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 15, i),
              vectorClock: null,
              content: <String, Object?>{'text': 'Obs $i'},
            );
          });
        }

        final message = await executeAndCaptureMessage(
          observations: observations,
        );

        expect(message, isNotNull);
        // The 20 most recent (hours 5-24) should appear; oldest 5 dropped.
        expect(message, contains('Obs 5'));
        expect(message, contains('Obs 24'));
        // Oldest observations (hours 0-4) should NOT appear.
        expect(message, isNot(contains('Obs 0')));
        expect(message, isNot(contains('Obs 4')));
      });

      test('includes prior critical observations section '
          'with grievances and excellence', () async {
        final grievanceObs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-grievance',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 8),
                  vectorClock: null,
                  contentEntryId: 'pay-grievance',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        final excellenceObs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-excellence',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 9),
                  vectorClock: null,
                  contentEntryId: 'pay-excellence',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        final routineObs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-routine',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 10),
                  vectorClock: null,
                  contentEntryId: 'pay-routine',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        when(() => mockAgentRepository.getEntity('pay-grievance')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-grievance',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 8),
            vectorClock: null,
            content: <String, Object?>{
              'text': 'User frustrated with wrong priority',
              'priority': 'critical',
              'category': 'grievance',
            },
          );
        });

        when(() => mockAgentRepository.getEntity('pay-excellence')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-excellence',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 9),
            vectorClock: null,
            content: <String, Object?>{
              'text': 'User praised report quality',
              'priority': 'critical',
              'category': 'excellence',
            },
          );
        });

        when(() => mockAgentRepository.getEntity('pay-routine')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-routine',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 10),
            vectorClock: null,
            content: <String, Object?>{
              'text': 'Routine observation note',
              'priority': 'routine',
              'category': 'operational',
            },
          );
        });

        final message = await executeAndCaptureMessage(
          observations: [grievanceObs, excellenceObs, routineObs],
        );

        expect(message, isNotNull);
        // Critical section should appear.
        expect(
          message,
          contains('## Prior Critical Observations (Self-Review)'),
        );
        expect(message, contains('### Grievances'));
        expect(message, contains('User frustrated with wrong priority'));
        expect(message, contains('### Excellence (keep doing this)'));
        expect(message, contains('User praised report quality'));
        // Routine observation should NOT appear in critical section.
        final criticalSection = message!.substring(
          message.indexOf('## Prior Critical Observations'),
          message.indexOf('## Agent Journal'),
        );
        expect(criticalSection, isNot(contains('Routine observation note')));
        // But routine observation should appear in the journal.
        expect(message, contains('## Agent Journal'));
        expect(message, contains('Routine observation note'));
      });

      test(
        'omits critical section when no critical observations exist',
        () async {
          final routineObs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-routine',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 14, 10),
                    vectorClock: null,
                    contentEntryId: 'pay-routine',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          when(() => mockAgentRepository.getEntity('pay-routine')).thenAnswer((
            _,
          ) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-routine',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 14, 10),
              vectorClock: null,
              content: <String, Object?>{
                'text': 'Just a routine note',
                'priority': 'routine',
                'category': 'operational',
              },
            );
          });

          final message = await executeAndCaptureMessage(
            observations: [routineObs],
          );

          expect(message, isNotNull);
          expect(message, isNot(contains('Prior Critical Observations')));
          expect(message, contains('## Agent Journal'));
          expect(message, contains('Just a routine note'));
        },
      );

      test('critical section appears before Agent Journal '
          'in message order', () async {
        final critObs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-crit',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 8),
                  vectorClock: null,
                  contentEntryId: 'pay-crit',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        when(() => mockAgentRepository.getEntity('pay-crit')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-crit',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 8),
            vectorClock: null,
            content: <String, Object?>{
              'text': 'Critical grievance item',
              'priority': 'critical',
              'category': 'grievance',
            },
          );
        });

        final message = await executeAndCaptureMessage(observations: [critObs]);

        expect(message, isNotNull);
        final criticalIdx = message!.indexOf('Prior Critical Observations');
        final journalIdx = message.indexOf('## Agent Journal');
        expect(criticalIdx, lessThan(journalIdx));
      });

      test('handles payload resolution errors gracefully '
          'in critical observation filtering', () async {
        final obs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-err',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 8),
                  vectorClock: null,
                  contentEntryId: 'pay-err',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        when(
          () => mockAgentRepository.getEntity('pay-err'),
        ).thenThrow(Exception('DB error'));

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        // Should not crash; observation renders with fallback text.
        expect(message, contains('## Agent Journal'));
        expect(message, contains('(no content)'));
        // No critical section since payload resolution failed.
        expect(message, isNot(contains('Prior Critical Observations')));
      });

      test(
        'treats template_improvement as grievance in critical section',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-tmpl',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 14, 8),
                    vectorClock: null,
                    contentEntryId: 'pay-tmpl',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          when(() => mockAgentRepository.getEntity('pay-tmpl')).thenAnswer((
            _,
          ) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-tmpl',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 14, 8),
              vectorClock: null,
              content: <String, Object?>{
                'text': 'User wants different behavior',
                'priority': 'critical',
                'category': 'template_improvement',
              },
            );
          });

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('### Grievances'));
          expect(message, contains('User wants different behavior'));
          // Should not appear in excellence.
          expect(message, isNot(contains('### Excellence')));
        },
      );

      test('skips critical observations with empty text', () async {
        final obs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-empty',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 8),
                  vectorClock: null,
                  contentEntryId: 'pay-empty',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        when(() => mockAgentRepository.getEntity('pay-empty')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-empty',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 8),
            vectorClock: null,
            content: <String, Object?>{
              'text': '',
              'priority': 'critical',
              'category': 'grievance',
            },
          );
        });

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        // Empty text should be skipped from critical section.
        expect(message, isNot(contains('Prior Critical Observations')));
      });

      test('includes all observations when count is exactly 20', () async {
        // Create exactly 20 observations ordered newest-first.
        final observations = List.generate(20, (i) {
          final hour =
              19 - i; // Index 0 = newest (hour 19), index 19 = oldest (hour 0).
          return AgentDomainEntity.agentMessage(
                id: 'obs-exact-$hour',
                agentId: agentId,
                threadId: threadId,
                kind: AgentMessageKind.observation,
                createdAt: DateTime(2024, 6, 15, hour),
                vectorClock: null,
                contentEntryId: 'pay-exact-$hour',
                metadata: const AgentMessageMetadata(runKey: runKey),
              )
              as AgentMessageEntity;
        });

        // Stub all 20 payloads.
        for (var i = 0; i < 20; i++) {
          when(() => mockAgentRepository.getEntity('pay-exact-$i')).thenAnswer((
            _,
          ) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-exact-$i',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 15, i),
              vectorClock: null,
              content: <String, Object?>{'text': 'ExactObs $i'},
            );
          });
        }

        final message = await executeAndCaptureMessage(
          observations: observations,
        );

        expect(message, isNotNull);
        // All 20 observations should appear — none truncated.
        expect(message, contains('ExactObs 0'));
        expect(message, contains('ExactObs 19'));
        expect(message, contains('## Agent Journal'));
      });

      test('truncates observations to 20 when count is 21', () async {
        // Create 21 observations ordered newest-first.
        final observations = List.generate(21, (i) {
          final hour =
              20 - i; // Index 0 = newest (hour 20), index 20 = oldest (hour 0).
          return AgentDomainEntity.agentMessage(
                id: 'obs-boundary-$hour',
                agentId: agentId,
                threadId: threadId,
                kind: AgentMessageKind.observation,
                createdAt: DateTime(2024, 6, 15, hour),
                vectorClock: null,
                contentEntryId: 'pay-boundary-$hour',
                metadata: const AgentMessageMetadata(runKey: runKey),
              )
              as AgentMessageEntity;
        });

        // Stub all 21 payloads.
        for (var i = 0; i <= 20; i++) {
          when(
            () => mockAgentRepository.getEntity('pay-boundary-$i'),
          ).thenAnswer((_) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-boundary-$i',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 15, i),
              vectorClock: null,
              content: <String, Object?>{'text': 'BoundaryObs $i'},
            );
          });
        }

        final message = await executeAndCaptureMessage(
          observations: observations,
        );

        expect(message, isNotNull);
        // The 20 most recent (hours 1-20) should appear.
        expect(message, contains('BoundaryObs 1'));
        expect(message, contains('BoundaryObs 20'));
        // The single oldest observation (hour 0) should be truncated.
        expect(message, isNot(contains('BoundaryObs 0')));
      });

      test('filters linked tasks with null or empty IDs gracefully', () async {
        // Provide linked tasks JSON where some entries have no 'id' or an
        // empty string 'id'. The production code (lines 1333-1337) filters
        // these out via whereType<String>().where(id.isNotEmpty).
        final linkedJson = jsonEncode({
          'linked_from': [
            {'id': '', 'title': 'Empty ID Task', 'status': 'OPEN'},
            {'title': 'Null ID Task', 'status': 'OPEN'},
            {'id': 'valid-1', 'title': 'Valid Task', 'status': 'OPEN'},
          ],
          'linked_to': <Map<String, dynamic>>[],
        });
        final message = await executeAndCaptureMessage(
          linkedTasksJson: linkedJson,
        );

        expect(message, isNotNull);
        // The section should still appear because there is one valid linked task.
        expect(message, contains('## Linked Tasks'));
        expect(message, contains('Valid Task'));
        // Entries with missing/empty IDs should not cause errors — the message
        // should still include the rows (they're serialized), but no report
        // enrichment happens for them.
        expect(message, contains('Empty ID Task'));
        expect(message, contains('Null ID Task'));
        // No taskAgentId should have been injected for entries without valid IDs.
        // Valid ID entry also won't have a report since getLinksTo returns [].
        verifyNever(
          () => mockAgentRepository.getLinksTo('', type: 'agent_task'),
        );
      });
    });
  });
}
