import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_editor.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/eval/local_task_agent_inference_eval.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  final provider = AiConfigInferenceProvider(
    id: 'provider-omlx',
    baseUrl: 'http://127.0.0.1:8003/v1',
    apiKey: 'test-key',
    name: 'Local oMLX',
    createdAt: DateTime(2026, 6, 21),
    inferenceProviderType: InferenceProviderType.omlx,
  );

  const profile = LocalTaskAgentEvalProfile(
    name: 'local-model',
    providerModelId: 'local-model-id',
    modelClass: 'local-test',
  );

  test(
    'default scenario uses production task-agent scaffold and expectations',
    () {
      final scenario = defaultLocalTaskAgentWakeScenario();

      expect(
        defaultLocalTaskAgentEvalProfiles.map((profile) => profile.name),
        equals(['qwen36-a35b-a3b-mlx4', 'gemma4-26b-a4b-qat-mlx4']),
      );
      expect(scenario.systemPrompt, contains('You are a Task Agent'));
      expect(scenario.systemPrompt, contains('You are Laura.'));
      expect(scenario.systemPrompt, contains('## Your Personality'));
      expect(scenario.userMessage, contains('## Current Task Context'));
      expect(scenario.userMessage, contains('## Parent Project Context'));
      expect(
        scenario.expectedToolCalls.map((expected) => expected.name),
        equals([
          TaskAgentToolNames.setTaskTitle,
          TaskAgentToolNames.updateTaskEstimate,
          TaskAgentToolNames.updateTaskDueDate,
          TaskAgentToolNames.updateTaskPriority,
        ]),
      );
    },
  );

  test(
    'execution mode parser accepts known modes and rejects unknown input',
    () {
      expect(
        parseLocalTaskAgentEvalExecutionMode('twoPass'),
        LocalTaskAgentEvalExecutionMode.twoPass,
      );
      expect(
        parseLocalTaskAgentEvalExecutionMode('reportRevision'),
        LocalTaskAgentEvalExecutionMode.reportRevision,
      );
      expect(
        parseLocalTaskAgentEvalExecutionMode('reportEditing'),
        LocalTaskAgentEvalExecutionMode.reportEditing,
      );
      expect(
        () => parseLocalTaskAgentEvalExecutionMode('parallel'),
        throwsFormatException,
      );
    },
  );

  test('reasoning effort parser accepts empty and known values', () {
    expect(parseLocalTaskAgentEvalReasoningEffort(null), isNull);
    expect(parseLocalTaskAgentEvalReasoningEffort('  '), isNull);
    expect(
      parseLocalTaskAgentEvalReasoningEffort(' high '),
      ReasoningEffort.high,
    );
    expect(
      () => parseLocalTaskAgentEvalReasoningEffort('maximum'),
      throwsFormatException,
    );
  });

  test('report editor attempt parser accepts positive bounded values', () {
    expect(parseLocalTaskAgentEvalReportEditorAttempts(null), 1);
    expect(parseLocalTaskAgentEvalReportEditorAttempts(' 2 '), 2);
    expect(
      () => parseLocalTaskAgentEvalReportEditorAttempts('0'),
      throwsFormatException,
    );
    expect(
      () => parseLocalTaskAgentEvalReportEditorAttempts('4'),
      throwsFormatException,
    );
    expect(
      () => parseLocalTaskAgentEvalReportEditorAttempts('many'),
      throwsFormatException,
    );
  });

  test(
    'task-agent eval tool surface uses the full enabled task-agent registry',
    () {
      final expected = AgentToolRegistry.taskAgentTools
          .where((definition) => definition.enabled)
          .map((definition) => definition.name)
          .toList();

      expect(
        buildLocalTaskAgentEvalTools().map((tool) => tool.function.name),
        equals(expected),
      );
      expect(expected, contains(TaskAgentToolNames.updateReport));
      expect(expected, contains(TaskAgentToolNames.recordObservations));
    },
  );

  test('evidence synthesis puts scope policy next to update_report', () {
    final tools = buildLocalTaskAgentEvalTools(
      promptVariant: LocalTaskAgentEvalPromptVariant.evidenceSynthesis,
    );
    final reportTool = tools.singleWhere(
      (tool) => tool.function.name == TaskAgentToolNames.updateReport,
    );
    final mutationTool = tools.singleWhere(
      (tool) => tool.function.name == TaskAgentToolNames.setTaskTitle,
    );
    final reportProperties =
        reportTool.function.parameters!['properties']! as Map<String, dynamic>;

    expect(
      reportTool.function.description,
      allOf(
        contains('stale report claims'),
        contains('out-of-scope concepts completely'),
      ),
    );
    expect(
      mutationTool.function.description,
      isNot(contains('out-of-scope concepts')),
    );
    expect(
      (reportProperties['content']! as Map<String, dynamic>)['description'],
      contains('free-form Markdown'),
    );
  });

  test(
    'report editor material state keeps values and removes tool handles',
    () {
      final state = buildLocalTaskAgentEvalMaterialTaskState(const [
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.setTaskTitle,
          argumentsJson: '{"title":"Launch beta"}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.updateTaskPriority,
          argumentsJson: '{"priority":"P1"}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.updateTaskDueDate,
          argumentsJson: '{"dueDate":"2026-09-30"}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.updateTaskEstimate,
          argumentsJson: '{"minutes":90}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.addMultipleChecklistItems,
          argumentsJson:
              '{"items":[{"title":"Ask Ben"},{"title":"Review beta"}]}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.addChecklistItem,
          argumentsJson: '{"title":"Ship beta"}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.updateChecklistItems,
          argumentsJson: '{"items":[{"id":"private-id","isChecked":true}]}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.updateReport,
          argumentsJson: '{"oneLiner":"ignored"}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.setTaskTitle,
          argumentsJson: 'invalid',
        ),
      ]);

      expect(state, {
        'title': 'Launch beta',
        'priority': 'P1',
        'dueDate': '2026-09-30',
        'estimateMinutes': 90,
        'newChecklistItems': ['Ask Ben', 'Review beta', 'Ship beta'],
      });
      expect(jsonEncode(state), isNot(contains('private-id')));
      expect(buildLocalTaskAgentEvalMaterialTaskState(const []), isEmpty);
    },
  );

  test('eval contracts serialize report and markdown details', () {
    final scenario = defaultLocalTaskAgentWakeScenario();
    const nestedToolCall = LocalTaskAgentEvalToolCall(
      name: TaskAgentToolNames.setTaskTitle,
      argumentsJson:
          '{"title":"Validate efficient task-agent model","nested":{"items":[1,{"ok":true}]}}',
    );
    const invalidToolCall = LocalTaskAgentEvalToolCall(
      name: TaskAgentToolNames.updateTaskEstimate,
      argumentsJson: '[]',
    );
    final result = LocalTaskAgentEvalCaseResult(
      profile: profile,
      scenario: scenario,
      provider: provider,
      latencyMs: 42,
      inputTokens: 123,
      outputTokens: 45,
      thoughtsTokens: 12,
      cachedInputTokens: 34,
      finalContent: 'The model stopped before writing a valid report.',
      toolCalls: const [nestedToolCall, invalidToolCall],
      failureCategory: LocalTaskAgentEvalFailureCategory.invalidToolArguments,
    );
    final report = LocalTaskAgentEvalReport(
      provider: provider,
      profiles: const [profile],
      scenarios: [scenario],
      results: [result],
      temperature: 0.3,
      executionMode: LocalTaskAgentEvalExecutionMode.singlePass,
      reasoningEffort: ReasoningEffort.high,
    );

    expect(profile.toJson(), {
      'name': 'local-model',
      'providerModelId': 'local-model-id',
      'modelClass': 'local-test',
    });
    expect(
      nestedToolCall.containsExpectedArguments({
        'nested': {
          'items': [
            1,
            {'ok': true},
          ],
        },
      }),
      isTrue,
    );
    expect(
      nestedToolCall.containsExpectedArguments({'title': 'wrong'}),
      isFalse,
    );
    expect(invalidToolCall.hasJsonObjectArguments, isFalse);
    expect(invalidToolCall.toJson()['argumentsJsonValid'], isFalse);

    final json = report.toJson();
    expect(json['schemaVersion'], 6);
    expect(json['kind'], localTaskAgentEvalKind);
    expect(json['temperature'], 0.3);
    expect(json['executionMode'], 'singlePass');
    expect(json['reasoningEffort'], 'high');
    expect(json['reportEditorModelId'], isNull);
    expect(json['reportEditorMaxAttempts'], 1);
    expect(
      jsonDecode(report.toPrettyJson()),
      isA<Map<String, Object?>>().having(
        (json) => json['kind'],
        'kind',
        localTaskAgentEvalKind,
      ),
    );
    expect(
      (json['scenarios']! as List<Object?>).single,
      containsPair('maxTurns', scenario.maxTurns),
    );
    expect(nestedToolCall.toJson()['phase'], 'main');
    expect(
      result.toJson()['toolCallNames']! as List<Object?>,
      equals([
        TaskAgentToolNames.setTaskTitle,
        TaskAgentToolNames.updateTaskEstimate,
      ]),
    );
    expect(result.toJson()['thoughtsTokens'], 12);
    expect(result.toJson()['cachedInputTokens'], 34);

    final markdown = report.toMarkdown();
    expect(markdown, contains('| local-model | `local-model-id` |'));
    expect(markdown, contains('reasoning effort `high`'));
    expect(markdown, contains('## Failures'));
    expect(markdown, contains('invalidToolArguments'));
  });

  test('scenarios expose the report language explicitly', () {
    final scenarios = defaultMeliousTaskAgentEvalScenarios();

    expect(
      scenarios
          .firstWhere(
            (scenario) => scenario.id.startsWith('german_voice_plan'),
          )
          .languageCode,
      'de',
    );
    expect(
      scenarios
          .firstWhere(
            (scenario) => scenario.id.startsWith('spanish_mixed_context'),
          )
          .toJson()['languageCode'],
      'es',
    );
    expect(defaultLocalTaskAgentWakeScenario().languageCode, 'en');
  });

  test('Melious matrix covers every configured prompt variant', () {
    final defaultScenarios = defaultMeliousTaskAgentEvalScenarios();
    final scenarios = defaultMeliousTaskAgentEvalScenarios(
      variants: LocalTaskAgentEvalPromptVariant.values,
    );

    expect(defaultMeliousTaskAgentEvalProfiles.map((profile) => profile.name), [
      'mistral-small-4-baseline',
      'qwen3.5-122b-a10b-candidate',
      'deepseek-v4-flash-candidate',
      'glm-5.2-reference',
    ]);
    expect(defaultScenarios, hasLength(13));
    expect(
      defaultScenarios.map((scenario) => scenario.promptVariant).toSet(),
      {LocalTaskAgentEvalPromptVariant.production},
    );
    expect(
      scenarios,
      hasLength(13 * LocalTaskAgentEvalPromptVariant.values.length),
    );
    expect(
      scenarios.map((scenario) => scenario.promptVariant).toSet(),
      LocalTaskAgentEvalPromptVariant.values.toSet(),
    );
    expect(
      scenarios.map((scenario) => scenario.id),
      containsAll([
        'metadata_explicit_production',
        'german_voice_plan_production',
        'progress_update_production',
        'metadata_explicit_compactModel',
        'german_voice_plan_compactModel',
        'progress_update_compactModel',
        'no_op_background_refresh_production',
        'duplicate_checklist_reconciliation_production',
        'stale_deadline_user_override_production',
        'messy_german_transcript_production',
        'deferred_scope_filter_production',
        'active_deployment_constraint_production',
        'user_completed_item_resurfaced_production',
        'spanish_mixed_context_production',
        'external_link_and_completion_production',
        'latest_deadline_wins_production',
        'messy_german_transcript_qualityFocused',
        'latest_deadline_wins_qualityFocused',
        'messy_german_transcript_evidenceSynthesis',
        'deferred_scope_filter_evidenceSynthesis',
        'active_deployment_constraint_evidenceSynthesis',
        'latest_deadline_wins_evidenceSynthesis',
      ]),
    );
    final compact = scenarios.firstWhere(
      (scenario) =>
          scenario.promptVariant ==
          LocalTaskAgentEvalPromptVariant.compactModel,
    );
    expect(compact.systemPrompt, contains('Compact-Model Execution Protocol'));
    expect(compact.systemPrompt, contains('MANDATORY FINAL TOOL CALL'));
    final qualityFocused = scenarios.firstWhere(
      (scenario) =>
          scenario.promptVariant ==
          LocalTaskAgentEvalPromptVariant.qualityFocused,
    );
    expect(qualityFocused.systemPrompt, contains('Report Quality Gate'));
    expect(qualityFocused.systemPrompt, contains('Omit empty sections'));
  });

  test(
    'prompt variant parser accepts known names and rejects unknown ones',
    () {
      expect(
        parseLocalTaskAgentEvalPromptVariant(' production '),
        LocalTaskAgentEvalPromptVariant.production,
      );
      expect(
        parseLocalTaskAgentEvalPromptVariant('compactModel'),
        LocalTaskAgentEvalPromptVariant.compactModel,
      );
      expect(
        parseLocalTaskAgentEvalPromptVariant('qualityFocused'),
        LocalTaskAgentEvalPromptVariant.qualityFocused,
      );
      expect(
        parseLocalTaskAgentEvalPromptVariant('conciseReport'),
        LocalTaskAgentEvalPromptVariant.conciseReport,
      );
      expect(
        parseLocalTaskAgentEvalPromptVariant('evidenceSynthesis'),
        LocalTaskAgentEvalPromptVariant.evidenceSynthesis,
      );
      expect(
        () => parseLocalTaskAgentEvalPromptVariant('compact'),
        throwsFormatException,
      );
    },
  );

  test('concise report variant replaces the decorative report contract', () {
    final scenario = defaultMeliousTaskAgentEvalScenarios(
      variants: const [LocalTaskAgentEvalPromptVariant.conciseReport],
    ).first;

    expect(scenario.systemPrompt, contains('specific current-state tagline'));
    expect(scenario.systemPrompt, contains('Omit empty sections'));
    expect(scenario.systemPrompt, isNot(contains('slightly motivational')));
    expect(scenario.systemPrompt, isNot(contains('1-2 relevant emojis')));
  });

  test(
    'evidence synthesis variant filters deferred ideas before reporting',
    () {
      final scenarios = defaultMeliousTaskAgentEvalScenarios(
        variants: const [LocalTaskAgentEvalPromptVariant.evidenceSynthesis],
      );
      final scenario = scenarios.firstWhere(
        (scenario) => scenario.id.startsWith('messy_german_transcript'),
      );

      expect(
        scenario.systemPrompt,
        contains('Evidence-First Synthesis Protocol'),
      );
      expect(scenario.systemPrompt, contains('Mutation coverage:'));
      expect(scenario.systemPrompt, contains('adopted commitment'));
      expect(scenario.systemPrompt, isNot(contains('- `## Decisions`:')));
      expect(scenario.systemPrompt, contains('material qualifiers'));
      expect(scenario.systemPrompt, contains('internal JSON IDs'));
      expect(
        scenario.systemPrompt,
        contains('idiomatically in `languageCode`'),
      );
      expect(
        scenario.systemPrompt,
        isNot(contains('## Mistral Evidence Examples')),
      );
      expect(scenario.systemPrompt, contains('specific current-state tagline'));
      expect(scenario.systemPrompt, isNot(contains('1-2 relevant emojis')));
    },
  );

  test(
    'held-out scope scenarios distinguish discarded and active constraints',
    () {
      final scenarios = defaultMeliousTaskAgentEvalScenarios(
        variants: const [LocalTaskAgentEvalPromptVariant.evidenceSynthesis],
      );
      final deferred = scenarios.firstWhere(
        (scenario) => scenario.id.startsWith('deferred_scope_filter'),
      );
      final activeConstraint = scenarios.firstWhere(
        (scenario) => scenario.id.startsWith('active_deployment_constraint'),
      );

      expect(
        deferred.forbiddenReportTerms,
        containsAll(['dashboard', 'analytics']),
      );
      expect(deferred.userMessage, contains('as checklist items'));
      expect(
        deferred.requiredToolArgumentTermGroups[TaskAgentToolNames
            .addMultipleChecklistItems],
        containsAll([
          ['security'],
          ['priya'],
          ['webhook'],
        ]),
      );
      expect(
        activeConstraint.requiredReportTermGroups,
        containsAll([
          ['legal'],
          ['marta'],
          ['deploy'],
        ]),
      );
      expect(
        activeConstraint.expectedToolCalls.single.name,
        TaskAgentToolNames.updateChecklistItems,
      );
    },
  );

  test('progress scenario accepts an unambiguous abbreviated deadline', () {
    final scenario = defaultMeliousTaskAgentEvalScenarios().firstWhere(
      (scenario) => scenario.id == 'progress_update_production',
    );

    expect(scenario.requiredReportTermGroups.last, contains('oct 15'));
  });

  test('resurfaced work accepts natural recurrence wording', () {
    final scenario = defaultMeliousTaskAgentEvalScenarios().firstWhere(
      (scenario) => scenario.id == 'user_completed_item_resurfaced_production',
    );

    expect(
      scenario.requiredReportTermGroups,
      contains(
        equals([
          'reappeared',
          'resurfaced',
          'again',
          'recurrence',
          'recurred',
        ]),
      ),
    );
    expect(
      scenario.requiredReportTermGroups.last,
      containsAll(['root cause', 'investigat']),
    );
  });

  test(
    'metadata report checks task specificity without repeating its title',
    () {
      final scenario = defaultMeliousTaskAgentEvalScenarios().firstWhere(
        (scenario) => scenario.id == 'metadata_explicit_production',
      );

      expect(scenario.requiredReportTermGroups.first, [
        'candidate',
        'task-agent',
      ]);
      expect(
        scenario.requiredReportTermGroups.expand((group) => group),
        isNot(contains('validate efficient task-agent model')),
      );
    },
  );

  test('scenario selection rejects unknown IDs', () {
    final scenarios = defaultMeliousTaskAgentEvalScenarios();

    expect(
      selectLocalTaskAgentEvalScenarios(scenarios, const [
        'german_voice_plan_production',
      ]).single.id,
      'german_voice_plan_production',
    );
    expect(
      () => selectLocalTaskAgentEvalScenarios(scenarios, const ['missing']),
      throwsArgumentError,
    );
  });

  test('quality scoring checks report facts, IDs, and tool arguments', () {
    final scenario = defaultMeliousTaskAgentEvalScenarios().firstWhere(
      (scenario) => scenario.id.startsWith('german_voice_plan'),
    );
    final result = LocalTaskAgentEvalCaseResult(
      profile: profile,
      scenario: scenario,
      provider: provider,
      latencyMs: 10,
      toolCalls: const [
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.addMultipleChecklistItems,
          argumentsJson:
              '{"items":[{"title":"API-Umfang mit Ben klaeren"},{"title":"Figma-Prototyp fertigstellen"},{"title":"Anmeldung implementieren"},{"title":"Lea um Security-Review bitten"}]}',
        ),
        LocalTaskAgentEvalToolCall(
          name: TaskAgentToolNames.updateReport,
          argumentsJson:
              '{"oneLiner":"Beta bis 30. September","tldr":"Ben klaert den API-Umfang; Figma, Anmeldung und Leas Security-Review folgen.","content":"Alle konkreten Schritte sind erfasst."}',
        ),
      ],
      failureCategory: LocalTaskAgentEvalFailureCategory.none,
    );

    expect(result.qualityCheckCount, 11);
    expect(result.passedQualityCheckCount, 11);
    expect(result.qualityScore, 1);
    expect(result.reportToolCall?.name, TaskAgentToolNames.updateReport);
  });

  test(
    'parseLocalTaskAgentEvalProfile trims and validates name=model pairs',
    () {
      final parsed = parseLocalTaskAgentEvalProfile(
        '  gemma4 = gemma-4-26B-A4B-it-QAT-MLX-4bit  ',
      );

      expect(parsed.name, 'gemma4');
      expect(parsed.providerModelId, 'gemma-4-26B-A4B-it-QAT-MLX-4bit');
      expect(parsed.modelClass, 'gemma4');
      expect(
        () => parseLocalTaskAgentEvalProfile('gemma4'),
        throwsFormatException,
      );
      expect(
        () => parseLocalTaskAgentEvalProfile('=model'),
        throwsFormatException,
      );
      expect(
        () => parseLocalTaskAgentEvalProfile('name='),
        throwsFormatException,
      );
      for (final value in [' =model', 'name= ']) {
        expect(
          () => parseLocalTaskAgentEvalProfile(value),
          throwsFormatException,
        );
      }
    },
  );

  test('parseLocalTaskAgentEvalTemperature validates the accepted range', () {
    expect(parseLocalTaskAgentEvalTemperature(null), isNull);
    expect(parseLocalTaskAgentEvalTemperature('   '), isNull);
    expect(parseLocalTaskAgentEvalTemperature('0'), 0);
    expect(parseLocalTaskAgentEvalTemperature(' 0.7 '), 0.7);
    expect(parseLocalTaskAgentEvalTemperature('2'), 2);

    for (final value in ['nan', 'NaN', 'Infinity', '-0.1', '2.1']) {
      expect(
        () => parseLocalTaskAgentEvalTemperature(value),
        throwsFormatException,
      );
    }
  });

  test('runner classifies empty inference responses', () async {
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: _QueuedInferenceRepository([const []]),
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultLocalTaskAgentWakeScenario()],
    );

    expect(
      report.results.single.failureCategory,
      LocalTaskAgentEvalFailureCategory.emptyResponse,
    );
  });

  test('runner classifies invalid tool arguments', () async {
    final category = await _runSingleFailureScenario(
      provider: provider,
      profile: profile,
      responses: [
        _toolCalls([
          (
            name: TaskAgentToolNames.setTaskTitle,
            argumentsJson: '{"title":',
          ),
        ]),
      ],
    );

    expect(category, LocalTaskAgentEvalFailureCategory.invalidToolArguments);
  });

  test('runner classifies missing expected tool calls', () async {
    final category = await _runSingleFailureScenario(
      provider: provider,
      profile: profile,
      responses: [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Report exists',
              'tldr': 'Report exists.',
              'content': '## TLDR\nReport exists.',
            }),
          ),
        ]),
      ],
    );

    expect(category, LocalTaskAgentEvalFailureCategory.missingExpectedToolCall);
  });

  test('runner classifies expected argument mismatches', () async {
    final category = await _runSingleFailureScenario(
      provider: provider,
      profile: profile,
      responses: [
        _toolCalls([
          ..._expectedMetadataToolCalls(
            title: 'Investigate a different local model',
          ),
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Report exists',
              'tldr': 'Report exists.',
              'content': '## TLDR\nReport exists.',
            }),
          ),
        ]),
      ],
    );

    expect(category, LocalTaskAgentEvalFailureCategory.argumentMismatch);
  });

  test(
    'runner exercises real conversation continuation until update_report',
    () async {
      final scenario = defaultLocalTaskAgentWakeScenario();
      final fakeInference = _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.setTaskTitle,
              argumentsJson: '{"title":"Validate efficient task-agent model"}',
            ),
            (
              name: TaskAgentToolNames.updateTaskEstimate,
              argumentsJson: '{"minutes":150}',
            ),
            (
              name: TaskAgentToolNames.updateTaskDueDate,
              argumentsJson: '{"dueDate":"2026-07-04"}',
            ),
            (
              name: TaskAgentToolNames.updateTaskPriority,
              argumentsJson: '{"priority":"P1"}',
            ),
          ]),
        ],
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Efficient task-agent model is being validated',
                'tldr': 'The local model eval now exercises a real wake shape.',
                'content': '## TLDR\nThe stronger local eval passed.',
              }),
            ),
          ]),
        ],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: fakeInference,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [scenario],
      );

      final result = report.results.single;
      expect(result.passed, isTrue);
      expect(result.failureCategory, LocalTaskAgentEvalFailureCategory.none);
      expect(fakeInference.requests, hasLength(2));
      expect(
        fakeInference.requests.first.toolNames,
        containsAll([
          TaskAgentToolNames.setTaskTitle,
          TaskAgentToolNames.updateReport,
          TaskAgentToolNames.recordObservations,
        ]),
      );
      expect(
        jsonEncode(
          fakeInference.requests.first.messages
              .map((message) => message.toJson())
              .toList(),
        ),
        contains('## Current Task Context'),
      );
    },
  );

  test('runner records inference failure and continues the matrix', () async {
    const secondProfile = LocalTaskAgentEvalProfile(
      name: 'second-local-model',
      providerModelId: 'second-local-model-id',
      modelClass: 'local-test',
    );
    final fakeInference = _FailThenSucceedInferenceRepository();
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: fakeInference,
      forceReportRetry: false,
    );

    final report = await runner.run(
      profiles: const [profile, secondProfile],
      scenarios: [defaultLocalTaskAgentWakeScenario()],
    );

    expect(report.results, hasLength(2));
    expect(
      report.results.first.failureCategory,
      LocalTaskAgentEvalFailureCategory.inferenceFailed,
    );
    expect(
      report.results.first.finalContent,
      'Bad state: connection refused',
    );
    expect(
      report.results.last.failureCategory,
      LocalTaskAgentEvalFailureCategory.none,
    );
    expect(
      fakeInference.requests.map((request) => request.model),
      equals(['local-model-id', 'second-local-model-id']),
    );
  });

  test(
    'runner converts conversation creation failures into case results',
    () async {
      final conversationRepository = _ThrowingConversationRepository(
        _ConversationFailurePoint.create,
      );
      addTearDown(conversationRepository.disposeManager);
      final runner = LocalTaskAgentInferenceEvalRunner(
        provider: provider,
        conversationRepository: conversationRepository,
        inferenceRepository: _QueuedInferenceRepository(const []),
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      final result = report.results.single;
      expect(
        result.failureCategory,
        LocalTaskAgentEvalFailureCategory.inferenceFailed,
      );
      expect(result.errorMessage, 'Bad state: create failed');
      expect(result.finalContent, contains('create failed'));
      expect(conversationRepository.deleteCount, 0);
    },
  );

  test('runner converts send failures and deletes the conversation', () async {
    final conversationRepository = _ThrowingConversationRepository(
      _ConversationFailurePoint.send,
    );
    addTearDown(conversationRepository.disposeManager);
    final runner = LocalTaskAgentInferenceEvalRunner(
      provider: provider,
      conversationRepository: conversationRepository,
      inferenceRepository: _QueuedInferenceRepository(const []),
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultLocalTaskAgentWakeScenario()],
    );

    final result = report.results.single;
    expect(
      result.failureCategory,
      LocalTaskAgentEvalFailureCategory.inferenceFailed,
    );
    expect(result.errorMessage, 'Bad state: send failed');
    expect(result.finalContent, contains('send failed'));
    expect(conversationRepository.deleteCount, 1);
  });

  test(
    'runner recovers a missing first report with report-only tools',
    () async {
      final fakeInference = _QueuedInferenceRepository([
        [
          _toolCalls(_expectedMetadataToolCalls()),
        ],
        [_content('The requested task fields are updated.')],
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Validate efficient task-agent model',
                'tldr': 'P1, due July 4, with a 150 minute estimate.',
                'content': 'Compare the candidate against the reference model.',
              }),
            ),
          ]),
          _usage(inputTokens: 25, outputTokens: 8),
        ],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: fakeInference,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      expect(
        report.results.single.failureCategory,
        LocalTaskAgentEvalFailureCategory.none,
      );
      expect(report.results.single.usedForcedReportRetry, isTrue);
      expect(report.results.single.inputTokens, 25);
      expect(report.results.single.outputTokens, 8);
      expect(fakeInference.requests, hasLength(3));
      expect(fakeInference.requests.last.toolNames, [
        TaskAgentToolNames.updateReport,
      ]);
    },
  );

  test(
    'runner fails simple tool smoke output when final report is missing',
    () async {
      final fakeInference = _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.setTaskTitle,
              argumentsJson: '{"title":"Validate efficient task-agent model"}',
            ),
            (
              name: TaskAgentToolNames.updateTaskEstimate,
              argumentsJson: '{"minutes":150}',
            ),
            (
              name: TaskAgentToolNames.updateTaskDueDate,
              argumentsJson: '{"dueDate":"2026-07-04"}',
            ),
            (
              name: TaskAgentToolNames.updateTaskPriority,
              argumentsJson: '{"priority":"P1"}',
            ),
          ]),
        ],
        [_content('Done.')],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: fakeInference,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      expect(
        report.results.single.failureCategory,
        LocalTaskAgentEvalFailureCategory.missingReport,
      );
    },
  );

  test('runner flags unexpected production-wake tool calls', () async {
    final fakeInference = _QueuedInferenceRepository([
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.setTaskTitle,
            argumentsJson: '{"title":"Validate efficient task-agent model"}',
          ),
          (
            name: TaskAgentToolNames.updateTaskEstimate,
            argumentsJson: '{"minutes":150}',
          ),
          (
            name: TaskAgentToolNames.updateTaskDueDate,
            argumentsJson: '{"dueDate":"2026-07-04"}',
          ),
          (
            name: TaskAgentToolNames.updateTaskPriority,
            argumentsJson: '{"priority":"P1"}',
          ),
          (
            name: TaskAgentToolNames.setTaskStatus,
            argumentsJson: '{"status":"IN PROGRESS"}',
          ),
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Report exists',
              'tldr': 'Report exists.',
              'content': '## TLDR\nReport exists.',
            }),
          ),
        ]),
      ],
    ]);
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: fakeInference,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultLocalTaskAgentWakeScenario()],
    );

    expect(
      report.results.single.failureCategory,
      LocalTaskAgentEvalFailureCategory.unexpectedToolCall,
    );
  });

  test('runner flags missing required report facts', () async {
    final scenario = defaultMeliousTaskAgentEvalScenarios().firstWhere(
      (scenario) => scenario.id.startsWith('german_voice_plan'),
    );
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.addMultipleChecklistItems,
              argumentsJson: jsonEncode({
                'items': [
                  {'title': 'API-Umfang mit Ben klaeren'},
                  {'title': 'Figma-Prototyp fertigstellen'},
                  {'title': 'Anmeldung implementieren'},
                  {'title': 'Lea um Security-Review bitten'},
                ],
              }),
            ),
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Beta-Plan steht',
                'tldr': 'Ben, Figma, Anmeldung und Leas Security-Review.',
                'content': 'Alle vier Schritte sind geplant.',
              }),
            ),
          ]),
        ],
      ]),
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [scenario],
    );

    expect(
      report.results.single.failureCategory,
      LocalTaskAgentEvalFailureCategory.missingRequiredContent,
    );
  });

  test('runner flags internal IDs leaked into the report', () async {
    final scenario = defaultMeliousTaskAgentEvalScenarios().firstWhere(
      (scenario) => scenario.id.startsWith('metadata_explicit'),
    );
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: _QueuedInferenceRepository([
        [
          _toolCalls([
            ..._expectedMetadataToolCalls(),
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Validate efficient task-agent model',
                'tldr': 'P1, due July 4, with a 150 minute estimate.',
                'content':
                    'Compare against the reference and complete check-1 before 2026-07-04.',
              }),
            ),
          ]),
        ],
      ]),
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [scenario],
    );

    expect(
      report.results.single.failureCategory,
      LocalTaskAgentEvalFailureCategory.forbiddenReportContent,
    );
  });

  test(
    'runner rewards a no-op note and rejects unnecessary report churn',
    () async {
      final scenario = defaultMeliousTaskAgentEvalScenarios().firstWhere(
        (scenario) => scenario.id.startsWith('no_op_background_refresh'),
      );
      final passingRunner = _createRunner(
        provider: provider,
        inferenceRepository: _QueuedInferenceRepository([
          [_content('No task or report changes were needed.')],
        ]),
      );

      final passing = await passingRunner.run(
        profiles: const [profile],
        scenarios: [scenario],
      );

      expect(
        passing.results.single.failureCategory,
        LocalTaskAgentEvalFailureCategory.none,
      );
      expect(passing.results.single.qualityScore, 1);

      final failingRunner = _createRunner(
        provider: provider,
        inferenceRepository: _QueuedInferenceRepository([
          [
            _toolCalls([
              (
                name: TaskAgentToolNames.updateReport,
                argumentsJson: jsonEncode({
                  'oneLiner': 'Tax return remains complete',
                  'tldr': 'Nothing changed.',
                  'content': 'The return remains complete.',
                }),
              ),
            ]),
          ],
        ]),
      );

      final failing = await failingRunner.run(
        profiles: const [profile],
        scenarios: [scenario],
      );

      expect(
        failing.results.single.failureCategory,
        LocalTaskAgentEvalFailureCategory.forbiddenToolCall,
      );
    },
  );

  test(
    'two-pass runner isolates mutation tools from the report tool',
    () async {
      final inferenceRepository = _QueuedInferenceRepository([
        [
          _content('Mutation analysis complete.'),
          _usage(
            inputTokens: 100,
            outputTokens: 20,
            thoughtsTokens: 12,
            cachedInputTokens: 5,
          ),
        ],
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Local model evaluation planned',
                'tldr': 'The evaluation is ready to run.',
                'content':
                    'Validate efficient task-agent model at P1 by July 4, 2026. '
                    'The estimate is 150 minutes and the reference is the baseline.',
              }),
            ),
          ]),
          _usage(
            inputTokens: 40,
            outputTokens: 10,
            thoughtsTokens: 3,
            cachedInputTokens: 2,
          ),
        ],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: inferenceRepository,
        executionMode: LocalTaskAgentEvalExecutionMode.twoPass,
        temperature: 0,
        reasoningEffort: ReasoningEffort.high,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      expect(report.results.single.usedForcedReportRetry, isTrue);
      expect(report.results.single.inputTokens, 140);
      expect(report.results.single.outputTokens, 30);
      expect(report.results.single.thoughtsTokens, 15);
      expect(report.results.single.cachedInputTokens, 7);
      expect(report.reasoningEffort, ReasoningEffort.high);
      expect(inferenceRepository.requests, hasLength(2));
      expect(
        inferenceRepository.requests.first.toolNames,
        isNot(contains(TaskAgentToolNames.updateReport)),
      );
      expect(inferenceRepository.requests.last.toolNames, [
        TaskAgentToolNames.updateReport,
      ]);
      expect(
        inferenceRepository.requests.map((request) => request.temperature),
        everyElement(0),
      );
    },
  );

  test(
    'report revision replaces an unsupported draft with grounded prose',
    () async {
      final scenario =
          defaultMeliousTaskAgentEvalScenarios(
            variants: const [
              LocalTaskAgentEvalPromptVariant.evidenceSynthesis,
            ],
          ).firstWhere(
            (scenario) =>
                scenario.id.startsWith('user_completed_item_resurfaced'),
          );
      final inferenceRepository = _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Sync fix deployed',
                'tldr': 'The sync issue reappeared and is blocked.',
                'content': 'The deployed fix failed validation.',
              }),
            ),
          ]),
          _usage(inputTokens: 100, outputTokens: 20),
        ],
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner':
                    'Duplicate sync issue resurfaced after reconnection',
                'tldr':
                    'The user-marked-complete fix did not prevent recurrence. '
                    'Root-cause investigation is the current risk.',
                'content':
                    'QA observed the sync issue again after reconnecting two '
                    'devices. Investigate the root cause before deciding '
                    'whether the completed checklist state needs follow-up.',
              }),
            ),
          ]),
          _usage(inputTokens: 50, outputTokens: 10),
        ],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: inferenceRepository,
        executionMode: LocalTaskAgentEvalExecutionMode.reportRevision,
        temperature: 0,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [scenario],
      );

      final result = report.results.single;
      expect(result.failureCategory, LocalTaskAgentEvalFailureCategory.none);
      expect(result.inputTokens, 150);
      expect(result.outputTokens, 30);
      expect(result.usedForcedReportRetry, isTrue);
      expect(
        result.toolCalls.where(
          (call) => call.name == TaskAgentToolNames.updateReport,
        ),
        hasLength(2),
      );
      expect(inferenceRepository.requests, hasLength(2));
      expect(
        inferenceRepository.requests.last.toolNames,
        [TaskAgentToolNames.updateReport],
      );
    },
  );

  test('report editing retries once with exact validation issues', () async {
    final inferenceRepository = _QueuedInferenceRepository([
      [
        _toolCalls([
          ..._expectedMetadataToolCalls(),
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Task configured for model validation',
              'tldr': 'P1, due July 4, 2026, estimated 150 minutes.',
              'content': '## Next actions\nRun eval and compare reference.',
            }),
          ),
        ]),
        _usage(inputTokens: 100, outputTokens: 20),
      ],
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the evaluation',
              'tldr': 'Two actions remain. No blockers.',
              'content': 'Checklist created.',
            }),
          ),
        ]),
        _usage(inputTokens: 50, outputTokens: 10),
      ],
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the P1 evaluation by July 4, 2026',
              'tldr': 'The 150-minute evaluation has two remaining actions.',
              'content':
                  'Run the local app eval, then compare the candidate with '
                  'the reference model.',
            }),
          ),
        ]),
        _usage(inputTokens: 40, outputTokens: 8),
      ],
    ]);
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: inferenceRepository,
      executionMode: LocalTaskAgentEvalExecutionMode.reportEditing,
      reportEditorModelId: 'qwen-report-editor',
      reportEditorMaxAttempts: 2,
      temperature: 0,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultLocalTaskAgentWakeScenario()],
    );

    final result = report.results.single;
    expect(result.failureCategory, LocalTaskAgentEvalFailureCategory.none);
    expect(result.reportEditorAttempts, 2);
    expect(result.reportEditorValidationIssues, isEmpty);
    expect(result.inputTokens, 190);
    expect(result.outputTokens, 38);
    expect(inferenceRepository.requests, hasLength(3));
    final repairMessages = jsonEncode(
      inferenceRepository.requests.last.messages
          .map((message) => message.toJson())
          .toList(),
    );
    expect(repairMessages, contains('requiredCorrections'));
    expect(repairMessages, contains('missingPriority'));
    expect(repairMessages, contains('processNarration'));
    expect(result.reportText, contains('150-minute'));
  });

  test(
    'report editing uses an isolated model and compact committed evidence',
    () async {
      final inferenceRepository = _QueuedInferenceRepository([
        [
          _toolCalls([
            ..._expectedMetadataToolCalls(),
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Task configured for model validation',
                'tldr': 'Metadata updated. Ready to begin.',
                'content':
                    '## Progress\nTask configured.\n\n## Blockers\nNone.',
              }),
            ),
          ]),
          _usage(inputTokens: 100, outputTokens: 20),
        ],
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Run the local model evaluation by July 4, 2026',
                'tldr':
                    'This P1 task has a 150-minute budget to validate the '
                    'candidate task-agent model.',
                'content':
                    'Run the local app eval, then compare the candidate with '
                    'the reference model.',
              }),
            ),
          ]),
          _usage(inputTokens: 50, outputTokens: 10),
        ],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: inferenceRepository,
        executionMode: LocalTaskAgentEvalExecutionMode.reportEditing,
        reportEditorModelId: 'qwen-report-editor',
        temperature: 0,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      final result = report.results.single;
      expect(result.failureCategory, LocalTaskAgentEvalFailureCategory.none);
      expect(result.inputTokens, 150);
      expect(result.outputTokens, 30);
      expect(result.usedForcedReportRetry, isTrue);
      expect(result.reportEditorAttempts, 1);
      expect(result.reportEditorValidationIssues, isEmpty);
      expect(
        result.reportToolCall?.phase,
        LocalTaskAgentEvalToolCallPhase.reportPass,
      );
      expect(result.reportText, contains('Run the local app eval'));
      expect(report.reportEditorModelId, 'qwen-report-editor');
      expect(report.toJson()['reportEditorModelId'], 'qwen-report-editor');
      expect(
        report.toMarkdown(),
        contains('report editor `qwen-report-editor`'),
      );
      expect(inferenceRepository.requests, hasLength(2));
      expect(inferenceRepository.requests.first.model, profile.providerModelId);
      expect(inferenceRepository.requests.last.model, 'qwen-report-editor');
      expect(inferenceRepository.requests.last.toolNames, [
        TaskAgentToolNames.updateReport,
      ]);
      final editorMessages = jsonEncode(
        inferenceRepository.requests.last.messages
            .map((message) => message.toJson())
            .toList(),
      );
      expect(editorMessages, contains('draftReport'));
      expect(editorMessages, contains('materialTaskState'));
      expect(editorMessages, contains('estimateMinutes'));
      expect(editorMessages, contains('P1'));
      expect(editorMessages, isNot(contains('committedMutations')));
      expect(
        editorMessages,
        isNot(contains(TaskAgentToolNames.updateTaskPriority)),
      );
      expect(editorMessages, isNot(contains('taskContext')));
      expect(editorMessages, isNot(contains('## Current Task Context')));
      expect(
        editorMessages,
        isNot(contains('You are a persistent Task Agent')),
      );
    },
  );

  test(
    'report editing fails when the model does not return a revision',
    () async {
      final inferenceRepository = _QueuedInferenceRepository([
        [
          _toolCalls([
            ..._expectedMetadataToolCalls(),
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Task configured for model validation',
                'tldr': 'Metadata updated. Ready to begin.',
                'content': 'Task configured.',
              }),
            ),
          ]),
        ],
        [_content('No revision needed.')],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: inferenceRepository,
        executionMode: LocalTaskAgentEvalExecutionMode.reportEditing,
        temperature: 0,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      expect(
        report.results.single.failureCategory,
        LocalTaskAgentEvalFailureCategory.missingReportRevision,
      );
      expect(inferenceRepository.requests.last.model, profile.providerModelId);
    },
  );

  test('report editing fails after the final invalid revision', () async {
    final inferenceRepository = _QueuedInferenceRepository([
      [
        _toolCalls([
          ..._expectedMetadataToolCalls(),
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Task configured for model validation',
              'tldr': 'P1, due July 4, 2026, estimated 150 minutes.',
              'content': 'Run eval and compare reference.',
            }),
          ),
        ]),
      ],
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the evaluation',
              'tldr': 'No blockers.',
              'content': 'Checklist created.',
            }),
          ),
        ]),
      ],
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the evaluation',
              'tldr': 'Ready to begin.',
              'content': 'The checklist contains two items.',
            }),
          ),
        ]),
      ],
    ]);
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: inferenceRepository,
      executionMode: LocalTaskAgentEvalExecutionMode.reportEditing,
      reportEditorMaxAttempts: 2,
      temperature: 0,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultLocalTaskAgentWakeScenario()],
    );

    final result = report.results.single;
    expect(
      result.failureCategory,
      LocalTaskAgentEvalFailureCategory.invalidReportRevision,
    );
    expect(result.reportEditorAttempts, 2);
    expect(
      result.reportEditorValidationIssues,
      contains(TaskAgentReportRevisionIssue.processNarration),
    );
    expect(inferenceRepository.requests, hasLength(3));
  });

  test('runner rejects speculative content in checklist arguments', () async {
    final scenario = defaultMeliousTaskAgentEvalScenarios().firstWhere(
      (scenario) => scenario.id.startsWith('messy_german_transcript'),
    );
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.addMultipleChecklistItems,
              argumentsJson: jsonEncode({
                'items': [
                  {'title': 'CSV-Export reparieren'},
                  {'title': 'Sam nach Testdaten fragen'},
                  {'title': 'Regressionstest ausfuehren'},
                  {'title': 'Newsletter vorbereiten'},
                ],
              }),
            ),
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Export-Reparatur geplant',
                'tldr':
                    'Export, Testdaten von Sam und Regressionstest stehen an.',
                'content': 'Die drei verbindlichen Schritte sind erfasst.',
              }),
            ),
          ]),
        ],
      ]),
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [scenario],
    );

    final result = report.results.single;
    expect(
      result.failureCategory,
      LocalTaskAgentEvalFailureCategory.forbiddenToolArguments,
    );
    expect(result.qualityCheckCount, greaterThan(0));
    expect(result.passedQualityCheckCount, lessThan(result.qualityCheckCount));
  });
}

