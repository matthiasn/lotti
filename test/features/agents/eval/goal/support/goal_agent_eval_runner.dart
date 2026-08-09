/// Runner, recording strategy, classifier and report for the goal-agent
/// inference evals.
///
/// Chassis-wise this is the task-agent inference eval pattern (declarative
/// scenarios over a synthetic wake context), goal-shaped: no forced report
/// pass (a wake that should be a no-op must be *allowed* to do nothing), and
/// credits captured per case from day one via the wake-run key.
library;

import 'dart:convert';

import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../ai/eval/support/eval_text_matchers.dart';
import 'goal_agent_eval_scenarios.dart';
import 'goal_agent_spec.dart';

const goalAgentEvalKind = 'lotti.goalAgentInferenceEvalReport';

/// A recorded tool call.
class GoalAgentEvalToolCall {
  const GoalAgentEvalToolCall({
    required this.name,
    required this.argumentsJson,
  });

  final String name;
  final String argumentsJson;

  Map<String, dynamic>? get jsonObjectArguments {
    try {
      final decoded = jsonDecode(argumentsJson);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'argumentsJson': argumentsJson,
  };
}

enum GoalAgentEvalFailureCategory {
  none,
  inferenceError,
  invalidToolArguments,
  noOpViolated,
  forbiddenToolCall,
  unexpectedToolCall,
  toolCallOverBudget,
  missingExpectedToolCall,
  argumentMismatch,
  missingRequiredReportContent,
  forbiddenReportContent,
  missingRequiredToolArguments,
  forbiddenToolArguments,
  missingAssistantContent,
  forbiddenAssistantClaim,
}

/// One (model, scenario) outcome.
class GoalAgentEvalCaseResult {
  const GoalAgentEvalCaseResult({
    required this.modelId,
    required this.scenario,
    required this.toolCalls,
    required this.assistantContent,
    required this.latencyMs,
    required this.failureCategory,
    this.inputTokens,
    this.outputTokens,
    this.thoughtsTokens,
    this.cachedInputTokens,
    this.consumption = const [],
    this.errorMessage,
  });

  final String modelId;
  final GoalAgentEvalScenario scenario;
  final List<GoalAgentEvalToolCall> toolCalls;

  /// All plain assistant text across turns, newline-joined.
  final String assistantContent;
  final int latencyMs;
  final GoalAgentEvalFailureCategory failureCategory;
  final int? inputTokens;
  final int? outputTokens;
  final int? thoughtsTokens;
  final int? cachedInputTokens;

  /// Consumption events attributed to this case's wake-run key. Only the
  /// Melious non-streaming path fills in billing.
  final List<AiConsumptionEvent> consumption;
  final String? errorMessage;

  bool get passed => failureCategory == GoalAgentEvalFailureCategory.none;

  /// Total reported energy for this case in watt-hours, or null when the
  /// provider sent no energy data. The "my fitness agent costs N Wh/month"
  /// number starts here (ADR 0058 Decision 4).
  double? get energyWh {
    final values = consumption
        .map((e) => e.energyKwh)
        .whereType<double>()
        .toList();
    return values.isEmpty ? null : values.reduce((a, b) => a + b) * 1000;
  }

  /// Total billed credits for this case, or null when nothing was reported.
  /// Never zero-defaulted: a missing bill is not a free run.
  double? get credits {
    final values = consumption
        .map((e) => e.credits)
        .whereType<double>()
        .toList();
    return values.isEmpty ? null : values.reduce((a, b) => a + b);
  }

  Map<String, Object?> toJson() => {
    'modelId': modelId,
    'scenarioId': scenario.id,
    'policyRuleId': scenario.policyRuleId,
    'latencyMs': latencyMs,
    'failureCategory': failureCategory.name,
    'passed': passed,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'thoughtsTokens': thoughtsTokens,
    'cachedInputTokens': cachedInputTokens,
    'credits': credits,
    'energyWh': energyWh,
    'toolCalls': [for (final call in toolCalls) call.toJson()],
    'assistantContent': assistantContent,
    'consumption': [for (final event in consumption) event.toJson()],
    'errorMessage': errorMessage,
  };
}

/// The report: matrix, failures and cost — including the headline
/// cost-per-goal-month extrapolation.
class GoalAgentEvalReport {
  const GoalAgentEvalReport({
    required this.provider,
    required this.modelIds,
    required this.scenarios,
    required this.results,
    required this.temperature,
    required this.wakesPerDayAssumption,
  });

