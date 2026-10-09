import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon.dart';

/// English, as people say it when they tell someone how a conversation went.
const englishCheckInLexicon = _EnglishCheckInLexicon();

/// `‹` and `›` stand for a word boundary that knows letters beyond ASCII.
RegExp _re(String pattern) => RegExp(
  pattern
      .replaceAll('‹', r'(?<![\p{L}\p{N}])')
      .replaceAll('›', r'(?![\p{L}\p{N}])'),
  unicode: true,
);

/// One phrase from [phrases] (regex alternatives), as a whole word or words.
RegExp _anyOf(List<String> phrases) => _re('‹(?:${phrases.join('|')})›');

const Map<String, num> _numbers = {
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'fifteen': 15,
  'twenty': 20,
  'twenty-five': 25,
  'twenty five': 25,
  'thirty': 30,
  'forty': 40,
  'forty-five': 45,
  'forty five': 45,
  'fifty': 50,
  'sixty': 60,
  'ninety': 90,
};

/// The hours a clock is read in, as words.
const Map<String, num> _hourWords = {
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
};

final String _num = '(\\d+(?:[.,]\\d+)?|${spokenNumberAlternation(_numbers)})';
final String _hourWord = '(\\d{1,2}|${spokenNumberAlternation(_hourWords)})';
const _hours = '(?:hours?|hrs?)';
const _minutes = '(?:minutes?|mins?)';
const _gap = r'(?:\s+|-)';

/// Each length rule: its pattern and how a match becomes a length. Ordered
/// most specific first; a later rule never reads what an earlier one did.
final List<(RegExp, Duration? Function(RegExpMatch))> _lengthRules = [
  (
    _re(
      '‹$_num${_gap}and$_gap(a half|a quarter|three quarters)$_gap$_hours›',
    ),
    (m) => _hoursPlus(m[1]!, m[2]!),
  ),
  (
    _re('‹$_num\\s+$_hours\\s+and\\s+(a half|a quarter)›'),
    (m) => _hoursPlus(m[1]!, m[2]!),
  ),
  (
    _re('‹$_num\\s+$_hours\\s+(?:and\\s+)?$_num\\s+$_minutes›'),
    (m) {
      final hours = parseSpokenNumber(m[1]!, _numbers);
      final minutes = parseSpokenNumber(m[2]!, _numbers);
      if (hours == null || minutes == null) return null;
      return spokenLength(hours, 60) + spokenLength(minutes, 1);
    },
  ),
  (_re('‹three quarters of an hour›'), (_) => const Duration(minutes: 45)),
  (
    _re('‹(?:half an hour|a half[- ]hour|half[- ]hour)›'),
    (_) => const Duration(minutes: 30),
  ),
  (
    _re('‹(?:a quarter (?:of an )?hour|quarter of an hour|quarter[- ]hour)›'),
    (_) => const Duration(minutes: 15),
  ),
  (_re('‹$_num$_gap$_hours›'), (m) => _amount(m[1]!, 60)),
  (_re('‹$_num$_gap$_minutes›'), (m) => _amount(m[1]!, 1)),
];

Duration? _amount(String token, int unitMinutes) {
  final amount = parseSpokenNumber(token, _numbers);
  return amount == null ? null : spokenLength(amount, unitMinutes);
}

Duration? _hoursPlus(String token, String fraction) {
  final hours = parseSpokenNumber(token, _numbers);
  if (hours == null) return null;
  final extra = switch (fraction.replaceAll(RegExp(r'\s+'), ' ')) {
    'a half' => 30,
    'a quarter' => 15,
    _ => 45,
  };
  return spokenLength(hours, 60) + Duration(minutes: extra);
}

/// Words before a length that make it a when, not a how long.
final RegExp _lengthNotBefore = _re(
  r'‹(?:in|within|every|each|per)\s+'
  r'(?:(?:about|around|roughly|maybe|approximately|like|almost|nearly)\s+)?$',
);

/// Words after a length that make it a when, not a how long.
final RegExp _lengthNotAfter = _re(
  r'^\s+(?:ago|late|early|later|earlier|before|after|behind|from now)›',
);

const _meridiem = r'(a\.?\s?m\.?|p\.?\s?m\.?)';
const _clockUnitsAfter =
    r'(?!\s*(?:[:.]\d|minutes?|mins?|hours?|hrs?|people|persons|times|'
    'of|points?|years?|days?|weeks?|months?|percent|%|euros?|dollars?))';

