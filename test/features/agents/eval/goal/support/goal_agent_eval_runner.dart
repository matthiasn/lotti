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
import 'goal_eval_cost_table.dart';

const goalAgentEvalKind = 'lotti.goalAgentInferenceEvalReport';

/// A recorded tool call.
class GoalAgentEvalToolCall {
  const GoalAgentEvalToolCall({
    required this.name,
    required this.argumentsJson,
    this.exchangeIndex = 0,
  });

  final String name;
  final String argumentsJson;

  /// Which user turn produced this call. The contract's "exactly once first"
  /// is a per-wake rule, so cardinality and position are only meaningful
  /// within one exchange — a flattened list cannot tell a second reply from
  /// the legitimate reply to a follow-up message.
  final int exchangeIndex;

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
    'exchangeIndex': exchangeIndex,
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
class GoalAgentEvalCaseResult implements GoalEvalCostCase {
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

  @override
  final String modelId;
  final GoalAgentEvalScenario scenario;
  final List<GoalAgentEvalToolCall> toolCalls;

  /// All plain assistant text across turns, newline-joined.
  final String assistantContent;
  final int latencyMs;
  final GoalAgentEvalFailureCategory failureCategory;
  @override
  final int? inputTokens;
  @override
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
  @override
  double? get energyWh {
    final values = consumption
        .map((e) => e.energyKwh)
        .whereType<double>()
        .toList();
    return values.isEmpty ? null : values.reduce((a, b) => a + b) * 1000;
  }

  /// Total billed credits for this case, or null when nothing was reported.
  /// Never zero-defaulted: a missing bill is not a free run.
  @override
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

    buffer.write(
      renderGoalEvalCostTable(
        modelIds: modelIds,
        cases: results,
        wakesPerDayAssumption: wakesPerDayAssumption,
      ),
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
  var _exchangeIndex = 0;

  List<GoalAgentEvalToolCall> get toolCalls => List.unmodifiable(_toolCalls);

  /// Called by the runner before each user turn, so per-wake rules stay
  /// per-wake across a multi-turn scenario.
  // ignore: use_setters_to_change_properties
  void beginExchange(int index) => _exchangeIndex = index;

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
        exchangeIndex: _exchangeIndex,
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
  // whose arguments cannot decode into NudgeBrief must not score as a
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

  // The reply carrier's own contract, enforced the way the runtime enforces
  // it rather than merely tolerated. `GoalAgentStrategy` rejects a blank
  // message and any second reply in a wake, so a payload the runtime would
  // refuse must not score as a delivered answer here.
  final replies = toolCalls
      .where((call) => call.name == GoalAgentToolNames.replyToUser)
      .toList();
  for (final reply in replies) {
    final message = reply.jsonObjectArguments?['message'];
    if (message is! String || message.trim().isEmpty) {
      return GoalAgentEvalFailureCategory.invalidToolArguments;
    }
  }
  // Cardinality only, deliberately. `GoalAgentStrategy` rejects a SECOND
  // reply and nothing else; a scenario's follow-up turns are separate wakes
  // to the runtime, so the eval mirrors that as one reply PER EXCHANGE.
  //
  // An earlier revision also required the reply to be the first call of its
  // exchange, reading the contract's "exactly once first" as an ordering
  // rule. The runtime does not enforce it, the user reads the same answer
  // either way, and it became the largest single failure category — scoring
  // models for a sequence production accepts. Stricter than the code under
  // test is the same defect as looser; both measure the harness.
  final exchangesWithReplies = <int>{};
  for (final reply in replies) {
    if (!exchangesWithReplies.add(reply.exchangeIndex)) {
      return GoalAgentEvalFailureCategory.toolCallOverBudget;
    }
  }

  // Tools outside expected ∪ tolerated: reporting and observations are
  // always tolerated unless explicitly forbidden — the policy regulates
  // them by situation, and over-reporting is measured by the no-op and
  // budget checks, not by this allow-list.
  //
  // `reply_to_user` is tolerated for the same reason it is not optional:
  // the shipped contract orders "unanswered user message → call
  // reply_to_user exactly once first". Scoring the contract-mandated reply
  // as an unexpected call made every dialogue scenario unpassable.
  //
  // Tolerated only where the contract actually calls for it, though: the
  // tool description says "call exactly once when FACTS contain a PENDING
  // USER MESSAGE", and the runtime only arms the reply path for an
  // interactive wake. An unsolicited reply on a scheduled status wake is
  // chat the user never asked for, and stays an unexpected call.
  final allowedNames = {
    for (final expected in scenario.expectedToolCalls) expected.name,
    GoalAgentToolNames.updateGoalReport,
    GoalAgentToolNames.recordGoalObservation,
    GoalAgentToolNames.retireGoalAd,
    if (scenario.hasPendingUserMessage) GoalAgentToolNames.replyToUser,
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
          (call) {
            final arguments = call.jsonObjectArguments ?? const {};
            if (!_containsExpectedValues(
              arguments,
              expected.expectedArgumentsSubset,
            )) {
              return false;
            }
            return expected.name != GoalAgentToolNames.updateGoalReport ||
                !expected.expectedArgumentsSubset.containsKey('report') ||
                GoalStructuredReport.tryParse(arguments['report']) != null;
          },
        )) {
      return GoalAgentEvalFailureCategory.argumentMismatch;
    }
  }

