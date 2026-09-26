import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/components/time_pickers/time_wheel_rollover.dart';

void main() {
  group('timeWheelHourFrom24 / timeWheelHourTo24', () {
    test('12-hour rows put midnight and noon on the "12" row', () {
      expect(
        timeWheelHourFrom24(0, use24h: false),
        (hourIndex: 11, periodIndex: 0),
      );
      expect(
        timeWheelHourFrom24(12, use24h: false),
        (hourIndex: 11, periodIndex: 1),
      );
      expect(
        timeWheelHourFrom24(13, use24h: false),
        (hourIndex: 0, periodIndex: 1),
      );
      expect(
        timeWheelHourFrom24(14, use24h: true),
        (hourIndex: 14, periodIndex: 0),
      );
    });

    test('every hour of the day round-trips in both formats', () {
      for (final use24h in [true, false]) {
        for (var hour = 0; hour < 24; hour++) {
          final wheel = timeWheelHourFrom24(hour, use24h: use24h);
          expect(
            timeWheelHourTo24(wheel, use24h: use24h),
            hour,
            reason: 'hour $hour, use24h $use24h',
          );
        }
      }
    });
  });

  group('rollTimeWheelHour', () {
    test('rolls back across noon and midnight on a 12-hour wheel', () {
      // 12 PM back one hour is 11 AM.
      expect(
        rollTimeWheelHour(
          (hourIndex: 11, periodIndex: 1),
          -1,
          use24h: false,
        ),
        (hourIndex: 10, periodIndex: 0),
      );
      // 12 AM back one hour is 11 PM.
      expect(
        rollTimeWheelHour(
          (hourIndex: 11, periodIndex: 0),
          -1,
          use24h: false,
        ),
        (hourIndex: 10, periodIndex: 1),
      );
      // 11 AM forward one hour is 12 PM.
      expect(
        rollTimeWheelHour(
          (hourIndex: 10, periodIndex: 0),
          1,
          use24h: false,
        ),
        (hourIndex: 11, periodIndex: 1),
      );
    });

    test('wraps around midnight on a 24-hour wheel', () {
      expect(
        rollTimeWheelHour((hourIndex: 0, periodIndex: 0), -1, use24h: true),
        (hourIndex: 23, periodIndex: 0),
      );
      expect(
        rollTimeWheelHour((hourIndex: 23, periodIndex: 0), 1, use24h: true),
        (hourIndex: 0, periodIndex: 0),
      );
    });

    glados.Glados2(
      glados.any.intInRange(0, 24),
      glados.any.intInRange(-100, 100),
      glados.ExploreConfig(numRuns: 200),
    ).test('moves the hour of day by exactly the requested hours', (
      hour,
      hours,
    ) {
      for (final use24h in [true, false]) {
        final start = timeWheelHourFrom24(hour, use24h: use24h);
        final rolled = rollTimeWheelHour(start, hours, use24h: use24h);
        expect(timeWheelHourTo24(rolled, use24h: use24h), (hour + hours) % 24);
        expect(rollTimeWheelHour(rolled, -hours, use24h: use24h), start);
      }
    }, tags: 'glados');
  });

  group('wheelWrapBetween', () {
    test('reports the minute drum crossing the hour in either direction', () {
      expect(wheelWrapBetween(0, 59, 60), -1);
      expect(wheelWrapBetween(59, 0, 60), 1);
      expect(wheelWrapBetween(2, 57, 60), -1);
      expect(wheelWrapBetween(19, 18, 60), 0);
      expect(wheelWrapBetween(58, 59, 60), 0);
    });

    glados.Glados2(
      glados.any.intInRange(0, 60),
      glados.any.intInRange(-29, 30),
      glados.ExploreConfig(numRuns: 200),
    ).test('matches the turn a less-than-half-turn step lands in', (
      from,
      step,
    ) {
      final expectedWrap = from + step < 0
          ? -1
          : from + step >= 60
          ? 1
          : 0;
      expect(wheelWrapBetween(from, (from + step) % 60, 60), expectedWrap);
    }, tags: 'glados');
  });

  group('shortestWheelDelta', () {
    glados.Glados2(
      glados.any.intInRange(0, 24),
      glados.any.intInRange(0, 24),
      glados.ExploreConfig(numRuns: 200),
    ).test('lands on the target within half a turn', (from, to) {
      final delta = shortestWheelDelta(from, to, 24);
      expect((from + delta) % 24, to);
      expect(delta.abs(), lessThanOrEqualTo(12));
    }, tags: 'glados');
  });

  group('TimeWheelColumnDriver', () {
    late List<int> selected;
    late List<(int, int)> wraps;

    TimeWheelColumnDriver driver({bool looping = true, int initial = 0}) {
      selected = [];
      wraps = [];
      return TimeWheelColumnDriver(
        itemCount: 60,
        initialIndex: initial,
        looping: looping,
        onSelectedIndexChanged: selected.add,
        onWrapped: (index, direction) => wraps.add((index, direction)),
      );
    }

    test('reports a wrapping row once, together with its direction', () {
      final column = driver()
        ..handleSelectedItemChanged(59)
        ..handleSelectedItemChanged(58)
        ..handleSelectedItemChanged(59)
        ..handleSelectedItemChanged(0);
      addTearDown(column.dispose);

      expect(wraps, [(59, -1), (0, 1)]);
      // Wrapping rows go only to onWrapped, never also as a plain change.
      expect(selected, [58, 59]);
      expect(column.selectedIndex.value, 0);
    });

    test('without onWrapped a wrapping row is a plain change', () {
      final column = TimeWheelColumnDriver(
        itemCount: 60,
        initialIndex: 0,
        onSelectedIndexChanged: (selected = []).add,
      )..handleSelectedItemChanged(59);
      addTearDown(column.dispose);

      expect(selected, [59]);
    });

    test('normalizes an absolute index without inventing a wrap', () {
      final column = driver(initial: 30)..handleSelectedItemChanged(12035);
      addTearDown(column.dispose);

      expect(column.selectedIndex.value, 35);
      expect(selected, [35]);
      expect(wraps, isEmpty);
    });

    test('a non-looping column never wraps and stops at its ends', () {
      final column = driver(looping: false)..handleSelectedItemChanged(59);
      addTearDown(column.dispose);

      expect(wraps, isEmpty);
      expect(column.indexFor(1), isNull);
      expect(column.indexFor(-59), 0);
      expect(column.indexFor(-60), isNull);
    });
  });
}