CheckInMeridiem? _meridiemOf(String? token) {
  if (token == null) return null;
  return token.startsWith('a') ? CheckInMeridiem.am : CheckInMeridiem.pm;
}

CheckInClockMention? _clock(
  String hourToken,
  String? minuteToken, {
  String? meridiem,
}) {
  final hour = parseSpokenNumber(hourToken, _hourWords);
  if (hour == null || hour != hour.roundToDouble()) return null;
  final minute = minuteToken == null ? 0 : int.parse(minuteToken);
  final clock = CheckInClockMention(
    hour.toInt(),
    minute: minute,
    meridiem: _meridiemOf(meridiem),
    twentyFourHour: hourToken.length == 2 && hourToken.startsWith('0'),
  );
  return clock.isValid ? clock : null;
}

const _clockToken = '(\\d{1,2})(?:[:.](\\d{2}))?\\s*$_meridiem?';
final RegExp _rangeRule = _re(
  '‹(?:from|between)\\s+$_clockToken\\s*(?:to|until|till|and|-)\\s*'
  '$_clockToken(?![\\p{L}\\p{N}])',
);
final RegExp _meridiemRule = _re(
  '‹(\\d{1,2})(?:[:.](\\d{2}))?\\s*$_meridiem(?![\\p{L}\\p{N}])',
);
final RegExp _colonRule = _re(
  r'‹(?:at|around|about|by|since|approximately)\s+(\d{1,2})[:.](\d{2})›'
  '$_clockUnitsAfter',
);
final RegExp _digitHourRule = _re(
  r"‹(?:at|around|about|by|since)\s+(\d{1,2})(?:\s*o'?clock)?›"
  '$_clockUnitsAfter',
);
final RegExp _wordHourRule = _re(
  '‹at\\s+${_hourWord.replaceFirst(r'\d{1,2}|', '')}'
  r"(?:\s+o'?clock›|(?=\s*(?:[,.;!?]|$|in the|this|today|yesterday)))",
);
final RegExp _pastRule = _re('‹(half|quarter)\\s+past\\s+$_hourWord›');
final RegExp _toRule = _re('‹quarter\\s+to\\s+$_hourWord›');
final RegExp _noonRule = _re(r'‹(?:at\s+)?(noon|midday|midnight)›');

final _dayRules = <(RegExp, int, CheckInDayPeriod?)>[
  (_re('‹the day before yesterday›'), 2, null),
  (_re('‹last night›'), 1, CheckInDayPeriod.evening),
  (
    _re(r'‹yesterday\s+(?:morning|afternoon|evening)›'),
    1,
    null,
  ),
  (_re('‹yesterday›'), 1, null),
  (_re('‹tonight›'), 0, CheckInDayPeriod.evening),
  (_re(r'‹this\s+(?:morning|afternoon|evening)›'), 0, null),
  (_re('‹today›'), 0, null),
  (_re('‹tomorrow›'), -1, null),
];

final _periodRules = <(RegExp, CheckInDayPeriod)>[
  (_re('‹morning›'), CheckInDayPeriod.morning),
  (_re('‹afternoon›'), CheckInDayPeriod.afternoon),
  (_re('‹(?:evening|tonight|last night)›'), CheckInDayPeriod.evening),
];

/// Channel phrases, in the order they claim their words: FaceTime audio
/// before FaceTime, any video phrase before the "call" inside it.
final _channelRules = <(RegExp, CheckInInteractionType)>[
  (_re(r'‹facetime(?:\s|-)audio›'), CheckInInteractionType.call),
  (
    _anyOf([
      r'video(?:\s|-)?(?:calls?|chat(?:ted)?|called)',
      'videocall(?:ed)?',
      r'(?:on|via|over)\s+(?:video|zoom|facetime|teams|skype|webex|google meet)',
      r'(?:zoom|facetime|teams|skype|webex)(?:\s|-)(?:call|meeting)',
      'facetimed',
      'google meet',
    ]),
    CheckInInteractionType.videoCall,
  ),
  (
    _anyOf([
      'called',
      'phoned',
      'rang',
      'telephoned',
      r'(?:phone|voice|audio|whatsapp|signal|telegram)(?:\s|-)?calls?',
      r'(?:on|over)\s+the\s+phone',
      r'by\s+phone',
      r'(?:a|the|our|this|that|quick|short|long|brief|good|nice|great)\s+call',
      r'call\s+with',
    ]),
    CheckInInteractionType.call,
  ),
  (
    _anyOf([
      r'in(?:\s|-)person',
      r'face(?:\s|-)to(?:\s|-)face',
      r'met\s+up',
      r'we\s+met',
      r'met\s+(?:with|for|at)',
      r'(?:had|grabbed|got)\s+(?:a\s+)?(?:coffee|lunch|dinner|breakfast|drinks?|beers?)',
      r'visited\s+(?:her|him|them|me|us)',
      r'came\s+over',
      r'went\s+over',
    ]),
    CheckInInteractionType.inPerson,
  ),
];

