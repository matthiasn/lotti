import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
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
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
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
    required this.outbox,
    required this.nudgeProcessing,
  });

  final DayAgentCaptureService captureService;
  final DayAgentPlanService planService;
  final DayAgentService dayAgentService;
  final JournalDb journalDb;
  final DayAgentInterface mockFallback;

  /// Durable processing outbox (ADR 0032 phase 1): draft/refine requests are
  /// enqueued as jobs here instead of firing a wake directly, so the intent
  /// survives a process kill and completion is observed via its `changes`
  /// stream instead of polling.
  final DayProcessingOutboxRepository outbox;

  /// Nudges the processing runtime to drain immediately after an enqueue,
  /// rather than waiting for its next scheduled tick.
  final void Function() nudgeProcessing;

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
    required DateTime dayDate,
    String? audioId,
  }) async {
    // ADR 0032: the per-day agent owns the day's captures; the first capture
    // for a clean day creates it lazily (pre-cutover days resolve to the
    // coordinator).
    final identity = await dayAgentService.getOrCreateDayAgentForDate(dayDate);
    final capture = await captureService.submitCapture(
      agentId: identity.agentId,
      transcript: transcript,
      capturedAt: capturedAt,
      dayId: dayAgentIdForDate(dayDate),
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
    // Deliberately coordinator-resolved: the interface carries no date, and
    // the agent id is only used for category scoping, which per-day agents
    // inherit from the coordinator at creation anyway (ADR 0032 phase 2).
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

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) async {
    final dayId = dayAgentIdForDate(dayDate);
    // PR #3212: the workflow turns these into `decided_task:<id>` trigger
    // tokens and surfaces the hydrated tasks in the drafting prompt so the
    // model can attach `taskId` to each placed block.
    final job = await outbox.enqueueDraftPlan(
      dayId: dayId,
      payload: DraftPlanPayload(
        captureId: captureId.value,
        decidedTaskIds: decidedTaskIds,
        decidedCaptureItemIds: decidedCaptureItemIds,
      ),
    );
    nudgeProcessing();

    final terminal = await _awaitJobTerminal(job.id, isCancelled: isCancelled);
    if (terminal.status == DayProcessingJobStatus.succeeded) {
      final identity = await dayAgentService.getDayAgentForDate(dayDate);
      if (identity is! AgentIdentityEntity) {
        throw DayAgentInteractionException(
          'No day agent exists for $dayId after drafting completed.',
        );
      }
      final plan = await planService.draftPlanForDay(
        agentId: identity.agentId,
        dayId: dayId,
      );
      if (plan == null) {
        throw DayAgentInteractionException(
          'Drafting completed but $dayId has no drafted plan.',
        );
      }
      return _projectDayPlan(plan, dayDate);
    }

    throw DayAgentInteractionException(_jobFailureMessage(terminal));
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
    final plan = await planService.draftPlanForDay(
      agentId: identity.agentId,
      dayId: dayId,
    );
    if (plan == null) {
      throw const DayAgentInteractionException(
        'Failed to enqueue the refine wake. The plan may have been '
        'deleted — refresh and try again.',
      );
    }

    // Persisted once up front so a crash-and-retry of the durable job
    // re-runs against this exact wording instead of writing a duplicate.
    final transcriptCaptureId = await dayAgentService.persistRefineCapture(
      agentId: identity.agentId,
      dayId: dayId,
      transcript: voiceTranscript,
    );
    final job = await outbox.enqueueRefinePlan(
      dayId: dayId,
      transcriptCaptureId: transcriptCaptureId,
    );
    nudgeProcessing();

    final terminal = await _awaitJobTerminal(job.id, isCancelled: isCancelled);
    if (terminal.status == DayProcessingJobStatus.succeeded) {
      final diffs = await planService.pendingPlanDiffsForDay(
        agentId: identity.agentId,
        dayId: dayId,
      );
      final diff = diffs
          .where((d) => d.id == terminal.resultEntityId)
          .firstOrNull;
      if (diff == null) {
        throw DayAgentInteractionException(
          'Refining completed but $dayId has no pending diff.',
        );
      }
      return _projectPlanDiff(
        changeSet: diff,
        currentPlan: currentPlan,
        transcript: voiceTranscript,
      );
    }

    throw DayAgentInteractionException(_jobFailureMessage(terminal));
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
  Future<DraftPlan> editBlock({
    required DraftPlan plan,
    required String blockId,
    required DateTime start,
    required DateTime end,
    String? title,
    DayAgentCategory? category,
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(plan.dayDate);
    if (identity is! AgentIdentityEntity) {
      throw DayAgentInteractionException(
        'No day agent exists for ${dayAgentIdForDate(plan.dayDate)}.',
      );
    }
    final edited = await planService.editBlock(
      agentId: identity.agentId,
      dayId: dayAgentIdForDate(plan.dayDate),
      blockId: blockId,
      start: start,
      end: end,
      title: title,
      categoryId: category?.id,
    );
    return _projectDayPlan(edited, plan.dayDate);
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

  /// How often [_awaitJobTerminal] re-checks its cancellation callback
  /// between outbox change events. Not a poll of job state — the job is
  /// only ever re-read on an actual change notification or this tick.
  static const _cancelCheckInterval = Duration(seconds: 1);

  /// Soft cap on how long a caller awaits a durable job. The job itself
  /// keeps running in the background past this point — the durable outbox
  /// is what makes that safe — this only bounds how long the UI call sits
  /// waiting before surfacing a "check the Activity timeline" message.
  static const _jobAwaitSoftCap = Duration(minutes: 10);

  /// Awaits [jobId] reaching a terminal status via outbox change events,
  /// falling back only to a periodic [isCancelled] check and the soft cap
  /// — never to polling job state on a timer.
  ///
  /// On [isCancelled] firing, the durable job is left running: the caller
  /// gave up on this await, not on the underlying work. A later re-open of
  /// the same request re-enqueues, which coalesces (draft) or attaches
  /// (refine/parse) onto the still-live job.
  Future<DayProcessingJob> _awaitJobTerminal(
    String jobId, {
    bool Function()? isCancelled,
  }) {
    final completer = Completer<DayProcessingJob>();
    final deadline = clock.now().add(_jobAwaitSoftCap);
    late final StreamSubscription<void> subscription;
    Timer? ticker;

    Future<void> checkTerminal() async {
      if (completer.isCompleted) return;
      final job = await outbox.getById(jobId);
      if (job != null && _isAwaitDone(job)) {
        completer.complete(job);
      }
    }

    subscription = outbox.changes.listen((_) => unawaited(checkTerminal()));
    ticker = Timer.periodic(_cancelCheckInterval, (timer) {
      // Dart's event loop always drains the microtask queue — including
      // `whenComplete`'s `ticker?.cancel()` below — before the next Timer
      // callback runs, so this tick can never observe `isCompleted` true
      // through legitimate single-threaded scheduling. Kept as a genuine
      // belt-and-suspenders guard against relying on that guarantee.
      // coverage:ignore-start
      if (completer.isCompleted) {
        timer.cancel();
        return;
      }
      // coverage:ignore-end
      if (isCancelled?.call() ?? false) {
        completer.completeError(
          const DayAgentInteractionException('cancelled by caller'),
        );
        timer.cancel();
        return;
      }
      if (!clock.now().isBefore(deadline)) {
        completer.completeError(
          const DayAgentInteractionException(
            "Still working in background — check the day's Activity "
            'timeline for progress.',
          ),
        );
        timer.cancel();
      }
    });

    unawaited(checkTerminal());

    return completer.future.whenComplete(() {
      unawaited(subscription.cancel());
      ticker?.cancel();
    });
  }

  /// Whether [job] has settled into a status [_awaitJobTerminal] should stop
  /// waiting on. Broader than [DayProcessingJob.isTerminal] (which the
  /// outbox/repair layer uses to mean "never claim this again"): `failed`
  /// and `waitingForUser` need explicit user action (Settings, or a retry
  /// from the Activity timeline) to make further progress, so a live caller
  /// must give up and surface them rather than wait indefinitely.
  /// `waitingForNetwork` is left waiting through — the outbox retries it
  /// automatically once its backoff elapses or connectivity returns.
  static bool _isAwaitDone(DayProcessingJob job) =>
      job.isTerminal ||
      job.status == DayProcessingJobStatus.failed ||
      job.status == DayProcessingJobStatus.waitingForUser;

  String _jobFailureMessage(DayProcessingJob job) {
    final base = switch (job.status) {
      DayProcessingJobStatus.waitingForUser =>
        'Setup required before this can continue. Open Settings to fix the '
            "day agent's model/profile, then retry.",
      DayProcessingJobStatus.cancelled => 'Cancelled.',
      _ =>
        'The day agent could not complete this. Check "Inspect agent" '
            'for the wake log and retry.',
    };
    final detail = job.lastError;
    return detail == null || detail.isEmpty ? base : '$base ($detail)';
  }
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
