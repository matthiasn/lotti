/// Tier 2 of the goal-agent eval: score what the wake PERSISTED, not what
/// the model attempted.
///
/// Tier 1 (`goal_agent_eval_runner.dart`) sends a hand-authored FACTS block
/// straight to a model and grades the tool calls that come back. It is cheap,
/// fast and every scenario is legible — but three whole layers of production
/// sit between a tool call and the user, and tier 1 cannot see any of them:
///
///  1. **The FACTS are authored.** Production renders them from domain
///     entities via `GoalFactsRenderer`. A fixture that drifts from the
///     renderer measures a prompt the app never sends.
///  2. **The strategy rejects.** `GoalAgentStrategy` refuses a report that
///     contradicts the deterministic status, an aggregate the FACTS never
///     carried, an ad id that was never offered. Tier 1's recording strategy
///     accepts everything.
///  3. **The workflow repairs.** `_forceReport`, `_forceAd` and `_forceReply`
///     re-ask when a required output is missing, and persistence discards ads
///     on turns that did not request one. A tier-1 "failure" may be a
///     production success, and a tier-1 "pass" may persist nothing at all.
///
/// So this tier runs the real [GoalAgentWorkflow] against a live model over a
/// world built from real entities, and grades the writes. The two tiers'
/// numbers are NOT comparable — tier 1 scores attempts, tier 2 scores
/// outcomes — and that gap is the measurement, not a defect.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/workflow/goal_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../ai/eval/support/eval_text_matchers.dart';
import '../../../test_data/entity_factories.dart';
import 'goal_eval_cost_table.dart';

const goalAgentOutcomeEvalKind = 'lotti.goalAgentOutcomeEvalReport';

/// The agent, period and clock every tier-2 scenario shares. Fixed so a
/// scenario's evidence days and its escalation period cannot drift apart.
const goalOutcomeEvalAgentId = 'goal-eval-agent';
const goalOutcomeEvalPeriodKey = '2026-08-09';
final goalOutcomeEvalNow = DateTime(2026, 8, 9, 12);

/// What the wake was allowed, required and forbidden to leave behind.
///
/// Every field is a policy row restated over persisted entities. A `null`
/// or `false` field is not an expectation — it is silence, and silence must
/// never fail a case.
class GoalOutcomeExpectation {
  const GoalOutcomeExpectation({
    this.expectsNoOutcome = false,
    this.requiresReport = false,
    this.expectedReportStatus,
    this.requiresNewAd = false,
    this.forbidsNewAd = false,
    this.requiresRerun = false,
    this.requiresRetirement = false,
    this.requiredReportTermGroups = const [],
    this.forbiddenReportTerms = const [],
    this.requiresReply = false,
    this.requiredReplyPatterns = const [],
    this.forbiddenReplyClaims = const [],
  });

  /// P2: a wake with nothing to say must leave nothing behind.
  ///
  /// Checked against [GoalAgentEvalOutcome.outcomeWrites], not every write:
  /// a scheduled wake persists its FACTS context row before inference even
  /// starts, and bills its tokens afterwards, so demanding a literally empty
  /// batch would fail every model for doing its bookkeeping. What must be
  /// empty is what the user or the next wake can see.
  final bool expectsNoOutcome;

  /// A standing report must land. Implied by [expectedReportStatus], so a
  /// scenario pinning the status does not need to set both.
  final bool requiresReport;

  /// The deterministic tier's status, which the persisted report's
  /// provenance must carry. `GoalAgentStrategy` already rejects a
  /// contradicting claim in-conversation; this proves the rejection held all
  /// the way to the write. Requiring the report is part of the claim: "the
  /// report must say insufficientData" cannot be satisfied by no report.
  final GoalTrackStatus? expectedReportStatus;

  /// A newly authored banner (activation 1). Distinct from [requiresRerun],
  /// which reuses proven copy at zero authoring cost.
  final bool requiresNewAd;

  /// No banner may be *activated* this wake — neither authored nor re-run.
  /// This is the outcome-level form of "ad over-creation", and unlike tier 1
  /// it is blind to attempts persistence would have discarded anyway.
  final bool forbidsNewAd;

