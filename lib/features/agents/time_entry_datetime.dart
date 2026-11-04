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

/// The one spelling of an accepted local timestamp: `yyyy-MM-ddTHH:mm:ss`,
/// with a fraction only when it is not zero — so `T09:00`, `T09:00:00` and
/// `T09:00:00.0` all become `T09:00:00` and compare equal as strings.
///
/// Returns [raw] unchanged when it is not an accepted timestamp, leaving the
/// rejection to whoever validates it.
String canonicalTimeEntryLocalDateTime(String raw) {
  final parsed = parseTimeEntryLocalDateTime(raw);
  if (parsed == null) return raw;
  String two(int value) => value.toString().padLeft(2, '0');
  final base =
      '${parsed.year.toString().padLeft(4, '0')}-${two(parsed.month)}-'
      '${two(parsed.day)}T${two(parsed.hour)}:${two(parsed.minute)}:'
      '${two(parsed.second)}';
  final micros = parsed.millisecond * 1000 + parsed.microsecond;
  return micros == 0 ? base : '$base.${micros.toString().padLeft(6, '0')}';
}

/// Formats a wall-clock time as `HH:mm`.
String formatTimeEntryHhMm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