  final AiConfigInferenceProvider provider;
  final List<String> modelIds;
  final List<GoalAgentEvalScenario> scenarios;
  final List<GoalAgentEvalCaseResult> results;
  final double temperature;

  /// Printed assumption behind the €/goal-month extrapolation — an OBSERVED
  /// ESTIMATE input, never a target (cost policy: monitoring, not caps).
  final int wakesPerDayAssumption;

  Map<String, Object?> toJson() => {
    'kind': goalAgentEvalKind,
    'provider': {
      'id': provider.id,
      'name': provider.name,
      'type': provider.inferenceProviderType.name,
      'baseUrl': provider.baseUrl,
    },
    'modelIds': modelIds,
    'temperature': temperature,
    'wakesPerDayAssumption': wakesPerDayAssumption,
    'scenarioIds': [for (final scenario in scenarios) scenario.id],
    'results': [for (final result in results) result.toJson()],
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Goal-agent inference eval')
      ..writeln()
      ..writeln(
        'Provider: `${provider.baseUrl}` '
        '(${provider.inferenceProviderType.name}), '
        'temperature $temperature.',
      )
      ..writeln()
      ..writeln('## Scenario × model matrix')
      ..writeln()
      ..writeln('| Scenario | Policy | ${modelIds.join(' | ')} |')
      ..writeln('| --- | --- |${' ---: |' * modelIds.length}');
    for (final scenario in scenarios) {
      final cells = modelIds.map((modelId) {
        final cases = results.where(
          (r) => r.modelId == modelId && r.scenario.id == scenario.id,
        );
        if (cases.isEmpty) return '—';
        final passedCount = cases.where((r) => r.passed).length;
        return '$passedCount/${cases.length}';
      });
      buffer.writeln(
        '| ${scenario.id} | ${scenario.policyRuleId} | '
        '${cells.join(' | ')} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Failures')
      ..writeln();
    final failures = results.where((r) => !r.passed).toList();
    if (failures.isEmpty) {
      buffer.writeln('None.');
    }
    for (final failure in failures) {
      buffer
        ..writeln(
          '### ${failure.scenario.id} × `${failure.modelId}` — '
          '${failure.failureCategory.name}',
        )
        ..writeln()
        ..writeln(
          'Tool calls: '
          '${failure.toolCalls.map((c) => c.name).join(', ')}',
        )
        ..writeln();
      if (failure.errorMessage != null) {
        buffer
          ..writeln('Error: ${failure.errorMessage}')
          ..writeln();
      }
    }

    buffer
      ..writeln('## Cost (observed, not a target)')
      ..writeln()
      ..writeln(
        '| Model | Cases | In | Out | Credits | Credits/goal-month* | '
        'Wh | Wh/goal-month* |',
      )
      ..writeln('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |');
    for (final modelId in modelIds) {
      final cases = results.where((r) => r.modelId == modelId).toList();
      final inTokens = cases.fold<int>(
        0,
        (sum, r) => sum + (r.inputTokens ?? 0),
      );
      final outTokens = cases.fold<int>(
        0,
        (sum, r) => sum + (r.outputTokens ?? 0),
      );
      final creditValues = cases
          .map((r) => r.credits)
          .whereType<double>()
          .toList();
      final credits = creditValues.isEmpty
          ? null
          : creditValues.reduce((a, b) => a + b);
      // Per-month figures divide by REPORTED cases only: missing telemetry
      // must widen uncertainty, never masquerade as zero cost.
      final perGoalMonth = credits == null
          ? null
          : credits / creditValues.length * wakesPerDayAssumption * 30;
      final energyValues = cases
          .map((r) => r.energyWh)
          .whereType<double>()
          .toList();
      final energyWh = energyValues.isEmpty
          ? null
          : energyValues.reduce((a, b) => a + b);
      final energyPerGoalMonth = energyWh == null
          ? null
          : energyWh / energyValues.length * wakesPerDayAssumption * 30;
      buffer.writeln(
        '| `$modelId` | ${cases.length} | $inTokens | $outTokens | '
        '${credits?.toStringAsFixed(4) ?? 'not reported'} | '
        '${perGoalMonth?.toStringAsFixed(4) ?? 'not reported'} | '
        '${energyWh?.toStringAsFixed(2) ?? 'not reported'} | '
        '${energyPerGoalMonth?.toStringAsFixed(1) ?? 'not reported'} |',
      );
    }
    buffer
      ..writeln()
      ..writeln(
        '*Extrapolation assumes $wakesPerDayAssumption LLM wakes '
        'per goal per day — a printed assumption, not a measurement — '
        'and divide by cases that actually reported the figure: missing '
        'telemetry widens uncertainty, it is never counted as zero. '
        'Credits and energy are Melious-reported; "not reported" means '
        'the provider sent no data, never that the run was free. Banner '
        'creation itself (ADR 0058) adds no image inference on top of '
        'the Phase B text turn.',
      );
    return buffer.toString();
  }
}

/// Records every tool call and answers it the way the future dispatcher
/// would: known tools succeed with a minimal payload, unknown names come
/// back as recoverable errors (confirming a fabricated tool would make the
/// harness measure something the app never does).
class GoalAgentEvalStrategy extends ConversationStrategy {
  final _toolCalls = <GoalAgentEvalToolCall>[];

