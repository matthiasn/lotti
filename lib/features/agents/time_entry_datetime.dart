/// Internal dispatch arg used to preserve the originating wake timestamp for
/// deferred `create_time_entry` confirmations.
const timeEntryReferenceTimestampArg = '_referenceTimestamp';

final _timezoneSuffix = RegExp(r'([Zz]|[+-]\d{2}:?\d{2})$');

/// Parses only local ISO 8601 timestamps with an explicit time component.
///
/// Rejects date-only values and timezone-qualified strings because the
/// time-entry feature uses local wall-clock semantics end-to-end.
DateTime? parseTimeEntryLocalDateTime(String raw) {
  if (!raw.contains('T') || _timezoneSuffix.hasMatch(raw)) {
    return null;
  }

  return DateTime.tryParse(raw);
}

/// Formats a wall-clock time as `HH:mm`.
String formatTimeEntryHhMm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';
