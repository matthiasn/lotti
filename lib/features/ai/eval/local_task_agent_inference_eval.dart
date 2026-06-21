import 'dart:convert';

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_prompt_builder.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:openai_dart/openai_dart.dart';

const localTaskAgentEvalKind = 'lotti.localTaskAgentInferenceEvalReport';

const defaultLocalTaskAgentEvalProfiles = [
  LocalTaskAgentEvalProfile(
    name: 'qwen36-a35b-a3b-mlx4',
    providerModelId: omlxQwen36A35bA3b4BitModelId,
    modelClass: 'qwen36-a35b-a3b-omlx',
  ),
  LocalTaskAgentEvalProfile(
    name: 'gemma4-26b-a4b-qat-mlx4',
    providerModelId: omlxGemma426BA4BItQatMlx4BitModelId,
    modelClass: 'gemma4-26b-a4b-omlx',
  ),
];

class LocalTaskAgentEvalProfile {
  const LocalTaskAgentEvalProfile({
    required this.name,
    required this.providerModelId,
    required this.modelClass,
  });

  final String name;
  final String providerModelId;
  final String modelClass;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'providerModelId': providerModelId,
      'modelClass': modelClass,
    };
  }
}

class LocalTaskAgentExpectedToolCall {
  const LocalTaskAgentExpectedToolCall({
    required this.name,
    this.expectedArgumentsSubset = const {},
  });

  final String name;
  final Map<String, Object?> expectedArgumentsSubset;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'expectedArgumentsSubset': expectedArgumentsSubset,
    };
  }
}

class LocalTaskAgentEvalScenario {
  const LocalTaskAgentEvalScenario({
    required this.id,
    required this.systemPrompt,
    required this.userMessage,
    required this.expectedToolCalls,
    this.allowedExtraToolNames = const {
      TaskAgentToolNames.updateReport,
      TaskAgentToolNames.recordObservations,
    },
    this.requiresReport = true,
    this.maxTurns = 6,
  });

  final String id;
  final String systemPrompt;
  final String userMessage;
  final List<LocalTaskAgentExpectedToolCall> expectedToolCalls;
  final Set<String> allowedExtraToolNames;
  final bool requiresReport;
  final int maxTurns;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'expectedToolCalls': expectedToolCalls
          .map((expected) => expected.toJson())
          .toList(),
      'allowedExtraToolNames': allowedExtraToolNames.toList()..sort(),
      'requiresReport': requiresReport,
      'maxTurns': maxTurns,
      'systemPromptChars': systemPrompt.length,
      'userMessageChars': userMessage.length,
    };
  }
}

LocalTaskAgentEvalProfile parseLocalTaskAgentEvalProfile(String value) {
  final separator = value.indexOf('=');
  if (separator <= 0 || separator == value.length - 1) {
    throw FormatException(
      'Expected profile as name=model, got "$value".',
      value,
    );
  }
  final name = value.substring(0, separator).trim();
  final model = value.substring(separator + 1).trim();
  if (name.isEmpty || model.isEmpty) {
    throw FormatException(
      'Expected profile as name=model, got "$value".',
      value,
    );
  }
  return LocalTaskAgentEvalProfile(
    name: name,
    providerModelId: model,
    modelClass: name,
  );
}

List<ChatCompletionTool> buildLocalTaskAgentEvalTools() {
  return AgentToolRegistry.taskAgentTools
      .where((definition) {
        return definition.enabled;
      })
      .map((definition) {
        return ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: definition.name,
            description: definition.description,
            parameters: definition.parameters,
          ),
        );
      })
      .toList(growable: false);
}

LocalTaskAgentEvalScenario defaultLocalTaskAgentWakeScenario() {
  final version =
      AgentDomainEntity.agentTemplateVersion(
            id: 'local-task-agent-eval-template-version',
            agentId: 'local-task-agent-eval-template',
            version: 1,
            status: AgentTemplateVersionStatus.active,
            directives:
                'Be precise, avoid redundant task updates, and publish a '
                'short user-facing report only after required changes are '
                'queued.',
            authoredBy: 'system',
            createdAt: DateTime.utc(2026, 6, 21),
            vectorClock: null,
          )
          as AgentTemplateVersionEntity;

  return LocalTaskAgentEvalScenario(
    id: 'task_agent_first_wake_metadata_and_report',
    systemPrompt: TaskAgentPromptBuilder.buildSystemPrompt(
      version: version,
      soulVersion: null,
    ),
    userMessage: _defaultProductionWakeUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.setTaskTitle,
        expectedArgumentsSubset: {'title': 'Validate local Gemma fallback'},
      ),
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskEstimate,
        expectedArgumentsSubset: {'minutes': 150},
      ),
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskDueDate,
        expectedArgumentsSubset: {'dueDate': '2026-07-04'},
      ),
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskPriority,
        expectedArgumentsSubset: {'priority': 'P1'},
      ),
    ],
  );
}

