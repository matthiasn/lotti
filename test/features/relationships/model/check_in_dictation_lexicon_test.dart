import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon.dart';

void main() {
  group('CheckInClockMention', () {
    test('is valid only for a time of day', () {
      expect(const CheckInClockMention(23, minute: 59).isValid, isTrue);
      expect(const CheckInClockMention(24).isValid, isFalse);
      expect(const CheckInClockMention(9, minute: 60).isValid, isFalse);
      expect(
        const CheckInClockMention(13, meridiem: CheckInMeridiem.pm).isValid,
        isFalse,
        reason: '"13 pm" names no time',
      );
    });

    test('takes a meridiem only when it has none of its own', () {
      expect(
        const CheckInClockMention(2).withMeridiem(CheckInMeridiem.pm),
        const CheckInClockMention(2, meridiem: CheckInMeridiem.pm),
      );
      expect(
        const CheckInClockMention(
          2,
          meridiem: CheckInMeridiem.am,
        ).withMeridiem(CheckInMeridiem.pm),
        const CheckInClockMention(2, meridiem: CheckInMeridiem.am),
      );
      expect(
        const CheckInClockMention(
          8,
          twentyFourHour: true,
        ).withMeridiem(CheckInMeridiem.pm),
        const CheckInClockMention(8, twentyFourHour: true),
      );
      expect(
        const CheckInClockMention(2).withMeridiem(null),
        const CheckInClockMention(2),
      );
    });

    test('equals a clock with the same fields only', () {
      expect(
        const CheckInClockMention(2, minute: 30),
        const CheckInClockMention(2, minute: 30),
      );
      expect(
        const CheckInClockMention(2, minute: 30).hashCode,
        const CheckInClockMention(2, minute: 30).hashCode,
      );
      expect(
        const CheckInClockMention(2, minute: 30),
        isNot(const CheckInClockMention(2, minute: 30, twentyFourHour: true)),
      );
      expect(const CheckInClockMention(2).toString(), contains('2:0'));
    });
  });

  group('CheckInClockRange.spoken', () {
    test('"from 2 to 3 pm" started at 2 pm', () {
      final range = CheckInClockRange.spoken(
        const CheckInClockMention(2),
        const CheckInClockMention(3, meridiem: CheckInMeridiem.pm),
      );
      expect(range.start.meridiem, CheckInMeridiem.pm);
    });

    test('"from 11 to 1 pm" keeps the start unmarked: 11 pm would end '
        'before it began', () {
      final range = CheckInClockRange.spoken(
        const CheckInClockMention(11),
        const CheckInClockMention(1, meridiem: CheckInMeridiem.pm),
      );
      expect(range.start.meridiem, isNull);
    });
  });

  group('SpanClaims', () {
    test('a later pattern never reads what an earlier one claimed', () {
      const text = 'a video call and a call';
      final seen = <String>[];
      SpanClaims()
        ..each(RegExp('video call'), text, (m) {
          seen.add(m[0]!);
          return true;
        })
        ..each(RegExp('call'), text, (m) {
          seen.add('${m[0]}@${m.start}');
          return true;
        });
      expect(seen, ['video call', 'call@19']);
    });

    test('a match its callback declines stays free for later patterns', () {
      const text = 'from 2 to 3';
      final seen = <String>[];
      SpanClaims()
        ..each(RegExp('from 2 to 3'), text, (_) => false)
        ..each(RegExp(r'\d'), text, (m) {
          seen.add(m[0]!);
          return true;
        });
      expect(seen, ['2', '3']);
    });
  });

  group('spoken numbers', () {
    const words = {'two': 2, 'twenty-five': 25, 'twenty': 20};

    test('digits, decimals and words', () {
      expect(parseSpokenNumber('45', words), 45);
      expect(parseSpokenNumber('1.5', words), 1.5);
      expect(parseSpokenNumber('1,5', words), 1.5);
      expect(parseSpokenNumber('two', words), 2);
      expect(parseSpokenNumber('several', words), isNull);
    });

    test('the alternation tries longer words first', () {
      final pattern = RegExp('^(?:${spokenNumberAlternation(words)})');
      expect(pattern.firstMatch('twenty-five minutes')![0], 'twenty-five');
    });

    test('a length rounds to the whole minute', () {
      expect(spokenLength(1.5, 60), const Duration(minutes: 90));
      expect(spokenLength(0.33, 60), const Duration(minutes: 20));
    });
  });
}
