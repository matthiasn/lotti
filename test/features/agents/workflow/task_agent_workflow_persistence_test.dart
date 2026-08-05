import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_editor.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';
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
  final testDate = taskAgentTestDate;
  final testTemplate = taskAgentTestTemplate;
  final testTemplateVersion = taskAgentTestTemplateVersion;
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
    group('successful execute', () {
      void stubMeliousTaskAgentModel({
        required String providerId,
        required String modelConfigId,
        required String modelName,
        required String providerModelId,
        AgentTemplateVersionEntity? templateVersion,
        InferenceProviderType providerType = InferenceProviderType.melious,
      }) {
        final provider =
            AiConfig.inferenceProvider(
                  id: providerId,
                  baseUrl: 'https://api.melious.ai/v1',
                  apiKey: 'test-key',
                  name: 'Melious',
                  createdAt: DateTime(2024),
                  inferenceProviderType: providerType,
                )
                as AiConfigInferenceProvider;
        final model =
            AiConfig.model(
                  id: modelConfigId,
                  name: modelName,
                  providerModelId: providerModelId,
                  inferenceProviderId: provider.id,
                  createdAt: DateTime(2024),
                  inputModalities: const [Modality.text],
                  outputModalities: const [Modality.text],
                  isReasoningModel: true,
                  supportsFunctionCalling: true,
                )
                as AiConfigModel;
        final template = makeTestTemplate(modelId: providerModelId);
        when(
          () => mockTemplateService.getTemplateForAgent(agentId),
        ).thenAnswer((_) async => template);
        when(
          () => mockTemplateService.getActiveVersion(template.id),
        ).thenAnswer((_) async => templateVersion ?? testTemplateVersion);
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [model]);
        when(
          () => mockAiConfigRepository.getConfigById(provider.id),
        ).thenAnswer((_) async => provider);
      }

      Future<({WakeResult result, List<dynamic> captured})>
      runMistralReportEditorSafetyCase({
        required List<String> editorArguments,
        bool throwOnEditor = false,
        bool throwOnEditorCreate = false,
        String? reportDirective,
        String? taskLanguageCode,
        DateTime? taskDue,
      }) async {
        stubMeliousTaskAgentModel(
          providerId: 'melious-provider-safety',
          modelConfigId: 'mistral-model-safety',
          modelName: 'Mistral Small 4 119B',
          providerModelId: meliousMistralSmall4119BInstructModelId,
          templateVersion: reportDirective == null
              ? null
              : makeTestTemplateVersion(reportDirective: reportDirective),
        );
        if (taskLanguageCode != null || taskDue != null) {
          when(() => mockJournalDb.journalEntityById(taskId)).thenAnswer(
            (_) async => makeWorkflowTestTask(
              taskId,
              languageCode: taskLanguageCode,
              due: taskDue,
            ),
          );
        }

        var callIndex = 0;
        var conversationCount = 0;
        final safetyRepo =
            MockConversationRepository(
                mockConversationManager,
                onSystemMessage: (_) {
                  conversationCount++;
                  if (throwOnEditorCreate && conversationCount == 2) {
                    throw StateError('editor conversation unavailable');
                  }
                },
              )
              ..maxDelegateCalls = throwOnEditor
                  ? 2
                  : 1 + editorArguments.length
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
                    callIndex++;
                    if (callIndex == 1 && strategy is TaskAgentStrategy) {
                      await strategy.processToolCalls(
                        toolCalls: [
                          const ChatCompletionMessageToolCall(
                            id: 'priority-call',
                            type: ChatCompletionMessageToolCallType.function,
                            function: ChatCompletionMessageFunctionCall(
                              name: TaskAgentToolNames.updateTaskPriority,
                              arguments: '{"priority":"P1"}',
                            ),
                          ),
                          ChatCompletionMessageToolCall(
                            id: 'draft-report-call',
                            type: ChatCompletionMessageToolCallType.function,
                            function: ChatCompletionMessageFunctionCall(
                              name: TaskAgentToolNames.updateReport,
                              arguments: jsonEncode({
                                'oneLiner': 'Task configured',
                                'tldr': 'Priority updated. Ready to begin.',
                                'content': '## Progress\nTask configured.',
                              }),
                            ),
                          ),
                        ],
                        manager: mockConversationManager,
                      );
                      return const InferenceUsage(
                        inputTokens: 100,
                        outputTokens: 20,
                      );
                    }
                    if (throwOnEditor) {
                      throw StateError('editor unavailable');
                    }
                    await strategy!.processToolCalls(
                      toolCalls: [
                        ChatCompletionMessageToolCall(
                          id: 'editor-call-$callIndex',
                          type: ChatCompletionMessageToolCallType.function,
                          function: ChatCompletionMessageFunctionCall(
                            name: TaskAgentToolNames.updateReport,
                            arguments: editorArguments[callIndex - 2],
                          ),
                        ),
                      ],
                      manager: mockConversationManager,
                    );
                    return const InferenceUsage(
                      inputTokens: 5,
                      outputTokens: 2,
                    );
                  };
        final safetyWorkflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: safetyRepo,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
        );

        final result = await safetyWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        return (result: result, captured: captured);
      }

      Future<
        ({
          WakeResult result,
          List<dynamic> captured,
          List<String> models,
        })
      >
      runMistralWithoutDraft({
        required AgentReportEntity? previousReport,
      }) async {
        stubMeliousTaskAgentModel(
          providerId: 'melious-provider-no-draft',
          modelConfigId: 'mistral-model-no-draft',
          modelName: 'Mistral Small 4 119B',
          providerModelId: meliousMistralSmall4119BInstructModelId,
        );
        when(
          () => mockAgentRepository.getLatestReport(agentId, 'current'),
        ).thenAnswer((_) async => previousReport);

        final models = <String>[];
        final noDraftRepo = MockConversationRepository(mockConversationManager)
          ..maxDelegateCalls = previousReport == null ? 2 : 1
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
                models.add(model);
                return const InferenceUsage(
                  inputTokens: 10,
                  outputTokens: 2,
                );
              };
        final noDraftWorkflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: noDraftRepo,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
        );

        final result = await noDraftWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        return (result: result, captured: captured, models: models);
      }

      setUp(() {
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
      });

      test(
        'Mistral evidence mode records not_needed when an unchanged wake has '
        'no new report',
        () async {
          final previousReport =
              AgentDomainEntity.agentReport(
                    id: 'previous-report',
                    agentId: agentId,
                    scope: 'current',
                    createdAt: testDate,
                    vectorClock: null,
                    content: 'Current report.',
                    tldr: 'Current report.',
                    oneLiner: 'Current report',
                  )
                  as AgentReportEntity;
          final (:result, :captured, :models) = await runMistralWithoutDraft(
            previousReport: previousReport,
          );

          expect(result.success, isTrue);
          expect(models, [meliousMistralSmall4119BInstructModelId]);
          final editorAudit =
              capturedEntitiesOfType<AgentMessageEntity>(captured).singleWhere(
                (message) =>
                    message.metadata.toolName ==
                    '${TaskAgentReportEditor.auditToolPrefix}_not_needed',
              );
          expect(editorAudit.metadata.errorMessage, isNull);
          expect(capturedTokenUsageEntities(captured), hasLength(1));
        },
      );

      test(
        'Mistral evidence mode records failure when the required report retry '
        'still produces no draft',
        () async {
          final (:result, :captured, :models) = await runMistralWithoutDraft(
            previousReport: null,
          );

          expect(result.success, isTrue);
          expect(models, [
            meliousMistralSmall4119BInstructModelId,
            meliousMistralSmall4119BInstructModelId,
          ]);
          final editorAudit =
              capturedEntitiesOfType<AgentMessageEntity>(captured).singleWhere(
                (message) =>
                    message.metadata.toolName ==
                    '${TaskAgentReportEditor.auditToolPrefix}_failed',
              );
          expect(
            editorAudit.metadata.errorMessage,
            'executor_missing_required_report',
          );
          expect(
            capturedTokenUsageEntities(captured).map((entry) => entry.modelId),
            everyElement(meliousMistralSmall4119BInstructModelId),
          );
        },
      );

      test('Mistral evidence mode preserves its draft after invalid editor '
          'candidates', () async {
        final (:result, :captured) = await runMistralReportEditorSafetyCase(
          editorArguments: [
            jsonEncode({
              'oneLiner': 'Run evaluation',
              'tldr': 'No blockers.',
              'content': 'Checklist created.',
            }),
            jsonEncode({
              'oneLiner': 'Run evaluation',
              'tldr': 'Ready to begin.',
              'content': 'The checklist contains two items.',
            }),
            jsonEncode({
              'oneLiner': 'Run evaluation',
              'tldr': 'No recorded outcomes.',
              'content': 'Checklist items added.',
            }),
          ],
        );

        expect(result.success, isTrue);
        final reports = capturedEntitiesOfType<AgentReportEntity>(captured);
        expect(reports, hasLength(1));
        expect(reports.single.content, '## Progress\nTask configured.');
        final usage = capturedTokenUsageEntities(captured);
        expect(usage, hasLength(2));
        final editorUsage = usage.singleWhere(
          (entry) => entry.modelId == meliousQwen35122BA10BModelId,
        );
        expect(editorUsage.inputTokens, 15);
        expect(editorUsage.outputTokens, 6);
        final editorAudit = capturedEntitiesOfType<AgentMessageEntity>(captured)
            .singleWhere(
              (message) =>
                  message.metadata.toolName ==
                  '${TaskAgentReportEditor.auditToolPrefix}_rejected',
            );
        expect(editorAudit.metadata.errorMessage, contains('processNarration'));
      });

      test(
        'Mistral evidence mode preserves its draft when the editor fails',
        () async {
          final (:result, :captured) = await runMistralReportEditorSafetyCase(
            editorArguments: const [],
            throwOnEditor: true,
          );

          expect(result.success, isTrue);
          final reports = capturedEntitiesOfType<AgentReportEntity>(captured);
          expect(reports, hasLength(1));
          expect(reports.single.content, '## Progress\nTask configured.');
          final usage = capturedTokenUsageEntities(captured);
          expect(usage, hasLength(1));
          expect(usage.single.modelId, meliousMistralSmall4119BInstructModelId);
          final editorAudit =
              capturedEntitiesOfType<AgentMessageEntity>(captured).singleWhere(
                (message) =>
                    message.metadata.toolName ==
                    '${TaskAgentReportEditor.auditToolPrefix}_failed',
              );
          expect(editorAudit.metadata.errorMessage, 'StateError');
        },
      );

      test('Mistral evidence mode preserves its draft when editor conversation '
          'creation fails', () async {
        final (:result, :captured) = await runMistralReportEditorSafetyCase(
          editorArguments: const [],
          throwOnEditorCreate: true,
        );

        expect(result.success, isTrue);
        final reports = capturedEntitiesOfType<AgentReportEntity>(captured);
        expect(reports.single.content, '## Progress\nTask configured.');
        expect(capturedTokenUsageEntities(captured), hasLength(1));
        final editorAudit = capturedEntitiesOfType<AgentMessageEntity>(captured)
            .singleWhere(
              (message) =>
                  message.metadata.toolName ==
                  '${TaskAgentReportEditor.auditToolPrefix}_failed',
            );
        expect(editorAudit.metadata.errorMessage, 'StateError');
      });

      test(
        'Mistral evidence mode validates the editor against the task language',
        () async {
          final (:result, :captured) = await runMistralReportEditorSafetyCase(
            taskLanguageCode: 'de',
            editorArguments: [
              jsonEncode({
                'oneLiner': 'P1-Aufgabe prüfen',
                'tldr': 'Die P1-Prüfung bleibt offen.',
                'content':
                    '## Nächster Schritt\nPrüfen Sie den Modellkandidaten.',
              }),
            ],
          );

          expect(result.success, isTrue);
          final reports = capturedEntitiesOfType<AgentReportEntity>(captured);
          expect(reports.single.content, '## Progress\nTask configured.');
          final usage = capturedTokenUsageEntities(captured);
          expect(
            usage
                .singleWhere(
                  (entry) => entry.modelId == meliousQwen35122BA10BModelId,
                )
                .inputTokens,
            5,
          );
        },
      );

      test(
        'Mistral evidence mode restores an existing task deadline',
        () async {
          final (:result, :captured) = await runMistralReportEditorSafetyCase(
            taskLanguageCode: 'de',
            taskDue: DateTime(2026, 9, 30),
            editorArguments: [
              jsonEncode({
                'oneLiner': 'P1-Beta vorbereiten',
                'tldr': 'Die P1-Beta hat vier offene Aktionen.',
                'content': '## Nächster Schritt\nAPI-Umfang mit Ben klären.',
              }),
              jsonEncode({
                'oneLiner': 'P1-Beta bis 30. September 2026 vorbereiten',
                'tldr':
                    'Die P1-Beta ist bis zum 30. September 2026 '
                    'vorzubereiten.',
                'content':
                    '## Nächster Schritt\nAPI-Umfang mit Ben bis zur Beta am '
                    '30. September 2026 klären.',
              }),
            ],
          );

          expect(result.success, isTrue);
          final report = capturedEntitiesOfType<AgentReportEntity>(
            captured,
          ).single;
          expect(report.content, contains('30. September 2026'));
          final editorUsage = capturedTokenUsageEntities(captured).singleWhere(
            (entry) => entry.modelId == meliousQwen35122BA10BModelId,
          );
          expect(editorUsage.inputTokens, 10);
        },
      );

      test(
        'Mistral evidence mode edits reports under custom directives',
        () async {
          final (:result, :captured) = await runMistralReportEditorSafetyCase(
            reportDirective: '''
Write a compact release decision memo. Start with `## Recommendation`, then
use `## Next moves` for concrete pending actions. Omit empty sections and do
not describe task configuration or tool activity as progress.
''',
            editorArguments: [
              jsonEncode({
                'oneLiner': 'P1 evaluation is the immediate release priority',
                'tldr': 'The P1 evaluation remains the next release action.',
                'content':
                    '## Recommendation\nRun the P1 evaluation.\n\n'
                    '## Next moves\n- Complete the evaluation.',
              }),
            ],
          );

          expect(result.success, isTrue);
          final reports = capturedEntitiesOfType<AgentReportEntity>(captured);
          expect(reports, hasLength(1));
          expect(reports.single.content, contains('## Recommendation'));
          expect(reports.single.content, contains('## Next moves'));
          final usage = capturedTokenUsageEntities(captured);
          expect(usage, hasLength(2));
          expect(
            usage.map((entry) => entry.modelId),
            containsAll([
              meliousMistralSmall4119BInstructModelId,
              meliousQwen35122BA10BModelId,
            ]),
          );
        },
      );

      test('queries proposal ledger for deduplication context', () async {
        // Override with a non-empty ledger (pendingSets populated) to
        // exercise the expand/where lambda in the dedup path.
        final pendingChangeSet =
            AgentDomainEntity.changeSet(
                  id: 'cs-existing',
                  agentId: agentId,
                  taskId: taskId,
                  threadId: 'old-thread',
                  runKey: 'old-run',
                  status: ChangeSetStatus.pending,
                  items: const [
                    ChangeItem(
                      toolName: 'set_task_title',
                      args: {'title': 'Existing proposal'},
                      humanSummary: 'Set title',
                    ),
                  ],
                  createdAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                )
                as ChangeSetEntity;

        when(
          () => mockAgentRepository.getProposalLedger(
            any(),
            taskId: any(named: 'taskId'),
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer(
          (_) async => ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [pendingChangeSet],
          ),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        verify(
          () => mockAgentRepository.getProposalLedger(
            agentId,
            taskId: taskId,
            resolvedLimit: TaskAgentWorkflow.resolvedDecisionWindow,
          ),
        ).called(1);
      });

      test('system prompt contains scaffold and template directives', () async {
        String? capturedSystemMessage;
        // Override createConversation to capture the system message.
        final capturingRepo = MockConversationRepository(
          mockConversationManager,
          onSystemMessage: (msg) => capturedSystemMessage = msg,
        );
        final capturingWorkflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: capturingRepo,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
        );

        await capturingWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedSystemMessage, isNotNull);
        // Scaffold content.
        expect(capturedSystemMessage, contains('You are a Task Agent'));
        expect(capturedSystemMessage, contains('update_report'));
        expect(capturedSystemMessage, contains('oneLiner'));
        // Parent project context scaffold section.
        expect(capturedSystemMessage, contains('## Parent Project Context'));
        // Linked-tasks legend (graph-3): the directed `relations` vocabulary
        // is explained so the model can read it, and the freshness marker
        // (graph-5) is documented.
        expect(capturedSystemMessage, contains('## Linked Tasks'));
        expect(
          capturedSystemMessage,
          contains('with THIS task as the subject'),
        );
        expect(capturedSystemMessage, contains('summaryStatus'));
        // The enforced single-use contract is surfaced up front (sp-3).
        expect(capturedSystemMessage, contains('queued at most ONCE per wake'));
        // Related-tasks scaffold is disabled to reduce context pollution.
        expect(
          capturedSystemMessage,
          isNot(contains('## Related Tasks In This Project')),
        );
        // Template directives appended.
        expect(
          capturedSystemMessage,
          contains('Your Personality & Directives'),
        );
        expect(
          capturedSystemMessage,
          contains('You are a diligent task agent named Laura.'),
        );
      });

      test(
        'system prompt uses split directives when generalDirective is set',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Be thorough and precise.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          String? capturedSystemMessage;
          final capturingRepo = MockConversationRepository(
            mockConversationManager,
            onSystemMessage: (msg) => capturedSystemMessage = msg,
          );
          final capturingWorkflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: capturingRepo,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
          );

          await capturingWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedSystemMessage, isNotNull);
          // Core scaffold present.
          expect(capturedSystemMessage, contains('You are a Task Agent'));
          // Parent project context scaffold section.
          expect(capturedSystemMessage, contains('## Parent Project Context'));
          // Related-tasks scaffold is disabled to reduce context pollution.
          expect(
            capturedSystemMessage,
            isNot(contains('## Related Tasks In This Project')),
          );
          // General directive injected.
          expect(capturedSystemMessage, contains('Be thorough and precise.'));
          expect(
            capturedSystemMessage,
            contains('Your Personality & Directives'),
          );
          // The permanent evidence-first path supplies the evaluated report
          // directive when the saved directive is empty.
          expect(capturedSystemMessage, contains('## Report Directive'));
          expect(capturedSystemMessage, contains('## Final report'));
        },
      );

      test(
        'system prompt uses custom report directive when reportDirective is set',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Be concise.',
            reportDirective: 'Write reports in bullet points only.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          String? capturedSystemMessage;
          final capturingRepo = MockConversationRepository(
            mockConversationManager,
            onSystemMessage: (msg) => capturedSystemMessage = msg,
          );
          final capturingWorkflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: capturingRepo,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
          );

          await capturingWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedSystemMessage, isNotNull);
          // Custom report directive replaces the default report section.
          expect(capturedSystemMessage, contains('## Report Directive'));
          expect(
            capturedSystemMessage,
            contains('Write reports in bullet points only.'),
          );
          // Parent project context scaffold section.
          expect(capturedSystemMessage, contains('## Parent Project Context'));
          // Related-tasks scaffold is disabled to reduce context pollution.
          expect(
            capturedSystemMessage,
            isNot(contains('## Related Tasks In This Project')),
          );
          // General directive present.
          expect(capturedSystemMessage, contains('Be concise.'));
          // Tool usage guidelines (trailing scaffold) still present.
          expect(capturedSystemMessage, contains('## Tool Usage Guidelines'));
        },
      );

      test(
        'system prompt separates personality from skills when soul is assigned',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Focus on task completion and accuracy.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          final mockSoulService = MockSoulDocumentService();
          final soulVersion = makeTestSoulDocumentVersion(
            voiceDirective: 'Speak warmly and with clarity.',
            toneBounds: 'Never be sarcastic.',
            coachingStyle: 'Celebrate small wins.',
            antiSycophancyPolicy: 'Push back when tasks seem misguided.',
          );
          when(
            () => mockSoulService.resolveActiveSoulForTemplate(testTemplate.id),
          ).thenAnswer((_) async => soulVersion);

          String? capturedSystemMessage;
          final capturingRepo = MockConversationRepository(
            mockConversationManager,
            onSystemMessage: (msg) => capturedSystemMessage = msg,
          );
          final capturingWorkflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: capturingRepo,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
            soulDocumentService: mockSoulService,
          );

          await capturingWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedSystemMessage, isNotNull);
          // Soul personality fields injected under separate heading.
          expect(capturedSystemMessage, contains('## Your Personality'));
          expect(
            capturedSystemMessage,
            contains('Speak warmly and with clarity.'),
          );
          expect(capturedSystemMessage, contains('Never be sarcastic.'));
          expect(capturedSystemMessage, contains('Celebrate small wins.'));
          expect(
            capturedSystemMessage,
            contains('Push back when tasks seem misguided.'),
          );
          // Operational directives under separate heading.
          expect(
            capturedSystemMessage,
            contains('## Your Operational Directives'),
          );
          expect(
            capturedSystemMessage,
            contains('Focus on task completion and accuracy.'),
          );
          // Combined heading must NOT appear when soul is present.
          expect(
            capturedSystemMessage,
            isNot(contains('## Your Personality & Directives')),
          );
        },
      );

      test(
        'system prompt uses legacy heading when no soul is assigned',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Skills only directive.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          final mockSoulService = MockSoulDocumentService();
          when(
            () => mockSoulService.resolveActiveSoulForTemplate(testTemplate.id),
          ).thenAnswer((_) async => null);

          String? capturedSystemMessage;
          final capturingRepo = MockConversationRepository(
            mockConversationManager,
            onSystemMessage: (msg) => capturedSystemMessage = msg,
          );
          final capturingWorkflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: capturingRepo,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
            soulDocumentService: mockSoulService,
          );

          await capturingWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedSystemMessage, isNotNull);
          // Legacy combined heading.
          expect(
            capturedSystemMessage,
            contains('## Your Personality & Directives'),
          );
          expect(capturedSystemMessage, contains('Skills only directive.'));
          // Separate headings must NOT appear.
          expect(
            capturedSystemMessage,
            isNot(contains('## Your Personality\n')),
          );
          expect(
            capturedSystemMessage,
            isNot(contains('## Your Operational Directives')),
          );
        },
      );

      test('soul resolution failure propagates as exception', () async {
        final splitVersion = makeTestTemplateVersion(
          generalDirective: 'Skills directive.',
        );
        when(
          () => mockTemplateService.getActiveVersion(testTemplate.id),
        ).thenAnswer((_) async => splitVersion);

        final mockSoulService = MockSoulDocumentService();
        when(
          () => mockSoulService.resolveActiveSoulForTemplate(testTemplate.id),
        ).thenThrow(Exception('Soul DB error'));

        final soulWorkflow = createTestWorkflow(
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
          soulDocumentService: mockSoulService,
        );

        await expectLater(
          soulWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Soul DB error'),
            ),
          ),
        );
      });

      test(
        'token usage records soul provenance when soul is assigned',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Be precise.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          final mockSoulService = MockSoulDocumentService();
          final soulVersion = makeTestSoulDocumentVersion(
            id: 'sv-001',
            agentId: 'soul-doc-001',
            voiceDirective: 'Warm voice.',
          );
          when(
            () => mockSoulService.resolveActiveSoulForTemplate(testTemplate.id),
          ).thenAnswer((_) async => soulVersion);

          // Use a conversation repo that returns actual token usage.
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
              }) async =>
                  const InferenceUsage(inputTokens: 50, outputTokens: 25);

          final soulWorkflow = TaskAgentWorkflow(
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
            soulDocumentService: mockSoulService,
          );

          await soulWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          // Verify soul provenance in wake run.
          verify(
            () => mockAgentRepository.updateWakeRunTemplate(
              runKey,
              testTemplate.id,
              splitVersion.id,
              resolvedModelId: any(named: 'resolvedModelId'),
              soulId: 'soul-doc-001',
              soulVersionId: 'sv-001',
            ),
          ).called(1);

          // Verify soul provenance in token usage entity.
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final tokenUsages = capturedTokenUsageEntities(captured);
          expect(tokenUsages, isNotEmpty);
          final tokenUsage = tokenUsages.first;
          expect(tokenUsage.soulDocumentId, 'soul-doc-001');
          expect(tokenUsage.soulDocumentVersionId, 'sv-001');
        },
      );

      test('records template provenance on wake run', () async {
        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        verify(
          () => mockAgentRepository.updateWakeRunTemplate(
            runKey,
            testTemplate.id,
            testTemplateVersion.id,
            resolvedModelId: any(named: 'resolvedModelId'),
            soulId: any(named: 'soulId'),
            soulVersionId: any(named: 'soulVersionId'),
          ),
        ).called(1);
      });

      test('continues when template provenance recording fails', () async {
        when(
          () => mockAgentRepository.updateWakeRunTemplate(
            any(),
            any(),
            any(),
            resolvedModelId: any(named: 'resolvedModelId'),
            soulId: any(named: 'soulId'),
            soulVersionId: any(named: 'soulVersionId'),
          ),
        ).thenThrow(Exception('DB error'));

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Wake should still succeed despite provenance failure.
        expect(result.success, isTrue);
      });

      test(
        'persists observations from record_observations tool calls',
        () async {
          // Set up sendMessage to simulate the strategy accumulating
          // observations via the record_observations tool during conversation.
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
                // Simulate the LLM calling record_observations by directly
                // invoking processToolCalls with a record_observations call.
                if (strategy is TaskAgentStrategy) {
                  await strategy.processToolCalls(
                    toolCalls: [
                      const ChatCompletionMessageToolCall(
                        id: 'obs-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'record_observations',
                          arguments:
                              '{"observations":["Pattern A","Pattern B"]}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          // Should persist: assistant message (from processToolCalls)
          // + 2 observation payloads + 2 observation messages
          // + state update = 6 total.
          verify(
            () => mockSyncService.upsertEntity(any()),
          ).called(greaterThanOrEqualTo(6));
        },
      );

      test(
        'persists observation payloads with priority and category fields',
        () async {
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
                if (strategy is TaskAgentStrategy) {
                  await strategy.processToolCalls(
                    toolCalls: [
                      const ChatCompletionMessageToolCall(
                        id: 'obs-structured',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'record_observations',
                          arguments:
                              '{"observations":[{"text":"User is frustrated",'
                              ' "priority":"critical","category":"grievance"}]}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          // Find the persisted observation payload entity (has priority key).
          final payloads = capturedPayloadEntities(
            captured,
          ).where((p) => p.content.containsKey('priority')).toList();

          expect(payloads, hasLength(1));
          final payload = payloads.first;
          expect(payload.content['text'], 'User is frustrated');
          expect(payload.content['priority'], 'critical');
          expect(payload.content['category'], 'grievance');
        },
      );

      test(
        'persists wakeTokenUsage entity when usage data is returned',
        () async {
          // Return non-null usage from sendMessage.
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
                return const InferenceUsage(
                  inputTokens: 150,
                  outputTokens: 75,
                  thoughtsTokens: 30,
                  cachedInputTokens: 20,
                );
              };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          // Verify a wakeTokenUsage entity was persisted.
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final tokenUsageEntities = capturedTokenUsageEntities(captured);

          expect(tokenUsageEntities, hasLength(1));
          final entity = tokenUsageEntities.first;
          expect(entity.agentId, agentId);
          expect(entity.runKey, runKey);
          expect(entity.threadId, threadId);
          expect(entity.inputTokens, 150);
          expect(entity.outputTokens, 75);
          expect(entity.thoughtsTokens, 30);
          expect(entity.cachedInputTokens, 20);
        },
      );

      test('does not persist wakeTokenUsage when usage is null', () async {
        // Default delegate returns null.
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final tokenUsageEntities = capturedTokenUsageEntities(captured);

        expect(tokenUsageEntities, isEmpty);
      });

      test('does not persist wakeTokenUsage when usage has no data', () async {
        // Return an empty usage (hasData == false).
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
              return InferenceUsage.empty;
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final tokenUsageEntities = capturedTokenUsageEntities(captured);

        expect(tokenUsageEntities, isEmpty);
      });

      test('handles _persistTokenUsage failure gracefully', () async {
        // Return usage data, but make the sync service throw on wakeTokenUsage.
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
              return const InferenceUsage(inputTokens: 100, outputTokens: 50);
            };

        // Make upsertEntity throw only for wakeTokenUsage entities.
        var callCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((inv) async {
          final entity = inv.positionalArguments[0] as AgentDomainEntity;
          final isTokenUsage =
              entity.mapOrNull(wakeTokenUsage: (_) => true) ?? false;
          if (isTokenUsage) {
            throw Exception('Sync failed');
          }
          callCount++;
        });

        // Should NOT fail the overall wake despite persistence error.
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        // Other entities (user message, state update, etc.) were still persisted.
        expect(callCount, greaterThan(0));
      });

      test('cleans up conversation in finally block even on success', () async {
        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );
      });
    });
    group('forced update_report retry', () {
      setUp(() {
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
      });

      test(
        'issues a second sendMessage with toolChoice forced to update_report '
        'at the model default when evidence synthesis has no report',
        () async {
          final calls =
              <
                ({
                  String message,
                  ChatCompletionToolChoiceOption? toolChoice,
                  double temperature,
                })
              >[];

          // Allow the delegate to run for both the primary call and the retry
          // so the test can observe both invocations.
          mockConversationRepository
            ..maxDelegateCalls = 2
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
                  calls.add((
                    message: message,
                    toolChoice: toolChoice,
                    temperature: temperature,
                  ));
                  return null;
                };

          final evidenceWorkflow = createTestWorkflow(
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
          );
          final result = await evidenceWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(calls, hasLength(2));
          expect(calls.map((call) => call.temperature), [0.3, 0.3]);

          // First call: normal wake, no forced tool choice.
          expect(calls[0].toolChoice, isNull);

          // Second call: forced update_report.
          final retryToolChoice = calls[1].toolChoice;
          expect(retryToolChoice, isNotNull);
          retryToolChoice!.map(
            mode: (_) => fail('Expected named tool choice, got mode.'),
            tool: (named) {
              expect(
                named.value.function.name,
                TaskAgentStrategy.reportToolName,
              );
            },
          );
          expect(
            calls[1].message,
            contains('You did not call `update_report`'),
          );
        },
      );

      test('forces update_report after a successful mutation when a prior report '
          'exists', () async {
        final previousReport =
            AgentDomainEntity.agentReport(
                  id: 'previous-report',
                  agentId: agentId,
                  scope: 'current',
                  createdAt: testDate,
                  vectorClock: null,
                  content: 'Old report without the new checklist action.',
                  tldr: 'Old report.',
                  oneLiner: 'Old state',
                )
                as AgentReportEntity;
        when(
          () => mockAgentRepository.getLatestReport(agentId, 'current'),
        ).thenAnswer((_) async => previousReport);

        final calls = <ChatCompletionToolChoiceOption?>[];
        mockConversationRepository
          ..maxDelegateCalls = 2
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
                calls.add(toolChoice);
                if (strategy is! TaskAgentStrategy) return null;
                if (toolChoice == null) {
                  await strategy.processToolCalls(
                    toolCalls: const [
                      ChatCompletionMessageToolCall(
                        id: 'add-action',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: TaskAgentToolNames.addMultipleChecklistItems,
                          arguments: '{"items":[{"title":"Run release QA"}]}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                } else {
                  await strategy.processToolCalls(
                    toolCalls: const [
                      ChatCompletionMessageToolCall(
                        id: 'fresh-report',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: TaskAgentToolNames.updateReport,
                          arguments:
                              r'''{"oneLiner":"Release QA is next","tldr":"Run release QA next.","content":"## Next action\nRun release QA."}''',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

        final evidenceWorkflow = createTestWorkflow(
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
        );

        final result = await evidenceWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        expect(calls, hasLength(2));
        expect(calls.first, isNull);
        expect(calls.last, isNotNull);
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(
          capturedEntitiesOfType<AgentReportEntity>(captured).single.content,
          contains('Run release QA'),
        );
      });

      test(
        'keeps the prior report without retrying when no mutation succeeds',
        () async {
          final previousReport =
              AgentDomainEntity.agentReport(
                    id: 'previous-report',
                    agentId: agentId,
                    scope: 'current',
                    createdAt: testDate,
                    vectorClock: null,
                    content: 'Current report.',
                    tldr: 'Current state.',
                    oneLiner: 'Current state',
                  )
                  as AgentReportEntity;
          when(
            () => mockAgentRepository.getLatestReport(agentId, 'current'),
          ).thenAnswer((_) async => previousReport);

          final calls = <ChatCompletionToolChoiceOption?>[];
          mockConversationRepository
            ..maxDelegateCalls = 2
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
                  calls.add(toolChoice);
                  return null;
                };

          final evidenceWorkflow = createTestWorkflow(
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
          );

          final result = await evidenceWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(calls, [isNull]);
        },
      );

      test('swallows retry failures so the main-pass observations and metadata '
          'still reach the transaction', () async {
        mockConversationRepository
          ..maxDelegateCalls = 2
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
                // First call: record an observation via the real strategy
                // so the wake has something meaningful to persist.
                if (toolChoice == null) {
                  if (strategy is TaskAgentStrategy) {
                    await strategy.processToolCalls(
                      toolCalls: const [
                        ChatCompletionMessageToolCall(
                          id: 'obs-1',
                          type: ChatCompletionMessageToolCallType.function,
                          function: ChatCompletionMessageFunctionCall(
                            name: 'record_observations',
                            arguments: '{"observations":["important finding"]}',
                          ),
                        ),
                      ],
                      manager: mockConversationManager,
                    );
                  }
                  return null;
                }
                // Second call (retry): blow up. The workflow must catch
                // this and still persist the observation recorded above.
                throw Exception('simulated retry failure');
              };

        when(() => mockConversationManager.messages).thenReturn([]);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // The wake must NOT fail because of the retry exception.
        expect(result.success, isTrue);

        // The observation recorded before the retry threw must be persisted.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final observationPayloads = capturedPayloadEntities(
          captured,
        ).where((p) => p.content['text'] == 'important finding').toList();
        expect(observationPayloads, hasLength(1));
      });

      test(
        'accumulates token usage across the main call and the forced retry',
        () async {
          mockConversationRepository
            ..maxDelegateCalls = 2
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
                  // First call returns usage; retry (forced tool choice)
                  // returns more usage. Both must be merged and persisted.
                  if (toolChoice == null) {
                    return const InferenceUsage(
                      inputTokens: 100,
                      outputTokens: 40,
                    );
                  }
                  return const InferenceUsage(
                    inputTokens: 25,
                    outputTokens: 15,
                  );
                };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final tokenUsageEntities = capturedTokenUsageEntities(captured);

          expect(tokenUsageEntities, hasLength(1));
          final entity = tokenUsageEntities.first;
          expect(entity.inputTokens, 125);
          expect(entity.outputTokens, 55);
        },
      );

      test(
        'does NOT issue a retry when the strategy already published a report',
        () async {
          var callCount = 0;
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
                callCount++;
                if (strategy is TaskAgentStrategy) {
                  await strategy.processToolCalls(
                    toolCalls: const [
                      ChatCompletionMessageToolCall(
                        id: 'report-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              '{"oneLiner":"one","tldr":"tldr","content":"body"}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(callCount, 1);
        },
      );
    });

    group('report and thought persistence', () {
      setUp(() {
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
      });

      test(
        'persists report and report head when strategy produces report',
        () async {
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
                if (strategy is TaskAgentStrategy) {
                  await strategy.processToolCalls(
                    toolCalls: [
                      const ChatCompletionMessageToolCall(
                        id: 'rpt-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              r'{"content":"# Report\nAll good.","oneLiner":"Implementation done, release next","tldr":"Implementation is done and release is next."}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          // Report + report head + state update + assistant message = 4+
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final reports = captured
              .whereType<AgentDomainEntity>()
              .where((e) => e.mapOrNull(agentReport: (_) => true) ?? false)
              .toList();
          expect(reports, hasLength(1));
          final report = reports.first as AgentReportEntity;
          expect(report.content, '# Report\nAll good.');

          final heads = captured
              .whereType<AgentDomainEntity>()
              .where((e) => e.mapOrNull(agentReportHead: (_) => true) ?? false)
              .toList();
          expect(heads, hasLength(1));
        },
      );

      test('persists report with tldr and oneLiner when provided', () async {
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
              if (strategy is TaskAgentStrategy) {
                await strategy.processToolCalls(
                  toolCalls: [
                    ChatCompletionMessageToolCall(
                      id: 'rpt-call',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: 'update_report',
                        arguments: jsonEncode({
                          'content': '# Detailed Report\nFull analysis.',
                          'oneLiner': 'Implementation done, release next',
                          'tldr': 'Brief summary.',
                        }),
                      ),
                    ),
                  ],
                  manager: mockConversationManager,
                );
              }
              return null;
            };

        when(() => mockConversationManager.messages).thenReturn([]);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final reports = captured
            .whereType<AgentDomainEntity>()
            .where((e) => e.mapOrNull(agentReport: (_) => true) ?? false)
            .toList();
        expect(reports, hasLength(1));
        final report = reports.first as AgentReportEntity;
        expect(report.content, '# Detailed Report\nFull analysis.');
        expect(report.tldr, 'Brief summary.');
        expect(report.oneLiner, 'Implementation done, release next');
      });

      test('persists thought message when LLM produces final text', () async {
        when(() => mockConversationManager.messages).thenReturn([
          const ChatCompletionMessage.assistant(
            content: 'I analyzed the task and it looks good.',
          ),
        ]);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        // Find the thought payload entity (the one with the LLM response,
        // not the user message payload).
        final payloads = capturedPayloadEntities(captured);
        // At least 2 payloads: user message + thought.
        expect(payloads.length, greaterThanOrEqualTo(2));
        final thoughtPayload = payloads.firstWhere(
          (p) => p.content['text'] == 'I analyzed the task and it looks good.',
        );
        expect(
          thoughtPayload.content['text'],
          'I analyzed the task and it looks good.',
        );
      });

      test('uses existing report head ID when one exists', () async {
        final existingHead =
            AgentDomainEntity.agentReportHead(
                  id: 'existing-head-id',
                  agentId: agentId,
                  scope: 'current',
                  reportId: 'old-report',
                  updatedAt: testDate,
                  vectorClock: null,
                )
                as AgentReportHeadEntity;

        when(
          () => mockAgentRepository.getReportHead(agentId, 'current'),
        ).thenAnswer((_) async => existingHead);

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
              if (strategy is TaskAgentStrategy) {
                await strategy.processToolCalls(
                  toolCalls: [
                    const ChatCompletionMessageToolCall(
                      id: 'rpt-call',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: 'update_report',
                        arguments:
                            '{"content":"# Updated","oneLiner":"Implementation done, release next","tldr":"Implementation is done and release is next."}',
                      ),
                    ),
                  ],
                  manager: mockConversationManager,
                );
              }
              return null;
            };

        when(() => mockConversationManager.messages).thenReturn([]);

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final heads = captured
            .whereType<AgentDomainEntity>()
            .where((e) => e.mapOrNull(agentReportHead: (_) => true) ?? false)
            .toList();
        expect(heads, hasLength(1));
        final head = heads.first as AgentReportHeadEntity;
        expect(head.id, 'existing-head-id');
      });

      test(
        'embeds a new report and deletes the previous report embedding',
        () async {
          final existingHead =
              AgentDomainEntity.agentReportHead(
                    id: 'existing-head-id',
                    agentId: agentId,
                    scope: 'current',
                    reportId: 'old-report',
                    updatedAt: testDate,
                    vectorClock: null,
                  )
                  as AgentReportHeadEntity;
          final mockEmbeddingStore = MockEmbeddingStore();
          final mockEmbeddingRepository = MockOllamaEmbeddingRepository();
          final workflowWithEmbeddings = TaskAgentWorkflow(
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
            domainLogger: DomainLogger(loggingService: LoggingService())
              ..enabledDomains.add(LogDomain.agentWorkflow),
            embeddingStore: mockEmbeddingStore,
            embeddingRepository: mockEmbeddingRepository,
          );

          when(
            () => mockAgentRepository.getReportHead(agentId, 'current'),
          ).thenAnswer((_) async => existingHead);
          when(
            () => mockAiConfigRepository.resolveOllamaBaseUrl(),
          ).thenAnswer((_) async => 'http://localhost:11434');
          when(() => mockEmbeddingStore.getContentHash(any())).thenReturn(null);
          when(
            () => mockEmbeddingRepository.embed(
              input: any(named: 'input'),
              baseUrl: any(named: 'baseUrl'),
            ),
          ).thenAnswer(
            (_) async => Float32List.fromList(
              List<double>.filled(kEmbeddingDimensions, 0.25),
            ),
          );
          when(() => mockJournalDb.journalEntityById(taskId)).thenAnswer(
            (_) async => Task(
              data: TaskData(
                status: TaskStatus.open(
                  id: 'status_id',
                  createdAt: DateTime(2024, 3, 15),
                  utcOffset: 60,
                ),
                title: 'Add tests for embedding cleanup',
                statusHistory: [],
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
                if (strategy is TaskAgentStrategy) {
                  await strategy.processToolCalls(
                    toolCalls: [
                      const ChatCompletionMessageToolCall(
                        id: 'rpt-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              r'{"content":"# Report\nThis report has enough content to embed.","oneLiner":"Implementation done, release next","tldr":"Implementation is done and release is next."}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };
          when(() => mockConversationManager.messages).thenReturn([]);

          // The old-report deletion is the last side effect of the
          // fire-and-forget _embedAgentReport future; completing a
          // Completer from its stub lets the test await the pipeline
          // deterministically instead of draining the event queue.
          final embedPipelineDone = Completer<void>();
          when(
            () => mockEmbeddingStore.deleteEntityEmbeddings('old-report'),
          ).thenAnswer((_) async {
            if (!embedPipelineDone.isCompleted) embedPipelineDone.complete();
          });

          final result = await workflowWithEmbeddings.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          await embedPipelineDone.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'embedding pipeline never deleted the old report embedding',
            ),
          );

          verify(
            () => mockEmbeddingRepository.embed(
              input: any(named: 'input'),
              baseUrl: 'http://localhost:11434',
            ),
          ).called(1);
          verify(
            () => mockEmbeddingStore.deleteEntityEmbeddings('old-report'),
          ).called(1);
        },
      );

      test('swallows errors thrown while embedding the report', () async {
        // _embedAgentReport runs fire-and-forget after the transaction
        // commits. If the category lookup throws, the failure must be
        // caught (logged) and never surface as a wake failure, and no
        // embedding/deletion side effects should run.
        final mockEmbeddingStore = MockEmbeddingStore();
        final mockEmbeddingRepository = MockOllamaEmbeddingRepository();
        final workflowWithEmbeddings = TaskAgentWorkflow(
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
          domainLogger: DomainLogger(loggingService: LoggingService())
            ..enabledDomains.add(LogDomain.agentWorkflow),
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepository,
        );

        when(
          () => mockAgentRepository.getReportHead(agentId, 'current'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiConfigRepository.resolveOllamaBaseUrl(),
        ).thenAnswer((_) async => 'http://localhost:11434');
        // The category lookup inside _embedAgentReport throws — this is the
        // branch we want to exercise (the catch on line 885).
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenThrow(Exception('db unavailable'));

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
              if (strategy is TaskAgentStrategy) {
                await strategy.processToolCalls(
                  toolCalls: [
                    const ChatCompletionMessageToolCall(
                      id: 'rpt-call',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: 'update_report',
                        arguments:
                            r'{"content":"# Report\nThis report has enough content to embed.","oneLiner":"done","tldr":"done."}',
                      ),
                    ),
                  ],
                  manager: mockConversationManager,
                );
              }
              return null;
            };
        when(() => mockConversationManager.messages).thenReturn([]);

        final result = await workflowWithEmbeddings.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // The wake itself still succeeds — embedding is best-effort.
        expect(result.success, isTrue);
        // No Completer hook is possible here: the throwing lookup is the
        // last observable call and its catch handler produces no further
        // side effects. pumpEventQueue is a bounded deterministic drain
        // (Duration.zero turns, not real waiting), acceptable for letting
        // the swallowed error settle before the verifyNever checks.
        await pumpEventQueue();

        // The throwing lookup short-circuits before any embed/delete call.
        verifyNever(
          () => mockEmbeddingRepository.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
          ),
        );
        verifyNever(() => mockEmbeddingStore.deleteEntityEmbeddings(any()));
      });
    });
  });
}
