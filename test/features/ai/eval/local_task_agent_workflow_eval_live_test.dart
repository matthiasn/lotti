@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  test(
    'executes the real task-agent workflow against local oMLX',
    () async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
            ..registerSingleton<TimeService>(TimeService());
        },
      );
      addTearDown(tearDownTestGetIt);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      const providerType = InferenceProviderType.omlx;
      final provider =
          AiConfig.inferenceProvider(
                id: 'local-task-agent-workflow-omlx',
                name: 'Local oMLX',
                baseUrl:
                    Platform
                        .environment['LOCAL_TASK_AGENT_WORKFLOW_EVAL_BASE_URL'] ??
                    Platform.environment['OMLX_BASE_URL'] ??
                    ProviderConfig.defaultBaseUrls[providerType]!,
                apiKey:
                    Platform
                        .environment['LOCAL_TASK_AGENT_WORKFLOW_EVAL_API_KEY'] ??
                    Platform.environment['OMLX_API_KEY'] ??
                    '',
                inferenceProviderType: providerType,
                createdAt: DateTime(2026, 6, 21),
              )
              as AiConfigInferenceProvider;
      final model =
          AiConfig.model(
                id: 'local-task-agent-workflow-model',
                name: 'Local task-agent workflow eval model',
                providerModelId:
                    Platform
                        .environment['LOCAL_TASK_AGENT_WORKFLOW_EVAL_MODEL'] ??
                    omlxGemma426BA4BItQatMlx4BitModelId,
                inferenceProviderId: provider.id,
                createdAt: DateTime(2026, 6, 21),
                inputModalities: const [Modality.text, Modality.image],
                outputModalities: const [Modality.text],
                isReasoningModel: true,
                supportsFunctionCalling: true,
                description: 'Live oMLX model under workflow eval.',
              )
              as AiConfigModel;
      final profile = AiConfigInferenceProfile(
        id: profileLocalGemmaOmlxId,
        name: 'Local Gemma 4 (oMLX)',
        thinkingModelId: model.providerModelId,
        imageRecognitionModelId: model.providerModelId,
        createdAt: DateTime(2026, 6, 21),
      );

      const agentId = 'agent-local-task-workflow-eval';
      const taskId = 'task-local-task-workflow-eval';
      const runKey = 'run-local-task-workflow-eval';
      const threadId = 'thread-local-task-workflow-eval';
      final now = DateTime.utc(2026, 6, 21, 9);
      final task = _evalTask(taskId: taskId, now: now);
      final agentIdentity = _evalAgentIdentity(
        agentId: agentId,
        profileId: profile.id,
        now: now,
      );
      final agentState =
          AgentDomainEntity.agentState(
                id: 'state-local-task-workflow-eval',
                agentId: agentId,
                revision: 1,
                slots: const AgentSlots(activeTaskId: taskId),
                updatedAt: now,
                vectorClock: null,
              )
              as AgentStateEntity;

      final captured = <AgentDomainEntity>[];
      final mocks = _WorkflowMocks();
      _stubWorkflow(
        mocks: mocks,
        captured: captured,
        agentId: agentId,
        taskId: taskId,
        task: task,
        state: agentState,
        provider: provider,
        model: model,
        profile: profile,
      );

      final workflow = TaskAgentWorkflow(
        agentRepository: mocks.agentRepository,
        conversationRepository: container.read(
          conversationRepositoryProvider.notifier,
        ),
        aiInputRepository: mocks.aiInputRepository,
        aiConfigRepository: mocks.aiConfigRepository,
        journalDb: mocks.journalDb,
        cloudInferenceRepository: container.read(
          cloudInferenceRepositoryProvider,
        ),
        journalRepository: mocks.journalRepository,
        checklistRepository: mocks.checklistRepository,
        labelsRepository: mocks.labelsRepository,
        syncService: mocks.syncService,
        templateService: mocks.templateService,
        domainLogger: DomainLogger(loggingService: LoggingService())
          ..enabledDomains.add(LogDomain.agentWorkflow),
      );

      final stopwatch = Stopwatch()..start();
      final result = await workflow.execute(
        agentIdentity: agentIdentity,
        runKey: runKey,
        triggerTokens: {taskId},
        threadId: threadId,
      );
      stopwatch.stop();

      final report = _WorkflowEvalReport.fromCaptured(
        provider: provider,
        model: model,
        result: result,
        latencyMs: stopwatch.elapsedMilliseconds,
        captured: captured,
      );
      _writeReport(report);

      expect(result.success, isTrue, reason: result.error);
      expect(
        report.changeSetToolNames,
        containsAll([
          TaskAgentToolNames.setTaskTitle,
          TaskAgentToolNames.updateTaskEstimate,
          TaskAgentToolNames.updateTaskDueDate,
          TaskAgentToolNames.updateTaskPriority,
        ]),
        reason:
            'The real workflow did not persist the expected suggestions. '
            'See ${report.markdownPath}.',
      );
      expect(
        report.agentReportCount,
        greaterThanOrEqualTo(1),
        reason:
            'The real workflow did not persist an agent report. '
            'See ${report.markdownPath}.',
      );
      expect(
        report.systemPromptChars,
        greaterThan(1000),
        reason: 'The workflow did not persist a real system prompt payload.',
      );
      expect(
        report.userPromptChars,
        greaterThan(1000),
        reason: 'The workflow did not persist a real user prompt payload.',
      );
    },
    skip:
        Platform.environment['LOTTI_LOCAL_TASK_AGENT_WORKFLOW_EVAL_LIVE'] == '1'
        ? null
        : 'Set LOTTI_LOCAL_TASK_AGENT_WORKFLOW_EVAL_LIVE=1 to run the app-path local oMLX eval.',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

