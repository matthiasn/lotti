import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The local calendar day currently shown on the Daily OS Next
/// surface. Lifted out of the root widget so external surfaces — the
/// desktop sidebar's month calendar — can drive day selection.
class DailyOsNextSelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Selects the local calendar day containing [day].
  void select(DateTime day) {
    state = DateTime(day.year, day.month, day.day);
  }

  /// Moves the selection by [days] (negative for backwards). Day
  /// arithmetic via the `DateTime` constructor stays DST-safe.
  void shiftDays(int days) {
    state = DateTime(state.year, state.month, state.day + days);
  }

  /// Returns the selection to today.
  void goToToday() {
    final now = clock.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final NotifierProvider<DailyOsNextSelectedDate, DateTime>
dailyOsNextSelectedDateProvider =
    NotifierProvider<DailyOsNextSelectedDate, DateTime>(
      DailyOsNextSelectedDate.new,
    );
