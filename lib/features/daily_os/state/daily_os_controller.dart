import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'daily_os_controller.g.dart';

/// UI section of the Daily OS view.
enum DailyOsSection {
  timeline,
  budgets,
  summary,
}

/// Combined state for the Daily OS view.
class DailyOsState {
  const DailyOsState({
    required this.selectedDate,
    required this.dayPlan,
    required this.budgetProgress,
    required this.timelineData,
    this.expandedSection,
    this.isEditingPlan = false,
    this.highlightedCategoryId,
  });

  final DateTime selectedDate;
  final DayPlanEntry? dayPlan;
  final List<TimeBudgetProgress> budgetProgress;
  final DailyTimelineData timelineData;
  final DailyOsSection? expandedSection;
  final bool isEditingPlan;

  /// Currently highlighted category ID for cross-component communication.
  final String? highlightedCategoryId;

  /// Whether the current plan is a draft.
  bool get isDraft => dayPlan?.data.isDraft ?? true;

  /// Whether the plan is agreed.
  bool get isAgreed => dayPlan?.data.isAgreed ?? false;

  /// Whether the plan needs review.
  bool get needsReview => dayPlan?.data.needsReview ?? false;

  /// Whether this is today's plan.
  bool get isToday =>
      selectedDate.dayAtMidnight == DateTime.now().dayAtMidnight;

  /// Total budgeted time for the day.
  Duration get totalBudgetedTime =>
      dayPlan?.data.totalPlannedDuration ?? Duration.zero;

  /// Total recorded time for the day.
  Duration get totalRecordedTime => budgetProgress.fold(
        Duration.zero,
        (total, p) => total + p.recordedDuration,
      );

  /// Number of budgets that are over their limit.
  int get overBudgetCount => budgetProgress.where((p) => p.isOverBudget).length;

  DailyOsState copyWith({
    DateTime? selectedDate,
    DayPlanEntry? dayPlan,
    List<TimeBudgetProgress>? budgetProgress,
    DailyTimelineData? timelineData,
    DailyOsSection? expandedSection,
    bool? isEditingPlan,
    String? highlightedCategoryId,
    bool clearExpandedSection = false,
    bool clearHighlight = false,
  }) {
    return DailyOsState(
      selectedDate: selectedDate ?? this.selectedDate,
      dayPlan: dayPlan ?? this.dayPlan,
      budgetProgress: budgetProgress ?? this.budgetProgress,
      timelineData: timelineData ?? this.timelineData,
      expandedSection: clearExpandedSection
          ? null
          : (expandedSection ?? this.expandedSection),
      isEditingPlan: isEditingPlan ?? this.isEditingPlan,
      highlightedCategoryId: clearHighlight
          ? null
          : (highlightedCategoryId ?? this.highlightedCategoryId),
    );
  }
}

/// Provides the selected date for the Daily OS view.
@riverpod
class DailyOsSelectedDate extends _$DailyOsSelectedDate {
  @override
  DateTime build() {
    return DateTime.now().dayAtMidnight;
  }

  void selectDate(DateTime date) {
    state = date.dayAtMidnight;
  }

  void goToToday() {
    state = DateTime.now().dayAtMidnight;
  }

  void goToPreviousDay() {
    state = state.subtract(const Duration(days: 1));
  }

  void goToNextDay() {
    state = state.add(const Duration(days: 1));
  }
}

/// Main controller for the Daily OS view.
///
/// Combines day plan, budget progress, and timeline data into a unified state.
@riverpod
class DailyOsController extends _$DailyOsController {
  @override
  Future<DailyOsState> build() async {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);

    // Watch all dependencies
    final dayPlanAsync = await ref.watch(
      dayPlanControllerProvider(date: selectedDate).future,
    );

    final budgetProgressAsync = await ref.watch(
      timeBudgetProgressControllerProvider(date: selectedDate).future,
    );

    final timelineDataAsync = await ref.watch(
      timelineDataControllerProvider(date: selectedDate).future,
    );

    return DailyOsState(
      selectedDate: selectedDate,
      dayPlan: dayPlanAsync is DayPlanEntry ? dayPlanAsync : null,
      budgetProgress: budgetProgressAsync,
      timelineData: timelineDataAsync,
    );
  }

  /// Toggles the expanded section.
  void toggleSection(DailyOsSection section) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        expandedSection: current.expandedSection == section ? null : section,
        clearExpandedSection: current.expandedSection == section,
      ),
    );
  }

  /// Sets editing mode for the plan.
  void setEditingPlan({required bool editing}) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isEditingPlan: editing));
  }

  /// Highlights a category across timeline and budget sections.
  ///
  /// Tapping a timeline block or budget card will highlight the related
  /// category in both sections for visual correlation.
  void highlightCategory(String? categoryId) {
    final current = state.value;
    if (current == null) return;

    if (categoryId == null || current.highlightedCategoryId == categoryId) {
      // Clear highlight if same category tapped again or null passed
      state = AsyncData(current.copyWith(clearHighlight: true));
    } else {
      state = AsyncData(current.copyWith(highlightedCategoryId: categoryId));
    }
  }

  /// Clears any category highlighting.
  void clearHighlight() {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(clearHighlight: true));
  }
}

/// Provides just the highlighted category ID for efficient rebuilds.
@riverpod
String? highlightedCategoryId(Ref ref) {
  final controllerAsync = ref.watch(dailyOsControllerProvider);
  return controllerAsync.value?.highlightedCategoryId;
}