Future<LocalTaskAgentEvalFailureCategory> _runSingleFailureScenario({
  required AiConfigInferenceProvider provider,
  required LocalTaskAgentEvalProfile profile,
  required List<CreateChatCompletionStreamResponse> responses,
}) async {
  final runner = _createRunner(
    provider: provider,
    inferenceRepository: _QueuedInferenceRepository([responses]),
  );

  final report = await runner.run(
    profiles: [profile],
    scenarios: [defaultLocalTaskAgentWakeScenario()],
  );

  return report.results.single.failureCategory;
}

LocalTaskAgentInferenceEvalRunner _createRunner({
  required AiConfigInferenceProvider provider,
  required InferenceRepositoryInterface inferenceRepository,
  bool forceReportRetry = true,
  double temperature = 0.3,
  ReasoningEffort? reasoningEffort,
  LocalTaskAgentEvalExecutionMode executionMode =
      LocalTaskAgentEvalExecutionMode.singlePass,
  String? reportEditorModelId,
  int reportEditorMaxAttempts = 1,
}) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return LocalTaskAgentInferenceEvalRunner(
    provider: provider,
    conversationRepository: container.read(
      conversationRepositoryProvider.notifier,
    ),
    inferenceRepository: inferenceRepository,
    temperature: temperature,
    reasoningEffort: reasoningEffort,
    forceReportRetry: forceReportRetry,
    executionMode: executionMode,
    reportEditorModelId: reportEditorModelId,
    reportEditorMaxAttempts: reportEditorMaxAttempts,
  );
}

