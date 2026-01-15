import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_view_mode_controller.g.dart';

/// View modes for the calendar tab.
enum CalendarViewMode {
  /// Classic calendar view with day/week timeline.
  classic,

  /// Daily Operating System view with budgets and planning.
  dailyOs,
}

/// Controller for the calendar view mode preference.
///
/// This allows users to toggle between the classic calendar view
/// and the new Daily OS view.
@riverpod
class CalendarViewModeController extends _$CalendarViewModeController {
  @override
  CalendarViewMode build() {
    // Default to classic view for now
    // TODO: Persist preference to settings
    return CalendarViewMode.classic;
  }

  /// Toggle between classic and Daily OS views.
  void toggleViewMode() {
    state = state == CalendarViewMode.classic
        ? CalendarViewMode.dailyOs
        : CalendarViewMode.classic;
  }

  /// Set to a specific view mode.
  // ignore: use_setters_to_change_properties
  void setViewMode(CalendarViewMode mode) => state = mode;
}
