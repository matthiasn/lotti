import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon.dart';

/// German, as people say it when they tell someone how a conversation went.
const germanCheckInLexicon = _GermanCheckInLexicon();

/// `‹` and `›` stand for a word boundary that knows umlauts and ß.
RegExp _re(String pattern) => RegExp(
  pattern
      .replaceAll('‹', r'(?<![\p{L}\p{N}])')
      .replaceAll('›', r'(?![\p{L}\p{N}])'),
  unicode: true,
);

/// One phrase from [phrases] (regex alternatives), as a whole word or words.
RegExp _anyOf(List<String> phrases) => _re('‹(?:${phrases.join('|')})›');

const Map<String, num> _numbers = {
  'ein': 1,
  'eine': 1,
  'einer': 1,
  'einen': 1,
  'einem': 1,
  'eins': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fünf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'elf': 11,
  'zwölf': 12,
  'fünfzehn': 15,
  'zwanzig': 20,
  'fünfundzwanzig': 25,
  'dreißig': 30,
  'dreissig': 30,
  'vierzig': 40,
  'fünfundvierzig': 45,
  'fünfzig': 50,
  'sechzig': 60,
  'neunzig': 90,
};

/// The hours a clock is read in, as words.
const Map<String, num> _hourWords = {
  'eins': 1,
  'ein': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fünf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'elf': 11,
  'zwölf': 12,
};

const Map<String, num> _halfHours = {
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fünf': 5,
  'sechs': 6,
};

final String _num = '(\\d+(?:[.,]\\d+)?|${spokenNumberAlternation(_numbers)})';
final String _hourWord = '(\\d{1,2}|${spokenNumberAlternation(_hourWords)})';
const _hours = r'(?:stunden?|std\.?)';
const _minutes = r'(?:minuten?|min\.?)';

final List<(RegExp, Duration? Function(RegExpMatch))> _lengthRules = [
  (
    _re('‹(?:anderthalb|eineinhalb|einundeinhalb)\\s+$_hours›'),
    (_) => const Duration(minutes: 90),
  ),
  (
    _re('‹(${spokenNumberAlternation(_halfHours)})einhalb\\s+$_hours›'),
    (m) => spokenLength(_halfHours[m[1]!]! + 0.5, 60),
  ),
  (
    _re('‹$_num\\s+$_hours\\s+(?:und\\s+)?$_num\\s+$_minutes›'),
    (m) {
      final hours = parseSpokenNumber(m[1]!, _numbers);
      final minutes = parseSpokenNumber(m[2]!, _numbers);
      if (hours == null || minutes == null) return null;
      return spokenLength(hours, 60) + spokenLength(minutes, 1);
    },
  ),
  (
    _re(r'‹(?:eine[rn]?\s+)?dreiviertelstunde›|‹drei\s+viertelstunden›'),
    (_) => const Duration(minutes: 45),
  ),
  (
    _re(r'‹(?:eine[rn]?\s+)?halben?\s+stunde›'),
    (_) => const Duration(minutes: 30),
  ),
  (
    _re(r'‹(?:eine[rn]?\s+)?viertelstunde›'),
    (_) => const Duration(minutes: 15),
  ),
  (_re('‹$_num\\s+$_hours›'), (m) => _amount(m[1]!, 60)),
  (_re('‹$_num\\s+$_minutes›'), (m) => _amount(m[1]!, 1)),
];

Duration? _amount(String token, int unitMinutes) {
  final amount = parseSpokenNumber(token, _numbers);
  return amount == null ? null : spokenLength(amount, unitMinutes);
}

/// Words before a length that make it a when, not a how long: "vor zehn
/// Minuten" was ten minutes ago, "nach einer Stunde" an hour in.
final RegExp _lengthNotBefore = _re(
  r'‹(?:vor|in|nach|alle|seit|binnen|innerhalb)\s+'
  r'(?:(?:etwa|ungefähr|circa|ca\.|knapp|rund|gut)\s+)?$',
);