  final bool requiresRerun;

  /// A stale banner must end the wake retired.
  final bool requiresRetirement;

  /// Each group is a synonym set: the report must contain at least one term
  /// from every group.
  final List<List<String>> requiredReportTermGroups;
  final List<String> forbiddenReportTerms;

  /// Interactive turns only: the user must actually get an answer.
  final bool requiresReply;
  final List<String> requiredReplyPatterns;
  final List<String> forbiddenReplyClaims;
}

/// A tier-2 scenario: a goal world expressed in domain entities, so the FACTS
/// the model reads are rendered by production rather than authored here.
class GoalOutcomeEvalScenario {
  const GoalOutcomeEvalScenario({
    required this.id,
    required this.policyRuleId,
    required this.statement,
    required this.criteria,
    required this.window,
    required this.expectation,
    this.title = 'Goal',
    this.nudges,
    this.priorRegisters,
    this.pendingUserMessage,
    this.previousAssistantMessage,
    this.triggerTokens = const {
      'goal-escalation:$goalOutcomeEvalPeriodKey',
    },
  });

  final String id;

  /// The row of `goalAgentPolicyMatrix` this scenario instantiates.
  final String policyRuleId;
  final String title;
  final String statement;
  final GoalCriterion criteria;

  /// The evidence Phase A derives from — the ONLY place a scenario states
  /// what happened. Status, attainment and trend all follow from it.
  final GoalSignalWindow window;

  /// Banners already on the board, built against the run's clock so
  /// freshness, cooldown and reusability resolve the way they would live.
  final List<GoalNudgeEntity> Function(String agentId, DateTime now)? nudges;

  /// Prior period registers keyed by period key, for scenarios whose policy
  /// depends on trend rather than on today alone.
  final Map<String, GoalProgressEntity> Function(String agentId, DateTime now)?
  priorRegisters;

  final String? pendingUserMessage;
  final String? previousAssistantMessage;
  final Set<String> triggerTokens;

  final GoalOutcomeExpectation expectation;
}

enum GoalOutcomeFailureCategory {
  none,
  inferenceError,
  wakeFailed,
  writesOnNoOp,
  missingReport,
  wrongReportStatus,
  missingReportContent,
  forbiddenReportContent,
  missingAd,
  unexpectedAd,
  missingRerun,
  missingRetirement,
  missingReply,
  missingReplyContent,
  forbiddenReplyClaim,
}

/// Everything one wake left behind, projected out of the captured upserts.
class GoalAgentEvalOutcome {
  const GoalAgentEvalOutcome({
    required this.wakeSucceeded,
    required this.writes,
    this.wakeError,
  });

  final bool wakeSucceeded;
  final String? wakeError;
  final List<AgentDomainEntity> writes;

  AgentReportEntity? get report =>
      writes.whereType<AgentReportEntity>().lastOrNull;

