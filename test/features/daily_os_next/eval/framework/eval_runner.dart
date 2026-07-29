import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../ai_consumption/test_utils.dart';
import '../../integration/day_agent_pipeline_harness.dart';
import 'eval_constraints.dart';
import 'eval_journal_fixture.dart';
import 'eval_models.dart';
import 'eval_scenario.dart';
import 'eval_variant.dart';

/// Runs day-planning scenarios through the real ADR 0032 pipeline and scores
/// what comes back.
///
/// The matrix is scenario x model x variant x sample. Everything below the
/// model is real production code — outbox, runtime, executor, orchestrator,
/// workflow, plan writer — assembled by [DayAgentPipelineHarness]; only the
/// inference layer is supplied by the caller, which is what lets the same
/// runner drive a scripted model in ordinary CI and a live provider behind an
/// opt-in flag.
///
/// Each cell gets a fresh harness (fresh temp dir, in-memory agent store and
/// outbox database), so no run can read another's plan, jobs or tool log.

/// One cell of the matrix, handed to [EvalModelTarget.open] so a caller can
/// vary the endpoint per scenario if it needs to.
@immutable
class EvalRunRequest {
  const EvalRunRequest({
    required this.scenario,
    required this.variant,
    required this.modelId,
    required this.sample,
    required this.planDate,
  });

  final EvalScenario scenario;
  final EvalVariant variant;
  final String modelId;

  /// 1-based sample index within this cell.
  final int sample;

  final DateTime planDate;

  /// Stable identifier for this cell, for logs and report keys.
  String get label => '${scenario.id}/$modelId/${variant.id}#$sample';
}

/// The inference layer for one run, plus the configs the workflow resolves
/// against it.
@immutable
class EvalLlmLayer {
  const EvalLlmLayer({
    required this.conversationRepository,
    required this.cloudInferenceRepository,
    required this.profile,
    required this.model,
    required this.provider,
    this.close,
  });

  final ConversationRepository conversationRepository;
  final CloudInferenceRepository cloudInferenceRepository;
  final AiConfigInferenceProfile profile;
  final AiConfigModel model;
  final AiConfigInferenceProvider provider;

  /// Released after the run, whether or not it succeeded.
  final Future<void> Function()? close;
}

/// One model under test and how to reach it.
@immutable
class EvalModelTarget {
  const EvalModelTarget({required this.id, required this.open});

  /// Reported model id — the leaderboard key.
  final String id;

  /// Builds the inference layer for one run. Called once per cell.
  final Future<EvalLlmLayer> Function(EvalRunRequest request) open;
}

/// Everything one cell produced.
@immutable
class EvalRunResult {
  const EvalRunResult({
    required this.request,
    required this.outcome,
    required this.constraints,
    required this.latency,
    required this.wakes,
    required this.jobStatus,
    required this.jobAttempts,
    required this.jobLastFailureClass,
    required this.jobLastError,
    required this.consumption,
    this.error,
  });

  final EvalRunRequest request;
  final EvalRunOutcome outcome;
  final List<EvalConstraintResult> constraints;

  /// Wall-clock time for the drafting round trip.
  final Duration latency;

  /// One entry per conversation the cell opened, in order.
  ///
  /// A cell is normally one wake and therefore one conversation, but the
  /// durable job retries a transient failure up to `maxAttempts` times and
  /// each attempt is a *fresh* wake with its own conversation. Keeping them
  /// separate is what lets [forcedDraftRetry] mean what it says.
  final List<EvalWakeTranscript> wakes;

  /// Terminal status of the draft job, or null when no job was found.
  final String? jobStatus;
  final int? jobAttempts;

  /// Most recent failed attempt, retained even when a later retry succeeded.
  final String? jobLastFailureClass;
  final String? jobLastError;

  /// Consumption events recorded during this run. Empty for scripted models,
  /// which never reach a provider.
  final List<AiConsumptionEvent> consumption;