final RegExp _lengthNotAfter = _re(
  r'^\s+(?:zu\s+spät|zu\s+früh|später|früher|verspätet|her)›',
);

const _clockUnitsAfter =
    r'(?!\s*(?:[:.]\d|minuten?|min|stunden?|std|prozent|%|leute|personen|'
    'mal|jahre?n?|tage?n?|wochen?|monate?n?|euro))';

CheckInClockMention? _clock(String hourToken, String? minuteToken) {
  final hour = parseSpokenNumber(hourToken, _hourWords);
  if (hour == null || hour != hour.roundToDouble()) return null;
  final clock = CheckInClockMention(
    hour.toInt(),
    minute: minuteToken == null ? 0 : int.parse(minuteToken),
    twentyFourHour: hourToken.length == 2 && hourToken.startsWith('0'),
  );
  return clock.isValid ? clock : null;
}

/// "halb drei" is half past two; "viertel vor drei" a quarter to three.
CheckInClockMention? _offsetClock(
  String hourToken,
  int minute, {
  int back = 0,
}) {
  final named = _clock(hourToken, null);
  if (named == null) return null;
  final hour = named.hour - back;
  return CheckInClockMention(hour <= 0 ? hour + 12 : hour, minute: minute);
}

const _clockToken = r'(\d{1,2})(?:[:.](\d{2}))?(?:\s*uhr)?';
final RegExp _rangeRule = _re(
  '‹(?:von|zwischen)\\s+$_clockToken\\s*(?:bis|und|-)\\s*$_clockToken›',
);
final RegExp _umRule = _re(
  '‹um\\s+(\\d{1,2})(?:[:.](\\d{2}))?(?:\\s*uhr)?›$_clockUnitsAfter',
);
final RegExp _uhrRule = _re(
  r'‹(\d{1,2})(?:[:.](\d{2}))?\s*uhr(?:\s+(\d{1,2}))?›',
);
final RegExp _umWordRule = _re(
  '‹um\\s+${_hourWord.replaceFirst(r'\d{1,2}|', '')}(?:\\s+uhr)?›'
  '$_clockUnitsAfter',
);
final RegExp _halbRule = _re('‹(?:um\\s+)?halb\\s+$_hourWord›');
final RegExp _viertelNachRule = _re(
  '‹(?:um\\s+)?viertel\\s+nach\\s+$_hourWord›',
);
final RegExp _viertelVorRule = _re(
  '‹(?:um\\s+)?(?:viertel\\s+vor|dreiviertel)\\s+$_hourWord›',
);
final RegExp _midnightRule = _re(r'‹um\s+mitternacht›');

const _dayParts = '(?:morgen|früh|vormittag|mittag|nachmittag|abend|nacht)';

final _dayRules = <(RegExp, int?, CheckInDayPeriod?)>[
  // Not days at all: a greeting, "in the morning", "every morning".
  (_re(r'‹(?:guten|am|jeden|den)\s+morgen›'), null, CheckInDayPeriod.morning),
  (_re('‹vorgestern(?:\\s+$_dayParts)?›'), 2, null),
  (_re('‹gestern(?:\\s+$_dayParts)?›'), 1, null),
  (_re(r'‹letzte\s+nacht›'), 1, CheckInDayPeriod.evening),
  (_re('‹heute(?:\\s+$_dayParts)?›'), 0, null),
  (_re('‹morgen›'), -1, null),
];

final _periodRules = <(RegExp, CheckInDayPeriod)>[
  (
    _re(
      r'‹(?:heute|gestern|vorgestern)\s+(?:morgen|früh)›|‹(?:morgens|vormittags?)›',
    ),
    CheckInDayPeriod.morning,
  ),
  (_re('‹(?:mittags?|nachmittags?)›'), CheckInDayPeriod.afternoon),
  (_re('‹(?:abends?|nachts?)›'), CheckInDayPeriod.evening),
];

