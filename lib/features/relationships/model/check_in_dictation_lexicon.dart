import 'package:flutter/foundation.dart';
import 'package:lotti/classes/check_in_data.dart';

/// Morning or afternoon, when the words say which.
enum CheckInMeridiem { am, pm }

/// The part of the day spoken around a time ("this morning at 9").
enum CheckInDayPeriod { morning, afternoon, evening }

/// A time of day as spoken: [hour] as said (1–12 or 0–23), [minute], and
/// whatever says how to read the hour.
@immutable
class CheckInClockMention {
  const CheckInClockMention(
    this.hour, {
    this.minute = 0,
    this.meridiem,
    this.twentyFourHour = false,
  });

  final int hour;
  final int minute;
  final CheckInMeridiem? meridiem;

  /// Written or spoken the 24-hour way, so it is never shifted to the
  /// afternoon ("08:30", "8 Uhr").
  final bool twentyFourHour;

  /// [hour] and [minute] name a time of day at all.
  bool get isValid =>
      hour >= 0 &&
      hour <= 23 &&
      minute >= 0 &&
      minute <= 59 &&
      (meridiem == null || (hour >= 1 && hour <= 12));

  /// This clock with [meridiem] when it has none of its own.
  CheckInClockMention withMeridiem(CheckInMeridiem? meridiem) =>
      this.meridiem != null || meridiem == null || twentyFourHour
      ? this
      : CheckInClockMention(hour, minute: minute, meridiem: meridiem);

  @override
  bool operator ==(Object other) =>
      other is CheckInClockMention &&
      other.hour == hour &&
      other.minute == minute &&
      other.meridiem == meridiem &&
      other.twentyFourHour == twentyFourHour;

  @override
  int get hashCode => Object.hash(hour, minute, meridiem, twentyFourHour);

  @override
  String toString() =>
      'CheckInClockMention($hour:$minute, $meridiem, 24h: $twentyFourHour)';
}

/// "From 2 to 3": when it started and when it ended.
class CheckInClockRange {
  const CheckInClockRange(this.start, this.end);

  /// The range with the start reading the end's am/pm when it names none —
  /// "from 2 to 3 pm" started at 2 pm — as long as that keeps the start
  /// before the end.
  factory CheckInClockRange.spoken(
    CheckInClockMention start,
    CheckInClockMention end,
  ) {
    final inherited = start.withMeridiem(end.meridiem);
    final startHour = inherited.hour % 12;
    final endHour = end.hour % 12;
    return CheckInClockRange(
      startHour <= endHour ? inherited : start,
      end,
    );
  }

  final CheckInClockMention start;
  final CheckInClockMention end;
}

/// Everything one language found in a transcript, before any of it is
/// resolved against the clock.
class CheckInDictationReading {
  const CheckInDictationReading({
    this.clocks = const [],
    this.ranges = const [],
    this.durations = const [],
    this.dayOffsets = const {},
    this.periods = const {},
    this.channels = const [],
  });

  /// Times of day spoken on their own ("at 3 pm").
  final List<CheckInClockMention> clocks;

  /// Times of day spoken as a span ("from 2 to 3").
  final List<CheckInClockRange> ranges;

  /// Lengths spoken ("45 minutes").
  final List<Duration> durations;

  /// Days named, as days before today: 0 today, 1 yesterday, 2 the day
  /// before, -1 tomorrow.
  final Set<int> dayOffsets;

  /// Parts of the day named.
  final Set<CheckInDayPeriod> periods;

  /// Channels named, one entry per phrase.
  final List<CheckInInteractionType> channels;
}

/// One language's reading of a normalised transcript
/// (`normalizeCheckInDictation`).
abstract class CheckInDictationLexicon {
  const CheckInDictationLexicon();

  CheckInDictationReading read(String text);
}

/// Walks a text's matches while remembering which characters an earlier,
/// more specific rule already explained, so "an hour and a half" is never
/// read again as "an hour", and "video call" never as "call".
class SpanClaims {
  final _claimed = <(int, int)>[];

  bool _free(int start, int end) =>
      _claimed.every((span) => end <= span.$1 || start >= span.$2);

  /// Calls [onMatch] for each match of [pattern] in [text] that overlaps no
  /// claimed span, and claims it when [onMatch] returns true.
  void each(
    RegExp pattern,
    String text,
    bool Function(RegExpMatch match) onMatch,
  ) {
    for (final match in pattern.allMatches(text)) {
      if (!_free(match.start, match.end)) continue;
      if (onMatch(match)) _claimed.add((match.start, match.end));
    }
  }
}

/// A spoken number: digits (with a decimal comma or point) or a word from
/// [words].
num? parseSpokenNumber(String token, Map<String, num> words) {
  final trimmed = token.trim();
  final digits = num.tryParse(trimmed.replaceAll(',', '.'));
  return digits ?? words[trimmed];
}

/// [words]' keys as a regex alternation, longest first so "fünfundvierzig"
/// is not read as "fünf".
String spokenNumberAlternation(Map<String, num> words) {
  final keys = words.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return keys.map(RegExp.escape).join('|');
}

/// The length [amount] of [unitMinutes] makes, to the whole minute.
Duration spokenLength(num amount, int unitMinutes) =>
    Duration(minutes: (amount * unitMinutes).round());