  /// The exception the run ended with, if any. A failed run still carries an
  /// outcome; its plan-reading constraints are inapplicable, not failed.
  final String? error;

  bool get failed => error != null;

  /// The wake that produced the persisted plan — the last one, since any
  /// earlier attempt failed and was retried. Null when nothing ran.
  EvalWakeTranscript? get draftWake => wakes.isEmpty ? null : wakes.last;

  /// The system prompt of the wake that produced the plan.
  String? get systemPrompt => draftWake?.systemPrompt;

  /// The user messages of the wake that produced the plan, in order.
  List<String> get userPrompts => draftWake?.userMessages ?? const [];

  /// Whether the workflow had to force the artifact out of the model.
  ///
  /// Scoped to a single conversation on purpose. `_forceDraftDayPlanIfMissing`
  /// sends a *second message into the same conversation* when the model
  /// finished its turn without calling `draft_day_plan`. A durable job retry,
  /// by contrast, opens a fresh conversation and sends its normal first
  /// prompt — so counting messages across the whole cell would report a
  /// transient provider failure as the model ignoring the prompt. [jobAttempts]
  /// is where infrastructure retries are visible.
  bool get forcedDraftRetry => wakes.any((wake) => wake.forcedRetry);
}

/// Runs the full matrix, sequentially.
///
/// Sequential on purpose: the runs share the ambient `getIt` registrations and
/// a live provider's rate limit, and overlapping them would make the reported
/// latency meaningless.
///
/// [today] anchors the plan dates and is injectable so tests are deterministic;
/// it defaults to the current day. Same-day scenarios (those with a
/// `startHour`) plan for [today] itself and run under a clock shifted to that
/// hour, so production's same-day guard is live; the rest plan for the
/// following day, where the guard is legitimately inert.
///
/// A cell that throws is recorded and the matrix continues — one model failing
/// on one scenario must not cost the whole run.
Future<List<EvalRunResult>> runEvalMatrix({
  required List<EvalModelTarget> models,
  List<EvalScenario> scenarios = evalScenarios,
  List<EvalVariant> variants = evalVariants,
  int samples = 1,
  DateTime? today,
  AiInteractionCaptureTestBench? attribution,
  void Function(String message)? log,
}) async {
  if (models.isEmpty) {
    throw ArgumentError.value(models, 'models', 'at least one model target');
  }
  if (scenarios.isEmpty) {
    throw ArgumentError.value(scenarios, 'scenarios', 'at least one scenario');
  }
  if (samples < 1) {
    throw RangeError.value(samples, 'samples', 'must be at least 1');
  }
  final controls = variants.where(
    (variant) => variant.id == evalBaselineVariantId,
  );
  if (controls.length != 1 || controls.single.configure != null) {
    // Not just "an entry named baseline": a baseline carrying a transform is
    // not a control, and every A/B in the report would be a delta against
    // something that had itself been changed.
    throw ArgumentError.value(
      variants,
      'variants',
      'must include exactly one "$evalBaselineVariantId" variant with no '
          'transform — a delta measured against a modified control measures '
          'nothing',
    );
  }
  // Ids are the report keys — the model id is the leaderboard row, and
  // `EvalRunRequest.label` is scenario/model/variant. A duplicate anywhere
  // silently collapses two different cells into one row.
  _requireUniqueIds(models.map((model) => model.id), 'models');
  _requireUniqueIds(scenarios.map((scenario) => scenario.id), 'scenarios');
  _requireUniqueIds(variants.map((variant) => variant.id), 'variants');

  final anchorCandidate = today ?? clock.now();
  if (anchorCandidate.isUtc) {
    // Everything downstream is local-day: `localDay`, the working-hours
    // window, and production's same-day guard. Quietly reinterpreting a UTC
    // anchor as local would plan a different day than the caller asked for.
    throw ArgumentError.value(
      today,
      'today',
      'must be a local DateTime — the day agent plans local days',
    );
  }

  final anchor = anchorCandidate;
  final results = <EvalRunResult>[];
  for (final scenario in scenarios) {
    for (final model in models) {
      for (final variant in variants) {
        for (var sample = 1; sample <= samples; sample++) {
          final request = EvalRunRequest(
            scenario: scenario,
            variant: variant,
            modelId: model.id,
            sample: sample,
            planDate: evalPlanDateFor(scenario, anchor),
          );
          log?.call('run ${request.label}');
          EvalRunResult result;
          try {
            result = await runEvalCell(
              request: request,
              model: model,
              attribution: attribution,
              log: log,
            );
          }
          // ignore: avoid_catching_errors — a malformed matrix must stay loud
          on ArgumentError {
            // A malformed scenario or variant is a bug in the matrix, not a
            // result about a model. Swallowing it would file the bug as a
            // finding.
            rethrow;
          } catch (e) {
            log?.call('cell failed ${request.label}: $e');
            result = _failedResult(
              request,
              request.scenario.inputsFor(
                request.planDate,
                config: request.variant.apply(request.scenario.baseConfig),
              ),
              e,
            );
          }
          log?.call(
            'done ${request.label}: '
            '${result.error ?? '${result.outcome.blocks.length} block(s)'} '
            'in ${result.latency.inMilliseconds}ms',
          );
          results.add(result);
        }
      }
    }
  }
  return results;
}

