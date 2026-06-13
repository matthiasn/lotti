import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/util/day_arithmetic.dart';
import 'package:meta/meta.dart';

part 'real_day_agent_projection.dart';

/// Bridges the UI's [DayAgentInterface] to the real agent layer.
///
/// **Graduated to real** — direct calls into `DayAgentCaptureService`
/// / `DayAgentPlanService` / `DayAgentService`. Failures throw a
/// [DayAgentInteractionException] (or propagate the underlying service
/// exception) so the UI can render a real error state instead of a
/// scripted fallback that pretends the call succeeded:
/// `submitCapture`, `parseCaptureToItems`, `surfacePendingDecisions`,
/// `applyTriage`, `linkCapturePhraseToTask`, `breakCaptureLink`,
/// `summarizeRecentPatterns`, `draftDayPlan`, `proposePlanDiff`,
/// `acceptDiff`, `revertDiff`, `commitDay`, `currentPlanForDate`,
/// `deletePlanForDate`.
///
/// **Still mocked** — these methods still delegate to [mockFallback]
/// because their agent-side tools have not shipped yet. Once each
/// phase lands they graduate the same way (real calls + thrown
/// errors): `surfaceShutdownData`, `recordReflection`,
/// `recordCarryoverDecision`, `generateTomorrowNote` (Phase 6),
/// `surfaceTaskCorpus` (Phase 7).
///
/// As those phases ship in the agent layer, methods graduate from
/// `mockFallback` to direct service calls.
class RealDayAgent implements DayAgentInterface {
  RealDayAgent({
    required this.captureService,
    required this.planService,
    required this.dayAgentService,
    required this.journalDb,
    required this.mockFallback,
  });

  final DayAgentCaptureService captureService;
  final DayAgentPlanService planService;
  final DayAgentService dayAgentService;
  final JournalDb journalDb;
  final DayAgentInterface mockFallback;

  /// In-memory cache so the adapter does not hit the categories
  /// table once per parsed item / pending item. Cleared on adapter
  /// recreation (Riverpod provider invalidation).
  final Map<String, DayAgentCategory> _categoryCache = {};

  /// Default fallback when a `categoryId` is null or resolves to a
  /// deleted/missing row. Teal matches the brand interactive token
  /// so the UI still surfaces *something* sensible.
  static const _fallbackCategory = DayAgentCategory(
    id: 'unknown',
    name: 'Uncategorised',
    colorHex: '5ED4B7',
  );

  // ───────────────────────────── Graduated methods ──

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async {
    // One long-lived planner owns every day (ADR 0022); create it lazily on
    // the first capture.
    final identity = await dayAgentService.getOrCreatePlannerAgent();
    final capture = await captureService.submitCapture(
      agentId: identity.agentId,
      transcript: transcript,
      capturedAt: capturedAt,
      audioRef: audioId,
    );
    return CaptureId(capture.id);
  }

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async {
    final identity = await dayAgentService.getDayAgentForDate(date);
    if (identity is! AgentIdentityEntity) return null;
    final dayId = dayAgentIdForDate(date);
    final plan = await planService.draftPlanForDay(
      agentId: identity.agentId,
      dayId: dayId,
    );
    if (plan == null) return null;
    return _projectDayPlan(plan, date);
  }

  @override
  Future<bool> deletePlanForDate(DateTime date) async {
    final identity = await dayAgentService.getDayAgentForDate(date);
    if (identity is! AgentIdentityEntity) return false;
    return planService.deletePlanForDay(
      agentId: identity.agentId,
      dayId: dayAgentIdForDate(date),
    );
  }

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async {
    final entities = await captureService.parsedItemsForCapture(id.value);
    final out = <ParsedItem>[];
    for (final entity in entities) {
      out.add(await _projectParsedItem(entity));
    }
    return out;
  }

  @override
  Future<List<PendingItem>> surfacePendingDecisions({DateTime? forDate}) async {
    final date = forDate ?? clock.now();
    final selectedDay = DateTime(date.year, date.month, date.day);
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final identity = await dayAgentService.getDayAgentForDate(date);
    if (identity is! AgentIdentityEntity) return const [];
    final items = await captureService.surfacePendingDecisions(
      agentId: identity.agentId,
      dayId: dayAgentIdForDate(date),
    );
    return Future.wait([
      for (final item in items)
        _projectPendingItem(item, selectedDay: selectedDay, today: today),
    ]);
  }

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async {
    final updated = await captureService.breakCaptureLink(parsedItemId);
    return _projectParsedItem(updated);
  }

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async {
    final identity = await dayAgentService.getOrCreatePlannerAgent();
    await captureService.applyTriage(
      agentId: identity.agentId,
      taskId: taskId,
      action: action.name,
      deferTo: deferTo,
    );
    return TriageResult(
      taskId: taskId,
      action: action,
      deferredTo: action == TriageAction.defer ? deferTo : null,
    );
  }

