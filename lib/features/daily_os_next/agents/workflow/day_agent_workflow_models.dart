import 'dart:async';

import 'package:lotti/features/agents/memory/memory_links.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Model-facing mode of one day-agent wake.
enum DayAgentWakeKind { capture, draft, refine, digest, general }

/// Maximum provider-stream lifetime for each wake kind.
///
/// This deadline includes streamed reasoning. A model that keeps emitting
/// thought chunks without producing the terminal artifact cannot extend the
/// user's wait to the wake orchestrator's two-minute hard abort.
class DayAgentInferenceTimeoutPolicy {
  const DayAgentInferenceTimeoutPolicy({
    this.capture = const Duration(seconds: 20),
    this.draft = const Duration(seconds: 30),
    this.refine = const Duration(seconds: 30),
    this.digest = const Duration(seconds: 60),
    this.general = const Duration(seconds: 60),
  });

  final Duration capture;
  final Duration draft;
  final Duration refine;
  final Duration digest;
  final Duration general;

  Duration forKind(DayAgentWakeKind kind) => switch (kind) {
    DayAgentWakeKind.capture => capture,
    DayAgentWakeKind.draft => draft,
    DayAgentWakeKind.refine => refine,
    DayAgentWakeKind.digest => digest,
    DayAgentWakeKind.general => general,
  };
}

/// Per-provider-turn output ceilings selected from measured Daily OS wakes.
///
/// Drafts receive more headroom because they serialize a complete block list.
/// Capture, refine, and digest turns produce smaller bounded artifacts. The
/// policy is injected into the day-agent workflow, so tests and future provider
/// profiles can tune it without bypassing the truncation safety boundary.
class DayAgentOutputTokenBudgetPolicy {
  const DayAgentOutputTokenBudgetPolicy({
    this.capture = 4096,
    this.draft = 8192,
    this.refine = 4096,
    this.digest = 4096,
    this.general = 4096,
  });

  final int capture;
  final int draft;
  final int refine;
  final int digest;
  final int general;

  int forKind(DayAgentWakeKind kind) => switch (kind) {
    DayAgentWakeKind.capture => capture,
    DayAgentWakeKind.draft => draft,
    DayAgentWakeKind.refine => refine,
    DayAgentWakeKind.digest => digest,
    DayAgentWakeKind.general => general,
  };
}

/// A provider exhausted the output ceiling before completing its response.
class DayAgentOutputLimitExceededException implements Exception {
  const DayAgentOutputLimitExceededException({
    required this.wakeKind,
    required this.maxCompletionTokens,
  });

  final DayAgentWakeKind wakeKind;
  final int maxCompletionTokens;

  @override
  String toString() =>
      'DayAgentOutputLimitExceededException: ${wakeKind.name} inference '
      'reached its $maxCompletionTokens-token output ceiling';
}

