import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// Surface the UI calls into to interact with the day-level agent.
///
/// One-to-one with the §E tool inventory in
/// `docs/implementation_plans/2026-05-25_day_agent_layer.md`. Only the
/// Capture + Reconcile tools are exposed for now; the rest land when
/// the real `DayAgentWorkflow` ships in a later session.
///
/// Implementations are kept side-effect-free where possible. The
/// canonical "mock" implementation (`MockDayAgent`) returns scripted
/// data so the UI can be developed end-to-end without the real
/// backing agent layer.
abstract class DayAgentInterface {
  /// Tool: `submit_capture`. Persist the spoken/typed check-in.
  /// Returns the capture id used by subsequent reconciliation calls.
  ///
  /// [audioId] is the optional `JournalAudio.meta.id` of the persisted
  /// recording. When set it is forwarded as the capture's `audioRef`
  /// so the agent layer can find the underlying audio.
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  });

  /// Returns the currently persisted [DraftPlan] for [date], if any.
  /// Used to route directly to the Day view on app open when a plan
  /// already exists, instead of forcing the user back through Capture.
  Future<DraftPlan?> currentPlanForDate(DateTime date);

  /// Tool: `parse_capture_to_items`. Tokenize the transcript into
  /// editable structured items, each tagged with NEW / MATCHED /
  /// UPDATE and a confidence level.
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id);

  /// Tool: `surface_pending_decisions`. Items the agent thinks
  /// the user should decide on today: overdue, in-progress carries,
  /// missed recurring, due today.
  Future<List<PendingItem>> surfacePendingDecisions({DateTime? forDate});

  /// Tool: `break_capture_link`. Remove the link between a parsed
  /// MATCHED item and the task it was pointed at. The card returns
  /// to its NEW-task shape.
  Future<ParsedItem> breakCaptureLink(String parsedItemId);

  /// Tool: `apply_triage`. Record the user's triage decision for a
  /// pending item (or for a NEW parsed item the user wants to keep).
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  });

  /// Tool: `draft_day_plan`. Compose a day plan from the chosen
  /// capture items plus today's calendar events (deferred — caller
  /// passes `calendarBlocks: const []`).
  ///
  /// Returns the placed blocks, the day's energy bands, and capacity
  /// metadata. Every block of [TimeBlockType.ai] carries a verbatim
  /// `reason` string — surfaced in the WhyChip popover.
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<TimeBlock> calendarBlocks,
  });

  /// Tool: `summarize_recent_patterns`. Pulls a small set of learning
  /// cards (yesterday, this-week-so-far, gentle nudge) the Drafting
  /// screen renders in the right column while the plan is being
  /// composed.
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  });

  /// Tool: `propose_plan_diff`. Re-shape the current plan based on a
  /// spoken (or typed) refinement request. The returned [PlanDiff]
  /// carries both the change list and the resulting plan so the UI
  /// can render the day "with changes applied in place" plus a diff
  /// row list on the right.
  ///
  /// In the real agent layer this is persisted as a
  /// `ChangeSetEntity` so it survives a refresh; the mock keeps it
  /// in-memory.
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
  });

  /// Tool: `accept_diff`. Commit the proposed [PlanDiff] — the
  /// returned plan becomes the user's current draft.
  Future<DraftPlan> acceptDiff(PlanDiff diff);

  /// Tool: `revert_diff`. Discard the proposed [PlanDiff] — the
  /// caller-provided plan is the one to keep.
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
  });

  /// Tool: `commit_day`. Toggles the day's state from drafted to
  /// committed. Blocks render solid (no dashed outline) once this
  /// completes; the agent's role shifts to shepherding (no more
  /// re-proposals unless the user invokes Refine).
  Future<DraftPlan> commitDay(DraftPlan plan);

  /// Tool: `surface_shutdown_data`. Returns the three lists the
  /// Shutdown screen needs: what completed today, what carries
  /// forward, and the metrics card payload. Bundled because they
  /// share the same lookback window.
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate});

  /// Tool: `record_reflection`. Persists the user's one-line
  /// end-of-day reflection. Appended to the Logbook journal entry
  /// for [forDate] in the real agent layer; here it's a no-op that
  /// echoes back so the UI can render confirmation.
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  });

  /// Tool: `record_carryover_decision`. Records what the user chose
  /// for a carryover item — re-place tomorrow, pick a date, or drop.
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  });

  /// Tool: `generate_tomorrow_note`. Returns the "For tomorrow"
  /// paragraph the Shutdown screen shows at the bottom right.
  Future<TomorrowNote> generateTomorrowNote({required DateTime forDate});

  /// Tool: `surface_task_corpus`. Browse the user's task corpus.
  /// Pure read; no agent involvement per the design.
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  });
}