List<({String name, String argumentsJson})> _expectedMetadataToolCalls({
  String title = 'Validate efficient task-agent model',
}) {
  return [
    (
      name: TaskAgentToolNames.setTaskTitle,
      argumentsJson: jsonEncode({'title': title}),
    ),
    (
      name: TaskAgentToolNames.updateTaskEstimate,
      argumentsJson: '{"minutes":150}',
    ),
    (
      name: TaskAgentToolNames.updateTaskDueDate,
      argumentsJson: '{"dueDate":"2026-07-04"}',
    ),
    (
      name: TaskAgentToolNames.updateTaskPriority,
      argumentsJson: '{"priority":"P1"}',
    ),
  ];
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.messages,
    required this.toolNames,
    required this.model,
    required this.temperature,
  });

  final List<ChatCompletionMessage> messages;
  final List<String> toolNames;
  final String model;
  final double temperature;
}

enum _ConversationFailurePoint { create, send }

class _ThrowingConversationRepository extends ConversationRepository {
  _ThrowingConversationRepository(this.failurePoint);

  final _ConversationFailurePoint failurePoint;
  final _manager = ConversationManager(
    conversationId: 'throwing-conversation',
    maxTurns: 2,
  );
  int deleteCount = 0;

  void disposeManager() => _manager.dispose();

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    if (failurePoint == _ConversationFailurePoint.create) {
      throw StateError('create failed');
    }
    _manager.initialize(systemMessage: systemMessage);
    return 'throwing-conversation';
  }

  @override
  ConversationManager? getConversation(String conversationId) => _manager;

  @override
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    double temperature = 0.7,
    ConversationStrategy? strategy,
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
  }) {
    throw StateError('send failed');
  }

  @override
  void deleteConversation(String conversationId) {
    deleteCount++;
  }
}