/// Applies a hard output ceiling and classifies truncated provider responses.
///
/// The ceiling is forwarded to the provider for every turn. A provider may
/// signal exhaustion explicitly with `finish_reason: length`; Gemini-style
/// adapters can omit that signal, so reported completion usage at the ceiling
/// is treated equivalently. The error is emitted only after the provider stream
/// ends, before the conversation repository can execute a collected tool call.
class DayAgentOutputBudgetInferenceRepository
    implements InferenceRepositoryInterface {
  DayAgentOutputBudgetInferenceRepository({
    required this.delegate,
    required this.wakeKind,
    required this.maxCompletionTokens,
  }) {
    if (maxCompletionTokens <= 0) {
      throw ArgumentError.value(
        maxCompletionTokens,
        'maxCompletionTokens',
        'must be positive',
      );
    }
  }

  final InferenceRepositoryInterface delegate;
  final DayAgentWakeKind wakeKind;
  final int maxCompletionTokens;

  int _effectiveLimit(int? requested) =>
      requested == null || requested > maxCompletionTokens
      ? maxCompletionTokens
      : requested;

  Stream<CreateChatCompletionStreamResponse> _bound(
    Stream<CreateChatCompletionStreamResponse> source,
    int effectiveLimit,
  ) async* {
    var reachedLimit = false;
    await for (final response in source) {
      final choices = response.choices;
      if (choices != null &&
          choices.any(
            (choice) =>
                choice.finishReason == ChatCompletionFinishReason.length,
          )) {
        reachedLimit = true;
      }
      final outputTokens = response.usage?.completionTokens;
      if (outputTokens != null && outputTokens >= effectiveLimit) {
        reachedLimit = true;
      }
      yield response;
    }
    if (reachedLimit) {
      throw DayAgentOutputLimitExceededException(
        wakeKind: wakeKind,
        maxCompletionTokens: effectiveLimit,
      );
    }
  }

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
    int? turnIndex,
    InferenceImpactCollector? impactCollector,
  }) {
    final effectiveLimit = _effectiveLimit(maxCompletionTokens);
    return _bound(
      delegate.generateTextWithMessages(
        messages: messages,
        model: model,
        temperature: temperature,
        provider: provider,
        maxCompletionTokens: effectiveLimit,
        tools: tools,
        toolChoice: toolChoice,
        thoughtSignatures: thoughtSignatures,
        signatureCollector: signatureCollector,
        turnIndex: turnIndex,
        impactCollector: impactCollector,
      ),
      effectiveLimit,
    );
  }

  @override
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) {
    final effectiveLimit = _effectiveLimit(maxCompletionTokens);
    return _bound(
      delegate.generateText(
        prompt: prompt,
        model: model,
        temperature: temperature,
        systemMessage: systemMessage,
        provider: provider,
        maxCompletionTokens: effectiveLimit,
        tools: tools,
        toolChoice: toolChoice,
      ),
      effectiveLimit,
    );
  }
}

/// Classified provider deadline failure for one day-agent wake.
class DayAgentInferenceTimedOutException extends TimeoutException {
  DayAgentInferenceTimedOutException({
    required this.wakeKind,
    required Duration timeout,
  }) : super(
         '${wakeKind.name} inference exceeded its '
         '${timeout.inSeconds}s deadline',
         timeout,
       );

  final DayAgentWakeKind wakeKind;
}

/// Applies a mode-specific total deadline to day-agent inference streams.
///
/// The timer starts when the wake wrapper is created and does not reset for a
/// later provider turn or streamed thought/content chunk. Crossing it cancels
/// every active upstream subscription before reporting the classified timeout,
/// so a late tool batch cannot mutate after the outbox starts a retry.
class DayAgentTimeoutInferenceRepository
    implements InferenceRepositoryInterface {
  DayAgentTimeoutInferenceRepository({
    required this.delegate,
    required this.wakeKind,
    required this.timeout,
  }) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'must be positive',
      );
    }
    _wakeDeadline = Timer(timeout, _expire);
  }

  final InferenceRepositoryInterface delegate;
  final DayAgentWakeKind wakeKind;
  final Duration timeout;
  late final Timer _wakeDeadline;
  final _active =
      <
        StreamController<CreateChatCompletionStreamResponse>,
        Future<void> Function()
      >{};
  var _expired = false;
  var _disposed = false;

  DayAgentInferenceTimedOutException _timeoutError() =>
      DayAgentInferenceTimedOutException(
        wakeKind: wakeKind,
        timeout: timeout,
      );

  Future<void> _cancelSafely(Future<void> Function() cancel) async {
    try {
      await cancel();
    } catch (_) {
      // The timeout is already the classified failure for this wake. Some
      // async provider streams surface their in-flight HTTP error from
      // StreamSubscription.cancel(); letting that detached cleanup future
      // escape would fail the process after the durable retry succeeds.
    }
  }

  void _expire() {
    if (_disposed) return;
    _wakeDeadline.cancel();
    _expired = true;
    for (final entry in _active.entries.toList()) {
      _active.remove(entry.key);
      unawaited(_cancelSafely(entry.value));
      entry.key.addError(_timeoutError());
      unawaited(entry.key.close());
    }
  }

  Stream<CreateChatCompletionStreamResponse> _bound(
    Stream<CreateChatCompletionStreamResponse> source,
  ) {
    late final StreamController<CreateChatCompletionStreamResponse> controller;
    StreamSubscription<CreateChatCompletionStreamResponse>? subscription;

    controller = StreamController<CreateChatCompletionStreamResponse>(
      sync: true,
      onListen: () {
        if (_disposed) {
          unawaited(controller.close());
          return;
        }
        if (_expired) {
          controller.addError(_timeoutError());
          unawaited(controller.close());
          return;
        }
        _active[controller] = () async {
          await subscription?.cancel();
        };
        subscription = source.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            if (_active.remove(controller) != null) {
              unawaited(controller.close());
            }
          },
        );
      },
      onCancel: () async {
        final cancel = _active.remove(controller);
        if (cancel != null) {
          await _cancelSafely(cancel);
        }
      },
    );
    return controller.stream;
  }

  /// Cancels the wake deadline and any provider stream still in flight.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _wakeDeadline.cancel();
    final active = _active.entries.toList(growable: false);
    _active.clear();
    for (final entry in active) {
      await _cancelSafely(entry.value);
      await entry.key.close();
    }
  }

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
    int? turnIndex,
    InferenceImpactCollector? impactCollector,
  }) => _bound(
    delegate.generateTextWithMessages(
      messages: messages,
      model: model,
      temperature: temperature,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
      toolChoice: toolChoice,
      thoughtSignatures: thoughtSignatures,
      signatureCollector: signatureCollector,
      turnIndex: turnIndex,
      impactCollector: impactCollector,
    ),
  );

  @override
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) => _bound(
    delegate.generateText(
      prompt: prompt,
      model: model,
      temperature: temperature,
      systemMessage: systemMessage,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
      toolChoice: toolChoice,
    ),
  );
}

