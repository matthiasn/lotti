import 'package:flutter/material.dart' show TimeOfDay, immutable;
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:timezone/timezone.dart' as tz;

/// The editable model behind the start/end date-time editor.
///
/// A single source of truth — a [startDate] (day only), a [startTime], an
/// [endTime], and an optional [endDateOverride] for entries that span different
/// days — from which the two timestamps are *derived*. The date is entered once
/// and stamped onto both [dateFrom] and [dateTo]; they can never desync.
///
/// In shared-date mode (`differentDates == false`) an end time earlier than the
/// start time auto-rolls the end to the next day ([overnightAuto]), so a plain
/// cross-midnight entry needs no extra input. Different-dates mode lets the end
/// fall on an arbitrary [endDateOverride] day.
@immutable
class EntryDateTimeRange {
  const EntryDateTimeRange({
    required this.startDate,
    required this.startTime,
    required this.endTime,
    required this.differentDates,
    this.endDateOverride,
  });

  /// Decompose two timestamps into the editor model. Opens in shared-date mode
  /// when ordered bounds fall on the same day, OR form a plain overnight span
  /// (end day is start day + 1 and the end clock is before the start clock) —
  /// that case is reproduced exactly by the auto-roll. Anything else (e.g. an
  /// inverted range, exactly-24h same-clock next-day entry, or multi-day span)
  /// opens in different-dates mode so both absolute endpoints round-trip.
  factory EntryDateTimeRange.fromBounds(DateTime dateFrom, DateTime dateTo) {
    final startDate = dateFrom.dateOnly;
    final startTime = TimeOfDay(hour: dateFrom.hour, minute: dateFrom.minute);
    final endTime = TimeOfDay(hour: dateTo.hour, minute: dateTo.minute);
    final endDate = dateTo.dateOnly;
    final endBeforeStart = _minutes(endTime) < _minutes(startTime);
    final pureOvernight =
        endDate.isSameCalendarDay(startDate.addCalendarDays(1)) &&
        endBeforeStart;
    final differentDates =
        dateTo.isBefore(dateFrom) ||
        (!endDate.isSameCalendarDay(startDate) && !pureOvernight);
    return EntryDateTimeRange(
      startDate: startDate,
      startTime: startTime,
      endTime: endTime,
      differentDates: differentDates,
      endDateOverride: differentDates ? endDate : null,
    );
  }

  final DateTime startDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool differentDates;
  final DateTime? endDateOverride;

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  static DateTime _dateAndTime(DateTime date, TimeOfDay time) {
    if (date is tz.TZDateTime) {
      return tz.TZDateTime(
        date.location,
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }
    return date.isUtc
        ? DateTime.utc(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          )
        : DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
  }

  /// In shared-date mode, whether the end clock falls before the start clock so
  /// the end is auto-rolled to the next day.
  bool get overnightAuto =>
      !differentDates && _minutes(endTime) < _minutes(startTime);

  DateTime get _effectiveEndDate {
    // Defensive: callers that flip [differentDates] on are expected to supply an
    // [endDateOverride], but fall back to the start day rather than crashing if
    // the invariant is ever violated (e.g. a bare copyWith(differentDates: true)).
    if (differentDates) return endDateOverride ?? startDate;
    return overnightAuto ? startDate.addCalendarDays(1) : startDate;
  }

  DateTime get dateFrom => _dateAndTime(startDate, startTime);

  DateTime get dateTo => _dateAndTime(_effectiveEndDate, endTime);

  Duration get duration => dateTo.difference(dateFrom);

  /// The end is never before the start. Always true in shared-date mode (the
  /// auto-roll guarantees it); only reachable in different-dates mode.
  bool get valid => !dateTo.isBefore(dateFrom);

  /// Replaces the complete start endpoint while preserving the absolute end.
  ///
  /// Re-deriving through [EntryDateTimeRange.fromBounds] chooses shared-date,
  /// automatic-overnight, or explicit-end-date mode from the resulting bounds
  /// instead of silently moving the end when the start day changes.
  EntryDateTimeRange withStart(DateTime start) =>
      EntryDateTimeRange.fromBounds(start, dateTo);

  /// Replaces the complete end endpoint while preserving the absolute start.
  ///
  /// This is the endpoint-level operation used by the editor's End Now action:
  /// a historical start stays historical while the end becomes the supplied
  /// timestamp, revealing an explicit end date when the two days differ.
  EntryDateTimeRange withEnd(DateTime end) =>
      EntryDateTimeRange.fromBounds(dateFrom, end);

  EntryDateTimeRange copyWith({
    DateTime? startDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? differentDates,
    DateTime? endDateOverride,
    bool clearOverride = false,
  }) {
    return EntryDateTimeRange(
      startDate: startDate ?? this.startDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      differentDates: differentDates ?? this.differentDates,
      endDateOverride: clearOverride
          ? null
          : (endDateOverride ?? this.endDateOverride),
    );
  }
}