class _QueuedInferenceRepository extends InferenceRepositoryInterface {
  _QueuedInferenceRepository(this.responsesByRequest);

  final List<List<CreateChatCompletionStreamResponse>> responsesByRequest;
  final requests = <_RecordedRequest>[];
  var _requestIndex = 0;

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    InferenceImpactCollector? impactCollector,
    int? turnIndex,
  }) {
    requests.add(
      _RecordedRequest(
        messages: messages,
        toolNames: tools?.map((tool) => tool.function.name).toList() ?? [],
        model: model,
        temperature: temperature,
      ),
    );
    final responses = _requestIndex < responsesByRequest.length
        ? responsesByRequest[_requestIndex]
        : const <CreateChatCompletionStreamResponse>[];
    _requestIndex++;
    return Stream.fromIterable(responses);
  }
}

class _FailThenSucceedInferenceRepository extends InferenceRepositoryInterface {
  final requests = <_RecordedRequest>[];

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    InferenceImpactCollector? impactCollector,
    int? turnIndex,
  }) {
    requests.add(
      _RecordedRequest(
        messages: messages,
        toolNames: tools?.map((tool) => tool.function.name).toList() ?? [],
        model: model,
        temperature: temperature,
      ),
    );
    if (requests.length == 1) {
      throw StateError('connection refused');
    }
    return Stream.fromIterable([
      _toolCalls([
        (
          name: TaskAgentToolNames.setTaskTitle,
          argumentsJson: '{"title":"Validate efficient task-agent model"}',
        ),
        (
          name: TaskAgentToolNames.updateTaskEstimate,
          argumentsJson: '{"minutes":150}',
        ),
        (
          name: TaskAgentToolNames.updateTaskDueDate,
          argumentsJson: '{"dueDate":"2026-07-04"}',
        ),
        (
          name: TaskAgentToolNames.updateTaskPriority,
          argumentsJson: '{"priority":"P1"}',
        ),
        (
          name: TaskAgentToolNames.updateReport,
          argumentsJson: jsonEncode({
            'oneLiner': 'Report exists',
            'tldr': 'Report exists.',
            'content': '## TLDR\nReport exists.',
          }),
        ),
      ]),
    ]);
  }
}

