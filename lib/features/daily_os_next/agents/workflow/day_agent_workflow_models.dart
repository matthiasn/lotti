import 'package:lotti/features/agents/memory/memory_links.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:uuid/uuid.dart';

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
  });

  final DayPlanEntity? baselinePlan;
  final List<DecidedTaskRef> decidedTasks;
  final List<ParsedItemEntity> decidedCaptureItems;

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