  /// Not part of [DayAgentInterface] but exposed for the Reconcile
  /// UI to call when the user re-points a parsed item to a different
  /// task from the "did you mean…" overflow menu.
  Future<ParsedItem> linkCapturePhraseToTask({
    required String parsedItemId,
    required String taskId,
  }) async {
    final updated = await captureService.linkCapturePhraseToTask(
      captureItemId: parsedItemId,
      taskId: taskId,
    );
    return _projectParsedItem(updated);
  }

  /// How often to re-check `draftPlanForDay` while waiting for the
  /// drafting wake to produce a new `DayPlanEntity`.
  static const _draftPollInterval = Duration(milliseconds: 500);

  /// Upper bound on how long [draftDayPlan] waits for the wake to
  /// produce a plan before surfacing a failure. Long enough for a
  /// typical model round-trip, short enough that the UI does not
  /// look stuck.
  static const _draftTimeout = Duration(seconds: 60);

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(dayDate);
    if (identity is! AgentIdentityEntity) {
      throw DayAgentInteractionException(
        'No day agent exists for ${dayAgentIdForDate(dayDate)}. '
        'Submit a capture first so the day-agent is created.',
      );
    }
    final dayId = dayAgentIdForDate(dayDate);
    final baseline = await planService.draftPlanForDay(
      agentId: identity.agentId,
      dayId: dayId,
    );
    final baselineUpdatedAt = baseline?.updatedAt;

    final enqueued = await dayAgentService.enqueueDraftingWake(
      dayDate: dayDate,
      captureId: captureId.value,
      // PR #3212: the workflow turns these into `decided_task:<id>`
      // trigger tokens and surfaces the hydrated tasks in the drafting
      // prompt so the model can attach `taskId` to each placed block.
      decidedTaskIds: decidedTaskIds,
      decidedCaptureItemIds: decidedCaptureItemIds,
    );
    if (!enqueued) {
      throw const DayAgentInteractionException(
        'Failed to enqueue the drafting wake — no day-agent was found '
        'for this date.',
      );
    }

    final deadline = clock.now().add(_draftTimeout);
    while (clock.now().isBefore(deadline)) {
      if (isCancelled?.call() ?? false) {
        throw const DayAgentInteractionException(
          'draftDayPlan poll cancelled by caller',
        );
      }
      await Future<void>.delayed(_draftPollInterval);
      if (isCancelled?.call() ?? false) {
        throw const DayAgentInteractionException(
          'draftDayPlan poll cancelled by caller',
        );
      }
      final current = await planService.draftPlanForDay(
        agentId: identity.agentId,
        dayId: dayId,
      );
      if (current == null) continue;
      if (baselineUpdatedAt == null ||
          current.updatedAt.isAfter(baselineUpdatedAt)) {
        return _projectDayPlan(current, dayDate);
      }
    }