void _requireUniqueIds(Iterable<String> ids, String field) {
  final seen = <String>{};
  final duplicates = {
    for (final id in ids)
      if (!seen.add(id)) id,
  };
  if (duplicates.isNotEmpty) {
    throw ArgumentError.value(
      duplicates.toList()..sort(),
      field,
      'ids must be unique — duplicates collapse distinct cells into one '
      'report row',
    );
  }
}

/// The day a scenario plans for, given [anchor] as today.
DateTime evalPlanDateFor(EvalScenario scenario, DateTime anchor) {
  // Next civil date, not +24h: on a DST boundary a fixed day-long duration
  // lands at 23:00 the same date or 01:00 the next, which would give the cell
  // the wrong day id and shift every block time by an hour.
  return scenario.startHour == null
      ? DateTime(anchor.year, anchor.month, anchor.day + 1)
      : DateTime(anchor.year, anchor.month, anchor.day);
}

/// Runs one cell and scores it.
Future<EvalRunResult> runEvalCell({
  required EvalRunRequest request,
  required EvalModelTarget model,
  AiInteractionCaptureTestBench? attribution,
  void Function(String message)? log,
}) {
  final scenario = request.scenario;
  if (scenario.includeCapture &&
      (scenario.captureTranscript?.trim().isEmpty ?? true)) {
    // Silently drafting without one would turn the scenario into its
    // no-capture twin — the corpus would never be rendered while the scorers
    // still believed it was visible.
    throw ArgumentError.value(
      scenario.id,
      'scenario',
      'includeCapture is set but captureTranscript is empty',
    );
  }

  final startHour = scenario.startHour;
  if (startHour == null) return _runCell(request, model, attribution, log);

  // A same-day scenario is only a same-day scenario if production's clock
  // agrees. The clock keeps running rather than being frozen: the pipeline's
  // job-await soft cap is a `clock.now()` deadline, and a frozen clock would
  // turn a hung run into an infinite wait instead of a diagnostic.
  final elapsed = Stopwatch()..start();
  final anchoredAt = DateTime(
    request.planDate.year,
    request.planDate.month,
    request.planDate.day,
    startHour,
  );
  return withClock(
    Clock(() => anchoredAt.add(elapsed.elapsed)),
    () => _runCell(request, model, attribution, log),
  );
}

