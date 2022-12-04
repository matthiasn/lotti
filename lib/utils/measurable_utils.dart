import 'package:lotti/classes/journal_entities.dart';

List<num> rankedByPopularity({
  required List<JournalEntity>? measurements,
  int n = 3,
}) {
  final countMeasurementsMap = <num, int>{};

  if (measurements == null) {
    return [];
  }

  for (final entry in measurements) {
    entry.maybeMap(
      measurement: (measurement) {
        final value = measurement.data.value;
        final prevCounter = countMeasurementsMap[value] ?? 0;
        countMeasurementsMap[value] = prevCounter + 1;
      },
      orElse: () {},
    );
  }

  final ranked = countMeasurementsMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ranked.map((item) => item.key).take(n).toList();
}