/// Raised when a day-agent tool call fails (bad arguments, unknown tool, or a
/// failed side effect). Carries a human-readable [message] surfaced back to the
/// model as the tool result so it can recover.
class DayAgentToolException implements Exception {
  const DayAgentToolException(this.message);

  final String message;
}

/// Raised when a drafting wake completes without ever persisting a
/// `draft_day_plan` tool call, even after the forced single retry. Signals a
/// degenerate model run rather than a recoverable per-tool error.
class MissingDraftDayPlanException implements Exception {
  const MissingDraftDayPlanException();

  @override
  String toString() {
    return 'Drafting wake did not persist draft_day_plan after forced retry.';
  }
}

/// Raised when a capture wake completes without ever persisting a
/// `parse_capture_to_items` tool call, even after the forced single retry.
class MissingCaptureParseException implements Exception {
  const MissingCaptureParseException();

  @override
  String toString() {
    return 'Capture wake did not persist parse_capture_to_items after forced '
        'retry.';
  }
}

/// The resolved agent template for a wake: its definition, the pinned version
/// whose prompt/tooling will run, and the optional Soul personality document
/// version layered on top.
class TemplateContext {
  const TemplateContext({
    required this.template,
    required this.version,
    required this.soulVersion,
  });

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;
  final SoulDocumentVersionEntity? soulVersion;
}

/// Inputs for a capture wake: the raw [CaptureEntity] (transcript + audio ref)
/// and the task corpus the model can match against. [toJson] renders the
/// JSON block injected into the prompt.
class CaptureContext {
  const CaptureContext({
    required this.capture,
    required this.taskCorpus,
  });

  final CaptureEntity capture;
  final List<Map<String, Object?>> taskCorpus;

  Map<String, Object?> toJson() => {
    'captureId': capture.id,
    'transcript': capture.transcript,
    'capturedAt': capture.capturedAt.toIso8601String(),
    'audioRef': capture.audioRef,
    'taskCorpus': taskCorpus,
  };
}

/// Inputs for a drafting wake: any existing [baselinePlan] to revise plus the
/// tasks and parsed capture items the user already decided to include
/// (`decidedTasks` / `decidedCaptureItems`). [toJson] serializes the whole
/// baseline plan (blocks + energy bands) and decisions into the prompt block.
class DraftingContext {
  const DraftingContext({
    this.baselinePlan,
    this.decidedTasks = const [],
    this.decidedCaptureItems = const [],
    this.baselineTaskStates = const {},
  });

