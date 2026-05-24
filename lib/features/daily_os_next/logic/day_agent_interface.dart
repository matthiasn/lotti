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
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
  });

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
}
