import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// Canonical recording fake for [DayAgentInterface], shared by the
/// daily_os_next page tests (capture / day / refine / commit).
///
/// Records the arguments of the mutating calls — [submitCapture],
/// [deletePlanForDate], [proposePlanDiff], [acceptDiff], [revertDiff],
/// [commitDay] — and returns configurable results. Every other interface
/// member is a benign default stub.
class RecordingDayAgent implements DayAgentInterface {
  RecordingDayAgent({
    this.diff,
    this.acceptedPlan,
    this.proposeError,
    this.proposeGate,
    this.submitResult = const CaptureId('cap'),
    this.draftPlanBuilder,
  });

  /// Diff returned by [proposePlanDiff]; when null, a no-change diff
  /// echoing the current plan is fabricated.
  final PlanDiff? diff;

  /// Plan returned by [acceptDiff]; defaults to the accepted diff's
  /// `updatedPlan`.
  final DraftPlan? acceptedPlan;

  /// When set, [proposePlanDiff] throws this error (after [proposeGate]).
  final Error? proposeError;

  /// When set, [proposePlanDiff] blocks on this future before returning,
  /// keeping callers pinned in their "thinking" phase so tests can observe
  /// the transient state.
  final Future<void>? proposeGate;

  /// Result of [submitCapture].
  final CaptureId submitResult;

  /// Result of [draftDayPlan]; defaults to an empty plan for the requested
  /// day.
  final DraftPlan Function(DateTime dayDate)? draftPlanBuilder;

  // ---- Recorded state ----

  String? capturedTranscript;
  String? capturedAudioId;
  DateTime? capturedAt;
  int submitCount = 0;

  DateTime? deletedFor;
  int deleteCount = 0;

  int proposeCount = 0;
  String? proposedTranscript;
  PlanDiff? capturedDiff;
  List<int>? acceptIndices;
  List<int>? revertIndices;
  DraftPlan? revertOriginalPlan;

  DraftPlan? capturedPlan;
  int commitCount = 0;

  // ---- Recorded members ----

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async {
    capturedTranscript = transcript;
    capturedAudioId = audioId;
    this.capturedAt = capturedAt;
    submitCount++;
    return submitResult;
  }

  @override
  Future<bool> deletePlanForDate(DateTime date) async {
    deletedFor = date;
    deleteCount++;
    return true;
  }

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async {
    proposeCount++;
    proposedTranscript = voiceTranscript;
    final gate = proposeGate;
    if (gate != null) await gate;
    final error = proposeError;
    if (error != null) throw error;
    return diff ??
        PlanDiff(
          id: 'd',
          transcript: voiceTranscript,
          changes: const [],
          updatedPlan: currentPlan,
        );
  }

  @override
  Future<DraftPlan> acceptDiff(PlanDiff diff, {List<int>? itemIndices}) async {
    capturedDiff = diff;
    acceptIndices = itemIndices;
    return acceptedPlan ?? diff.updatedPlan;
  }

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async {
    capturedDiff = diff;
    revertIndices = itemIndices;
    revertOriginalPlan = originalPlan;
    return originalPlan;
  }

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) async {
    capturedPlan = plan;
    commitCount++;
    return plan.copyWith(state: DayState.committed);
  }

  // ---- Benign default stubs ----

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async => null;

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async => const [];

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async =>
      throw UnimplementedError();

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async => TriageResult(taskId: taskId, action: action);

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) async =>
      draftPlanBuilder?.call(dayDate) ??
      DraftPlan(
        dayDate: dayDate,
        blocks: const [],
        bands: const [],
        capacityMinutes: 0,
        scheduledMinutes: 0,
      );

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async => const [];

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async => (
    completed: const <CompletedItem>[],
    carryover: const <CarryoverItem>[],
    metrics: const ShutdownMetrics(
      focusMinutes: 0,
      flowSessions: 0,
      contextSwitches: 0,
      contextSwitchesWeekAvg: 0,
      energyScore: 0,
      energyDeltaVsWeek: 0,
    ),
  );

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {}

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {}

  @override
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async => const TomorrowNote(body: '', maturity: 1);

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) async => const [];
}
