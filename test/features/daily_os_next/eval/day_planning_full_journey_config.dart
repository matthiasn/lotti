const fullJourneyDefaultModelIds = ['glm-5.2'];
const fullJourneyDefaultDate = '2030-01-15';

List<String> parseFullJourneyCsv(String? raw) => (raw ?? '')
    .split(',')
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toList();

List<String> fullJourneyModelIds(String? raw) {
  final parsed = parseFullJourneyCsv(raw);
  return parsed.isEmpty ? fullJourneyDefaultModelIds : parsed;
}

DateTime fullJourneyEvaluationDate(String? raw) {
  final value = raw?.trim();
  final selected = value == null || value.isEmpty
      ? fullJourneyDefaultDate
      : value;
  final parsed = DateTime.tryParse(selected);
  if (parsed == null ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(selected) ||
      _dateOnly(parsed) != selected) {
    throw FormatException(
      'DAY_PLANNING_EVAL_DATE must be a real calendar date in YYYY-MM-DD '
      'format; got "$selected".',
    );
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime fullJourneyClockValue({
  required DateTime evaluationDate,
  required int startHour,
  required Duration elapsed,
}) {
  final timeOfDay = DateTime.utc(2000, 1, 1, startHour).add(elapsed);
  return DateTime(
    evaluationDate.year,
    evaluationDate.month,
    evaluationDate.day,
    timeOfDay.hour,
    timeOfDay.minute,
    timeOfDay.second,
    timeOfDay.millisecond,
    timeOfDay.microsecond,
  );
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