  List<GoalAgentEvalToolCall> get toolCalls => List.unmodifiable(_toolCalls);

  static final Set<String> _knownToolNames = {
    for (final tool in goalAgentTools) tool.name,
  };

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      final recorded = GoalAgentEvalToolCall(
        name: call.function.name,
        argumentsJson: call.function.arguments,
      );
      _toolCalls.add(recorded);
      manager.addToolResponse(
        toolCallId: call.id,
        response: _responseFor(recorded),
      );
    }
    return ConversationAction.continueConversation;
  }

  String _responseFor(GoalAgentEvalToolCall call) {
    if (!_knownToolNames.contains(call.name)) {
      return jsonEncode({
        'error':
            'Unknown tool: ${call.name}. Available tools: '
            '${_knownToolNames.join(', ')}.',
      });
    }
    if (call.jsonObjectArguments == null) {
      return jsonEncode({
        'error': 'Invalid JSON arguments for ${call.name}.',
      });
    }
    return switch (call.name) {
      GoalAgentToolNames.createGoalAd => jsonEncode({
        'status': 'draft',
        'adId': 'ad-new-${_toolCalls.length}',
      }),
      GoalAgentToolNames.rerunGoalAd => jsonEncode({
        'status': 'active',
        'rerun': true,
      }),
      _ => jsonEncode({'status': 'ok'}),
    };
  }

  // ConversationRepository enforces the turn limit directly and does not
  // call this legacy strategy hook.
  // coverage:ignore-start
  @override
  bool shouldContinue(ConversationManager manager) => manager.canContinue();
  // coverage:ignore-end

  @override
  String? getContinuationPrompt(ConversationManager manager) => null;
}