class _EnglishCheckInLexicon extends CheckInDictationLexicon {
  const _EnglishCheckInLexicon();

  @override
  CheckInDictationReading read(String text) {
    final durations = <Duration>[];
    final lengthClaims = SpanClaims();
    for (final (pattern, toLength) in _lengthRules) {
      lengthClaims.each(pattern, text, (match) {
        final before = text.substring(0, match.start);
        final after = text.substring(match.end);
        final length = toLength(match);
        if (length != null &&
            !_lengthNotBefore.hasMatch(before) &&
            !_lengthNotAfter.hasMatch(after)) {
          durations.add(length);
        }
        return true;
      });
    }

    final clocks = <CheckInClockMention>[];
    final ranges = <CheckInClockRange>[];
    final clockClaims = SpanClaims()
      ..each(_rangeRule, text, (m) {
        final start = _clock(m[1]!, m[2], meridiem: m[3]);
        final end = _clock(m[4]!, m[5], meridiem: m[6]);
        if (start == null || end == null) return false;
        ranges.add(CheckInClockRange.spoken(start, end));
        return true;
      });
    void addClock(RegExpMatch m, CheckInClockMention? clock) {
      if (clock != null) clocks.add(clock);
    }

    clockClaims
      ..each(_meridiemRule, text, (m) {
        addClock(m, _clock(m[1]!, m[2], meridiem: m[3]));
        return true;
      })
      ..each(_colonRule, text, (m) {
        addClock(m, _clock(m[1]!, m[2]));
        return true;
      })
      ..each(_pastRule, text, (m) {
        final hour = _clock(m[2]!, null);
        addClock(
          m,
          hour == null
              ? null
              : CheckInClockMention(
                  hour.hour,
                  minute: m[1] == 'half' ? 30 : 15,
                ),
        );
        return true;
      })
      ..each(_toRule, text, (m) {
        final hour = _clock(m[1]!, null);
        addClock(
          m,
          hour == null
              ? null
              : CheckInClockMention(
                  hour.hour == 1 ? 12 : hour.hour - 1,
                  minute: 45,
                ),
        );
        return true;
      })
      ..each(_noonRule, text, (m) {
        clocks.add(
          CheckInClockMention(
            m[1] == 'midnight' ? 0 : 12,
            twentyFourHour: true,
          ),
        );
        return true;
      })
      ..each(_digitHourRule, text, (m) {
        addClock(m, _clock(m[1]!, null));
        return true;
      })
      ..each(_wordHourRule, text, (m) {
        addClock(m, _clock(m[1]!, null));
        return true;
      });

    final dayOffsets = <int>{};
    final periods = <CheckInDayPeriod>{};
    final dayClaims = SpanClaims();
    for (final (pattern, offset, period) in _dayRules) {
      dayClaims.each(pattern, text, (_) {
        dayOffsets.add(offset);
        if (period != null) periods.add(period);
        return true;
      });
    }
    for (final (pattern, period) in _periodRules) {
      if (pattern.hasMatch(text)) periods.add(period);
    }

    final channels = <CheckInInteractionType>[];
    final channelClaims = SpanClaims();
    for (final (pattern, channel) in _channelRules) {
      channelClaims.each(pattern, text, (_) {
        channels.add(channel);
        return true;
      });
    }

    return CheckInDictationReading(
      clocks: clocks,
      ranges: ranges,
      durations: durations,
      dayOffsets: dayOffsets,
      periods: periods,
      channels: channels,
    );
  }
}