class _WorkflowMocks {
  final agentRepository = MockAgentRepository();
  final syncService = MockAgentSyncService();
  final aiInputRepository = MockAiInputRepository();
  final aiConfigRepository = MockAiConfigRepository();
  final journalDb = MockJournalDb();
  final journalRepository = MockJournalRepository();
  final checklistRepository = MockChecklistRepository();
  final labelsRepository = MockLabelsRepository();
  final templateService = MockAgentTemplateService();
}

void _stubWorkflow({
  required _WorkflowMocks mocks,
  required List<AgentDomainEntity> captured,
  required String agentId,
  required String taskId,
  required Task task,
  required AgentStateEntity state,
  required AiConfigInferenceProvider provider,
  required AiConfigModel model,
  required AiConfigInferenceProfile profile,
}) {
  when(() => mocks.syncService.repository).thenReturn(mocks.agentRepository);
  when(() => mocks.syncService.upsertEntity(any())).thenAnswer((invocation) {
    captured.add(invocation.positionalArguments.single as AgentDomainEntity);
    return Future<void>.value();
  });
  stubAppendMilestone(mocks.syncService);
  when(
    () => mocks.syncService.reconciledAgentState(agentId),
  ).thenAnswer((_) async => state);

  when(
    () => mocks.agentRepository.getEntity(any()),
  ).thenAnswer((_) async => null);
  when(
    () => mocks.agentRepository.getEntitiesByIds(any()),
  ).thenAnswer((_) async => const <String, AgentDomainEntity>{});
  when(
    () => mocks.agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    ),
  ).thenAnswer((_) async => null);
  when(
    () =>
        mocks.agentRepository.getReportHead(agentId, AgentReportScopes.current),
  ).thenAnswer((_) async => null);
  when(
    () => mocks.agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    ),
  ).thenAnswer((_) async => const <AgentMessageEntity>[]);
  when(
    () => mocks.agentRepository.getProposalLedger(
      agentId,
      taskId: taskId,
      changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
      resolvedLimit: any(named: 'resolvedLimit'),
    ),
  ).thenAnswer((_) async => const ProposalLedger.empty());
  when(
    () => mocks.agentRepository.getPendingChangeSets(
      agentId,
      taskId: taskId,
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => const <ChangeSetEntity>[]);
  when(
    () => mocks.agentRepository.getLinksToMultiple(
      any(),
      type: any(named: 'type'),
    ),
  ).thenAnswer((_) async => const <String, List<AgentLink>>{});
  when(
    () => mocks.agentRepository.getLatestReportsByAgentIds(any(), any()),
  ).thenAnswer((_) async => const <String, AgentReportEntity>{});
  when(
    () => mocks.agentRepository.getLinksTo(any(), type: any(named: 'type')),
  ).thenAnswer((_) async => const <AgentLink>[]);
  when(
    () => mocks.agentRepository.getAttentionClaimsForTarget(
      targetKind: any(named: 'targetKind'),
      targetId: any(named: 'targetId'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => const <AttentionRequestEntity>[]);
  when(
    () => mocks.agentRepository.updateWakeRunTemplate(
      any(),
      any(),
      any(),
      resolvedModelId: any(named: 'resolvedModelId'),
      soulId: any(named: 'soulId'),
      soulVersionId: any(named: 'soulVersionId'),
    ),
  ).thenAnswer((_) async {});

  when(
    () => mocks.templateService.getTemplateForAgent(agentId),
  ).thenAnswer((_) async => _lauraTemplate(profile.id));
  when(
    () => mocks.templateService.getActiveVersion(lauraTemplateId),
  ).thenAnswer((_) async => _lauraTemplateVersion(profile.id));

  when(
    () => mocks.aiConfigRepository.getConfigById(profile.id),
  ).thenAnswer((_) async => profile);
  when(
    () => mocks.aiConfigRepository.getConfigById(provider.id),
  ).thenAnswer((_) async => provider);
  when(
    () => mocks.aiConfigRepository.getConfigsByType(AiConfigType.model),
  ).thenAnswer((_) async => [model]);

  when(
    () => mocks.aiInputRepository.buildTaskDetailsJson(id: taskId),
  ).thenAnswer((_) async => _taskDetailsJson(task));
  when(
    () => mocks.aiInputRepository.buildTaskStateMarkdown(taskId),
  ).thenAnswer((_) async => _taskStateMarkdown(task));
  when(
    () => mocks.aiInputRepository.buildProjectContextJsonForTask(taskId),
  ).thenAnswer((_) async => _projectContextJson);
  when(
    () => mocks.aiInputRepository.buildLinkedFromContext(taskId),
  ).thenAnswer((_) async => const []);
  when(
    () => mocks.aiInputRepository.buildLinkedToContext(taskId),
  ).thenAnswer((_) async => const []);

  when(
    () => mocks.journalDb.journalEntityById(any()),
  ).thenAnswer((invocation) async {
    final id = invocation.positionalArguments.single as String;
    return id == taskId ? task : null;
  });
  when(
    () => mocks.journalDb.getLinkedEntities(any()),
  ).thenAnswer((_) async => const <JournalEntity>[]);
  when(
    () => mocks.journalDb.getAllLabelDefinitions(),
  ).thenAnswer((_) async => const []);
  when(
    () => mocks.journalDb.getCategoryById(any()),
  ).thenAnswer((_) async => null);
  when(
    () => mocks.journalDb.getLabelDefinitionById(any()),
  ).thenAnswer((_) async => null);
  when(
    () => mocks.checklistRepository.getChecklistItemsForTask(
      task: task,
    ),
  ).thenAnswer((_) async => const []);
}

AgentTemplateEntity _lauraTemplate(String profileId) {
  return makeTestTemplate(
    id: lauraTemplateId,
    agentId: lauraTemplateId,
    displayName: 'Laura',
    profileId: profileId,
    createdAt: DateTime(2026, 6, 21),
    updatedAt: DateTime(2026, 6, 21),
  );
}

AgentTemplateVersionEntity _lauraTemplateVersion(String profileId) {
  return makeTestTemplateVersion(
    id: 'version-local-task-workflow-eval',
    agentId: lauraTemplateId,
    directives:
        'You are Laura, a diligent task management agent. You help users '
        'organize, prioritize, and complete their tasks efficiently. You '
        'write clear, actionable reports.',
    generalDirective: taskAgentGeneralDirective,
    reportDirective: taskAgentReportDirective,
    authoredBy: 'system',
    profileId: profileId,
    createdAt: DateTime(2026, 6, 21),
  );
}

AgentIdentityEntity _evalAgentIdentity({
  required String agentId,
  required String profileId,
  required DateTime now,
}) {
  return AgentDomainEntity.agent(
        id: agentId,
        agentId: agentId,
        kind: 'task_agent',
        displayName: 'Laura',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {'cat-local-eval'},
        currentStateId: 'state-local-task-workflow-eval',
        config: AgentConfig(
          profileId: profileId,
        ),
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      )
      as AgentIdentityEntity;
}

Task _evalTask({
  required String taskId,
  required DateTime now,
}) {
  return Task(
    meta: Metadata(
      id: taskId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      categoryId: 'cat-local-eval',
      vectorClock: const VectorClock({'eval': 1}),
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-local-task-workflow-eval',
        createdAt: now,
        utcOffset: 0,
      ),
      statusHistory: const [],
      title: 'Evaluate local model fallback',
      dateFrom: now,
      dateTo: now,
      languageCode: 'en',
    ),
    entryText: const EntryText(
      plainText:
          'User asked: rename this task to Validate local Gemma fallback, '
          'make it P1, due July 4 2026, and estimate two and a half hours. '
          'The user is skeptical of shallow tool-call smoke reports and wants '
          'a real app-shaped local eval.',
    ),
  );
}

String _taskDetailsJson(Task task) {
  return const JsonEncoder.withIndent('  ').convert({
    'id': task.meta.id,
    'title': task.data.title,
    'status': 'OPEN',
    'priority': task.data.priority.short,
    'estimate': null,
    'dueDate': null,
    'languageCode': task.data.languageCode,
    'description': task.entryText?.plainText,
    'checklist': [
      {
        'id': 'check-1',
        'title': 'Run a meaningful local app eval',
        'isChecked': false,
      },
      {
        'id': 'check-2',
        'title': 'Compare Gemma against Qwen on task-agent behavior',
        'isChecked': false,
      },
    ],
    'log': [
      {
        'timestamp': '2026-06-21T09:00:00Z',
        'text':
            'User asked: rename this task to Validate local Gemma fallback, '
            'make it P1, due July 4 2026, and estimate two and a half hours.',
      },
      {
        'timestamp': '2026-06-21T09:05:00Z',
        'text':
            'The user reported that local Gemma went on and on in-app and '
            'produced no useful suggestions or summary.',
      },
    ],
  });
}

String _taskStateMarkdown(Task task) {
  return '''
- id: ${task.meta.id}
- title: ${task.data.title}
- status: OPEN
- priority: ${task.data.priority.short}
- estimate: none
- dueDate: none
- languageCode: ${task.data.languageCode}
- description: ${task.entryText?.plainText}
''';
}

const _projectContextJson = '''
{
  "id": "project-local-inference",
  "title": "Local inference reliability",
  "latestProjectAgentReport": {
    "tldr": "Qwen is the current local default. Gemma needs stronger validation before it is trusted.",
    "content": "Focus on runtime behavior that affects the Lotti task-agent workflow, not generic benchmark scores."
  }
}
''';

class _WorkflowEvalReport {
  _WorkflowEvalReport({
    required this.provider,
    required this.model,
    required this.result,
    required this.latencyMs,
    required this.systemPromptChars,
    required this.userPromptChars,
    required this.changeSetToolNames,
    required this.agentReportCount,
    required this.markdownPath,
    required this.jsonPath,
  });

  factory _WorkflowEvalReport.fromCaptured({
    required AiConfigInferenceProvider provider,
    required AiConfigModel model,
    required WakeResult result,
    required int latencyMs,
    required List<AgentDomainEntity> captured,
  }) {
    final payloads = captured.whereType<AgentMessagePayloadEntity>();
    final systemPrompt = payloads
        .map((payload) => payload.content)
        .where((content) => content['role'] == 'system')
        .map((content) => content['text'])
        .whereType<String>()
        .firstOrNull;
    final userPrompt = payloads
        .map((payload) => payload.content)
        .map((content) => content['text'])
        .whereType<String>()
        .where((text) => text.contains('## Current Task Context'))
        .firstOrNull;
    final changeSets = captured.whereType<ChangeSetEntity>().toList();
    final toolNames = changeSets
        .expand((changeSet) => changeSet.items)
        .map((item) => item.toolName)
        .toList(growable: false);
    final tempDir = Directory.systemTemp.path;
    return _WorkflowEvalReport(
      provider: provider,
      model: model,
      result: result,
      latencyMs: latencyMs,
      systemPromptChars: systemPrompt?.length ?? 0,
      userPromptChars: userPrompt?.length ?? 0,
      changeSetToolNames: toolNames,
      agentReportCount: captured.whereType<AgentReportEntity>().length,
      markdownPath:
          Platform.environment['LOCAL_TASK_AGENT_WORKFLOW_EVAL_MARKDOWN'] ??
          '$tempDir/lotti-local-task-agent-workflow-eval.md',
      jsonPath:
          Platform.environment['LOCAL_TASK_AGENT_WORKFLOW_EVAL_JSON'] ??
          '$tempDir/lotti-local-task-agent-workflow-eval.json',
    );
  }

  final AiConfigInferenceProvider provider;
  final AiConfigModel model;
  final WakeResult result;
  final int latencyMs;
  final int systemPromptChars;
  final int userPromptChars;
  final List<String> changeSetToolNames;
  final int agentReportCount;
  final String markdownPath;
  final String jsonPath;

  Map<String, Object?> toJson() {
    return {
      'kind': 'lotti.localTaskAgentWorkflowEvalReport',
      'provider': {
        'id': provider.id,
        'name': provider.name,
        'type': provider.inferenceProviderType.name,
        'baseUrl': provider.baseUrl,
      },
      'model': {
        'id': model.id,
        'providerModelId': model.providerModelId,
      },
      'wakeResult': {
        'success': result.success,
        'error': result.error,
        'mutatedEntries': result.mutatedEntries,
      },
      'latencyMs': latencyMs,
      'systemPromptChars': systemPromptChars,
      'userPromptChars': userPromptChars,
      'changeSetToolNames': changeSetToolNames,
      'agentReportCount': agentReportCount,
    };
  }

  String toMarkdown() {
    return '''
# Local Task-Agent Workflow Eval

Provider: `${provider.name}` (${provider.inferenceProviderType.name}) at `${provider.baseUrl}`

| Model | Wake success | Latency | System prompt chars | User prompt chars | Change-set tools | Reports |
| --- | ---: | ---: | ---: | ---: | --- | ---: |
| `${model.providerModelId}` | ${result.success ? 'yes' : 'no'} | $latencyMs ms | $systemPromptChars | $userPromptChars | ${changeSetToolNames.isEmpty ? '-' : changeSetToolNames.join(', ')} | $agentReportCount |

${result.error == null ? '' : 'Error: `${result.error}`\n'}
''';
  }
}

void _writeReport(_WorkflowEvalReport report) {
  (File(report.jsonPath)..parent.createSync(recursive: true)).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report.toJson()),
  );
  (File(
    report.markdownPath,
  )..parent.createSync(recursive: true)).writeAsStringSync(report.toMarkdown());
}
