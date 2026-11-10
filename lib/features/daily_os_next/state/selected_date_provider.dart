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
