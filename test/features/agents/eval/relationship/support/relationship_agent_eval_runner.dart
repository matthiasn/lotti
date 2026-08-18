/// Runner, recording strategy, classifier and report for the
/// relationship-agent inference eval.
///
/// Chassis-wise this is the goal-agent inference eval, relationship-shaped.
/// Two deliberate differences, both because the runtime differs:
///
/// * **The full tool surface is always offered.** `GoalAgentWorkflow`
///   withholds the ad tools from a wake its deterministic tier has already
///   ruled out; `RelationshipAgentWorkflow` does not — it hands over all
///   four tools every time and enforces the banner rules in the FACTS block
///   and again at persistence. Withholding here would measure a surface the
///   app never presents.
/// * **The classifier mirrors `RelationshipAgentStrategy` exactly.** Every
///   shape rule below is one the runtime rejects in-conversation. Being
///   stricter than the code under test is the same defect as being looser:
///   both measure the harness rather than the model.
library;

import 'dart:convert';

import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../ai/eval/support/eval_text_matchers.dart';
import 'relationship_agent_eval_scenarios.dart';
import 'relationship_agent_spec.dart';

const relationshipAgentEvalKind = 'lotti.relationshipAgentInferenceEvalReport';

/// A recorded tool call.
class RelationshipAgentEvalToolCall {
  const RelationshipAgentEvalToolCall({
    required this.name,
    required this.argumentsJson,
    this.exchangeIndex = 0,
  });

  final String name;
  final String argumentsJson;

