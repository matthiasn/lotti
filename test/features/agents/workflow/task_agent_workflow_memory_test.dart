import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'task_agent_workflow_test_helpers.dart';

void main() {
  late MockAgentRepository mockAgentRepository;
  late MockAgentSyncService mockSyncService;
  late MockConversationRepository mockConversationRepository;
  late MockAiInputRepository mockAiInputRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockJournalDb mockJournalDb;
  late MockCloudInferenceRepository mockCloudInferenceRepository;
  late MockConversationManager mockConversationManager;
  late MockJournalRepository mockJournalRepository;
  late MockChecklistRepository mockChecklistRepository;
  late MockLabelsRepository mockLabelsRepository;
  late MockAgentTemplateService mockTemplateService;
  late TaskAgentWorkflow workflow;

  const agentId = taskAgentTestAgentId;
  const taskId = taskAgentTestTaskId;
  const runKey = taskAgentTestRunKey;
  const threadId = taskAgentTestThreadId;
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
    mockCloudInferenceRepository = bench.mockCloudInferenceRepository;
    mockConversationManager = bench.mockConversationManager;
    mockJournalRepository = bench.mockJournalRepository;
    mockChecklistRepository = bench.mockChecklistRepository;
    mockLabelsRepository = bench.mockLabelsRepository;
    mockTemplateService = bench.mockTemplateService;
    workflow = bench.workflow;
  });

  group('TaskAgentWorkflow', () {
    group('input capture (ADR 0020)', () {
      test(
        'captures the rendered task sources when a capture service is wired',
        () async {
          final capture = RecordingCaptureService();
          final linkedEntry = makeLinkedTimeEntry(
            id: 'linked-1',
            dateFrom: DateTime(2024, 6),
            dateTo: DateTime(2024, 6),
            text: 'a captured note',
          );
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => [linkedEntry]);

          final workflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: mockConversationRepository,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
            inputCaptureService: capture,
          );
          stubFullExecutePath(
            mockAgentRepository: mockAgentRepository,
            mockAiInputRepository: mockAiInputRepository,
            mockAiConfigRepository: mockAiConfigRepository,
            mockConversationManager: mockConversationManager,
            testAgentState: testAgentState,
            geminiModel: geminiModel,
            geminiProvider: geminiProvider,
            agentId: agentId,
            taskId: taskId,
          );

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(capture.callCount, 1);
          expect(capture.agentId, agentId);
          expect(capture.threadId, threadId);
          expect(capture.runKey, runKey);
          // The workflow rendered the linked journal entry into a source.
          expect(capture.sources.map((s) => s.contentEntryId), ['linked-1']);
          expect(capture.sources.single.content['text'], 'a captured note');
        },
      );

      test(
        'a capture failure is non-fatal — the wake still succeeds',
        () async {
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => const []);
          final workflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: mockConversationRepository,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
            inputCaptureService: ThrowingCaptureService(),
          );
          stubFullExecutePath(
            mockAgentRepository: mockAgentRepository,
            mockAiInputRepository: mockAiInputRepository,
            mockAiConfigRepository: mockAiConfigRepository,
            mockConversationManager: mockConversationManager,
            testAgentState: testAgentState,
            geminiModel: geminiModel,
            geminiProvider: geminiProvider,
            agentId: agentId,
            taskId: taskId,
          );

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {},
            threadId: threadId,
          );

          expect(result.success, isTrue);
        },
      );

      test(
        'a source rendering failure is non-fatal before capture starts',
        () async {
          final capture = RecordingCaptureService();
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenThrow(Exception('linked entities unavailable'));
          final workflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: mockConversationRepository,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
            inputCaptureService: capture,
          );
          stubFullExecutePath(
            mockAgentRepository: mockAgentRepository,
            mockAiInputRepository: mockAiInputRepository,
            mockAiConfigRepository: mockAiConfigRepository,
            mockConversationManager: mockConversationManager,
            testAgentState: testAgentState,
            geminiModel: geminiModel,
            geminiProvider: geminiProvider,
            agentId: agentId,
            taskId: taskId,
          );

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(capture.callCount, 0);
        },
      );
    });

    group('compaction read-flip (ADR 0017/0020)', () {
      test('assembles the task log from the captured frontier and drops the '
          'inline journal log', () async {
        // The captured frontier holds one source; with no summary yet it is
        // the verbatim tail.
        const tailContent = {
          'entryType': 'text',
          'text': 'captured tail content',
        };
        final tailDigest = ContentDigest.of(tailContent);

        when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
          (_) async => [
            AgentLink.messagePayload(
              id: 'pl-1',
              fromId: agentId,
              toId: tailDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime(2024, 6),
            ),
          ],
        );
        when(() => mockAgentRepository.getEntity(tailDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: tailDigest,
            agentId: agentId,
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: tailContent,
          ),
        );
        when(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).thenAnswer((_) async => '- Title: Slim header');
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        final workflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: mockConversationRepository,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          // A succeeding capture service so the read-flip trusts the frontier.
          inputCaptureService: RecordingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final sentMessages = <String>[];
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
              sentMessages.add(message);
              return null;
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        verify(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).called(1);

        // The SENT prompt carries the slim header + the assembled task log
        // (the captured tail) — proving the read-flip.
        final userText = sentMessages.first;
        expect(userText, contains('Slim header'));
        expect(userText, contains('## Task Log'));
        expect(userText, contains('captured tail content'));
        // Prefix-cache layout: the append-only task log must precede the
        // task-state JSON, whose timeSpent ticks on every working wake — a
        // single mutated byte upstream voids the cache for the whole log.
        expect(
          userText.indexOf('## Task Log'),
          lessThan(userText.indexOf('## Current Task Context')),
        );

        // The PERSISTED prompt is a v2 record: only the non-derivable
        // halves are stored — the log block itself is reconstructed from
        // the synced event log via the marker (ADR 0020).
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final record = capturedPayloadEntities(
          captured,
        ).map((p) => p.content).firstWhere((c) => c['promptFormat'] == 'v2');
        expect(record['head'], endsWith('## Task Log\n'));
        expect(record['tail']! as String, contains('## Current Task Context'));
        expect(record['head'], isNot(contains('captured tail content')));
        expect(record['tail'], isNot(contains('captured tail content')));
        final marker = record['log']! as Map<String, Object?>;
        expect(marker['until'], isNotNull);
      });

      test('falls back to the inline log when nothing is captured yet', () async {
        // Compaction on, but the captured frontier is empty (capture unwired or
        // failed) — the wake must keep the full journal log, not a blank header.
        when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        final workflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: mockConversationRepository,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          logSummarizer: stubLogSummarizer(),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        // Full inline log requested; the markdown task-state variant is NOT
        // used when there's nothing to replace the inline log with.
        verify(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).called(1);
        verifyNever(() => mockAiInputRepository.buildTaskStateMarkdown(taskId));
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final userText = capturedPayloadEntities(captured)
            .map((p) => p.content['text'] as String? ?? '')
            .firstWhere((t) => t.contains('Current Task Context'));
        expect(userText, isNot(contains('## Task Log')));
      });

      test('a capture failure falls back to the inline log even if a stale '
          'frontier exists', () async {
        // A non-empty captured frontier exists from a prior wake, but THIS
        // wake's capture throws — so the frontier may be stale and must not be
        // used; the wake keeps the full inline log.
        const tailContent = {
          'entryType': 'text',
          'text': 'stale captured content',
        };
        final tailDigest = ContentDigest.of(tailContent);
        when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
          (_) async => [
            AgentLink.messagePayload(
              id: 'pl-1',
              fromId: agentId,
              toId: tailDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime(2024, 6),
            ),
          ],
        );
        when(() => mockAgentRepository.getEntity(tailDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: tailDigest,
            agentId: 'shared-input-content',
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: tailContent,
          ),
        );
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        final workflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: mockConversationRepository,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          inputCaptureService: ThrowingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        verify(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).called(1);
        verifyNever(() => mockAiInputRepository.buildTaskStateMarkdown(taskId));
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final userText = capturedPayloadEntities(captured)
            .map((p) => p.content['text'] as String? ?? '')
            .firstWhere((t) => t.contains('Current Task Context'));
        expect(userText, isNot(contains('stale captured content')));
        expect(userText, isNot(contains('## Task Log')));
      });

      test('a failing summarizer is non-fatal: the wake still read-flips to the '
          'uncovered tail', () async {
        // budget 0 + two captured sources ⇒ compaction tries to fold the oldest
        // and calls the summarizer, which throws. Emission must be swallowed and
        // the wake must still assemble the captured (un-summarized) tail.
        const olderContent = {'entryType': 'text', 'text': 'older entry'};
        const newerContent = {'entryType': 'text', 'text': 'newer entry'};
        final olderDigest = ContentDigest.of(olderContent);
        final newerDigest = ContentDigest.of(newerContent);

        when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
          (_) async => [
            AgentLink.messagePayload(
              id: 'pl-1',
              fromId: agentId,
              toId: olderDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime(2024, 6),
            ),
            AgentLink.messagePayload(
              id: 'pl-2',
              fromId: agentId,
              toId: newerDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e2',
              sourceCreatedAt: DateTime(2024, 6, 2),
            ),
          ],
        );
        when(() => mockAgentRepository.getEntity(olderDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: olderDigest,
            agentId: 'shared-input-content',
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: olderContent,
          ),
        );
        when(() => mockAgentRepository.getEntity(newerDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: newerDigest,
            agentId: 'shared-input-content',
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: newerContent,
          ),
        );
        when(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).thenAnswer((_) async => '- Title: Slim header');
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        final boomSummarizer = stubLogSummarizer(
          error: StateError('summarizer boom'),
        );
        final workflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: mockConversationRepository,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          inputCaptureService: RecordingCaptureService(),
          compactionTailBudgetTokens: 0,
          logSummarizer: boomSummarizer,
        );

        final sentMessages = <String>[];
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
              sentMessages.add(message);
              return null;
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        // The wake completes despite the summarizer throwing, and no summary was
        // persisted — so the assembled tail still carries both sources verbatim.
        expect(result.success, isTrue);
        // The summarizer was invoked with the wake's resolved provider — the
        // agent distills its own memory with the model it thinks with.
        verify(
          () => boomSummarizer.summarize(
            sources: any(named: 'sources'),
            priorSummary: any(named: 'priorSummary'),
            model: any(named: 'model'),
            provider: geminiProvider,
          ),
        ).called(1);
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(
          captured.whereType<AgentMessageEntity>().where(
            (m) => m.kind == AgentMessageKind.summary,
          ),
          isEmpty,
        );
        expect(sentMessages.first, contains('older entry'));
        expect(sentMessages.first, contains('newer entry'));
        expect(
          sentMessages.first,
          isNot(contains('Summary of earlier activity')),
        );
      });

      test('resolved verdicts render as decision events in the task log; '
          'open proposal details render only in the guard', () async {
        const tailContent = {'entryType': 'text', 'text': 'captured note'};
        final tailDigest = ContentDigest.of(tailContent);
        when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
          (_) async => [
            AgentLink.messagePayload(
              id: 'pl-1',
              fromId: agentId,
              toId: tailDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime(2024, 6),
            ),
          ],
        );
        when(() => mockAgentRepository.getEntity(tailDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: tailDigest,
            agentId: agentId,
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: tailContent,
          ),
        );
        when(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).thenAnswer((_) async => '- Title: Slim header');
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );
        // One open proposal (state — must stay in the guard) and one
        // resolved verdict (event — must move into the task log).
        when(
          () => mockAgentRepository.getProposalLedger(
            any(),
            taskId: any(named: 'taskId'),
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer(
          (_) async => ProposalLedger(
            open: [
              LedgerEntry(
                changeSetId: 'cs-2',
                itemIndex: 0,
                toolName: 'update_task_estimate',
                args: const {},
                humanSummary: 'Estimate 2h',
                fingerprint: 'update_task_estimate:7',
                status: ChangeItemStatus.pending,
                createdAt: DateTime(2024, 6, 3),
              ),
            ],
            resolved: [
              LedgerEntry(
                changeSetId: 'cs-1',
                itemIndex: 0,
                toolName: 'set_task_title',
                args: const {},
                humanSummary: 'Set title to "X"',
                fingerprint: 'set_task_title:42',
                status: ChangeItemStatus.confirmed,
                createdAt: DateTime(2024, 6),
                resolvedAt: DateTime(2024, 6, 1, 12),
                resolvedBy: DecisionActor.user,
                verdict: ChangeDecisionVerdict.confirmed,
              ),
            ],
          ),
        );

        final workflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: mockConversationRepository,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          inputCaptureService: RecordingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final sentMessages = <String>[];
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
              sentMessages.add(message);
              return null;
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );
        expect(result.success, isTrue);

        final userText = sentMessages.first;

        // The verdict is an event in the task log…
        expect(userText, contains('## Task Log'));
        expect(
          userText,
          contains(
            '(id: cs-1:0, decision) [fp=set_task_title:42] '
            '✓ `set_task_title`: '
            'Set title to "X" — confirmed by user',
          ),
        );
        // …interleaved chronologically: verdict (June 1) before note (June 2).
        expect(
          userText.indexOf('(id: cs-1:0, decision)'),
          lessThan(userText.indexOf('captured note')),
        );
        // The guard carries the open (actionable) state once; compacted
        // prompts do not duplicate it through a separate Proposal Ledger.
        expect(userText, isNot(contains('## Proposal Ledger')));
        expect(userText, contains('## Open Proposal Guard'));
        expect(userText, contains('[fp=update_task_estimate:7]'));
        expect(countOccurrences(userText, '[fp=update_task_estimate:7]'), 1);
        expect(userText, isNot(contains('### Resolved')));
      });

      test('a throwing assembleContext degrades to the legacy inline log '
          'instead of killing the wake', () async {
        when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
        // The compactor's projection read throws (both maybeCompact and
        // assembleContext hit this; each is independently caught).
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer(
          (_) => Future<List<AgentMessageEntity>>.error(
            Exception('projection read failed'),
          ),
        );
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        final workflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: mockConversationRepository,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          inputCaptureService: RecordingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        verify(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).called(1);
        verifyNever(() => mockAiInputRepository.buildTaskStateMarkdown(taskId));
      });

      test('a saturated resolved-decision window logs loudly and the wake '
          'still renders the full legacy ledger', () async {
        final saturated = ProposalLedger(
          open: const [],
          resolved: List.generate(
            TaskAgentWorkflow.resolvedDecisionWindow,
            (i) => LedgerEntry(
              changeSetId: 'cs-$i',
              itemIndex: 0,
              toolName: 'set_task_title',
              args: const {},
              humanSummary: 'Proposal $i',
              fingerprint: 'set_task_title:$i',
              status: ChangeItemStatus.confirmed,
              createdAt: DateTime(2024, 6),
              resolvedAt: DateTime(2024, 6, 1, 12),
              resolvedBy: DecisionActor.user,
              verdict: ChangeDecisionVerdict.confirmed,
            ),
          ),
        );
        when(
          () => mockAgentRepository.getProposalLedger(
            any(),
            taskId: any(named: 'taskId'),
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer((_) async => saturated);
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        // Legacy mode renders the full resolved listing — proving the
        // saturated ledger flowed through unharmed.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final userText = capturedPayloadEntities(captured)
            .map((p) => p.content['text'] as String? ?? '')
            .firstWhere((t) => t.contains('Current Task Context'));
        expect(
          userText,
          contains(
            '### Resolved (${TaskAgentWorkflow.resolvedDecisionWindow}, '
            'most recent)',
          ),
        );
      });

      test('the full prompt is append-only across wakes: identical bytes '
          'before the task log, appends inside it', () async {
        // The provider prefix-cache invariant at the PROMPT level: when a new
        // event lands between two wakes, everything upstream of the task log
        // is byte-identical and the log block itself only grows at the end.
        // The volatile tail (task state, timer, ledger…) follows the log.
        const firstContent = {'entryType': 'text', 'text': 'first note'};
        const secondContent = {'entryType': 'text', 'text': 'second note'};
        final firstDigest = ContentDigest.of(firstContent);
        final secondDigest = ContentDigest.of(secondContent);

        when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        final links = <AgentLink>[
          AgentLink.messagePayload(
            id: 'pl-1',
            fromId: agentId,
            toId: firstDigest,
            createdAt: DateTime(2024, 6, 2),
            updatedAt: DateTime(2024, 6, 2),
            vectorClock: null,
            contentEntryId: 'e1',
            sourceCreatedAt: DateTime(2024, 6),
          ),
        ];
        when(
          () => mockAgentRepository.getLinksFrom(agentId),
        ).thenAnswer((_) async => List.of(links));
        when(() => mockAgentRepository.getEntity(firstDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: firstDigest,
            agentId: agentId,
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: firstContent,
          ),
        );
        when(() => mockAgentRepository.getEntity(secondDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: secondDigest,
            agentId: agentId,
            createdAt: DateTime(2024, 6, 3),
            vectorClock: null,
            content: secondContent,
          ),
        );
        when(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).thenAnswer((_) async => '- Title: Slim header');
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        final workflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: mockConversationRepository,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          inputCaptureService: RecordingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final sentMessages = <String>[];
        // Each wake sends the prompt plus a forced-report retry.
        mockConversationRepository
          ..maxDelegateCalls = 4
          ..sendMessageDelegate =
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
                sentMessages.add(message);
                return null;
              };

        final firstResult = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );
        expect(firstResult.success, isTrue);
        // Filter out forced-report retry messages — only wake prompts.
        String lastPrompt() =>
            sentMessages.lastWhere((m) => m.contains('## Task Log'));
        final firstPrompt = lastPrompt();

        // A new event lands between the wakes.
        links.add(
          AgentLink.messagePayload(
            id: 'pl-2',
            fromId: agentId,
            toId: secondDigest,
            createdAt: DateTime(2024, 6, 3),
            updatedAt: DateTime(2024, 6, 3),
            vectorClock: null,
            contentEntryId: 'e2',
            sourceCreatedAt: DateTime(2024, 6, 3),
          ),
        );

        final secondResult = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: 'run-key-2',
          triggerTokens: {},
          threadId: threadId,
        );
        expect(secondResult.success, isTrue);
        final secondPrompt = lastPrompt();

        // Everything before the task log is byte-identical across the wakes…
        String head(String s) => s.substring(0, s.indexOf('## Task Log'));
        expect(head(secondPrompt), head(firstPrompt));
        // …and the log block itself only appends (modulo the trailing section
        // separator).
        String logBlock(String s) => s
            .substring(
              s.indexOf('## Task Log'),
              s.indexOf('## Current Task Context'),
            )
            .trimRight();
        expect(logBlock(secondPrompt), startsWith(logBlock(firstPrompt)));
        expect(logBlock(secondPrompt), contains('second note'));
      });

      test('a neighbor report change leaves the stable prefix byte-identical '
          '(parent/linked summaries live in the volatile tail)', () async {
        // asm-2 / ADR 0027: the parent-project and linked-task blocks embed
        // OTHER agents' reports, which change out-of-band with this task's
        // wakes. They must sit AFTER the task log so a neighbor's republish
        // cannot void this task's warm prefix cache. Here the log is held
        // constant and only the parent-project report changes between wakes.
        const noteContent = {'entryType': 'text', 'text': 'stable note'};
        final noteDigest = ContentDigest.of(noteContent);

        when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
          (_) async => <AgentLink>[
            AgentLink.messagePayload(
              id: 'pl-1',
              fromId: agentId,
              toId: noteDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime(2024, 6),
            ),
          ],
        );
        when(() => mockAgentRepository.getEntity(noteDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: noteDigest,
            agentId: agentId,
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: noteContent,
          ),
        );
        when(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).thenAnswer((_) async => '- Title: Slim header');

        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        // The parent-project agent republishes between the two wakes — its
        // tldr and createdAt change, simulating out-of-band neighbor activity.
        var projectWake = 0;
        when(
          () => mockAiInputRepository.buildProjectContextJsonForTask(taskId),
        ).thenAnswer((_) async {
          projectWake++;
          return jsonEncode({
            'projectId': 'proj-1',
            'latestProjectAgentReport': {
              'tldr': 'Project tldr v$projectWake',
              'createdAt': '2024-06-0${projectWake}T00:00:00.000',
            },
          });
        });

        final workflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: mockConversationRepository,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          inputCaptureService: RecordingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final sentMessages = <String>[];
        mockConversationRepository
          ..maxDelegateCalls = 4
          ..sendMessageDelegate =
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
                sentMessages.add(message);
                return null;
              };

        final firstResult = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );
        expect(firstResult.success, isTrue);
        String lastPrompt() =>
            sentMessages.lastWhere((m) => m.contains('## Task Log'));
        final firstPrompt = lastPrompt();

        final secondResult = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: 'run-key-2',
          triggerTokens: {},
          threadId: threadId,
        );
        expect(secondResult.success, isTrue);
        final secondPrompt = lastPrompt();

        // The neighbor report changed, yet everything up to the task log is
        // byte-identical — the warm prefix cache survives.
        String head(String s) => s.substring(0, s.indexOf('## Task Log'));
        expect(head(secondPrompt), head(firstPrompt));

        // The parent-project block lives in the volatile tail (after the log)
        // and reflects the changed neighbor report.
        expect(
          secondPrompt.indexOf('## Parent Project Context'),
          greaterThan(secondPrompt.indexOf('## Task Log')),
        );
        expect(firstPrompt, contains('Project tldr v1'));
        expect(secondPrompt, contains('Project tldr v2'));
      });
    });
  });
}
