import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

void main() {
  final day = DateTime.utc(2026, 8, 11);

  group('DayMark.successful', () {
    test('a recorded verdict outranks the measured state', () {
      expect(
        DayMark(
          day: day,
          state: DayMarkState.full,
          verdict: DayVerdict.missed,
        ).successful,
        isFalse,
        reason: 'a day filed as missed is not a success, however it measured',
      );
      expect(
        DayMark(
          day: day,
          state: DayMarkState.none,
          verdict: DayVerdict.met,
        ).successful,
        isTrue,
      );
      for (final verdict in [DayVerdict.improving, DayVerdict.mixed]) {
        expect(
          DayMark(
            day: day,
            state: DayMarkState.full,
            verdict: verdict,
          ).successful,
          isFalse,
          reason: '$verdict is not arrival',
        );
      }
    });

    test('without a verdict, only kept days count', () {
      expect(
        {
          for (final state in DayMarkState.values)
            state: DayMark(day: day, state: state).successful,
        },
        {
          DayMarkState.none: false,
          DayMarkState.partial: true,
          DayMarkState.full: true,
          DayMarkState.skipped: false,
          DayMarkState.missed: false,
        },
      );
    });
  });

  test('value equality covers every field', () {
    const a = DayMark(state: DayMarkState.full);
    const b = DayMark(state: DayMarkState.full);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(DayMark(day: day, state: DayMarkState.full)));
    expect(a, isNot(const DayMark(state: DayMarkState.partial)));
    expect(
      a,
      isNot(const DayMark(state: DayMarkState.full, verdict: DayVerdict.met)),
    );
    expect(
      a,
      isNot(
        const DayMark(
          state: DayMarkState.full,
          verdictProvenance: DayVerdictProvenance.ratedByUser,
        ),
      ),
    );
    expect(a, isNot(const DayMark(state: DayMarkState.full, isToday: true)));
    expect(a.toString(), contains('DayMarkState.full'));
  });

  test('verdict names are the persisted wire format and must not change', () {
    expect(DayVerdict.values.map((v) => v.name), [
      'met',
      'improving',
      'mixed',
      'missed',
    ]);
    expect(DayVerdictProvenance.values.map((v) => v.name), [
      'ratedByUser',
      'suggestedAndAccepted',
    ]);
  });
}
