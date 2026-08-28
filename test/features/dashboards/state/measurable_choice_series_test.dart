import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/state/measurable_choice_series.dart';

import '../../../test_data/test_data.dart';

void main() {
  final rangeStart = DateTime(2022, 7, 5);
  // Half-open like the numeric aggregators: four days, Jul 5 – Jul 8.
  final rangeEnd = DateTime(2022, 7, 9);

  MeasurementEntry recording(
    String id,
    DateTime at, {
    String? choiceId,
    num value = 1,
  }) => testMeasurementHydrationEntry.copyWith(
    meta: testMeasurementHydrationEntry.meta.copyWith(
      id: id,
      dateFrom: at,
      dateTo: at,
    ),
    data: testMeasurementHydrationEntry.data.copyWith(
      dateFrom: at,
      dateTo: at,
      value: value,
      choiceId: choiceId,
    ),
  );

  test('yields one day per day of the range, in order, empty by default', () {
    final days = choiceDaySeries(
      const [],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    expect(days.map((d) => d.day), [
      DateTime(2022, 7, 5),
      DateTime(2022, 7, 6),
      DateTime(2022, 7, 7),
      DateTime(2022, 7, 8),
    ]);
    expect(days.every((d) => d.choiceId == null), isTrue);
  });

  test('a day keeps its latest recording, by time then by id', () {
    final days = choiceDaySeries(
      [
        recording('a', DateTime(2022, 7, 6, 8), choiceId: hydrationClear.id),
        recording('b', DateTime(2022, 7, 6, 18), choiceId: hydrationDark.id),
        // Same instant: the greater id wins, so replicas agree.
        recording('c', DateTime(2022, 7, 7, 9), choiceId: hydrationPale.id),
        recording('d', DateTime(2022, 7, 7, 9), choiceId: hydrationClear.id),
        // Listed out of order: order of arrival must not matter.
        recording('e', DateTime(2022, 7, 7, 9), choiceId: hydrationDark.id),
      ],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    expect(days[1].choiceId, hydrationDark.id);
    expect(days[2].choiceId, hydrationDark.id);
  });

  test('numeric entries and other entry types never colour a day', () {
    final days = choiceDaySeries(
      [
        recording('n', DateTime(2022, 7, 5, 8), value: 3),
        testTextEntry,
      ],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    expect(days.every((d) => d.choiceId == null), isTrue);
  });

  test('a recording outside the range does not appear', () {
    final days = choiceDaySeries(
      [recording('x', DateTime(2022, 7, 9, 8), choiceId: hydrationClear.id)],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    expect(days.every((d) => d.choiceId == null), isTrue);
  });

  test('an inverted range is empty rather than an error', () {
    expect(
      choiceDaySeries(const [], rangeStart: rangeEnd, rangeEnd: rangeStart),
      isEmpty,
    );
  });
}