const _defaultProductionWakeUserMessage = '''
## Current Task Context
```json
{
  "id": "task-local-agent-eval-1",
  "title": "",
  "status": "OPEN",
  "priority": null,
  "estimate": null,
  "dueDate": null,
  "languageCode": "en",
  "description": "Evaluate whether a downloaded local Gemma oMLX model is usable in Lotti.",
  "checklist": [
    {"id": "check-1", "title": "Run a meaningful local app eval", "isChecked": false},
    {"id": "check-2", "title": "Compare Gemma against Qwen on task-agent behavior", "isChecked": false}
  ],
  "log": [
    {
      "timestamp": "2026-06-21T09:00:00Z",
      "text": "User asked: title this task Validate local Gemma fallback, make it P1, due July 4 2026, and estimate two and a half hours."
    },
    {
      "timestamp": "2026-06-21T09:05:00Z",
      "text": "The user is skeptical of shallow tool-call smoke reports and wants a real app-shaped local eval."
    }
  ]
}
```

## Parent Project Context
```json
{
  "id": "project-local-inference",
  "title": "Local inference reliability",
  "latestProjectAgentReport": {
    "tldr": "Qwen is the current local default. Gemma needs stronger validation before it is trusted.",
    "content": "Focus on runtime behavior that affects the Lotti task-agent workflow, not generic benchmark scores."
  }
}
```

## Linked Tasks
```json
{
  "linked_from": [],
  "linked_to": [
    {
      "id": "task-qwen-baseline",
      "title": "Qwen 3.6 local baseline",
      "summaryStatus": "present",
      "latestTaskAgentReportOneLiner": "Qwen passes app-shaped local task-agent checks",
      "latestTaskAgentReportTldr": "Qwen can emit task metadata tools and a final report through oMLX."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

## Changed Since Last Wake
The following entity IDs changed: task-local-agent-eval-1

Analyze the current state, maintain any attention requests, and call tools if
needed. The user explicitly asked for the title, priority, due date, and
estimate changes in the task log. Do not change status. If the report would
materially change, call `update_report` with the full updated report; otherwise
finish with a brief plain-text note. Add observations if warranted.
''';

enum LocalTaskAgentEvalFailureCategory {
  none,
  emptyResponse,
  missingExpectedToolCall,
  invalidToolArguments,
  argumentMismatch,
  unexpectedToolCall,
  missingReport,
}

class LocalTaskAgentEvalToolCall {
  const LocalTaskAgentEvalToolCall({
    required this.name,
    required this.argumentsJson,
  });

  final String name;
  final String argumentsJson;

  Map<String, dynamic>? get jsonObjectArguments {
    try {
      final decoded = jsonDecode(argumentsJson);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  bool get hasJsonObjectArguments => jsonObjectArguments != null;

  bool containsExpectedArguments(Map<String, Object?> expectedArguments) {
    final arguments = jsonObjectArguments;
    if (arguments == null) return false;
    return _containsExpectedValues(arguments, expectedArguments);
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'argumentsJson': argumentsJson,
      'argumentsJsonValid': hasJsonObjectArguments,
    };
  }
}

class LocalTaskAgentEvalCaseResult {
  const LocalTaskAgentEvalCaseResult({
    required this.profile,
    required this.scenario,
    required this.provider,
    required this.latencyMs,
    required this.toolCalls,
    required this.failureCategory,
    this.inputTokens,
    this.outputTokens,
    this.finalContent,
  });

  final LocalTaskAgentEvalProfile profile;
  final LocalTaskAgentEvalScenario scenario;
  final AiConfigInferenceProvider provider;
  final int latencyMs;
  final int? inputTokens;
  final int? outputTokens;
  final String? finalContent;
  final List<LocalTaskAgentEvalToolCall> toolCalls;
  final LocalTaskAgentEvalFailureCategory failureCategory;

  bool get passed => failureCategory == LocalTaskAgentEvalFailureCategory.none;