Future<EvalRunResult> _runCell(
  EvalRunRequest request,
  EvalModelTarget model,
  AiInteractionCaptureTestBench? attribution,
  void Function(String message)? log,
) async {
  final scenario = request.scenario;
  final planDate = request.planDate;
  final config = request.variant.apply(scenario.baseConfig);
  final inputs = scenario.inputsFor(planDate, config: config);

  attribution?.clearRecordedInteractions();
  final EvalLlmLayer layer;
  try {
    layer = await model.open(request);
  } catch (e) {
    // A model that cannot even be reached (bad id, missing credentials) is
    // one cell's problem, not the matrix's.
    log?.call('open failed ${request.label}: $e');
    return _failedResult(request, inputs, e);
  }
  final recorder = EvalPromptRecorder(layer.conversationRepository);
  // Every acquired resource is released independently below: the harness holds
  // a running runtime with a periodic timer, a sqlite database and a temp
  // directory, so leaking one per failed cell would accumulate across a matrix
  // that is expected to keep going after a failure.
  DayAgentPipelineHarness? harness;
  final stopwatch = Stopwatch();
  String? error;
  try {
    harness = DayAgentPipelineHarness.create(
      now: clock.now(),
      conversationRepository: recorder,
      cloudInferenceRepository: layer.cloudInferenceRepository,
      profile: layer.profile,
      model: layer.model,
      provider: layer.provider,
      // Always non-null, matching production: the resolver gates whether ADR
      // 0043's blocked-work rule reaches the prompt at all, so a null one would
      // quietly measure a prompt production never sends. Scenarios without
      // blockers supply an empty map.
      dependencyResolver: EvalFixtureDependencyResolver(scenario.blockedStatus),
      config: config,
    );
    seedScenarioCorpus(
      journalDb: harness.journalDb,
      scenario: scenario,
      planDate: planDate,
      journalRepository: harness.journalRepository,
    );

    // Seeded before the timer starts: agent lookup/creation and fixture
    // persistence are the harness's cost, not the model's, and including them
    // only for capture-bearing scenarios would make latency mean a different
    // thing per scenario type.
    final captureId = scenario.includeCapture
        ? await _seedCapture(harness, scenario, planDate)
        : const CaptureId('');
    if (scenario.directive != null) {
      await _seedDirective(harness, scenario.directive!, planDate);
    }

    stopwatch.start();
    try {
      await harness.realDayAgent.draftDayPlan(
        captureId: captureId,
        decidedTaskIds: scenario.decidedTaskIds,
        dayDate: planDate,
      );
    } catch (e) {
      // Recorded, not rethrown: a matrix that aborts on the first bad cell
      // cannot report on the models that did work.
      error = e.toString();
      log?.call('error ${request.label}: $error');
    }
    stopwatch.stop();

    final dayId = dayAgentIdForDate(planDate);
    final identity = await harness.dayAgentService.getDayAgentForDate(planDate);
    final plan = identity is AgentIdentityEntity
        ? await harness.planService.draftPlanForDay(
            agentId: identity.agentId,
            dayId: dayId,
          )
        : null;
    final job = await harness.outbox.getById(
      DayProcessingOutboxRepository.draftJobId(dayId),
    );
    final outcome = EvalRunOutcome(
      inputs: inputs,
      blocks: plan?.data.plannedBlocks ?? const [],
      toolCalls: evalToolCallsFrom(harness.agentRepository.entities),
      planPersisted: plan != null,
      createdTaskIds: {
        // Both sources: the persistence stub records every created task, and
        // the parsed-item scan additionally covers ids the model resolved
        // through triage against work outside the seeded corpus.
        ...currentEvalJournal.createdIds,
        ...evalCreatedTaskIdsFrom(harness.agentRepository.entities),
      },
    );
    return EvalRunResult(
      request: request,
      outcome: outcome,
      constraints: scoreAll(outcome),
      latency: stopwatch.elapsed,
      wakes: recorder.wakes,
      jobStatus: job?.status.name,
      jobAttempts: job?.attempts,
      jobLastFailureClass: job?.lastFailureClass?.name,
      jobLastError: job?.lastError,
      consumption: List.unmodifiable(
        attribution?.recordedInteractions ?? const <AiConsumptionEvent>[],
      ),
      error: error,
    );
  } finally {
    await _release('harness', () => harness?.dispose(), log);
    await _release('model layer', () => layer.close?.call(), log);
  }
}

