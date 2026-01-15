import 'package:freezed_annotation/freezed_annotation.dart';

part 'day_plan.freezed.dart';
part 'day_plan.g.dart';

/// Generates deterministic ID for a day's plan.
/// Format: dayplan-YYYY-MM-DD
String dayPlanId(DateTime date) =>
    'dayplan-${date.toIso8601String().substring(0, 10)}';

/// Reasons why a day plan needs review after being agreed.
enum DayPlanReviewReason {
  /// A task with due date was added for this day
  newDueTask,

  /// A time budget was changed
  budgetModified,

  /// A task was moved to this day
  taskRescheduled,

  /// User explicitly requested review
  manualReset,
}

/// State machine for day plan status.
///
/// Transitions:
/// - Draft -> Agreed (user agrees to plan)
/// - Agreed -> NeedsReview (trigger event occurs)
/// - NeedsReview -> Agreed (user re-agrees)
@freezed
sealed class DayPlanStatus with _$DayPlanStatus {
  /// Initial state - plan exists but not yet committed to.
  const factory DayPlanStatus.draft() = DayPlanStatusDraft;

  /// User has agreed to this plan.
  const factory DayPlanStatus.agreed({
    required DateTime agreedAt,
  }) = DayPlanStatusAgreed;

  /// Plan needs review due to changes after agreement.
  const factory DayPlanStatus.needsReview({
    required DateTime triggeredAt,
    required DayPlanReviewReason reason,

    /// When the plan was last agreed (before this review trigger)
    DateTime? previouslyAgreedAt,
  }) = DayPlanStatusNeedsReview;

  factory DayPlanStatus.fromJson(Map<String, dynamic> json) =>
      _$DayPlanStatusFromJson(json);
}

/// A time budget allocation for a category within a day.
///
/// Embedded within [DayPlanData].
@freezed
abstract class TimeBudget with _$TimeBudget {
  const factory TimeBudget({
    /// UUID for internal reference within the plan
    required String id,

    /// Links to CategoryDefinition
    required String categoryId,

    /// Duration in minutes (JSON-friendly integer)
    required int plannedMinutes,

    /// Display order in budget list
    @Default(0) int sortOrder,
  }) = _TimeBudget;

  factory TimeBudget.fromJson(Map<String, dynamic> json) =>
      _$TimeBudgetFromJson(json);
}

/// Extension for Duration conversion on TimeBudget.
extension TimeBudgetX on TimeBudget {
  Duration get plannedDuration => Duration(minutes: plannedMinutes);
}

/// A planned time block on the timeline.
///
/// Represents intended structure of the day. Embedded within [DayPlanData].
@freezed
abstract class PlannedBlock with _$PlannedBlock {
  const factory PlannedBlock({
    /// UUID for internal reference within the plan
    required String id,

    /// Which category this block is for
    required String categoryId,

    /// When block starts
    required DateTime startTime,

    /// When block ends
    required DateTime endTime,

    /// Optional note on the block
    String? note,
  }) = _PlannedBlock;

  factory PlannedBlock.fromJson(Map<String, dynamic> json) =>
      _$PlannedBlockFromJson(json);
}

/// Extension for duration calculation on PlannedBlock.
extension PlannedBlockX on PlannedBlock {
  Duration get duration => endTime.difference(startTime);
}

/// A reference to a task pinned to a specific budget.
///
/// Embedded within [DayPlanData]. The actual Task entity is stored
/// separately in the journal table.
@freezed
abstract class PinnedTaskRef with _$PinnedTaskRef {
  const factory PinnedTaskRef({
    /// References Task entity by ID
    required String taskId,

    /// Which budget this task is pinned to (references TimeBudget.id)
    required String budgetId,

    /// Display order within the budget's task list
    @Default(0) int sortOrder,
  }) = _PinnedTaskRef;

  factory PinnedTaskRef.fromJson(Map<String, dynamic> json) =>
      _$PinnedTaskRefFromJson(json);
}

/// Data payload for a day plan entity.
///
/// Contains all plan information including embedded budgets,
/// planned blocks, and pinned task references.
@freezed
abstract class DayPlanData with _$DayPlanData {
  const factory DayPlanData({
    /// The day this plan is for (at midnight local time)
    required DateTime planDate,

    /// Current status of the plan (draft/agreed/needsReview)
    required DayPlanStatus status,

    /// Optional label for the day (e.g., "Focused Workday", "Recovery Day")
    String? dayLabel,

    /// When the plan was last agreed (convenience field, also in status)
    DateTime? agreedAt,

    /// When the day was marked complete
    DateTime? completedAt,

    /// Time budget allocations by category
    @Default([]) List<TimeBudget> budgets,

    /// Planned time blocks on the timeline
    @Default([]) List<PlannedBlock> plannedBlocks,

    /// References to tasks pinned to budgets
    @Default([]) List<PinnedTaskRef> pinnedTasks,
  }) = _DayPlanData;

  factory DayPlanData.fromJson(Map<String, dynamic> json) =>
      _$DayPlanDataFromJson(json);
}

/// Extension methods for DayPlanData.
extension DayPlanDataX on DayPlanData {
  /// Total planned duration across all budgets.
  Duration get totalPlannedDuration => budgets.fold(
        Duration.zero,
        (total, budget) => total + budget.plannedDuration,
      );

  /// Find budget by ID.
  TimeBudget? budgetById(String id) {
    for (final budget in budgets) {
      if (budget.id == id) return budget;
    }
    return null;
  }

  /// Find budget by category ID.
  TimeBudget? budgetByCategoryId(String categoryId) {
    for (final budget in budgets) {
      if (budget.categoryId == categoryId) return budget;
    }
    return null;
  }

  /// Get pinned tasks for a specific budget.
  List<PinnedTaskRef> pinnedTasksForBudget(String budgetId) =>
      pinnedTasks.where((ref) => ref.budgetId == budgetId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Get planned blocks for a specific category.
  List<PlannedBlock> blocksForCategory(String categoryId) =>
      plannedBlocks.where((block) => block.categoryId == categoryId).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// Whether this plan has been agreed to.
  bool get isAgreed => status is DayPlanStatusAgreed;

  /// Whether this plan needs review.
  bool get needsReview => status is DayPlanStatusNeedsReview;

  /// Whether this plan is still a draft.
  bool get isDraft => status is DayPlanStatusDraft;

  /// Whether the day has been marked complete.
  bool get isComplete => completedAt != null;
}
