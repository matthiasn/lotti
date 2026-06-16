import 'package:flutter/material.dart' show TimeOfDay, immutable;

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
  /// when the two fall on the same day, OR form a plain overnight span (end day
  /// is start day + 1 and the end clock is before the start clock) — that case
  /// is reproduced exactly by the auto-roll. Anything else (e.g. an exactly-24h
  /// same-clock next-day entry, or a multi-day span) opens in different-dates
  /// mode.
  factory EntryDateTimeRange.fromBounds(DateTime dateFrom, DateTime dateTo) {
    final startDate = _dateOnly(dateFrom);
    final startTime = TimeOfDay(hour: dateFrom.hour, minute: dateFrom.minute);
    final endTime = TimeOfDay(hour: dateTo.hour, minute: dateTo.minute);
    final endDate = _dateOnly(dateTo);
    final endBeforeStart = _minutes(endTime) < _minutes(startTime);
    final pureOvernight =
        endDate == startDate.add(const Duration(days: 1)) && endBeforeStart;
    final differentDates = endDate != startDate && !pureOvernight;
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

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  /// In shared-date mode, whether the end clock falls before the start clock so
  /// the end is auto-rolled to the next day.
  bool get overnightAuto =>
      !differentDates && _minutes(endTime) < _minutes(startTime);

  DateTime get _effectiveEndDate {
    if (differentDates) return endDateOverride!;
    return overnightAuto ? startDate.add(const Duration(days: 1)) : startDate;
  }

  DateTime get dateFrom => DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
    startTime.hour,
    startTime.minute,
  );

  DateTime get dateTo => DateTime(
    _effectiveEndDate.year,
    _effectiveEndDate.month,
    _effectiveEndDate.day,
    endTime.hour,
    endTime.minute,
  );

  Duration get duration => dateTo.difference(dateFrom);

  /// The end is never before the start. Always true in shared-date mode (the
  /// auto-roll guarantees it); only reachable in different-dates mode.
  bool get valid => !dateTo.isBefore(dateFrom);

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