  /// Every value the persisted report exposes to the user, joined — the
  /// report is graded as the user reads it, not field by field.
  String get reportText {
    final entity = report;
    if (entity == null) return '';
    return [
      entity.oneLiner,
      entity.tldr,
      entity.content,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join('\n');
  }

  List<GoalNudgeEntity> get nudgeWrites =>
      writes.whereType<GoalNudgeEntity>().toList(growable: false);

  /// The writes that constitute an OUTCOME — what the user or a later wake
  /// can see. Everything a wake persists regardless of what it decided is
  /// excluded by construction:
  ///
  ///  * the FACTS context row (`system` message) and its payload — inspectable
  ///    provenance, written before inference even starts;
  ///  * the final-prose `thought` row and its payload — never surfaced;
  ///  * `WakeTokenUsageEntity` — cost bookkeeping.
  ///
  /// A report, a report head, a banner, an observation, a proposal or a
  /// user-visible reply all survive the filter, which is what makes
  /// [GoalOutcomeExpectation.expectsNoOutcome] a real claim rather than a
  /// tautology.
  List<AgentDomainEntity> get outcomeWrites {
    final bookkeepingPayloadIds = {
      for (final message in writes.whereType<AgentMessageEntity>())
        if (message.kind == AgentMessageKind.system ||
            message.kind == AgentMessageKind.thought)
          ?message.contentEntryId,
    };
    return [
      for (final write in writes)
        if (write is! WakeTokenUsageEntity)
          if (!(write is AgentMessageEntity &&
              (write.kind == AgentMessageKind.system ||
                  write.kind == AgentMessageKind.thought)))
            if (!(write is AgentMessagePayloadEntity &&
                bookkeepingPayloadIds.contains(write.id)))
              write,
    ];
  }

  /// Banners this wake put in front of the user. Both arms of "an ad
  /// appeared" — freshly authored copy and a re-run of proven copy — because
  /// the user cannot tell them apart and the cooldown does not either.
  List<GoalNudgeEntity> get activatedAds => nudgeWrites
      .where((n) => n.status == NudgeStatus.active)
      .toList(growable: false);

  List<GoalNudgeEntity> get newAds =>
      activatedAds.where((n) => n.activationCount <= 1).toList(growable: false);

  List<GoalNudgeEntity> get rerunAds =>
      activatedAds.where((n) => n.activationCount > 1).toList(growable: false);

  List<GoalNudgeEntity> get retiredAds => nudgeWrites
      .where((n) => n.status == NudgeStatus.retired)
      .toList(growable: false);

  /// Every tool call the deterministic guard refused, as `tool: reason`.
  ///
  /// This is the tier's most useful diagnostic and it exists nowhere else: a
  /// rejection is invisible to tier 1 (whose strategy accepts everything) and
  /// invisible in the final state (a repaired wake looks identical to one
  /// that got it right first time). A scenario that passes only after two
  /// refusals is paying for three turns to do one turn's work, and a
  /// scenario that fails after two refusals shows exactly which rule the
  /// model could not satisfy.
  List<String> get rejections => [
    for (final message in writes.whereType<AgentMessageEntity>())
      if (message.kind == AgentMessageKind.toolResult)
        if (message.metadata.errorMessage case final String error)
          '${message.metadata.toolName}: ${error.split('\n').first}',
  ];

  /// The reply as the chat surface will render it: the `reply_to_user`
  /// action row's payload text. Read through the same message→payload join
  /// the projection uses, so a reply that persisted without its payload
  /// counts as no reply — which is what the user would see.
  String? get visibleReply {
    final action = writes
        .whereType<AgentMessageEntity>()
        .where(
          (m) =>
              m.kind == AgentMessageKind.action &&
              m.metadata.toolName == AgentConversationToolNames.replyToUser,
        )
        .lastOrNull;
    final payloadId = action?.contentEntryId;
    if (payloadId == null) return null;
    final payload = writes
        .whereType<AgentMessagePayloadEntity>()
        .where((p) => p.id == payloadId)
        .lastOrNull;
    final text = payload?.content['text'];
    return text is String && text.trim().isNotEmpty ? text : null;
  }

  Map<String, Object?> toJson() => {
    'wakeSucceeded': wakeSucceeded,
    'wakeError': wakeError,
    'reportText': reportText,
    'reportStatus': report?.provenance['trackStatus'],
    'newAdHeadlines': [for (final ad in newAds) ad.brief.headline],
    'rerunAdIds': [for (final ad in rerunAds) ad.id],
    'retiredAdIds': [for (final ad in retiredAds) ad.id],
    'visibleReply': visibleReply,
    'rejections': rejections,
    // Message rows carry their kind: "six AgentMessageEntity" says nothing
    // about what a wake did, while "six observations" or "six actions" is a
    // diagnosis.
    'outcomeWrites': [
      for (final write in outcomeWrites)
        if (write is AgentMessageEntity)
          'AgentMessage(${write.kind.name}'
              '${write.metadata.toolName == null ? '' : ':${write.metadata.toolName}'})'
        else
          write.runtimeType.toString(),
    ],
  };
}

/// Deterministic outcome classifier — first violated expectation names the
/// failure, same discipline as tier 1.
GoalOutcomeFailureCategory classifyGoalAgentOutcome({
  required GoalOutcomeEvalScenario scenario,
  required GoalAgentEvalOutcome outcome,
}) {
  if (!outcome.wakeSucceeded) return GoalOutcomeFailureCategory.wakeFailed;
  final expectation = scenario.expectation;

  // The no-op row is checked first and across every outcome kind, not just
  // banners: a wake that "did nothing" while advancing the report head did
  // not do nothing.
  if (expectation.expectsNoOutcome && outcome.outcomeWrites.isNotEmpty) {
    return GoalOutcomeFailureCategory.writesOnNoOp;
  }

  // Pinning the status IMPLIES requiring the report. Checking the status
  // only when a report exists let a wake that persisted nothing at all pass
  // a scenario whose whole point was what the report must say — the exact
  // vacuous pass the testing conventions warn about, and it inflated the
  // first published tier-2 numbers before review caught it.
  final expectedStatus = expectation.expectedReportStatus;
  if ((expectation.requiresReport || expectedStatus != null) &&
      outcome.report == null) {
    return GoalOutcomeFailureCategory.missingReport;
  }
  if (expectedStatus != null &&
      outcome.report!.provenance['trackStatus'] != expectedStatus.name) {
    return GoalOutcomeFailureCategory.wrongReportStatus;
  }

  final reportText = outcome.reportText;
  if (expectation.requiredReportTermGroups.any(
    (group) => !containsAnyEvalTerm(reportText, group),
  )) {
    return GoalOutcomeFailureCategory.missingReportContent;
  }
  if (expectation.forbiddenReportTerms.any(
    (term) => reportText.toLowerCase().contains(term.toLowerCase()),
  )) {
    return GoalOutcomeFailureCategory.forbiddenReportContent;
  }

  if (expectation.forbidsNewAd && outcome.activatedAds.isNotEmpty) {
    return GoalOutcomeFailureCategory.unexpectedAd;
  }
  if (expectation.requiresNewAd && outcome.newAds.isEmpty) {
    return GoalOutcomeFailureCategory.missingAd;
  }
  if (expectation.requiresRerun && outcome.rerunAds.isEmpty) {
    return GoalOutcomeFailureCategory.missingRerun;
  }
  if (expectation.requiresRetirement && outcome.retiredAds.isEmpty) {
    return GoalOutcomeFailureCategory.missingRetirement;
  }

  final reply = outcome.visibleReply;
  if (expectation.requiresReply && (reply == null || reply.trim().isEmpty)) {
    return GoalOutcomeFailureCategory.missingReply;
  }
  if (reply != null) {
    if (expectation.requiredReplyPatterns.any(
      (pattern) => !RegExp(
        pattern,
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(reply.trimRight()),
    )) {
      return GoalOutcomeFailureCategory.missingReplyContent;
    }
    if (expectation.forbiddenReplyClaims.any(
      (claim) => containsAffirmativeReportClaim(reply, claim),
    )) {
      return GoalOutcomeFailureCategory.forbiddenReplyClaim;
    }
  }

  return GoalOutcomeFailureCategory.none;
}

/// One (model, scenario) tier-2 outcome.
class GoalOutcomeEvalCaseResult implements GoalEvalCostCase {
  const GoalOutcomeEvalCaseResult({
    required this.modelId,
    required this.scenario,
    required this.outcome,
    required this.latencyMs,
    required this.failureCategory,
    this.inputTokens,
    this.outputTokens,
    this.consumption = const [],
    this.errorMessage,
  });

  @override
  final String modelId;
  final GoalOutcomeEvalScenario scenario;
  final GoalAgentEvalOutcome outcome;
  final int latencyMs;
  final GoalOutcomeFailureCategory failureCategory;
  @override
  final int? inputTokens;
  @override
  final int? outputTokens;
  final List<AiConsumptionEvent> consumption;
  final String? errorMessage;

  bool get passed => failureCategory == GoalOutcomeFailureCategory.none;

  @override
  double? get credits {
    final values = consumption.map((e) => e.credits).whereType<double>();
    return values.isEmpty ? null : values.reduce((a, b) => a + b);
  }

  @override
  double? get energyWh {
    final values = consumption.map((e) => e.energyKwh).whereType<double>();
    return values.isEmpty ? null : values.reduce((a, b) => a + b) * 1000;
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
    'credits': credits,
    'energyWh': energyWh,
    'outcome': outcome.toJson(),
    'errorMessage': errorMessage,
  };
}

/// The tier-2 report. Same cost table as tier 1 (shared, not copied); the
/// failure section prints persisted entities rather than tool calls, because
/// that is what this tier can actually testify about.
class GoalOutcomeEvalReport {
  const GoalOutcomeEvalReport({
    required this.provider,
    required this.modelIds,
    required this.scenarios,
    required this.results,
    required this.wakesPerDayAssumption,
  });

  final AiConfigInferenceProvider provider;
  final List<String> modelIds;
  final List<GoalOutcomeEvalScenario> scenarios;
  final List<GoalOutcomeEvalCaseResult> results;
  final int wakesPerDayAssumption;

  Map<String, Object?> toJson() => {
    'kind': goalAgentOutcomeEvalKind,
    'provider': {
      'id': provider.id,
      'type': provider.inferenceProviderType.name,
      'baseUrl': provider.baseUrl,
    },
    'modelIds': modelIds,
    'wakesPerDayAssumption': wakesPerDayAssumption,
    'scenarioIds': [for (final scenario in scenarios) scenario.id],
    'results': [for (final result in results) result.toJson()],
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Goal-agent OUTCOME eval (tier 2)')
      ..writeln()
      ..writeln(
        'Scores what the real `GoalAgentWorkflow` PERSISTED — not what the '
        'model attempted. Strategy rejections, forced retries and the '
        'persistence gates are all inside the measurement, so these numbers '
        'are not comparable with the tier-1 inference eval.',
      )
      ..writeln()
      ..writeln('Provider: `${provider.baseUrl}`.')
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
        return '${cases.where((r) => r.passed).length}/${cases.length}';
      });
      buffer.writeln(
        '| ${scenario.id} | ${scenario.policyRuleId} | ${cells.join(' | ')} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Failures')
      ..writeln();
    final failures = results.where((r) => !r.passed).toList();
    if (failures.isEmpty) buffer.writeln('None.');
    for (final failure in failures) {
      buffer
        ..writeln(
          '### ${failure.scenario.id} × `${failure.modelId}` — '
          '${failure.failureCategory.name}',
        )
        ..writeln()
        ..writeln(
          'Persisted: report=${failure.outcome.report != null}, '
          'newAds=${failure.outcome.newAds.length}, '
          'reruns=${failure.outcome.rerunAds.length}, '
          'retired=${failure.outcome.retiredAds.length}, '
          'reply=${failure.outcome.visibleReply != null}',
        )
        ..writeln();
      if (failure.outcome.rejections.isNotEmpty) {
        buffer.writeln('Refused by the deterministic guard:');
        for (final rejection in failure.outcome.rejections) {
          buffer.writeln('- $rejection');
        }
        buffer.writeln();
      }
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

/// A signal reader that answers with the scenario's window. The only fake in
/// the tier-2 stack: everything downstream of it — Phase A, the renderer, the
/// strategy, persistence — is the production code.
class GoalOutcomeEvalSignalReader extends GoalSignalReader {
  GoalOutcomeEvalSignalReader(this.window) : super(journalDb: MockJournalDb());

  final GoalSignalWindow window;

  @override
  Future<GoalSignalWindow> read({
    required GoalCriterion criteria,
    required DateTime reference,
    int shortTermDays = 3,
    bool includeTimeEntryEvidence = true,
    DateTime? timeEntryEvidenceStart,
    DateTime? timeEntryEndExclusive,
  }) async => window;
}

/// Wake-run key for one tier-2 case — the consumption-event join key.
///
/// Distinct from tier 1's prefix so a mixed session cannot cross-attribute
/// cost, and carrying the sample index so repeated runs of one scenario bill
/// separately instead of collapsing onto one key.
String goalOutcomeEvalWakeRunKey(
  String modelId,
  String scenarioId, {
  int sample = 0,
}) => 'goal-outcome-eval:$scenarioId:$modelId:$sample';

/// Builds the world for one scenario and runs the REAL workflow over it.
class GoalOutcomeEvalRunner {
  GoalOutcomeEvalRunner({
    required this.provider,
    required this.conversationRepository,
    required this.cloudInferenceRepository,
    this.wakesPerDayAssumption = 3,
    this.consumptionForWakeRunKey,
  });

  final AiConfigInferenceProvider provider;
  final ConversationRepository conversationRepository;
  final CloudInferenceRepository cloudInferenceRepository;
  final int wakesPerDayAssumption;
  final List<AiConsumptionEvent> Function(String wakeRunKey)?
  consumptionForWakeRunKey;

  /// Runs every (model, scenario) pair [repeats] times.
  ///
  /// Repeats are a first-class parameter rather than an outer loop because a
  /// single sample of a live model says almost nothing: the tier-1 noise
  /// floor over five identical runs was wide enough to swallow most of the
  /// differences that looked meaningful at n=1.
  Future<GoalOutcomeEvalReport> run({
    required List<String> modelIds,
    required List<GoalOutcomeEvalScenario> scenarios,
    int repeats = 1,
  }) async {
    final results = <GoalOutcomeEvalCaseResult>[];
    for (final modelId in modelIds) {
      for (var sample = 0; sample < repeats; sample++) {
        for (final scenario in scenarios) {
          results.add(
            await runCase(
              modelId: modelId,
              scenario: scenario,
              sample: sample,
            ),
          );
        }
      }
    }
    return GoalOutcomeEvalReport(
      provider: provider,
      modelIds: modelIds,
      scenarios: scenarios,
      results: results,
      wakesPerDayAssumption: wakesPerDayAssumption,
    );
  }

  Future<GoalOutcomeEvalCaseResult> runCase({
    required String modelId,
    required GoalOutcomeEvalScenario scenario,
    int sample = 0,
  }) async {
    final stopwatch = Stopwatch()..start();
    final wakeRunKey = goalOutcomeEvalWakeRunKey(
      modelId,
      scenario.id,
      sample: sample,
    );
    final bench = buildGoalOutcomeEvalBench(
      scenario: scenario,
      modelId: modelId,
      provider: provider,
      conversationRepository: conversationRepository,
      cloudInferenceRepository: cloudInferenceRepository,
    );

    GoalAgentEvalOutcome outcome;
    String? errorMessage;
    try {
      final result = await withClock(
        Clock.fixed(goalOutcomeEvalNow),
        () => bench.workflow.execute(
          agentIdentity: bench.identity,
          runKey: wakeRunKey,
          triggerTokens: scenario.triggerTokens,
          threadId: 'thread-${scenario.id}',
          pendingUserMessage: scenario.pendingUserMessage,
          previousAssistantMessage: scenario.previousAssistantMessage,
        ),
      );
      outcome = GoalAgentEvalOutcome(
        wakeSucceeded: result.success,
        writes: bench.writes,
        wakeError: result.error,
      );
      errorMessage = result.error;
    } catch (error) {
      // A thrown wake is not a policy failure — it is a broken run, and
      // conflating the two would let an outage read as a model regression.
      return GoalOutcomeEvalCaseResult(
        modelId: modelId,
        scenario: scenario,
        outcome: GoalAgentEvalOutcome(
          wakeSucceeded: false,
          writes: bench.writes,
          wakeError: error.toString(),
        ),
        latencyMs: stopwatch.elapsedMilliseconds,
        failureCategory: GoalOutcomeFailureCategory.inferenceError,
        consumption: consumptionForWakeRunKey?.call(wakeRunKey) ?? const [],
        errorMessage: error.toString(),
      );
    }

    final consumption =
        consumptionForWakeRunKey?.call(wakeRunKey) ??
        const <AiConsumptionEvent>[];
    final usage = bench.writes.whereType<WakeTokenUsageEntity>().toList();
    return GoalOutcomeEvalCaseResult(
      modelId: modelId,
      scenario: scenario,
      outcome: outcome,
      latencyMs: stopwatch.elapsedMilliseconds,
      failureCategory: classifyGoalAgentOutcome(
        scenario: scenario,
        outcome: outcome,
      ),
      inputTokens: usage.isEmpty
          ? null
          : usage.fold<int>(0, (sum, u) => sum + (u.inputTokens ?? 0)),
      outputTokens: usage.isEmpty
          ? null
          : usage.fold<int>(0, (sum, u) => sum + (u.outputTokens ?? 0)),
      consumption: consumption,
      errorMessage: errorMessage,
    );
  }
}

/// The assembled world for one scenario: the workflow under test, the
/// identity that wakes it, and the list every write lands in.
typedef GoalOutcomeEvalBench = ({
  GoalAgentWorkflow workflow,
  AgentIdentityEntity identity,
  List<AgentDomainEntity> writes,
  MockAgentRepository repository,
});

/// Stubs the repository so the goal world of [scenario] exists, and wires a
/// real [GoalAgentWorkflow] over it.
///
/// Shared by the live runner and the offline tests: the offline tests drive
/// the same bench with a scripted conversation repository, so the fixtures
/// themselves are covered in CI without a network call.
GoalOutcomeEvalBench buildGoalOutcomeEvalBench({
  required GoalOutcomeEvalScenario scenario,
  required String modelId,
  required AiConfigInferenceProvider provider,
  required ConversationRepository conversationRepository,
  required CloudInferenceRepository cloudInferenceRepository,
}) {
  const agentId = goalOutcomeEvalAgentId;
  final now = goalOutcomeEvalNow;
  final repository = MockAgentRepository();
  final syncService = MockAgentSyncService();
  final aiConfigRepository = MockAiConfigRepository();
  final writes = <AgentDomainEntity>[];

  // Resolution goes through a PROFILE, not the goal agent's built-in
  // `glm-5.2` default. The default branch matches on `providerModelId`, so it
  // can only ever run one model — while a profile is exactly how a real user
  // points their goal agent somewhere else. Evaluating an arbitrary model
  // therefore means evaluating the profile path, which is the configured
  // wake's own code path anyway.
  const modelConfigId = 'goal-outcome-eval-model';
  const profileId = 'goal-outcome-eval-profile';
  final model =
      AiConfig.model(
            id: modelConfigId,
            name: modelId,
            providerModelId: modelId,
            inferenceProviderId: provider.id,
            createdAt: DateTime(2026),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: true,
            supportsFunctionCalling: true,
            description: 'tier-2 eval model',
          )
          as AiConfigModel;
  when(
    () => aiConfigRepository.getConfigsByType(AiConfigType.model),
  ).thenAnswer((_) async => [model]);
  when(
    () => aiConfigRepository.getConfigById(provider.id),
  ).thenAnswer((_) async => provider);
  when(() => aiConfigRepository.getConfigById(modelConfigId)).thenAnswer(
    (_) async => model,
  );
  when(() => aiConfigRepository.getConfigById(profileId)).thenAnswer(
    (_) async =>
        AiConfig.inferenceProfile(
              id: profileId,
              name: 'Goal outcome eval',
              createdAt: DateTime(2026),
              thinkingModelId: modelConfigId,
            )
            as AiConfigInferenceProfile,
  );

  const specVersionId = '$agentId:spec-v1';
  final priorRegisters =
      scenario.priorRegisters?.call(agentId, now) ??
      const <String, GoalProgressEntity>{};

  when(() => repository.getEntity(any<String>())).thenAnswer((
    invocation,
  ) async {
    final id = invocation.positionalArguments.first as String;
    if (id == goalSpecHeadId(agentId)) {
      return AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: specVersionId,
        updatedAt: DateTime(2026),
        vectorClock: null,
      );
    }
    if (id == specVersionId) {
      return AgentDomainEntity.goalSpecVersion(
        id: specVersionId,
        agentId: agentId,
        version: 1,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: scenario.title,
        statement: scenario.statement,
        criteria: scenario.criteria,
        createdAt: DateTime(2026),
        vectorClock: null,
      );
    }
    for (final entry in priorRegisters.entries) {
      if (id == goalProgressId(agentId, entry.key)) return entry.value;
    }
    return null;
  });

  when(
    () => repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.goalNudge,
    ),
  ).thenAnswer(
    (_) async => scenario.nudges?.call(agentId, now) ?? <GoalNudgeEntity>[],
  );
  when(
    () => repository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
      limit: any<int>(named: 'limit'),
    ),
  ).thenAnswer((_) async => <AgentMessageEntity>[]);
  when(
    () => repository.getReportHead(agentId, AgentReportScopes.current),
  ).thenAnswer((_) async => null);
  when(
    () => repository.getLatestReport(agentId, AgentReportScopes.current),
  ).thenAnswer((_) async => null);
  when(() => syncService.upsertEntity(any<AgentDomainEntity>())).thenAnswer((
    invocation,
  ) async {
    writes.add(invocation.positionalArguments.first as AgentDomainEntity);
  });