    throw const DayAgentInteractionException(
      'Timed out waiting for the day-agent to produce a plan. Check '
      '"Inspect agent" for the wake log and retry.',
    );
  }

  // ───────────────────────────── Mocked methods ──

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(asOf);
    if (identity is! AgentIdentityEntity) return const [];
    final cards = await planService.summarizeRecentPatterns(
      agentId: identity.agentId,
      asOf: asOf,
      lookbackDays: lookbackDays,
    );
    return [for (final card in cards) _projectLearningCard(card)];
  }

  /// Polling cadence + ceiling for the refine wake. Same shape as the
  /// drafting poller — dumb-and-reliable, easy to swap to a stream
  /// later.
  static const _refinePollInterval = Duration(milliseconds: 500);
  static const _refineTimeout = Duration(seconds: 60);

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(
      currentPlan.dayDate,
    );
    if (identity is! AgentIdentityEntity) {
      throw DayAgentInteractionException(
        'No day agent exists for ${dayAgentIdForDate(currentPlan.dayDate)}.',
      );
    }
    final dayId = dayAgentIdForDate(currentPlan.dayDate);
    final baselineDiffs = await planService.pendingPlanDiffsForDay(
      agentId: identity.agentId,
      dayId: dayId,
    );
    final baselineIds = baselineDiffs.map((d) => d.id).toSet();

    final enqueued = await dayAgentService.enqueueRefineWake(
      dayDate: currentPlan.dayDate,
      transcript: voiceTranscript,
    );
    if (!enqueued) {
      throw const DayAgentInteractionException(
        'Failed to enqueue the refine wake. The plan may have been '
        'deleted — refresh and try again.',
      );
    }

    final deadline = clock.now().add(_refineTimeout);
    while (clock.now().isBefore(deadline)) {
      if (isCancelled?.call() ?? false) {
        throw const DayAgentInteractionException(
          'proposePlanDiff poll cancelled by caller',
        );
      }
      await Future<void>.delayed(_refinePollInterval);
      if (isCancelled?.call() ?? false) {
        throw const DayAgentInteractionException(
          'proposePlanDiff poll cancelled by caller',
        );
      }
      final diffs = await planService.pendingPlanDiffsForDay(
        agentId: identity.agentId,
        dayId: dayId,
      );
      for (final diff in diffs) {
        if (baselineIds.contains(diff.id)) continue;
        return _projectPlanDiff(
          changeSet: diff,
          currentPlan: currentPlan,
          transcript: voiceTranscript,
        );
      }
    }
    throw const DayAgentInteractionException(
      'Timed out waiting for the day-agent to produce a refine proposal. '
      'Check "Inspect agent" for the wake log and retry.',
    );
  }

  @override
  Future<DraftPlan> acceptDiff(
    PlanDiff diff, {
    List<int>? itemIndices,
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(
      diff.updatedPlan.dayDate,
    );
    if (identity is! AgentIdentityEntity) {
      throw DayAgentInteractionException(
        'No day agent exists for '
        '${dayAgentIdForDate(diff.updatedPlan.dayDate)}.',
      );
    }
    await planService.acceptPlanDiff(
      agentId: identity.agentId,
      changeSetId: diff.id,
      itemIndices: itemIndices,
    );
    final dayId = dayAgentIdForDate(diff.updatedPlan.dayDate);
    final plan = await planService.draftPlanForDay(
      agentId: identity.agentId,
      dayId: dayId,
    );
    if (plan == null) {
      throw DayAgentInteractionException(
        'Plan disappeared after accepting the diff — '
        '${dayAgentIdForDate(diff.updatedPlan.dayDate)} no longer has a '
        'drafted plan.',
      );
    }
    return _projectDayPlan(plan, diff.updatedPlan.dayDate);
  }

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(
      originalPlan.dayDate,
    );
    if (identity is! AgentIdentityEntity) {
      throw DayAgentInteractionException(
        'No day agent exists for ${dayAgentIdForDate(originalPlan.dayDate)}.',
      );
    }
    await planService.revertPlanDiff(
      agentId: identity.agentId,
      changeSetId: diff.id,
      itemIndices: itemIndices,
    );
    final dayId = dayAgentIdForDate(originalPlan.dayDate);
    final plan = await planService.draftPlanForDay(
      agentId: identity.agentId,
      dayId: dayId,
    );
    if (plan == null) {
      throw DayAgentInteractionException(
        'Plan disappeared after rejecting the diff — '
        '$dayId no longer has a drafted plan.',
      );
    }
    return _projectDayPlan(plan, originalPlan.dayDate);
  }

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) async {
    final identity = await dayAgentService.getDayAgentForDate(plan.dayDate);
    if (identity is! AgentIdentityEntity) {
      throw DayAgentInteractionException(
        'No day agent exists for ${dayAgentIdForDate(plan.dayDate)}.',
      );
    }
    final committed = await planService.commitDay(
      agentId: identity.agentId,
      dayId: dayAgentIdForDate(plan.dayDate),
    );
    return _projectDayPlan(committed, plan.dayDate);
  }

  @override
  Future<DraftPlan> renameBlock({
    required DraftPlan plan,
    required String blockId,
    required String title,
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(plan.dayDate);
    if (identity is! AgentIdentityEntity) {
      throw DayAgentInteractionException(
        'No day agent exists for ${dayAgentIdForDate(plan.dayDate)}.',
      );
    }
    final renamed = await planService.renameBlock(
      agentId: identity.agentId,
      dayId: dayAgentIdForDate(plan.dayDate),
      blockId: blockId,
      title: title,
    );
    return _projectDayPlan(renamed, plan.dayDate);
  }

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) =>
      mockFallback.surfaceShutdownData(forDate: forDate);

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) => mockFallback.recordReflection(
    forDate: forDate,
    text: text,
    source: source,
  );

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) => mockFallback.recordCarryoverDecision(
    taskId: taskId,
    action: action,
    when: when,
  );

  @override
  Future<TomorrowNote> generateTomorrowNote({required DateTime forDate}) =>
      mockFallback.generateTomorrowNote(forDate: forDate);

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) => mockFallback.surfaceTaskCorpus(
    stateFilter: stateFilter,
    categoryId: categoryId,
    query: query,
  );

  // ───────────────────────────── Helpers ──
}

/// Thrown by [RealDayAgent] when a graduated path cannot complete —
/// no day-agent for the date, an enqueue refused by the backend, or
/// the wake timed out. Replaces the previous "silently fall back to
/// scripted mock data" behaviour so failures surface in the UI as
/// real error states instead of being papered over with placeholder
/// blocks.
class DayAgentInteractionException implements Exception {
  const DayAgentInteractionException(this.message);

  final String message;

  @override
  String toString() => 'DayAgentInteractionException: $message';
}

/// Tiny helper so the adapter can override one field on the fallback
/// category constant without exposing a public copyWith on the model.
extension on DayAgentCategory {
  DayAgentCategory copyWith({
    required String id,
    String? name,
    String? colorHex,
  }) => DayAgentCategory(
    id: id,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
  );
}