/// Channel phrases, in the order they claim their words.
final _channelRules = <(RegExp, CheckInInteractionType)>[
  (_re(r'‹facetime(?:\s|-)audio›'), CheckInInteractionType.call),
  (
    _anyOf([
      'video(?:call|anruf|chat|telefonat|konferenz|gespräch)',
      'video-?(?:call|anruf)',
      r'(?:per|über|via)\s+video',
      r'(?:über|per|via|auf|mit)\s+(?:zoom|facetime|teams|skype|webex|google meet)',
      '(?:zoom|teams|skype|facetime|webex)-?(?:call|anruf|meeting|konferenz)',
      'gefacetimet',
      'gezoomt',
      'google meet',
    ]),
    CheckInInteractionType.videoCall,
  ),
  (
    _anyOf([
      'angerufen',
      'telefoniert',
      'anruf',
      'telefonat',
      'telefonisch',
      r'(?:am|per|übers|über das)\s+telefon',
      '(?:whatsapp|signal|telegram)-?(?:call|anruf)',
    ]),
    CheckInInteractionType.call,
  ),
  (
    _anyOf([
      'persönlich',
      r'vor\s+ort',
      // "Eine Entscheidung getroffen" made a decision; it met no one.
      r'(?<!(?:entscheidung|entschluss|vereinbarung|abmachung|wahl|auswahl|maßnahmen|vorkehrungen|absprache)\s+(?:\p{L}+\s+)?)getroffen',
      r'(?:trafen|treffen)\s+uns',
      r'(?:auf|zum|zu|beim)\s+(?:einen\s+|einem\s+)?(?:kaffee|mittagessen|abendessen|frühstück|essen|bier)',
      'vorbeigekommen',
      'besucht',
    ]),
    CheckInInteractionType.inPerson,
  ),
];

class _GermanCheckInLexicon extends CheckInDictationLexicon {
  const _GermanCheckInLexicon();

  @override
  CheckInDictationReading read(String text) {
    final durations = <Duration>[];
    final lengthClaims = SpanClaims();
    for (final (pattern, toLength) in _lengthRules) {
      lengthClaims.each(pattern, text, (match) {
        final length = toLength(match);
        if (length != null &&
            !_lengthNotBefore.hasMatch(text.substring(0, match.start)) &&
            !_lengthNotAfter.hasMatch(text.substring(match.end))) {
          durations.add(length);
        }
        return true;
      });
    }

    final clocks = <CheckInClockMention>[];
    final ranges = <CheckInClockRange>[];
    bool add(CheckInClockMention? clock) {
      if (clock != null) clocks.add(clock);
      return true;
    }

    SpanClaims()
      ..each(_rangeRule, text, (m) {
        final start = _clock(m[1]!, m[2]);
        final end = _clock(m[3]!, m[4]);
        if (start == null || end == null) return false;
        ranges.add(CheckInClockRange.spoken(start, end));
        return true;
      })
      ..each(_halbRule, text, (m) => add(_offsetClock(m[1]!, 30, back: 1)))
      ..each(_viertelNachRule, text, (m) => add(_offsetClock(m[1]!, 15)))
      ..each(
        _viertelVorRule,
        text,
        (m) => add(_offsetClock(m[1]!, 45, back: 1)),
      )
      ..each(
        _midnightRule,
        text,
        (_) => add(const CheckInClockMention(0, twentyFourHour: true)),
      )
      ..each(_umRule, text, (m) => add(_clock(m[1]!, m[2])))
      ..each(_uhrRule, text, (m) => add(_clock(m[1]!, m[2] ?? m[3])))
      ..each(_umWordRule, text, (m) => add(_clock(m[1]!, null)));

    final dayOffsets = <int>{};
    final periods = <CheckInDayPeriod>{};
    final dayClaims = SpanClaims();
    for (final (pattern, offset, period) in _dayRules) {
      dayClaims.each(pattern, text, (_) {
        if (offset != null) dayOffsets.add(offset);
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
