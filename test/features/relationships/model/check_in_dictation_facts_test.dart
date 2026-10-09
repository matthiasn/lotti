import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_facts.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon.dart';

/// Sunday afternoon, so "this morning" has happened and "at 8 pm" has not.
final _now = DateTime(2026, 3, 15, 16, 30);

CheckInDictationFacts _read(String transcript) =>
    extractCheckInDictationFacts(transcript, now: _now);

void main() {
  group('the spec example', () {
    test('fills start, length and channel from one sentence', () {
      expect(
        _read(
          'Just had a call with Sarah at 3 pm, we talked for about 45 '
          'minutes on video',
        ),
        // "a call" that was "on video" is one video call.
        CheckInDictationFacts(
          startedAt: DateTime(2026, 3, 15, 15),
          duration: const Duration(minutes: 45),
          interactionType: CheckInInteractionType.videoCall,
        ),
      );
    });

    test('a video call is a video call', () {
      expect(
        _read('We had a video call at 3 pm and talked for 45 minutes'),
        CheckInDictationFacts(
          startedAt: DateTime(2026, 3, 15, 15),
          duration: const Duration(minutes: 45),
          interactionType: CheckInInteractionType.videoCall,
        ),
      );
    });
  });

  group('start', () {
    final cases = <String, DateTime?>{
      'we met up at 10 am': DateTime(2026, 3, 15, 10),
      'yesterday at noon': DateTime(2026, 3, 14, 12),
      'at 3:30 pm': DateTime(2026, 3, 15, 15, 30),
      'at 15:30': DateTime(2026, 3, 15, 15, 30),
      'at 08:30': DateTime(2026, 3, 15, 8, 30),
      // Unmarked: 1–7 is the afternoon, 8–12 as said.
      'around 2': DateTime(2026, 3, 15, 14),
      'at nine': DateTime(2026, 3, 15, 9),
      "at nine o'clock": DateTime(2026, 3, 15, 9),
      'this morning at 9': DateTime(2026, 3, 15, 9),
      'this evening at 7': null,
      'yesterday evening at 7': DateTime(2026, 3, 14, 19),
      'last night at 11': DateTime(2026, 3, 14, 23),
      'half past two': DateTime(2026, 3, 15, 14, 30),
      // Today's 4:45 pm is still to come.
      'quarter to five': DateTime(2026, 3, 14, 16, 45),
      // Today's 8 pm is still to come: the most recent one was yesterday.
      'at 8 pm': DateTime(2026, 3, 14, 20),
      'the day before yesterday at 4 pm': DateTime(2026, 3, 13, 16),
      'um 15 Uhr': DateTime(2026, 3, 15, 15),
      'gestern um halb drei': DateTime(2026, 3, 14, 14, 30),
      'heute morgen um 9': DateTime(2026, 3, 15, 9),
      'von 14 bis 15 Uhr': DateTime(2026, 3, 15, 14),
      'from 2 to 3 pm': DateTime(2026, 3, 15, 14),
      'at three pm': DateTime(2026, 3, 15, 15),
      'around eleven a.m.': DateTime(2026, 3, 15, 11),
      // Today's 11 pm is still to come.
      'from 11 pm to 1 am': DateTime(2026, 3, 14, 23),
    };
    for (final MapEntry(key: words, value: expected) in cases.entries) {
      test('"$words" → $expected', () {
        expect(_read(words).startedAt, expected);
      });
    }

    test('a part of the day alone is no start', () {
      expect(_read('we caught up this morning').startedAt, isNull);
      expect(_read('called her yesterday').startedAt, isNull);
    });

    test('a start still to come sets nothing', () {
      expect(_read('today at 6 pm').startedAt, isNull);
      expect(_read('tomorrow at 10 am').startedAt, isNull);
      expect(_read('morgen um 10').startedAt, isNull);
    });

    test('two different starts set nothing', () {
      expect(_read('at 10 am, or maybe at 11 am').startedAt, isNull);
    });

    test('the same start said twice is still that start', () {
      expect(
        _read('at 3 pm, yes, at 3 pm').startedAt,
        DateTime(2026, 3, 15, 15),
      );
    });

    test('a number of things is not a time', () {
      expect(_read('about 5 people came').startedAt, isNull);
      expect(_read('at one point she laughed').startedAt, isNull);
    });
  });

  group('length', () {
    final cases = <String, Duration?>{
      'for 30 minutes': const Duration(minutes: 30),
      'we talked for about 45 minutes': const Duration(minutes: 45),
      'an hour and a half': const Duration(minutes: 90),
      'about two hours': const Duration(hours: 2),
      'two and a half hours': const Duration(minutes: 150),
      'about half an hour': const Duration(minutes: 30),
      'a quarter of an hour': const Duration(minutes: 15),
      'three quarters of an hour': const Duration(minutes: 45),
      'two and a quarter hours': const Duration(minutes: 135),
      'an hour and a quarter': const Duration(minutes: 75),
      '1.5 hours': const Duration(minutes: 90),
      'an hour and 15 minutes': const Duration(minutes: 75),
      'eine halbe Stunde': const Duration(minutes: 30),
      'anderthalb Stunden': const Duration(minutes: 90),
      'zweieinhalb Stunden': const Duration(minutes: 150),
      'etwa 45 Minuten': const Duration(minutes: 45),
      'eine Stunde und zwanzig Minuten': const Duration(minutes: 80),
      'eine Dreiviertelstunde': const Duration(minutes: 45),
      // When, not how long.
      'ten minutes ago': null,
      'she was 20 minutes late': null,
      'in an hour': null,
      'vor zehn Minuten': null,
      // An idiom, not a length.
      'wait a minute': null,
      // Too long to be a check-in.
      'a 20 hours flight': null,
    };
    for (final MapEntry(key: words, value: expected) in cases.entries) {
      test('"$words" → $expected', () {
        expect(_read(words).duration, expected);
      });
    }

    test('a clock range says the length when nothing else does', () {
      expect(_read('from 2 to 3 pm').duration, const Duration(hours: 1));
      expect(
        _read('von 14 bis 15:30 Uhr').duration,
        const Duration(minutes: 90),
      );
      expect(
        _read('from 11 to 1').duration,
        const Duration(hours: 2),
      );
      expect(
        _read('from 11 pm to 1 am').duration,
        const Duration(hours: 2),
        reason: 'a range that crosses midnight ends the next day',
      );
      expect(
        _read('from 11 pm to 1').duration,
        const Duration(hours: 2),
        reason: 'an unmarked end after a pm start is the early hours',
      );
    });

    test('a spoken length outranks the range it sits beside', () {
      expect(
        _read('from 2 to 3 pm, so about 45 minutes really').duration,
        const Duration(minutes: 45),
      );
    });

    test('two different lengths set nothing', () {
      expect(
        _read('we talked for 20 minutes, no, more like an hour').duration,
        isNull,
      );
    });
  });

  group('channel', () {
    final cases = <String, CheckInInteractionType?>{
      'we met up for coffee': CheckInInteractionType.inPerson,
      'saw her in person': CheckInInteractionType.inPerson,
      'had lunch together': CheckInInteractionType.inPerson,
      'she called me': CheckInInteractionType.call,
      'a quick phone call': CheckInInteractionType.call,
      'we talked on the phone': CheckInInteractionType.call,
      'video call': CheckInInteractionType.videoCall,
      'we spoke over zoom': CheckInInteractionType.videoCall,
      'facetimed with my sister': CheckInInteractionType.videoCall,
      'a facetime audio call': CheckInInteractionType.call,
      'wir haben uns persönlich getroffen': CheckInInteractionType.inPerson,
      'sie hat mich angerufen': CheckInInteractionType.call,
      'per Videoanruf': CheckInInteractionType.videoCall,
      'über Zoom gesprochen': CheckInInteractionType.videoCall,
      // Plans and other meanings are no channel.
      'I should call her next week': null,
      'we made a decision': null,
      'wir haben eine Entscheidung getroffen': null,
      // Two channels in one account: left for the user.
      'we met up and later she called me': null,
    };
    for (final MapEntry(key: words, value: expected) in cases.entries) {
      test('"$words" → $expected', () {
        expect(_read(words).interactionType, expected);
      });
    }
  });

  group('CheckInDictationFacts', () {
    test('equals facts with the same fields only, and names them', () {
      final facts = CheckInDictationFacts(
        startedAt: DateTime(2026, 3, 15, 15),
        duration: const Duration(minutes: 45),
        interactionType: CheckInInteractionType.call,
      );
      final same = CheckInDictationFacts(
        startedAt: DateTime(2026, 3, 15, 15),
        duration: const Duration(minutes: 45),
        interactionType: CheckInInteractionType.call,
      );
      expect(facts, same);
      expect(facts.hashCode, same.hashCode);
      expect(
        facts,
        isNot(
          CheckInDictationFacts(
            startedAt: DateTime(2026, 3, 15, 15),
            duration: const Duration(minutes: 45),
          ),
        ),
      );
      expect(
        facts.toString(),
        allOf(contains('15:00'), contains('0:45'), contains('call')),
      );
    });
  });

  group('nothing said', () {
    test('an account with no time, length or channel fills nothing', () {
      expect(
        _read('She told me about the new job and the trip to Lisbon.'),
        CheckInDictationFacts.none,
      );
    });

    test('an empty transcript fills nothing', () {
      expect(_read('   ').isEmpty, isTrue);
    });
  });

  group('languages', () {
    test('a field two languages answer differently is left alone', () {
      final facts = extractCheckInDictationFacts(
        'anything',
        now: _now,
        lexicons: const [
          _FixedLexicon(Duration(minutes: 30)),
          _FixedLexicon(Duration(minutes: 45)),
        ],
      );
      expect(facts.duration, isNull);
    });

    test('languages that agree, or say nothing, keep the answer', () {
      final facts = extractCheckInDictationFacts(
        'anything',
        now: _now,
        lexicons: const [
          _FixedLexicon(Duration(minutes: 30)),
          _FixedLexicon(Duration(minutes: 30)),
          _FixedLexicon(null),
        ],
      );
      expect(facts.duration, const Duration(minutes: 30));
    });
  });

  group('resolveCheckInHour', () {
    test('an explicit meridiem decides', () {
      expect(
        resolveCheckInHour(
          const CheckInClockMention(12, meridiem: CheckInMeridiem.am),
        ),
        0,
      );
      expect(
        resolveCheckInHour(
          const CheckInClockMention(12, meridiem: CheckInMeridiem.pm),
        ),
        12,
      );
      expect(
        resolveCheckInHour(
          const CheckInClockMention(3, meridiem: CheckInMeridiem.pm),
        ),
        15,
      );
    });

    test('a part of the day reads an unmarked hour', () {
      expect(
        resolveCheckInHour(
          const CheckInClockMention(3),
          period: CheckInDayPeriod.morning,
        ),
        3,
      );
      expect(
        resolveCheckInHour(
          const CheckInClockMention(9),
          period: CheckInDayPeriod.evening,
        ),
        21,
      );
    });
  });

  glados.Glados2(
    glados.any.intInRange(0, 24),
    glados.any.intInRange(0, 60),
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'a filled start is never after now and never more than two days back',
    (hour, minute) {
      final words =
          'at ${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
      final start = _read(words).startedAt;
      expect(start, isNotNull, reason: words);
      expect(start!.isAfter(_now.add(const Duration(minutes: 1))), isFalse);
      expect(_now.difference(start), lessThan(const Duration(days: 2)));
      expect(start.hour, hour);
      expect(start.minute, minute);
    },
    tags: 'glados',
  );

  glados.Glados(
    glados.any.intInRange(2, 721),
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'any plausible spoken number of minutes is that length',
    (minutes) {
      expect(
        _read('we talked for $minutes minutes').duration,
        Duration(minutes: minutes),
      );
    },
    tags: 'glados',
  );
}

class _FixedLexicon extends CheckInDictationLexicon {
  const _FixedLexicon(this.duration);

  final Duration? duration;

  @override
  CheckInDictationReading read(String text) => CheckInDictationReading(
    durations: [?duration],
  );
}