/// Deterministic classifier — first violated check names the failure.
GoalAgentEvalFailureCategory classifyGoalAgentResult({
  required GoalAgentEvalScenario scenario,
  required List<GoalAgentEvalToolCall> toolCalls,
  required String assistantContent,
}) {
  if (scenario.expectsNoToolCalls && toolCalls.isNotEmpty) {
    return GoalAgentEvalFailureCategory.noOpViolated;
  }

  if (toolCalls.any((call) => call.jsonObjectArguments == null)) {
    return GoalAgentEvalFailureCategory.invalidToolArguments;
  }

  // The banner contract is enforced, not just advertised: a create call
  // whose arguments cannot decode into GoalNudgeBrief must not score as a
  // success just because its name matched (JSON-schema enums are advisory
  // to many providers).
  for (final call in toolCalls) {
    if (call.name != GoalAgentToolNames.createGoalAd) continue;
    final args = call.jsonObjectArguments!;
    final headline = args['headline'];
    final validHeadline = headline is String && headline.trim().isNotEmpty;
    final validTone = goalNudgeToneNames.contains(args['tone']);
    final validAnimation = goalBannerAnimationNames.contains(args['animation']);
    final accent = args['accent'];
    final validAccent =
        accent == null || goalBannerAccentNames.contains(accent);
    final validOptionalCopy = [
      args['tagline'],
      args['cta'],
    ].every((value) => value == null || value is String);
    if (!validHeadline ||
        !validTone ||
        !validAnimation ||
        !validAccent ||
        !validOptionalCopy) {
      return GoalAgentEvalFailureCategory.invalidToolArguments;
    }
  }

  if (toolCalls.any(
    (call) => scenario.forbiddenToolNames.contains(call.name),
  )) {
    return GoalAgentEvalFailureCategory.forbiddenToolCall;
  }

  // Tools outside expected ∪ tolerated: reporting and observations are
  // always tolerated unless explicitly forbidden — the policy regulates
  // them by situation, and over-reporting is measured by the no-op and
  // budget checks, not by this allow-list.
  final allowedNames = {
    for (final expected in scenario.expectedToolCalls) expected.name,
    GoalAgentToolNames.updateGoalReport,
    GoalAgentToolNames.recordGoalObservation,
    GoalAgentToolNames.retireGoalAd,
  }..removeAll(scenario.forbiddenToolNames);
  if (toolCalls.any((call) => !allowedNames.contains(call.name))) {
    return GoalAgentEvalFailureCategory.unexpectedToolCall;
  }

  for (final entry in scenario.maxToolCallCounts.entries) {
    final count = toolCalls.where((call) => call.name == entry.key).length;
    if (count > entry.value) {
      return GoalAgentEvalFailureCategory.toolCallOverBudget;
    }
  }

  for (final expected in scenario.expectedToolCalls) {
    final matching = toolCalls
        .where((call) => call.name == expected.name)
        .toList();
    if (matching.isEmpty) {
      return GoalAgentEvalFailureCategory.missingExpectedToolCall;
    }
    if (expected.expectedArgumentsSubset.isNotEmpty &&
        !matching.any(
          (call) => _containsExpectedValues(
            call.jsonObjectArguments ?? const {},
            expected.expectedArgumentsSubset,
          ),
        )) {
      return GoalAgentEvalFailureCategory.argumentMismatch;
    }
  }

  final reportText = _latestReportArguments(toolCalls)?.toLowerCase() ?? '';
  if (scenario.requiredReportTermGroups.any(
    (group) => !containsAnyEvalTerm(reportText, group),
  )) {
    return GoalAgentEvalFailureCategory.missingRequiredReportContent;
  }
  if (scenario.forbiddenReportTerms.any(
    (term) => reportText.contains(term.toLowerCase()),
  )) {
    return GoalAgentEvalFailureCategory.forbiddenReportContent;
  }
  if (scenario.forbiddenReportClaims.any(
    (claim) => containsAffirmativeReportClaim(reportText, claim),
  )) {
    return GoalAgentEvalFailureCategory.forbiddenReportContent;
  }

  for (final entry in scenario.requiredToolArgumentTermGroups.entries) {
    final arguments = _argumentsFor(toolCalls, entry.key);
    if (entry.value.any((group) => !containsAnyEvalTerm(arguments, group))) {
      return GoalAgentEvalFailureCategory.missingRequiredToolArguments;
    }
  }
  for (final entry in scenario.forbiddenToolArgumentTerms.entries) {
    final arguments = _argumentsFor(toolCalls, entry.key).toLowerCase();
    if (entry.value.any((term) => arguments.contains(term.toLowerCase()))) {
      return GoalAgentEvalFailureCategory.forbiddenToolArguments;
    }
  }

  if (scenario.requiredAssistantContentTermGroups.any(
    (group) => !containsAnyEvalTerm(assistantContent, group),
  )) {
    return GoalAgentEvalFailureCategory.missingAssistantContent;
  }
  if (scenario.forbiddenAssistantContentClaims.any(
    (claim) => containsAffirmativeReportClaim(assistantContent, claim),
  )) {
    return GoalAgentEvalFailureCategory.forbiddenAssistantClaim;
  }

  return GoalAgentEvalFailureCategory.none;
}

String _argumentsFor(List<GoalAgentEvalToolCall> toolCalls, String name) =>
    toolCalls
        .where((call) => call.name == name)
        .map((call) => call.argumentsJson)
        .join('\n');

String? _latestReportArguments(List<GoalAgentEvalToolCall> toolCalls) {
  for (final call in toolCalls.reversed) {
    if (call.name == GoalAgentToolNames.updateGoalReport) {
      return call.argumentsJson;
    }
  }
  return null;
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
  if (expected is num && actual is num) return actual == expected;
  return actual == expected;
}

/// Wake-run key for one eval case — the consumption-event join key.
String goalAgentEvalWakeRunKey(String modelId, String scenarioId) =>
    'goal-eval:$scenarioId:$modelId';