  final structuredReport = _latestStructuredReport(toolCalls);
  for (final entry in scenario.requiredStructuredReportTermGroups.entries) {
    final sectionText = _structuredReportSectionText(
      structuredReport,
      entry.key,
    );
    if (sectionText == null ||
        entry.value.any((group) => !containsAnyEvalTerm(sectionText, group))) {
      return GoalAgentEvalFailureCategory.missingRequiredReportContent;
    }
  }

  final reportText = _latestReportText(toolCalls).toLowerCase();
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
  if (scenario.forbiddenReportPatterns.any(
    (pattern) => RegExp(pattern, caseSensitive: false).hasMatch(reportText),
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

  final userVisibleText = _userVisibleText(assistantContent, toolCalls);
  if (scenario.requiredAssistantContentTermGroups.any(
    (group) => !containsAnyEvalTerm(userVisibleText, group),
  )) {
    return GoalAgentEvalFailureCategory.missingAssistantContent;
  }
  if (scenario.requiredAssistantContentPatterns.any(
    (pattern) => !RegExp(
      pattern,
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(userVisibleText.trimRight()),
  )) {
    return GoalAgentEvalFailureCategory.missingAssistantContent;
  }
  if (scenario.forbiddenAssistantContentClaims.any(
    (claim) => containsAffirmativeReportClaim(userVisibleText, claim),
  )) {
    return GoalAgentEvalFailureCategory.forbiddenAssistantClaim;
  }

  return GoalAgentEvalFailureCategory.none;
}

/// Exactly what the user reads this turn — the SURFACED text, not every
/// string the model produced.
///
/// The runtime persists `strategy.replyToUser ?? strategy.finalResponse`:
/// when a reply carrier exists it wins outright and the bare assistant prose
/// stays a hidden thought. Concatenating both let hidden text satisfy a
/// requirement the visible answer missed — and let a forbidden claim the user
/// never saw fail an otherwise clean reply. Precedence, not union.
String _userVisibleText(
  String assistantContent,
  List<GoalAgentEvalToolCall> toolCalls,
) {
  final replies = [
    for (final call in toolCalls)
      if (call.name == GoalAgentToolNames.replyToUser)
        if (call.jsonObjectArguments?['message'] case final String message)
          if (message.trim().isNotEmpty) message,
  ];
  return replies.isEmpty ? assistantContent : replies.join('\n');
}

String _argumentsFor(List<GoalAgentEvalToolCall> toolCalls, String name) =>
    toolCalls
        .where((call) => call.name == name)
        .map((call) => call.argumentsJson)
        .join('\n');

String _latestReportText(List<GoalAgentEvalToolCall> toolCalls) {
  for (final call in toolCalls.reversed) {
    if (call.name == GoalAgentToolNames.updateGoalReport) {
      final arguments = call.jsonObjectArguments;
      final structured = GoalStructuredReport.tryParse(arguments?['report']);
      if (structured == null) return call.argumentsJson;
      final summary = structured.visibleSummary(
        allowedCurrentActionCriterionIds: {
          for (final action in structured.now) action.criterionId,
        },
      );
      final oneLiner = arguments?['oneLiner'];
      // Every string the user can actually read, including the TLDR. The
      // TLDR is the *collapsed* view — the one text guaranteed to be on
      // screen — and `visibleSummary` deliberately omits it, so checking
      // only the summary would let a forbidden claim sit in the most visible
      // slot on the card and still pass every scenario assertion.
      return [
        if (oneLiner is String && oneLiner.trim().isNotEmpty) oneLiner.trim(),
        structured.tldr,
        summary,
      ].where((part) => part.isNotEmpty).join('\n\n');
    }
  }
  return '';
}

GoalStructuredReport? _latestStructuredReport(
  List<GoalAgentEvalToolCall> toolCalls,
) {
  for (final call in toolCalls.reversed) {
    if (call.name == GoalAgentToolNames.updateGoalReport) {
      return GoalStructuredReport.tryParse(
        call.jsonObjectArguments?['report'],
      );
    }
  }
  return null;
}

String? _structuredReportSectionText(
  GoalStructuredReport? report,
  String key,
) => switch ((report, key)) {
  (final GoalStructuredReport value, GoalReportSectionKeys.currentPeriod) =>
    value.currentPeriod,
  (final GoalStructuredReport value, GoalReportSectionKeys.rollingWindow) =>
    value.rollingWindow,
  (final GoalStructuredReport value, GoalReportSectionKeys.latestChange) =>
    value.latestChange,
  (final GoalStructuredReport value, GoalReportSectionKeys.coverage) =>
    value.coverage,
  _ => null,
};

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
          // Mirrors `GoalAgentWorkflow`: a wake whose deterministic tier has
          // ruled out a banner is never handed the ad-creation tools, so the
          // eval measures the surface the app actually presents rather than a
          // harder problem the runtime never poses.
          tools: [
            for (final tool in goalAgentTools)
              if (scenario.adToolsOffered ||
                  (tool.name != GoalAgentToolNames.createGoalAd &&
                      tool.name != GoalAgentToolNames.rerunGoalAd))
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

      strategy.beginExchange(0);
      await exchange(scenario.facts);
      for (final (index, followUp) in scenario.followUpUserMessages.indexed) {
        strategy.beginExchange(index + 1);
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