CreateChatCompletionStreamResponse _content(String text) {
  return CreateChatCompletionStreamResponse(
    id: 'content',
    choices: [
      ChatCompletionStreamResponseChoice(
        delta: ChatCompletionStreamResponseDelta(content: text),
        index: 0,
      ),
    ],
    object: 'chat.completion.chunk',
    created: 0,
  );
}

CreateChatCompletionStreamResponse _usage({
  required int inputTokens,
  required int outputTokens,
  int? thoughtsTokens,
  int? cachedInputTokens,
}) {
  return CreateChatCompletionStreamResponse(
    id: 'usage',
    choices: const [],
    object: 'chat.completion.chunk',
    created: 0,
    usage: CompletionUsage(
      promptTokens: inputTokens,
      completionTokens: outputTokens,
      totalTokens: inputTokens + outputTokens,
      promptTokensDetails: cachedInputTokens == null
          ? null
          : PromptTokensDetails(cachedTokens: cachedInputTokens),
      completionTokensDetails: thoughtsTokens == null
          ? null
          : CompletionTokensDetails(reasoningTokens: thoughtsTokens),
    ),
  );
}

CreateChatCompletionStreamResponse _toolCalls(
  List<({String name, String argumentsJson})> calls,
) {
  return CreateChatCompletionStreamResponse(
    id: 'tool',
    choices: [
      ChatCompletionStreamResponseChoice(
        delta: ChatCompletionStreamResponseDelta.fromJson({
          'tool_calls': [
            for (var i = 0; i < calls.length; i++)
              {
                'index': i,
                'id': 'call-$i',
                'type': 'function',
                'function': {
                  'name': calls[i].name,
                  'arguments': calls[i].argumentsJson,
                },
              },
          ],
        }),
        index: 0,
      ),
    ],
    object: 'chat.completion.chunk',
    created: 0,
  );
}