/// Releases one resource, reporting rather than propagating its failure.
///
/// A throwing `dispose` must not prevent the next release from running, and
/// must not replace a cell's real result with a teardown error.
Future<void> _release(
  String what,
  Future<void>? Function() release,
  void Function(String message)? log,
) async {
  try {
    await release();
  } catch (e) {
    log?.call('failed to release $what: $e');
  }
}

/// A cell that produced nothing, still occupying its slot in the report.
///
/// Every constraint is scored so the row keeps the same shape as a successful
/// one; the plan-reading ones come back inapplicable rather than passed.
EvalRunResult _failedResult(
  EvalRunRequest request,
  EvalFixtureInputs inputs,
  Object error,
) {
  final outcome = EvalRunOutcome(inputs: inputs, planPersisted: false);
  return EvalRunResult(
    request: request,
    outcome: outcome,
    constraints: scoreAll(outcome),
    latency: Duration.zero,
    wakes: const [],
    jobStatus: null,
    jobAttempts: null,
    jobLastFailureClass: null,
    jobLastError: null,
    consumption: const [],
    error: error.toString(),
  );
}

/// Writes the scenario's capture directly, without enqueueing its parse job.
///
/// Production's `submitCapture` also enqueues a `parseCapture` job, which the
/// runtime drains as a **second wake** with its own conversation, prompt and
/// tool calls. That is right for the app and wrong for this measurement: the
/// unit here is one drafting wake, and letting the parse wake run would mix
/// two prompts and two tool-call logs into one record, double the live cost of
/// every cell, and add an uncontrolled second model call to a run whose whole
/// point is to isolate planning behaviour.
///
/// What the drafting wake needs from a capture is the capture *entity* — that
/// is what makes `captureContext` non-null and therefore what renders both the
/// transcript and the task corpus into the prompt. Seeding it directly gives
/// the wake exactly that. Parse quality is a separate question and would need
/// its own scenario type.
Future<CaptureId> _seedCapture(
  DayAgentPipelineHarness harness,
  EvalScenario scenario,
  DateTime planDate,
) async {
  final identity = await harness.dayAgentService.getOrCreateDayAgentForDate(
    planDate,
  );
  final now = clock.now();
  final capture =
      AgentDomainEntity.capture(
            id: 'capture_${scenario.id}',
            agentId: identity.agentId,
            transcript: scenario.captureTranscript!,
            capturedAt: now,
            createdAt: now,
            vectorClock: null,
            dayId: dayAgentIdForDate(planDate),
          )
          as CaptureEntity;
  await harness.syncService.upsertEntity(capture);
  return CaptureId(capture.id);
}

/// Writes the scenario's `<day_directive>` directly, without running a digest
/// wake to issue it.
///
/// Production issues a directive from the coordinator's digest, which is a
/// second model call with its own prompt and tool budget — the same reason the
/// capture is seeded rather than submitted. What the drafting wake needs is
/// the persisted [DayDirectiveEntity]: `directiveForDay` reads it by
/// deterministic id and the prompt builder renders the real section from it.
Future<void> _seedDirective(
  DayAgentPipelineHarness harness,
  EvalDirective directive,
  DateTime planDate,
) async {
  final dayId = dayAgentIdForDate(planDate);
  final now = clock.now();
  await harness.syncService.upsertEntity(
    AgentDomainEntity.dayDirective(
      id: dayDirectiveEntityId(dayId),
      agentId: dailyOsPlannerAgentId,
      dayId: dayId,
      planDate: planDate,
      directiveRevisionId: 'eval-directive-1',
      issuedAt: now,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
      commitments: [
        for (final commitment in directive.commitments)
          DayDirectiveCommitment(
            id: commitment.id,
            source: DayCommitmentSource.userCommitment,
            title: commitment.title,
            minutes: commitment.minutes,
          ),
      ],
      capacityBudget: DayCapacityBudget(
        availableMinutes: directive.availableMinutes,
        alreadyScheduledMinutes: directive.alreadyScheduledMinutes,
      ),
      attentionNotes: directive.attentionNotes,
    ),
  );
}

