import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
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
    this.expandedFoldRegions = const {},
  });

  final DateTime selectedDate;
  final DayPlanEntry? dayPlan;
  final List<TimeBudgetProgress> budgetProgress;
  final DailyTimelineData timelineData;
  final DailyOsSection? expandedSection;
  final bool isEditingPlan;

  /// Currently highlighted category ID for cross-component communication.
  final String? highlightedCategoryId;

  /// Set of startHour values for timeline fold regions that are expanded.
  /// By default, all regions are collapsed (folded).
  final Set<int> expandedFoldRegions;

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
    Set<int>? expandedFoldRegions,
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
      expandedFoldRegions: expandedFoldRegions ?? this.expandedFoldRegions,
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
/// Uses the UnifiedDailyOsDataController for data that auto-updates when
/// entries are created or synced.
@riverpod
class DailyOsController extends _$DailyOsController {
  @override
  Future<DailyOsState> build() async {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);

    // Watch the unified controller which handles all data fetching
    // and auto-updates via stream subscription
    final unifiedData = await ref.watch(
      unifiedDailyOsDataControllerProvider(date: selectedDate).future,
    );

    return DailyOsState(
      selectedDate: selectedDate,
      dayPlan: unifiedData.dayPlan,
      budgetProgress: unifiedData.budgetProgress,
      timelineData: unifiedData.timelineData,
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

  /// Toggles a fold region between expanded and collapsed states.
  ///
  /// The [startHour] identifies which compressed region to toggle.
  void toggleFoldRegion(int startHour) {
    final current = state.value;
    if (current == null) return;

    final updatedRegions = {...current.expandedFoldRegions};
    if (updatedRegions.contains(startHour)) {
      updatedRegions.remove(startHour);
    } else {
      updatedRegions.add(startHour);
    }

    state = AsyncData(current.copyWith(expandedFoldRegions: updatedRegions));
  }

  /// Resets all fold regions to collapsed state.
  void resetFoldState() {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(expandedFoldRegions: {}));
  }
}

/// Provides just the highlighted category ID for efficient rebuilds.
@riverpod
String? highlightedCategoryId(Ref ref) {
  final controllerAsync = ref.watch(dailyOsControllerProvider);
  return controllerAsync.value?.highlightedCategoryId;
}

/// Provides just the expanded fold regions for efficient rebuilds.
@riverpod
Set<int> expandedFoldRegions(Ref ref) {
  final controllerAsync = ref.watch(dailyOsControllerProvider);
  return controllerAsync.value?.expandedFoldRegions ?? {};
}

/// Provides the active focus category ID based on the current time.
///
/// Returns the category ID of the planned block that the current time
/// falls within on TODAY's schedule, or null if there's no active block.
/// This is used for the "Focus First" UX where only the currently active
/// category is expanded and all others are collapsed.
///
/// The active category persists even when viewing historical or future dates,
/// since it always checks TODAY's schedule regardless of the selected date.
///
/// Re-evaluates every 15 seconds to keep the focus state reasonably current
/// without excessive resource usage. Handles midnight crossings by
/// recalculating "today" on each iteration.
@riverpod
Stream<String?> activeFocusCategoryId(Ref ref) async* {
  // Track the current date to detect midnight crossings
  final currentDate = clock.now().dayAtMidnight;

  // Establish initial dependency on today's unified data
  ref.watch(unifiedDailyOsDataControllerProvider(date: currentDate));

  while (true) {
    final now = clock.now();
    final today = now.dayAtMidnight;

    // Handle midnight crossing: if the date changed, invalidate self to
    // re-establish the dependency on the new day's data provider
    if (today != currentDate) {
      ref.invalidateSelf();
      return;
    }

    // Use ref.read inside the loop for fresh data reads
    final todayData = ref.read(
      unifiedDailyOsDataControllerProvider(date: today),
    );

    final result = todayData.whenOrNull(
      data: (data) {
        // Find the planned block that contains the current time
        for (final slot in data.timelineData.plannedSlots) {
          if (!now.isBefore(slot.startTime) && now.isBefore(slot.endTime)) {
            return slot.categoryId;
          }
        }

        return null;
      },
    );

    yield result;

    await Future<void>.delayed(const Duration(seconds: 15));
  }
}

/// Provides the category ID of the currently running timer.
///
/// Returns the category ID (from linkedFrom or the entry itself) when a timer
/// is actively running, or null when no timer is running.
/// Used for visual indicators in the UI (e.g., showing a timer icon).
@riverpod
class RunningTimerCategoryId extends _$RunningTimerCategoryId {
  late TimeService _timeService;
  StreamSubscription<JournalEntity?>? _subscription;

  @override
  String? build() {
    _timeService = getIt<TimeService>();
    ref.onDispose(() => _subscription?.cancel());
    _listen();
    return _getCurrentCategoryId();
  }

  void _listen() {
    _subscription = _timeService.getStream().listen((_) {
      state = _getCurrentCategoryId();
    });
  }

  String? _getCurrentCategoryId() {
    final current = _timeService.getCurrent();
    if (current == null) return null;

    final linkedFrom = _timeService.linkedFrom;
    return linkedFrom?.meta.categoryId ?? current.meta.categoryId;
  }
}
