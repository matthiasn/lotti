final _timezoneSuffix = RegExp(r'([Zz]|[+-]\d{2}:?\d{2})$');
final _localTimestamp = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})'
  r'(?::(\d{2})(?:\.\d{1,6})?)?$',
);

/// Parses only local ISO 8601 timestamps with an explicit time component.
///
/// Rejects date-only values and timezone-qualified strings because the
/// time-entry feature uses local wall-clock semantics end-to-end.
DateTime? parseTimeEntryLocalDateTime(String raw) {
  if (!raw.contains('T') || _timezoneSuffix.hasMatch(raw)) {
    return null;
  }

  final match = _localTimestamp.firstMatch(raw);
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6) ?? '0');

  if (month < 1 || month > 12) return null;
  if (day < 1 || day > _daysInMonth(year, month)) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;

  return DateTime.tryParse(raw);
}

/// Formats a wall-clock time as `HH:mm`.
String formatTimeEntryHhMm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