/// Task ids that came into existence during the wake.
///
/// `create_task_from_phrase` materialises a task and writes its id onto the
/// parsed item as `matchedTaskId` (plus a `parsed_item_to_task` link), so the
/// ids are recoverable from persisted state rather than needing the tool
/// result — which the agent log does not keep. `apply_triage` matching an
/// existing task lands here too, and belongs just as much: an id the model
/// resolved through a tool is one it could legitimately go on to schedule.
Set<String> evalCreatedTaskIdsFrom(List<AgentDomainEntity> entities) => {
  for (final item in entities.whereType<ParsedItemEntity>())
    ?item.matchedTaskId,
};

/// Reconstructs the ordered tool-call log from the agent messages one wake
/// wrote.
///
/// This is the whole reason the runner exists rather than a loop: the write
/// path rejects an illegal `draft_day_plan` and hands the failure text back to
/// the model, which retries — so the persisted plan is always legal and a plan
/// that only became legal on the third attempt is indistinguishable from a
/// first-time-right one. `DayAgentStrategy` records an `action` message (with
/// the arguments as its payload) before each call and a `toolResult` message
/// after it, carrying the rejection text in `metadata.errorMessage`, so the
/// rejections are recoverable even though nothing else keeps them.
///
/// [entities] must be in write order, which the harness's in-memory store
/// preserves (a Dart map iterates in insertion order, and every message id is
/// a fresh UUID so no write ever re-enters an existing slot).
List<EvalToolCall> evalToolCallsFrom(List<AgentDomainEntity> entities) {
  final payloads = {
    for (final entity in entities.whereType<AgentMessagePayloadEntity>())
      entity.id: entity.content,
  };
  final calls = <EvalToolCall>[];
  AgentMessageEntity? pendingAction;

  void flushPendingAction() {
    final action = pendingAction;
    if (action == null) return;
    // An action with no result means the loop died mid-call. Reporting it as
    // accepted would credit a call that never landed.
    calls.add(
      EvalToolCall(
        name: action.metadata.toolName ?? '',
        accepted: false,
        rejectionMessage: 'no tool result was recorded',
        arguments: payloads[action.contentEntryId] ?? const {},
      ),
    );
    pendingAction = null;
  }

  for (final message in entities.whereType<AgentMessageEntity>()) {
    switch (message.kind) {
      case AgentMessageKind.action:
        // Two actions in a row can only mean the first lost its result.
        flushPendingAction();
        pendingAction = message;
      case AgentMessageKind.toolResult:
        final toolName = message.metadata.toolName ?? '';
        final action = pendingAction;
        // Arguments are only this call's if the pending action is for the same
        // tool. A tool call whose arguments failed to parse records a result
        // with no action at all, so pairing blindly would attach the previous
        // call's arguments to it.
        final arguments = action != null && action.metadata.toolName == toolName
            ? payloads[action.contentEntryId] ?? const {}
            : const <String, dynamic>{};
        if (action != null && action.metadata.toolName != toolName) {
          flushPendingAction();
        }
        pendingAction = null;
        calls.add(
          EvalToolCall(
            name: toolName,
            accepted: message.metadata.errorMessage == null,
            rejectionMessage: message.metadata.errorMessage,
            arguments: arguments,
          ),
        );
      case AgentMessageKind.user:
      case AgentMessageKind.thought:
      case AgentMessageKind.observation:
      case AgentMessageKind.summary:
      case AgentMessageKind.system:
        break;
    }
  }
  flushPendingAction();
  return calls;
}

/// Classifies a day-planning provider message for live usage reporting.
String dayPlanningMessageRole(String message) {
  if (message.contains('<digest>')) return 'plannerDigest';
  if (message.contains('<drafting>')) return 'dayDraft';
  if (message.contains('<capture>')) return 'captureParse';
  return 'other';
}

