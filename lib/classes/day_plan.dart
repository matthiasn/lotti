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

  /// A planned block was changed
  blockModified,

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

/// A planned time block on the timeline.
///
/// Represents intended structure of the day. Embedded within [DayPlanData].
/// Time budgets are derived by summing block durations per category.
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

/// A reference to a task pinned to a specific category for the day.
///
/// Embedded within [DayPlanData]. The actual Task entity is stored
/// separately in the journal table.
@freezed
abstract class PinnedTaskRef with _$PinnedTaskRef {
  const factory PinnedTaskRef({
    /// References Task entity by ID
    required String taskId,

    /// Which category this task is pinned to
    required String categoryId,

    /// Display order within the category's task list
    @Default(0) int sortOrder,
  }) = _PinnedTaskRef;

  factory PinnedTaskRef.fromJson(Map<String, dynamic> json) =>
      _$PinnedTaskRefFromJson(json);
}

/// Data payload for a day plan entity.
///
/// Contains all plan information including planned blocks and pinned task
/// references. Time budgets are derived from the sum of block durations
/// per category.
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

    /// Planned time blocks on the timeline
    @Default([]) List<PlannedBlock> plannedBlocks,

    /// References to tasks pinned to categories
    @Default([]) List<PinnedTaskRef> pinnedTasks,
  }) = _DayPlanData;

  factory DayPlanData.fromJson(Map<String, dynamic> json) =>
      _$DayPlanDataFromJson(json);
}

/// Derived time budget for a category, computed from planned blocks.
class DerivedTimeBudget {
  DerivedTimeBudget({
    required this.categoryId,
    required this.plannedDuration,
    required this.blocks,
  });

  final String categoryId;
  final Duration plannedDuration;
  final List<PlannedBlock> blocks;

  int get plannedMinutes => plannedDuration.inMinutes;
}

/// Extension methods for DayPlanData.
extension DayPlanDataX on DayPlanData {
  /// Get all unique category IDs that have planned blocks.
  Set<String> get categoryIds =>
      plannedBlocks.map((block) => block.categoryId).toSet();

  /// Get planned blocks for a specific category, sorted by start time.
  List<PlannedBlock> blocksForCategory(String categoryId) =>
      plannedBlocks.where((block) => block.categoryId == categoryId).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// Get total planned duration for a specific category.
  Duration plannedDurationForCategory(String categoryId) =>
      blocksForCategory(categoryId).fold(
        Duration.zero,
        (total, block) => total + block.duration,
      );

  /// Get derived time budgets for all categories with blocks.
  List<DerivedTimeBudget> get derivedBudgets {
    final budgets = <DerivedTimeBudget>[];
    for (final categoryId in categoryIds) {
      final blocks = blocksForCategory(categoryId);
      final duration = blocks.fold(
        Duration.zero,
        (total, block) => total + block.duration,
      );
      budgets.add(DerivedTimeBudget(
        categoryId: categoryId,
        plannedDuration: duration,
        blocks: blocks,
      ));
    }
    // Sort by earliest block start time
    budgets.sort((a, b) {
      if (a.blocks.isEmpty) return 1;
      if (b.blocks.isEmpty) return -1;
      return a.blocks.first.startTime.compareTo(b.blocks.first.startTime);
    });
    return budgets;
  }

  /// Total planned duration across all blocks.
  Duration get totalPlannedDuration => plannedBlocks.fold(
        Duration.zero,
        (total, block) => total + block.duration,
      );

  /// Get pinned tasks for a specific category.
  List<PinnedTaskRef> pinnedTasksForCategory(String categoryId) =>
      pinnedTasks.where((ref) => ref.categoryId == categoryId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Whether this plan has been agreed to.
  bool get isAgreed => status is DayPlanStatusAgreed;

  /// Whether this plan needs review.
  bool get needsReview => status is DayPlanStatusNeedsReview;

  /// Whether this plan is still a draft.
  bool get isDraft => status is DayPlanStatusDraft;

  /// Whether the day has been marked complete.
  bool get isComplete => completedAt != null;

  /// Find a block by ID.
  PlannedBlock? blockById(String id) {
    for (final block in plannedBlocks) {
      if (block.id == id) return block;
    }
    return null;
  }
}