class GoalAgentInferenceEvalRunner {
  GoalAgentInferenceEvalRunner({
    required this.provider,
    required this.conversationRepository,
    required this.inferenceRepository,
    this.temperature = 0,
    this.maxTurnsPerExchange = 6,
    this.wakesPerDayAssumption = 3,
    this.consumptionForWakeRunKey,
  });

  final AiConfigInferenceProvider provider;
  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final double temperature;
  final int maxTurnsPerExchange;
  final int wakesPerDayAssumption;

  /// Supplied by the live test: returns the consumption events recorded for
  /// one case's wake-run key (from `AiInteractionCaptureTestBench`).
  final List<AiConsumptionEvent> Function(String wakeRunKey)?
  consumptionForWakeRunKey;

  Future<GoalAgentEvalReport> run({
    required List<String> modelIds,
    required List<GoalAgentEvalScenario> scenarios,
  }) async {
    final results = <GoalAgentEvalCaseResult>[];
    for (final modelId in modelIds) {
      for (final scenario in scenarios) {
        results.add(await _runCase(modelId, scenario));
      }
    }
    return GoalAgentEvalReport(
      provider: provider,
      modelIds: modelIds,
      scenarios: scenarios,
      results: results,
      temperature: temperature,
      wakesPerDayAssumption: wakesPerDayAssumption,
    );
  }

  Future<GoalAgentEvalCaseResult> _runCase(
    String modelId,
    GoalAgentEvalScenario scenario,
  ) async {
    final stopwatch = Stopwatch()..start();
    final strategy = GoalAgentEvalStrategy();
    final wakeRunKey = goalAgentEvalWakeRunKey(modelId, scenario.id);
    final conversationId = conversationRepository.createConversation(
      systemMessage: goalAgentSystemPrompt,
      maxTurns:
          maxTurnsPerExchange * (1 + scenario.followUpUserMessages.length),
    );
    final manager = conversationRepository.getConversation(conversationId);

    try {
      InferenceUsage? usage;
      Future<void> exchange(String message) async {
        final turnUsage = await conversationRepository.sendMessage(
          conversationId: conversationId,
          message: message,
          model: modelId,
          provider: provider,
          inferenceRepo: inferenceRepository,
          tools: [
            for (final tool in goalAgentTools)
              ChatCompletionTool(
                type: ChatCompletionToolType.function,
                function: FunctionObject(
                  name: tool.name,
                  description: tool.description,
                  parameters: tool.parameters,
                ),
              ),
          ],
          temperature: temperature,
          strategy: strategy,
          consumptionAgentId: 'goal_agent:eval',
          consumptionWakeRunKey: wakeRunKey,
          consumptionThreadId: scenario.id,
          rethrowInferenceErrors: true,
        );
        if (turnUsage != null) {
          final current = usage;
          usage = current == null ? turnUsage : current.merge(turnUsage);
        }
      }

      await exchange(scenario.facts);
      for (final followUp in scenario.followUpUserMessages) {
        await exchange(followUp);
      }

      final assistantContent = _assistantContent(manager);
      return GoalAgentEvalCaseResult(
        modelId: modelId,
        scenario: scenario,
        toolCalls: strategy.toolCalls,
        assistantContent: assistantContent,
        latencyMs: stopwatch.elapsedMilliseconds,
        failureCategory: classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: strategy.toolCalls,
          assistantContent: assistantContent,
        ),
        inputTokens: usage?.inputTokens,
        outputTokens: usage?.outputTokens,
        thoughtsTokens: usage?.thoughtsTokens,
        cachedInputTokens: usage?.cachedInputTokens,
        consumption: consumptionForWakeRunKey?.call(wakeRunKey) ?? const [],
      );
    } catch (error) {
      return GoalAgentEvalCaseResult(
        modelId: modelId,
        scenario: scenario,
        toolCalls: strategy.toolCalls,
        assistantContent: _assistantContent(manager),
        latencyMs: stopwatch.elapsedMilliseconds,
        failureCategory: GoalAgentEvalFailureCategory.inferenceError,
        consumption: consumptionForWakeRunKey?.call(wakeRunKey) ?? const [],
        errorMessage: error.toString(),
      );
    } finally {
      conversationRepository.deleteConversation(conversationId);
    }
  }

  String _assistantContent(ConversationManager? manager) {
    if (manager == null) return '';
    return manager.messages
        .map(
          (message) => message.mapOrNull(assistant: (m) => m.content) ?? '',
        )
        .where((content) => content.isNotEmpty)
        .join('\n');
  }
}