  /// Which user turn produced this call. "At most once per wake" is a
  /// per-wake rule, and a follow-up message is a separate wake to the
  /// runtime — a flattened list cannot tell a second reply from the
  /// legitimate reply to a follow-up.
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

enum RelationshipAgentEvalFailureCategory {
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
  forbiddenAssistantContent,
  forbiddenAssistantClaim,
  healthBandMismatch,
  adToneViolation,
}

/// One (model, scenario) outcome.
class RelationshipAgentEvalCaseResult {
  const RelationshipAgentEvalCaseResult({
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
  final RelationshipAgentEvalScenario scenario;
  final List<RelationshipAgentEvalToolCall> toolCalls;

  /// All plain assistant text across turns, newline-joined.
  final String assistantContent;
  final int latencyMs;
  final RelationshipAgentEvalFailureCategory failureCategory;
  final int? inputTokens;
  final int? outputTokens;
  final int? thoughtsTokens;
  final int? cachedInputTokens;

  /// Consumption events attributed to this case's wake-run key. Only the
  /// Melious non-streaming path fills in billing.
  final List<AiConsumptionEvent> consumption;
  final String? errorMessage;

  bool get passed =>
      failureCategory == RelationshipAgentEvalFailureCategory.none;

  /// Total reported energy for this case in watt-hours, or null when the
  /// provider sent no energy data.
  double? get energyWh {
    final values = consumption
        .map((e) => e.energyKwh)
        .whereType<double>()
        .toList();
    return values.isEmpty ? null : values.reduce((a, b) => a + b) * 1000;
  }

  /// Total billed credits, or null when nothing was reported. Never
  /// zero-defaulted: a missing bill is not a free run.
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

/// The report: matrix, failures and cost.
class RelationshipAgentEvalReport {
  const RelationshipAgentEvalReport({
    required this.provider,
    required this.modelIds,
    required this.scenarios,
    required this.results,
    required this.temperature,
    required this.wakesPerDayAssumption,
  });

  final AiConfigInferenceProvider provider;
  final List<String> modelIds;
  final List<RelationshipAgentEvalScenario> scenarios;
  final List<RelationshipAgentEvalCaseResult> results;
  final double temperature;

  /// Printed assumption behind the €/relationship-month extrapolation — an
  /// OBSERVED ESTIMATE input, never a target.
  final int wakesPerDayAssumption;

  Map<String, Object?> toJson() => {
    'kind': relationshipAgentEvalKind,
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
      ..writeln('# Relationship-agent inference eval')
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
        '| Model | Cases | In | Out | Credits | '
        'Credits/relationship-month* | Wh | Wh/relationship-month* |',
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
      final perRelationshipMonth = credits == null
          ? null
          : credits / creditValues.length * wakesPerDayAssumption * 30;
      final energyValues = cases
          .map((r) => r.energyWh)
          .whereType<double>()
          .toList();
      final energyWh = energyValues.isEmpty
          ? null
          : energyValues.reduce((a, b) => a + b);
      final energyPerRelationshipMonth = energyWh == null
          ? null
          : energyWh / energyValues.length * wakesPerDayAssumption * 30;
      buffer.writeln(
        '| `$modelId` | ${cases.length} | $inTokens | $outTokens | '
        '${credits?.toStringAsFixed(4) ?? 'not reported'} | '
        '${perRelationshipMonth?.toStringAsFixed(4) ?? 'not reported'} | '
        '${energyWh?.toStringAsFixed(2) ?? 'not reported'} | '
        '${energyPerRelationshipMonth?.toStringAsFixed(1) ?? 'not reported'} '
        '|',
      );
    }
    buffer
      ..writeln()
      ..writeln(
        '*Extrapolation assumes $wakesPerDayAssumption LLM wakes '
        'per relationship per day — a printed assumption, not a '
        'measurement — and divides by cases that actually reported the '
        'figure: missing telemetry widens uncertainty, it is never counted '
        'as zero. Credits and energy are Melious-reported; "not reported" '
        'means the provider sent no data, never that the run was free. '
        'A deterministic Phase A tick costs no inference at all, so the '
        'real monthly figure is bounded above by this one.',
      );
    return buffer.toString();
  }
}

/// Records every tool call and answers it the way the runtime's strategy
/// would on the happy path: known tools acknowledge, unknown names come back
/// as recoverable errors. Confirming a fabricated tool would make the
/// harness measure something the app never does.
class RelationshipAgentEvalStrategy extends ConversationStrategy {
  final _toolCalls = <RelationshipAgentEvalToolCall>[];
  var _exchangeIndex = 0;

  List<RelationshipAgentEvalToolCall> get toolCalls =>
      List.unmodifiable(_toolCalls);

  /// Called by the runner before each user turn, so per-wake rules stay
  /// per-wake across a multi-turn scenario.
  // ignore: use_setters_to_change_properties
  void beginExchange(int index) => _exchangeIndex = index;

  static final Set<String> _knownToolNames = {
    for (final tool in relationshipAgentTools) tool.name,
  };

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      final recorded = RelationshipAgentEvalToolCall(
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

  String _responseFor(RelationshipAgentEvalToolCall call) {
    if (!_knownToolNames.contains(call.name)) {
      return jsonEncode({
        'error':
            'Unknown tool: ${call.name}. Available tools: '
            '${_knownToolNames.join(', ')}.',
      });
    }
    if (call.jsonObjectArguments == null) {
      return jsonEncode({'error': 'Invalid JSON arguments for ${call.name}.'});
    }
    return switch (call.name) {
      RelationshipAgentToolNames.updateRelationshipReport => jsonEncode({
        'status': 'ok',
        'detail': 'Briefing updated.',
      }),
      RelationshipAgentToolNames.createRelationshipAd => jsonEncode({
        'status': 'queued',
        'detail': 'Banner nudge queued for rendering.',
      }),
      RelationshipAgentToolNames.snoozeRelationshipAd => jsonEncode({
        'status': 'ok',
        'detail': 'Banner snoozed.',
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

  /// Never nags — the production strategy does not either, and a
  /// continuation prompt demanding output would train churn back in and
  /// destroy the no-op discriminator.
  @override
  String? getContinuationPrompt(ConversationManager manager) => null;
}

/// Deterministic classifier — first violated check names the failure.
///
/// Every shape rule below mirrors a rejection `RelationshipAgentStrategy`
/// performs in-conversation. Where the runtime is lenient the classifier is
/// too (an out-of-catalog accent silently becomes `calm`, so it is not a
/// failure here either); where the runtime rejects, a recorded call that
/// would have been rejected must not score as a success just because its
/// name matched.
RelationshipAgentEvalFailureCategory classifyRelationshipAgentResult({
  required RelationshipAgentEvalScenario scenario,
  required List<RelationshipAgentEvalToolCall> toolCalls,
  required String assistantContent,
}) {
  if (scenario.expectsNoToolCalls && toolCalls.isNotEmpty) {
    return RelationshipAgentEvalFailureCategory.noOpViolated;
  }

  if (toolCalls.any((call) => call.jsonObjectArguments == null)) {
    return RelationshipAgentEvalFailureCategory.invalidToolArguments;
  }

  // --- Shape rules, mirrored from the strategy's rejections. ------------

  for (final call in toolCalls) {
    final args = call.jsonObjectArguments!;
    switch (call.name) {
      case RelationshipAgentToolNames.updateRelationshipReport:
        final band = args['healthBand'];
        final validBand =
            band is String && relationshipHealthBandNames.contains(band);
        final requiredTexts = [
          args['healthRationale'],
          args['oneLiner'],
          args['tldr'],
          args['content'],
        ];
        final validTexts = requiredTexts.every(
          (value) => value is String && value.trim().isNotEmpty,
        );
        if (!validBand || !validTexts) {
          return RelationshipAgentEvalFailureCategory.invalidToolArguments;
        }
        // Band names are field values, never prose. The strategy bans only
        // the UNMISTAKABLE camelCase identifiers — `steady` or `strained`
        // are ordinary English a legitimate briefing may well contain.
        final unmistakable = relationshipHealthBandNames.where(
          (token) => token != token.toLowerCase(),
        );
        for (final value in requiredTexts) {
          for (final token in unmistakable) {
            if (RegExp('\\b$token\\b').hasMatch(value! as String)) {
              return RelationshipAgentEvalFailureCategory
                  .forbiddenReportContent;
            }
          }
        }
      case RelationshipAgentToolNames.createRelationshipAd:
        final headline = args['headline'];
        final validHeadline = headline is String && headline.trim().isNotEmpty;
        final validTone = relationshipNudgeToneNames.contains(args['tone']);
        final validAnimation = relationshipBannerAnimationNames.contains(
          args['animation'],
        );
        final validOptionalCopy = [
          args['tagline'],
          args['cta'],
        ].every((value) => value == null || value is String);
        if (!validHeadline ||
            !validTone ||
            !validAnimation ||
            !validOptionalCopy) {
          return RelationshipAgentEvalFailureCategory.invalidToolArguments;
        }
      case RelationshipAgentToolNames.replyToUser:
        final message = args['message'];
        if (message is! String || message.trim().isEmpty) {
          return RelationshipAgentEvalFailureCategory.invalidToolArguments;
        }
      case RelationshipAgentToolNames.snoozeRelationshipAd:
        final adId = args['adId'];
        final reason = args['reason'];
        final untilText = args['until'];
        // The strategy demands an EXPLICIT offset; a local instant would
        // shift on a syncing peer, so `2026-08-09T19:00:00` is rejected
        // even though DateTime.tryParse would take it.
        final hasExplicitOffset =
            untilText is String &&
            RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(untilText.trim());
        final until = hasExplicitOffset
            ? DateTime.tryParse(untilText.trim())?.toUtc()
            : null;
        if (adId is! String ||
            adId.trim().isEmpty ||
            reason is! String ||
            reason.trim().isEmpty ||
            until == null ||
            !until.isAfter(scenario.now.toUtc())) {
          return RelationshipAgentEvalFailureCategory.invalidToolArguments;
        }
        // A hallucinated id fails in-conversation in production; here it
        // fails the case (the FACTS hand the model every active id).
        if (!scenario.activeAdIds.contains(adId.trim())) {
          return RelationshipAgentEvalFailureCategory.argumentMismatch;
        }
    }
  }

  if (toolCalls.any(
    (call) => scenario.forbiddenToolNames.contains(call.name),
  )) {
    return RelationshipAgentEvalFailureCategory.forbiddenToolCall;
  }

  // --- Cardinality, per exchange (a follow-up is a separate wake). ------

  for (final name in [
    RelationshipAgentToolNames.replyToUser,
    RelationshipAgentToolNames.createRelationshipAd,
  ]) {
    final exchanges = <int>{};
    for (final call in toolCalls.where((call) => call.name == name)) {
      if (!exchanges.add(call.exchangeIndex)) {
        return RelationshipAgentEvalFailureCategory.toolCallOverBudget;
      }
    }
  }

  // Tools outside expected ∪ tolerated. Reporting is always tolerated —
  // the policy regulates it by situation, and over-reporting is measured
  // by the no-op scenario, not this allow-list. `reply_to_user` is
  // tolerated exactly when a pending message exists (its own tool
  // description scopes it to that case); an unsolicited reply on a
  // scheduled wake is chat the user never asked for. Banner actions are
  // never tolerated implicitly: an unexpected banner is spend and an
  // unexpected snooze is silence, both user-visible.
  final allowedNames = {
    for (final expected in scenario.expectedToolCalls) expected.name,
    RelationshipAgentToolNames.updateRelationshipReport,
    if (scenario.hasPendingUserMessage) RelationshipAgentToolNames.replyToUser,
  }..removeAll(scenario.forbiddenToolNames);
  if (toolCalls.any((call) => !allowedNames.contains(call.name))) {
    return RelationshipAgentEvalFailureCategory.unexpectedToolCall;
  }

  for (final expected in scenario.expectedToolCalls) {
    final matching = toolCalls
        .where((call) => call.name == expected.name)
        .toList();
    if (matching.isEmpty) {
      return RelationshipAgentEvalFailureCategory.missingExpectedToolCall;
    }
    if (expected.expectedArgumentsSubset.isNotEmpty &&
        !matching.any(
          (call) => _containsExpectedValues(
            call.jsonObjectArguments ?? const {},
            expected.expectedArgumentsSubset,
          ),
        )) {
      return RelationshipAgentEvalFailureCategory.argumentMismatch;
    }
  }

  // --- The health verdict and the banner tone are policy, not taste. ----

  final report = _latestReport(toolCalls);
  if (scenario.expectedHealthBands.isNotEmpty) {
    final band = RelationshipHealthBand.values
        .where((b) => b.name == report?['healthBand'])
        .firstOrNull;
    if (band == null || !scenario.expectedHealthBands.contains(band)) {
      return RelationshipAgentEvalFailureCategory.healthBandMismatch;
    }
  }

  final adTones = [
    for (final call in toolCalls)
      if (call.name == RelationshipAgentToolNames.createRelationshipAd)
        NudgeTone.values
            .where((t) => t.name == call.jsonObjectArguments!['tone'])
            .firstOrNull,
  ].whereType<NudgeTone>();
  if (adTones.any(scenario.forbiddenAdTones.contains)) {
    return RelationshipAgentEvalFailureCategory.adToneViolation;
  }
  if (scenario.expectedAdTones.isNotEmpty &&
      !adTones.any(scenario.expectedAdTones.contains)) {
    return RelationshipAgentEvalFailureCategory.adToneViolation;
  }

  // --- Content checks over what the user actually reads. ----------------

  final reportText = _visibleReportText(report).toLowerCase();
  if (scenario.requiredReportTermGroups.any(
    (group) => !containsAnyEvalTerm(reportText, group),
  )) {
    return RelationshipAgentEvalFailureCategory.missingRequiredReportContent;
  }
  if (scenario.requiredReportPatterns.any(
    (pattern) => !RegExp(pattern, caseSensitive: false).hasMatch(reportText),
  )) {
    return RelationshipAgentEvalFailureCategory.missingRequiredReportContent;
  }
  if (scenario.forbiddenReportClaims.any(
    (claim) => containsAffirmativeReportClaim(reportText, claim),
  )) {
    return RelationshipAgentEvalFailureCategory.forbiddenReportContent;
  }

  for (final entry in scenario.requiredToolArgumentTermGroups.entries) {
    final arguments = _argumentsFor(toolCalls, entry.key);
    if (entry.value.any((group) => !containsAnyEvalTerm(arguments, group))) {
      return RelationshipAgentEvalFailureCategory.missingRequiredToolArguments;
    }
  }
  for (final entry in scenario.forbiddenToolArgumentTerms.entries) {
    final arguments = _argumentsFor(toolCalls, entry.key).toLowerCase();
    if (entry.value.any((term) => arguments.contains(term.toLowerCase()))) {
      return RelationshipAgentEvalFailureCategory.forbiddenToolArguments;
    }
  }

  final userVisibleText = _userVisibleText(assistantContent, toolCalls);
  if (scenario.requiredAssistantContentTermGroups.any(
    (group) => !containsAnyEvalTerm(userVisibleText, group),
  )) {
    return RelationshipAgentEvalFailureCategory.missingAssistantContent;
  }
  final loweredVisible = userVisibleText.toLowerCase();
  if (scenario.forbiddenAssistantContentTerms.any(
    (term) => loweredVisible.contains(term.toLowerCase()),
  )) {
    return RelationshipAgentEvalFailureCategory.forbiddenAssistantContent;
  }
  if (scenario.forbiddenAssistantContentClaims.any(
    (claim) => containsAffirmativeReportClaim(userVisibleText, claim),
  )) {
    return RelationshipAgentEvalFailureCategory.forbiddenAssistantClaim;
  }

  return RelationshipAgentEvalFailureCategory.none;
}

/// The latest `update_relationship_report` call's arguments — the runtime
/// keeps only the last accepted briefing, so earlier calls are drafts.
Map<String, dynamic>? _latestReport(
  List<RelationshipAgentEvalToolCall> toolCalls,
) {
  for (final call in toolCalls.reversed) {
    if (call.name == RelationshipAgentToolNames.updateRelationshipReport) {
      return call.jsonObjectArguments;
    }
  }
  return null;
}

/// Every briefing string the user can read: the card renders tldr (or
/// content when tldr is empty), expands to content, shows oneLiner in list
/// rows, and surfaces the rationale as the band chip's tooltip.
String _visibleReportText(Map<String, dynamic>? report) {
  if (report == null) return '';
  return [
    report['oneLiner'],
    report['tldr'],
    report['content'],
    report['healthRationale'],
  ].whereType<String>().join('\n\n');
}

/// Exactly what the user reads this turn: when a reply carrier exists it
/// wins outright and bare assistant prose stays a hidden thought
/// (the runtime persists `strategy.replyToUser ?? strategy.finalResponse`).
/// Precedence, not union — concatenating both would let hidden text satisfy
/// a requirement the visible answer missed.
String _userVisibleText(
  String assistantContent,
  List<RelationshipAgentEvalToolCall> toolCalls,
) {
  final replies = [
    for (final call in toolCalls)
      if (call.name == RelationshipAgentToolNames.replyToUser)
        if (call.jsonObjectArguments?['message'] case final String message)
          if (message.trim().isNotEmpty) message,
  ];
  return replies.isEmpty ? assistantContent : replies.join('\n');
}

String _argumentsFor(
  List<RelationshipAgentEvalToolCall> toolCalls,
  String name,
) => toolCalls
    .where((call) => call.name == name)
    .map((call) => call.argumentsJson)
    .join('\n');

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
String relationshipAgentEvalWakeRunKey(String modelId, String scenarioId) =>
    'relationship-eval:$scenarioId:$modelId';

class RelationshipAgentInferenceEvalRunner {
  RelationshipAgentInferenceEvalRunner({
    required this.provider,
    required this.conversationRepository,
    required this.inferenceRepository,
    this.temperature = 0,
    this.maxTurnsPerExchange = 6,
    this.wakesPerDayAssumption = 1,
    this.consumptionForWakeRunKey,
  });

  final AiConfigInferenceProvider provider;
  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final double temperature;
  final int maxTurnsPerExchange;

  /// Default 1, not the goal suite's 3: a relationship wakes on a lapsed
  /// cadence or a fresh check-in, not on a daily signal sweep.
  final int wakesPerDayAssumption;

  /// Supplied by the live test: returns the consumption events recorded for
  /// one case's wake-run key (from `AiInteractionCaptureTestBench`).
  final List<AiConsumptionEvent> Function(String wakeRunKey)?
  consumptionForWakeRunKey;

  Future<RelationshipAgentEvalReport> run({
    required List<String> modelIds,
    required List<RelationshipAgentEvalScenario> scenarios,
  }) async {
    final results = <RelationshipAgentEvalCaseResult>[];
    for (final modelId in modelIds) {
      for (final scenario in scenarios) {
        results.add(await _runCase(modelId, scenario));
      }
    }
    return RelationshipAgentEvalReport(
      provider: provider,
      modelIds: modelIds,
      scenarios: scenarios,
      results: results,
      temperature: temperature,
      wakesPerDayAssumption: wakesPerDayAssumption,
    );
  }

  Future<RelationshipAgentEvalCaseResult> _runCase(
    String modelId,
    RelationshipAgentEvalScenario scenario,
  ) async {
    final stopwatch = Stopwatch()..start();
    final strategy = RelationshipAgentEvalStrategy();
    final wakeRunKey = relationshipAgentEvalWakeRunKey(modelId, scenario.id);
    final conversationId = conversationRepository.createConversation(
      // What production sends when no template version exists —
      // `composeAgentSystemPrompt(version: null)` returns the scaffold, and
      // the relationship workflow passes null explicitly (the constitution
      // is code, ADR 0059).
      systemMessage: relationshipAgentSystemPrompt,
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
          // Unlike the goal workflow, `RelationshipAgentWorkflow` always
          // offers the full surface — banner restraint is enforced by the
          // FACTS block and again at persistence, never by withholding
          // tools. The eval measures the surface the app actually presents.
          tools: [
            for (final tool in relationshipAgentTools)
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
          consumptionAgentId: 'relationship_agent:eval',
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
      return RelationshipAgentEvalCaseResult(
        modelId: modelId,
        scenario: scenario,
        toolCalls: strategy.toolCalls,
        assistantContent: assistantContent,
        latencyMs: stopwatch.elapsedMilliseconds,
        failureCategory: classifyRelationshipAgentResult(
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
      return RelationshipAgentEvalCaseResult(
        modelId: modelId,
        scenario: scenario,
        toolCalls: strategy.toolCalls,
        assistantContent: _assistantContent(manager),
        latencyMs: stopwatch.elapsedMilliseconds,
        failureCategory: RelationshipAgentEvalFailureCategory.inferenceError,
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
