import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent_capture.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent_planning.dart';
import 'package:meta/meta.dart';

/// Scripted [DayAgentInterface] for the Capture + Reconcile preview.
///
/// Replaces the real `DayAgentWorkflow` until the agentic backend
/// described in `docs/implementation_plans/2026-05-25_day_agent_layer.md`
/// ships. Returns a stable, demoable shape so the UI work can land
/// independently. Every call carries an artificial latency so the
/// loading states render in real conditions.
///
/// A thin facade over two scripted collaborators: [MockDayAgentCapture]
/// (capture/reconcile/draft) and [MockDayAgentPlanning] (refine/shutdown).
/// The capture collaborator keeps its own in-memory "broken link" tracker
/// so the `breakCaptureLink` action visibly mutates the returned parsed
/// items across calls.
class MockDayAgent implements DayAgentInterface {
  /// Creates a scripted day agent and wires its collaborators.
  MockDayAgent({
    Duration parseLatency = const Duration(milliseconds: 220),
    Duration pendingLatency = const Duration(milliseconds: 180),
    Duration triageLatency = const Duration(milliseconds: 120),
    Duration draftLatency = const Duration(milliseconds: 400),
    Duration summarizeLatency = const Duration(milliseconds: 120),
    DateTime Function()? clock,
  }) : _capture = MockDayAgentCapture(
         parseLatency: parseLatency,
         pendingLatency: pendingLatency,
         triageLatency: triageLatency,
         draftLatency: draftLatency,
         clock: clock ?? DateTime.now,
       ),
       _planning = MockDayAgentPlanning(
         draftLatency: draftLatency,
         triageLatency: triageLatency,
         summarizeLatency: summarizeLatency,
         pendingLatency: pendingLatency,
       );

  final MockDayAgentCapture _capture;
  final MockDayAgentPlanning _planning;

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) => _capture.submitCapture(
    transcript: transcript,
    capturedAt: capturedAt,
    audioId: audioId,
  );

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) =>
      _capture.currentPlanForDate(date);

  @override
  Future<bool> deletePlanForDate(DateTime date) =>
      _capture.deletePlanForDate(date);

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) =>
      _capture.parseCaptureToItems(id);

  @override
  Future<List<PendingItem>> surfacePendingDecisions({DateTime? forDate}) =>
      _capture.surfacePendingDecisions(forDate: forDate);

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) =>
      _capture.breakCaptureLink(parsedItemId);

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) => _capture.applyTriage(taskId: taskId, action: action, deferTo: deferTo);

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) => _capture.draftDayPlan(
    captureId: captureId,
    decidedTaskIds: decidedTaskIds,
    dayDate: dayDate,
    decidedCaptureItemIds: decidedCaptureItemIds,
    calendarBlocks: calendarBlocks,
    isCancelled: isCancelled,
  );

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) => _planning.proposePlanDiff(
    currentPlan: currentPlan,
    voiceTranscript: voiceTranscript,
    isCancelled: isCancelled,
  );

  @override
  Future<DraftPlan> acceptDiff(
    PlanDiff diff, {
    List<int>? itemIndices,
  }) => _planning.acceptDiff(diff, itemIndices: itemIndices);

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) => _planning.revertDiff(
    diff: diff,
    originalPlan: originalPlan,
    itemIndices: itemIndices,
  );

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) => _planning.summarizeRecentPatterns(
    asOf: asOf,
    lookbackDays: lookbackDays,
  );

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) => _planning.commitDay(plan);

  @override
  Future<DraftPlan> renameBlock({
    required DraftPlan plan,
    required String blockId,
    required String title,
  }) => _planning.renameBlock(plan: plan, blockId: blockId, title: title);

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) =>
      _planning.surfaceShutdownData(forDate: forDate);

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) => _planning.recordReflection(
    forDate: forDate,
    text: text,
    source: source,
  );

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) => _planning.recordCarryoverDecision(
    taskId: taskId,
    action: action,
    when: when,
  );

  @override
  Future<TomorrowNote> generateTomorrowNote({required DateTime forDate}) =>
      _planning.generateTomorrowNote(forDate: forDate);

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) => _planning.surfaceTaskCorpus(
    stateFilter: stateFilter,
    categoryId: categoryId,
    query: query,
  );

  /// Test seam for the pure corpus-filter predicate.
  @visibleForTesting
  bool debugMatchesFilter(
    TaskCorpusItem item,
    TaskCorpusState state,
    String? categoryId,
    String? query,
  ) => _planning.matchesFilter(item, state, categoryId, query);
}