  Map<String, Object?> toJson() {
    return {
      'profileName': profile.name,
      'providerModelId': profile.providerModelId,
      'modelClass': profile.modelClass,
      'scenarioId': scenario.id,
      'provider': {
        'id': provider.id,
        'name': provider.name,
        'type': provider.inferenceProviderType.name,
        'baseUrl': provider.baseUrl,
      },
      'latencyMs': latencyMs,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'finalContentLength': finalContent?.length ?? 0,
      'toolCallCount': toolCalls.length,
      'toolCallNames': toolCalls.map((call) => call.name).toList(),
      'expectedToolNames': scenario.expectedToolCalls
          .map((call) => call.name)
          .toList(),
      'failureCategory': failureCategory.name,
      'toolCalls': toolCalls.map((call) => call.toJson()).toList(),
    };
  }
}

class LocalTaskAgentEvalReport {
  const LocalTaskAgentEvalReport({
    required this.provider,
    required this.profiles,
    required this.scenarios,
    required this.results,
  });

  final AiConfigInferenceProvider provider;
  final List<LocalTaskAgentEvalProfile> profiles;
  final List<LocalTaskAgentEvalScenario> scenarios;
  final List<LocalTaskAgentEvalCaseResult> results;

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 1,
      'kind': localTaskAgentEvalKind,
      'provider': {
        'id': provider.id,
        'name': provider.name,
        'type': provider.inferenceProviderType.name,
        'baseUrl': provider.baseUrl,
      },
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
      'results': results.map((result) => result.toJson()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Local Task-Agent Inference Eval')
      ..writeln()
      ..writeln(
        'Provider: `${provider.name}` (${provider.inferenceProviderType.name}) '
        'at `${provider.baseUrl}`',
      )
      ..writeln()
      ..writeln(
        '| Profile | Model | Scenario | Pass | Latency | Tool calls | Failure |',
      )
      ..writeln('| --- | --- | --- | ---: | ---: | --- | --- |');

    for (final result in results) {
      final toolNames = result.toolCalls.map((call) => call.name).join(', ');
      buffer.writeln(
        '| ${result.profile.name} | `${result.profile.providerModelId}` | '
        '${result.scenario.id} | ${result.passed ? 'yes' : 'no'} | '
        '${result.latencyMs} ms | ${toolNames.isEmpty ? '-' : toolNames} | '
        '${result.failureCategory.name} |',
      );
    }

    final failures = results.where((result) => !result.passed);
    if (failures.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Failures');
      for (final result in failures) {
        buffer.writeln(
          '- `${result.profile.name}` / `${result.scenario.id}`: '
          '${result.failureCategory.name}',
        );
      }
    }

    return buffer.toString();
  }
}

class LocalTaskAgentInferenceEvalRunner {
  LocalTaskAgentInferenceEvalRunner({
    required this.provider,
    required this.conversationRepository,
    required this.inferenceRepository,
    this.temperature = 0.3,
  });

  final AiConfigInferenceProvider provider;
  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final double temperature;

  Future<LocalTaskAgentEvalReport> run({
    required List<LocalTaskAgentEvalProfile> profiles,
    required List<LocalTaskAgentEvalScenario> scenarios,
  }) async {
    final results = <LocalTaskAgentEvalCaseResult>[];
    for (final profile in profiles) {
      for (final scenario in scenarios) {
        results.add(await _runScenario(profile, scenario));
      }
    }
    return LocalTaskAgentEvalReport(
      provider: provider,
      profiles: profiles,
      scenarios: scenarios,
      results: results,
    );
  }

  Future<LocalTaskAgentEvalCaseResult> _runScenario(
    LocalTaskAgentEvalProfile profile,
    LocalTaskAgentEvalScenario scenario,
  ) async {
    final stopwatch = Stopwatch()..start();
    final strategy = _LocalTaskAgentEvalStrategy(scenario: scenario);
    final conversationId = conversationRepository.createConversation(
      systemMessage: scenario.systemPrompt,
      maxTurns: scenario.maxTurns,
    );

    try {
      final usage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: scenario.userMessage,
        model: profile.providerModelId,
        provider: provider,
        inferenceRepo: inferenceRepository,
        tools: buildLocalTaskAgentEvalTools(),
        temperature: temperature,
        strategy: strategy,
      );
      stopwatch.stop();

      final manager = conversationRepository.getConversation(conversationId);
      final finalContent = _extractFinalAssistantContent(manager);
      final failureCategory = _classifyResult(
        scenario: scenario,
        toolCalls: strategy.toolCalls,
        finalContent: finalContent,
        hasReport: strategy.hasReport,
      );

      return LocalTaskAgentEvalCaseResult(
        profile: profile,
        scenario: scenario,
        provider: provider,
        latencyMs: stopwatch.elapsedMilliseconds,
        inputTokens: usage?.inputTokens,
        outputTokens: usage?.outputTokens,
        finalContent: finalContent,
        toolCalls: strategy.toolCalls,
        failureCategory: failureCategory,
      );
    } finally {
      conversationRepository.deleteConversation(conversationId);
    }
  }
}

