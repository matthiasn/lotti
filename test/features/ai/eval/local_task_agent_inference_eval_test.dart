import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
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
        () => parseLocalTaskAgentEvalExecutionMode('parallel'),
        throwsFormatException,
      );
    },
  );

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
    expect(json['schemaVersion'], 3);
    expect(json['kind'], localTaskAgentEvalKind);
    expect(json['temperature'], 0.3);
    expect(json['executionMode'], 'singlePass');
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

    final markdown = report.toMarkdown();
    expect(markdown, contains('| local-model | `local-model-id` |'));
    expect(markdown, contains('## Failures'));
    expect(markdown, contains('invalidToolArguments'));
  });

  test('Melious matrix covers every configured prompt variant', () {
    final defaultScenarios = defaultMeliousTaskAgentEvalScenarios();
    final scenarios = defaultMeliousTaskAgentEvalScenarios(
      variants: LocalTaskAgentEvalPromptVariant.values,
    );

    expect(defaultMeliousTaskAgentEvalProfiles.map((profile) => profile.name), [
      'mistral-small-4-baseline',
      'glm-5.2-reference',
    ]);
    expect(defaultScenarios, hasLength(11));
    expect(
      defaultScenarios.map((scenario) => scenario.promptVariant).toSet(),
      {LocalTaskAgentEvalPromptVariant.production},
    );
    expect(
      scenarios,
      hasLength(11 * LocalTaskAgentEvalPromptVariant.values.length),
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
        'user_completed_item_resurfaced_production',
        'spanish_mixed_context_production',
        'external_link_and_completion_production',
        'latest_deadline_wins_production',
        'messy_german_transcript_qualityFocused',
        'latest_deadline_wins_qualityFocused',
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
          _usage(inputTokens: 100, outputTokens: 20),
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
          _usage(inputTokens: 40, outputTokens: 10),
        ],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: inferenceRepository,
        executionMode: LocalTaskAgentEvalExecutionMode.twoPass,
        temperature: 0,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      expect(report.results.single.usedForcedReportRetry, isTrue);
      expect(report.results.single.inputTokens, 140);
      expect(report.results.single.outputTokens, 30);
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
  LocalTaskAgentEvalExecutionMode executionMode =
      LocalTaskAgentEvalExecutionMode.singlePass,
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
    forceReportRetry: forceReportRetry,
    executionMode: executionMode,
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