  final DayPlanEntity? baselinePlan;
  final List<DecidedTaskRef> decidedTasks;
  final List<ParsedItemEntity> decidedCaptureItems;

  /// Blocked-work state (ADR 0043) for tasks the baseline plan schedules,
  /// keyed by task id, present only for tasks that are actually blocked.
  /// Annotates the blocks below rather than `decidedTasks`, which the prompt
  /// defines as tasks the *user* approved for placement.
  final Map<String, PlannedTaskState> baselineTaskStates;

  Map<String, Object?> toJson() {
    final plan = baselinePlan;
    return <String, Object?>{
      'requested': true,
      'baselinePlan': plan == null
          ? null
          : <String, Object?>{
              'planId': plan.id,
              'dayId': plan.dayId,
              'planDate': plan.planDate.toIso8601String(),
              'capacityMinutes': plan.capacityMinutes,
              'scheduledMinutes': plan.scheduledMinutes,
              'blocks': [
                for (final block in plan.data.plannedBlocks)
                  <String, Object?>{
                    'id': block.id,
                    'title': block.title,
                    'taskId': block.taskId,
                    'categoryId': block.categoryId,
                    'start': block.startTime.toIso8601String(),
                    'end': block.endTime.toIso8601String(),
                    'type': block.type.name,
                    'state': block.state.name,
                    'reason': block.reason,
                    'note': block.note,
                    // Only when the task became blocked since this block was
                    // drafted — by status or by link, since ADR 0043's rule is
                    // a union. Absent otherwise, so an unblocked plan
                    // serializes exactly as before.
                    if (baselineTaskStates[block.taskId] case final state?)
                      ...state.toJson(),
                  },
              ],
              'energyBands': [
                for (final band in plan.energyBands) band.toJson(),
              ],
            },
      'decidedTasks': [for (final task in decidedTasks) task.toJson()],
      'decidedCaptureItems': [
        for (final item in decidedCaptureItems)
          <String, Object?>{
            'id': item.id,
            'kind': item.kind.name,
            'title': item.title,
            'categoryId': item.categoryId,
            'confidence': item.confidence.name,
            'confidenceScore': item.confidenceScore,
            'lowConfidence': item.lowConfidence,
            'spokenPhrase': item.spokenPhrase,
            'matchedTaskId': item.matchedTaskId,
            'estimateMinutes': item.estimateMinutes,
            'timeAnchor': item.timeAnchor,
            'proposedUpdate': item.proposedUpdate,
          },
      ],
    };
  }
}

/// Inputs for a refine wake: the existing [baselinePlan] the spoken request
/// reshapes. [toJson] serializes that plan (blocks + energy bands) as the
/// reference the model proposes a diff against.
class RefineContext {
  const RefineContext({this.baselinePlan});

  final DayPlanEntity? baselinePlan;

  Map<String, Object?> toJson() {
    final plan = baselinePlan;
    return <String, Object?>{
      'requested': true,
      'baselinePlan': plan == null
          ? null
          : <String, Object?>{
              'planId': plan.id,
              'dayId': plan.dayId,
              'planDate': plan.planDate.toIso8601String(),
              'capacityMinutes': plan.capacityMinutes,
              'scheduledMinutes': plan.scheduledMinutes,
              'blocks': [
                for (final block in plan.data.plannedBlocks)
                  <String, Object?>{
                    'id': block.id,
                    'title': block.title,
                    'taskId': block.taskId,
                    'categoryId': block.categoryId,
                    'start': block.startTime.toIso8601String(),
                    'end': block.endTime.toIso8601String(),
                    'type': block.type.name,
                    'state': block.state.name,
                    'reason': block.reason,
                    'note': block.note,
                  },
              ],
              'energyBands': [
                for (final band in plan.energyBands) band.toJson(),
              ],
            },
    };
  }
}