class _LocalTaskAgentEvalStrategy extends ConversationStrategy {
  _LocalTaskAgentEvalStrategy({required this.scenario});

  final LocalTaskAgentEvalScenario scenario;
  final _toolCalls = <LocalTaskAgentEvalToolCall>[];
  bool hasReport = false;

  List<LocalTaskAgentEvalToolCall> get toolCalls =>
      List.unmodifiable(_toolCalls);

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      final recorded = LocalTaskAgentEvalToolCall(
        name: call.function.name,
        argumentsJson: call.function.arguments,
      );
      _toolCalls.add(recorded);

      final args = recorded.jsonObjectArguments;
      if (call.function.name == TaskAgentToolNames.updateReport &&
          args != null &&
          _hasNonEmptyString(args, 'oneLiner') &&
          _hasNonEmptyString(args, 'tldr') &&
          _hasNonEmptyString(args, 'content')) {
        hasReport = true;
      }

      manager.addToolResponse(
        toolCallId: call.id,
        response: args == null
            ? 'Eval harness rejected invalid JSON arguments.'
            : 'Eval harness accepted ${call.function.name}.',
      );
    }

    return hasReport
        ? ConversationAction.complete
        : ConversationAction.continueConversation;
  }

  @override
  bool shouldContinue(ConversationManager manager) => manager.canContinue();

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    if (hasReport) return null;
    return 'Continue. If you have finished your analysis, call '
        '`update_report` with `oneLiner`, `tldr`, and `content` if the '
        'report would materially change; otherwise finish with a brief '
        'plain-text note.';
  }
}

LocalTaskAgentEvalFailureCategory _classifyResult({
  required LocalTaskAgentEvalScenario scenario,
  required List<LocalTaskAgentEvalToolCall> toolCalls,
  required String? finalContent,
  required bool hasReport,
}) {
  if (toolCalls.isEmpty && (finalContent == null || finalContent.isEmpty)) {
    return LocalTaskAgentEvalFailureCategory.emptyResponse;
  }

  if (toolCalls.any((call) => !call.hasJsonObjectArguments)) {
    return LocalTaskAgentEvalFailureCategory.invalidToolArguments;
  }

  final expectedNames = scenario.expectedToolCalls
      .map((expected) => expected.name)
      .toSet();
  final allowedNames = {...expectedNames, ...scenario.allowedExtraToolNames};
  if (toolCalls.any((call) => !allowedNames.contains(call.name))) {
    return LocalTaskAgentEvalFailureCategory.unexpectedToolCall;
  }

  for (final expected in scenario.expectedToolCalls) {
    final matchingCalls = toolCalls
        .where((call) => call.name == expected.name)
        .toList(growable: false);
    if (matchingCalls.isEmpty) {
      return LocalTaskAgentEvalFailureCategory.missingExpectedToolCall;
    }
    if (expected.expectedArgumentsSubset.isNotEmpty &&
        !matchingCalls.any(
          (call) => call.containsExpectedArguments(
            expected.expectedArgumentsSubset,
          ),
        )) {
      return LocalTaskAgentEvalFailureCategory.argumentMismatch;
    }
  }

  if (scenario.requiresReport && !hasReport) {
    return LocalTaskAgentEvalFailureCategory.missingReport;
  }

  return LocalTaskAgentEvalFailureCategory.none;
}

String? _extractFinalAssistantContent(ConversationManager? manager) {
  if (manager == null) return null;
  for (final message in manager.messages.reversed) {
    if (message case ChatCompletionMessage(
      role: ChatCompletionMessageRole.assistant,
    )) {
      final content = message.mapOrNull(
        assistant: (message) => message.content,
      );
      if (content != null && content.isNotEmpty) return content;
    }
  }
  return null;
}

bool _hasNonEmptyString(Map<String, dynamic> args, String key) {
  final value = args[key];
  return value is String && value.trim().isNotEmpty;
}

bool _containsExpectedValues(
  Map<String, dynamic> actual,
  Map<String, Object?> expected,
) {
  for (final entry in expected.entries) {
    if (!actual.containsKey(entry.key)) return false;
    if (!_matchesExpectedValue(actual[entry.key], entry.value)) return false;
  }
  return true;
}

bool _matchesExpectedValue(Object? actual, Object? expected) {
  if (expected is Map<String, Object?>) {
    return actual is Map<String, dynamic> &&
        _containsExpectedValues(actual, expected);
  }
  if (expected is List<Object?>) {
    if (actual is! List || actual.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (!_matchesExpectedValue(actual[i], expected[i])) return false;
    }
    return true;
  }
  return actual == expected;
}