/// Preserves a wake's known role when an untagged continuation is sent.
String preserveDayPlanningWakeRole(String? currentRole, String message) {
  final nextRole = dayPlanningMessageRole(message);
  if (nextRole == 'other' && currentRole != null) return currentRole;
  return nextRole;
}

/// One conversation the model was driven through, as it was sent.
@immutable
class EvalWakeTranscript {
  const EvalWakeTranscript({
    required this.conversationId,
    required this.systemPrompt,
    required this.userMessages,
    this.wakeRunKeys = const [],
  });

  final String conversationId;

  /// The system prompt, which is never persisted anywhere else.
  final String? systemPrompt;

  /// User messages sent into this conversation, in order.
  final List<String> userMessages;

  /// Consumption owner for each user message, aligned with [userMessages].
  final List<String?> wakeRunKeys;

  /// More than one message in a single conversation means the workflow sent a
  /// follow-up to force the required tool call.
  bool get forcedRetry => userMessages.length > 1;
}

class _MutableWake {
  String? systemPrompt;
  final List<String> userMessages = [];
  final List<String?> wakeRunKeys = [];
}

/// Wraps a [ConversationRepository] to capture the prompts the model was sent.
///
/// The system prompt is never persisted — the workflow builds it and hands it
/// straight to `createConversation` — so reading the agent log back recovers
/// the user message and nothing else. Wrapping also makes the forced-retry
/// path visible, since it shows up as a second `sendMessage`.
class EvalPromptRecorder extends ConversationRepository {
  EvalPromptRecorder(this._inner);

  final ConversationRepository _inner;
  final Map<String, _MutableWake> _byConversation = {};
  final List<String> _order = [];

  /// One transcript per conversation, in the order they were opened.
  List<EvalWakeTranscript> get wakes => List.unmodifiable([
    for (final id in _order)
      EvalWakeTranscript(
        conversationId: id,
        systemPrompt: _byConversation[id]!.systemPrompt,
        userMessages: List.unmodifiable(_byConversation[id]!.userMessages),
        wakeRunKeys: List.unmodifiable(_byConversation[id]!.wakeRunKeys),
      ),
  ]);

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    final id = _inner.createConversation(
      systemMessage: systemMessage,
      maxTurns: maxTurns,
    );
    // Keyed by the id the inner repository chose, so a conversation reusing an
    // id after deletion appends to one transcript rather than silently
    // starting a second.
    _byConversation.putIfAbsent(id, () {
      _order.add(id);
      return _MutableWake();
    }).systemPrompt = systemMessage;
    return id;
  }

  @override
  ConversationManager? getConversation(String conversationId) =>
      _inner.getConversation(conversationId);

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
    bool rethrowInferenceErrors = false,
  }) {
    _byConversation[conversationId]
      ?..userMessages.add(message)
      ..wakeRunKeys.add(consumptionWakeRunKey);
    return _inner.sendMessage(
      conversationId: conversationId,
      message: message,
      model: model,
      provider: provider,
      inferenceRepo: inferenceRepo,
      tools: tools,
      toolChoice: toolChoice,
      temperature: temperature,
      strategy: strategy,
      consumptionAgentId: consumptionAgentId,
      consumptionTaskId: consumptionTaskId,
      consumptionCategoryId: consumptionCategoryId,
      consumptionWakeRunKey: consumptionWakeRunKey,
      consumptionThreadId: consumptionThreadId,
      rethrowInferenceErrors: rethrowInferenceErrors,
    );
  }

  @override
  void deleteConversation(String conversationId) =>
      _inner.deleteConversation(conversationId);
}

/// Convenience for a caller that wants the config a cell will use without
/// running it (the live entry point logs it).
DayAgentConfig evalConfigFor(EvalScenario scenario, EvalVariant variant) =>
    variant.apply(scenario.baseConfig);