/// Rendered durable-knowledge prompt blocks (ADR 0022): the always-on hook
/// index and the scope-filtered full statements for the current wake.
class KnowledgeContext {
  const KnowledgeContext({required this.hookIndex, required this.statements});

  const KnowledgeContext.empty() : hookIndex = '', statements = '';

  final String hookIndex;
  final String statements;
}

// ── Pure helpers (de-statified from DayAgentWorkflow) ──────────────────────

const workflowUuid = Uuid();

const _maxRecentObservationCount = 20;

/// Renders a resolved memory link as a `wire:id` prompt token, annotating
/// dangling (`(not found)`) and superseded (`→ liveId`) links so the model
/// sees the link's current health.
String formatLink(ResolvedMemoryLink link) {
  final wire = link.link.relation.wire;
  final id = link.link.entryId;
  if (!link.exists) return '$wire:$id (not found)';
  if (link.superseded) return '$wire:$id → ${link.liveEntryId}';
  return '$wire:$id';
}

/// Appends the Soul document's personality sections (voice directive, and any
/// non-empty tone bounds, coaching style, and anti-sycophancy policy) to the
/// prompt [buf] as Markdown headings.
void appendSoulPersonality(
  StringBuffer buf,
  SoulDocumentVersionEntity soul,
) {
  buf
    ..writeln()
    ..writeln()
    ..writeln('## Personality')
    ..writeln()
    ..write(soul.voiceDirective);
  if (soul.toneBounds.trim().isNotEmpty) {
    buf
      ..writeln()
      ..writeln()
      ..writeln('## Tone Bounds')
      ..writeln()
      ..write(soul.toneBounds.trim());
  }
  if (soul.coachingStyle.trim().isNotEmpty) {
    buf
      ..writeln()
      ..writeln()
      ..writeln('## Coaching Style')
      ..writeln()
      ..write(soul.coachingStyle.trim());
  }
  if (soul.antiSycophancyPolicy.trim().isNotEmpty) {
    buf
      ..writeln()
      ..writeln()
      ..writeln('## Anti-Sycophancy Policy')
      ..writeln()
      ..write(soul.antiSycophancyPolicy.trim());
  }
}

/// The most recent observations to replay into a wake, sorted oldest-first by
/// `createdAt` (id-tiebroken for stability) and capped to the last 20 so the
/// prompt stays bounded.
List<AgentMessageEntity> recentObservations(
  List<AgentMessageEntity> observations,
) {
  final sorted = observations.toList()
    ..sort((a, b) {
      final byCreatedAt = a.createdAt.compareTo(b.createdAt);
      if (byCreatedAt != 0) return byCreatedAt;
      return a.id.compareTo(b.id);
    });
  if (sorted.length <= _maxRecentObservationCount) {
    return sorted;
  }
  return sorted.sublist(sorted.length - _maxRecentObservationCount);
}

/// The agent's scheduled wake time if it is still in the future relative to
/// [now]; `null` when there is none or it has already elapsed (so a past
/// self-scheduled wake isn't re-surfaced as pending).
DateTime? remainingScheduledWakeAt(
  AgentStateEntity state,
  DateTime now,
) {
  final scheduledWakeAt = state.scheduledWakeAt;
  if (scheduledWakeAt == null || scheduledWakeAt.isAfter(now)) {
    return scheduledWakeAt;
  }
  return null;
}

/// Parses the calendar date out of a `dayplan-<iso-date>` day id, or `null`
/// when [dayId] is not in that form.
DateTime? dateFromDayId(String dayId) {
  const prefix = 'dayplan-';
  if (!dayId.startsWith(prefix)) return null;
  return DateTime.tryParse(dayId.substring(prefix.length));
}

/// Extracts the `text` field from a message payload, falling back to
/// `(no content)` when the payload is absent or carries no text.
String extractPayloadText(AgentMessagePayloadEntity? payload) {
  if (payload == null) return '(no content)';
  final text = payload.content['text'];
  if (text is String && text.isNotEmpty) return text;
  return '(no content)';
}