  final workflow = GoalAgentWorkflow(
    repository: repository,
    syncService: syncService,
    phaseA: GoalAgentPhaseA(
      repository: repository,
      syncService: syncService,
      signalReader: GoalOutcomeEvalSignalReader(scenario.window),
    ),
    conversationRepository: conversationRepository,
    cloudInferenceRepository: cloudInferenceRepository,
    aiConfigRepository: aiConfigRepository,
  );

  return (
    workflow: workflow,
    identity: makeTestIdentity(
      id: agentId,
      agentId: agentId,
      kind: AgentKinds.goalAgent,
      config: const AgentConfig(profileId: profileId),
    ),
    writes: writes,
    repository: repository,
  );
}

/// Builds a banner row for a scenario's starting board.
GoalNudgeEntity goalOutcomeEvalNudge({
  required String id,
  required String agentId,
  required NudgeStatus status,
  required String headline,
  required DateTime now,
  NudgeTone tone = NudgeTone.nudge,
  Duration age = const Duration(hours: 2),
  Duration? staleIn = goalAdLifetime,
  int activationCount = 1,
  DateTime? dismissedAt,
  DateTime? retiredAt,
  List<NudgeRating> ratings = const [],
}) {
  final brief = NudgeBrief(
    headline: headline,
    tone: tone,
    animation: NudgeBannerAnimation.steady,
  );
  final createdAt = now.subtract(age);
  return AgentDomainEntity.goalNudge(
        id: id,
        agentId: agentId,
        status: status,
        brief: brief,
        briefDigest: goalBriefDigest(brief),
        createdAt: createdAt,
        updatedAt: createdAt,
        vectorClock: null,
        // Spec-scoped exactly the way the workflow filters: a row whose
        // origin names another version is invisible to the wake.
        provenance: {'specVersionId': '$agentId:spec-v1'},
        activationCount: activationCount,
        activatedAt: status == NudgeStatus.active ? createdAt : null,
        staleAt: staleIn == null ? null : createdAt.add(staleIn),
        dismissedAt: dismissedAt,
        retiredAt: retiredAt,
        ratings: ratings,
      )
      as GoalNudgeEntity;
}

/// Builds a prior period register — the trend a policy row reads.
GoalProgressEntity goalOutcomeEvalRegister({
  required String agentId,
  required String periodKey,
  required GoalTrackStatus trackStatus,
  required double attainment,
  required DateTime now,
}) =>
    AgentDomainEntity.goalProgress(
          id: goalProgressId(agentId, periodKey),
          agentId: agentId,
          periodKey: periodKey,
          trackStatus: trackStatus,
          attainment: attainment,
          dataCoverage: 1,
          satisfied: false,
          specVersionId: '$agentId:spec-v1',
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        )
        as GoalProgressEntity;