/// Updates the per-day self-scheduled-wake counter map: sets [wakeCountKey] to
/// [nextCount] and garbage-collects only stale prior-date wake counters. Every
/// counter sharing today's date suffix is preserved so interleaved multi-day
/// planning never resets another day's wake cap.
Map<String, int> nextToolCounterByKey(
  Map<String, int> current,
  String wakeCountKey,
  int nextCount,
) {
  const prefix = 'day_agent_set_next_wake:';
  // Keys are `day_agent_set_next_wake:<dayId>:<date>`. Garbage-collect only
  // stale prior-date counters, keeping every day's counter for the current
  // date so interleaved multi-day planning does not reset another day's cap.
  final todaySuffix = wakeCountKey.substring(wakeCountKey.lastIndexOf(':'));
  return {
    for (final entry in current.entries)
      if (!entry.key.startsWith(prefix) || entry.key.endsWith(todaySuffix))
        entry.key: entry.value,
    wakeCountKey: nextCount,
  };
}

/// Builds the counter key `day_agent_set_next_wake:<dayId>:<today>` that scopes
/// the self-scheduled-wake cap to one planned day on one calendar date.
String scheduledWakeCountKey(DateTime now, String dayId) {
  return 'day_agent_set_next_wake:$dayId:'
      '${now.toIso8601String().substring(0, 10)}';
}

/// The next coordinator digest instant strictly after [now]: today at
/// [AgentSchedules.dayAgentDigestHour] local when that is still ahead,
/// otherwise the same hour tomorrow (ADR 0032 phase 3).
DateTime nextDigestTime(DateTime now) {
  final todayAt = DateTime(
    now.year,
    now.month,
    now.day,
    AgentSchedules.dayAgentDigestHour,
  );
  return todayAt.isAfter(now)
      ? todayAt
      : DateTime(
          now.year,
          now.month,
          now.day + 1,
          AgentSchedules.dayAgentDigestHour,
        );
}

/// Severity-ranked selection of status events for one digest (ADR 0032):
/// attention-weighted aggregation instead of arrival-order truncation.
///
/// When more events exist than the digest renders, relevance decides what
/// survives — `attentionNeeded` outranks `dayClosed` outranks `onTrack`, a
/// broken directive outranks capacity pressure outranks divergence or
/// blockage, and newer beats older within a tier (id as the final total-order
/// tiebreak). The survivors are returned in chronological order so the
/// rendered narrative still reads oldest-first; the returned `truncated`
/// flag is true only when something was actually dropped.
({List<DayStatusEventEntity> selected, bool truncated})
selectDigestStatusEvents(
  List<DayStatusEventEntity> candidates, {
  required int limit,
}) {
  List<DayStatusEventEntity> chronological(List<DayStatusEventEntity> list) =>
      [...list]..sort((a, b) => a.raisedAt.compareTo(b.raisedAt));
  if (candidates.length <= limit) {
    return (selected: chronological(candidates), truncated: false);
  }

  int statusWeight(DayStatusEventEntity event) => switch (event.status) {
    DayStatusKind.attentionNeeded => 2,
    DayStatusKind.dayClosed => 1,
    DayStatusKind.onTrack => 0,
  };
  int reasonWeight(DayStatusEventEntity event) {
    var weight = 0;
    for (final reason in event.reasons) {
      final w = switch (reason) {
        DayStatusReason.directiveUnsatisfiable => 4,
        DayStatusReason.overCommitted => 3,
        DayStatusReason.processingBlocked => 2,
        DayStatusReason.userDivergence => 1,
      };
      if (w > weight) weight = w;
    }
    return weight;
  }

  final ranked = [...candidates]
    ..sort((a, b) {
      final byStatus = statusWeight(b).compareTo(statusWeight(a));
      if (byStatus != 0) return byStatus;
      final byReason = reasonWeight(b).compareTo(reasonWeight(a));
      if (byReason != 0) return byReason;
      final byRecency = b.raisedAt.compareTo(a.raisedAt);
      if (byRecency != 0) return byRecency;
      return a.id.compareTo(b.id);
    });
  return (
    selected: chronological(ranked.take(limit).toList()),
    truncated: true,
  );
}
