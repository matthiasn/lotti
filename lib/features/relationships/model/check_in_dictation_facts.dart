import 'package:flutter/foundation.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon_de.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon_en.dart';

export 'package:lotti/features/relationships/model/check_in_dictation_lexicon.dart'
    show CheckInDictationLexicon;

/// What a dictated check-in says about itself: when it happened, how long it
/// ran and how it happened. Each is null when the words do not say it — or
/// say it more than one way, so the composer never picks between them.
@immutable
class CheckInDictationFacts {
  const CheckInDictationFacts({
    this.startedAt,
    this.duration,
    this.interactionType,
  });

  static const none = CheckInDictationFacts();

  final DateTime? startedAt;
  final Duration? duration;

  /// Only [CheckInInteractionType.inPerson], [CheckInInteractionType.call] or
  /// [CheckInInteractionType.videoCall] — the channels a spoken account
  /// names reliably.
  final CheckInInteractionType? interactionType;

  bool get isEmpty =>
      startedAt == null && duration == null && interactionType == null;

  @override
  bool operator ==(Object other) =>
      other is CheckInDictationFacts &&
      other.startedAt == startedAt &&
      other.duration == duration &&
      other.interactionType == interactionType;

  @override
  int get hashCode => Object.hash(startedAt, duration, interactionType);

  @override
  String toString() =>
      'CheckInDictationFacts(startedAt: $startedAt, duration: $duration, '
      'interactionType: $interactionType)';
}

/// The languages a dictation is read in. The transcript carries no usable
/// language tag, so every lexicon reads it, and a field two of them answer
/// differently is left alone.
const List<CheckInDictationLexicon> checkInDictationLexicons = [
  englishCheckInLexicon,
  germanCheckInLexicon,
];

/// The shortest and longest length a spoken duration may set. Outside them
/// the words were about something else — "wait a minute", "a five-year
/// plan" — and are not read as the check-in's length at all.
const _minDuration = Duration(minutes: 2);
const _maxDuration = Duration(hours: 12);

/// Reads [transcript] for the check-in's start, length and channel.
///
/// Entirely on-device and rule-based: nothing leaves the device for it, and
/// the result is the same every time for the same words and [now].
///
/// The rules lean towards leaving a field alone:
/// - **Start** needs a clock time ("at 3 pm", "um 15 Uhr", "half past two",
///   "from 2 to 3"). A part of the day on its own ("this morning") or a day
///   on its own ("yesterday") does not set one — the time would be a guess.
///   A day word places the time ("yesterday at noon"); without one the time
///   is the most recent past occurrence — today, or yesterday when today's
///   is still to come. A start in the future, or two different starts, sets
///   nothing.
/// - **Length** needs a number and a unit ("45 minutes", "an hour and a
///   half", "eine halbe Stunde"), or a clock range. Durations that say when
///   rather than how long ("ten minutes ago", "in an hour", "20 minutes
///   late") are not lengths, and neither is anything under two minutes or
///   over twelve hours. Two different lengths set nothing.
/// - **Channel** needs a phrase that says how it happened in the past ("we
///   met up", "called", "on the phone", "video call", "over Zoom"). A plan
///   ("I should call her") is not a channel. A call that was also on video
///   is a video call; in person and a call in one account set nothing.
CheckInDictationFacts extractCheckInDictationFacts(
  String transcript, {
  required DateTime now,
  List<CheckInDictationLexicon> lexicons = checkInDictationLexicons,
}) {
  final text = normalizeCheckInDictation(transcript);
  if (text.isEmpty) return CheckInDictationFacts.none;

  final readings = [for (final lexicon in lexicons) lexicon.read(text)];

  final starts = <DateTime>{};
  final lengths = <Duration>{};
  final channels = <CheckInInteractionType>{};
  var startConflict = false;
  var lengthConflict = false;
  var channelConflict = false;

  for (final reading in readings) {
    final start = _resolveStart(reading, now: now);
    switch (start) {
      case _Undecided():
        break;
      case _Conflict():
        startConflict = true;
      case _Decided(:final value):
        starts.add(value);
    }

    final length = _resolveLength(reading);
    switch (length) {
      case _Undecided():
        break;
      case _Conflict():
        lengthConflict = true;
      case _Decided(:final value):
        lengths.add(value);
    }

    final channel = _resolveChannel(reading);
    switch (channel) {
      case _Undecided():
        break;
      case _Conflict():
        channelConflict = true;
      case _Decided(:final value):
        channels.add(value);
    }
  }

  return CheckInDictationFacts(
    startedAt: !startConflict && starts.length == 1 ? starts.single : null,
    duration: !lengthConflict && lengths.length == 1 ? lengths.single : null,
    interactionType: !channelConflict && channels.length == 1
        ? channels.single
        : null,
  );
}

/// Lower-cased, typographic apostrophes and dashes made plain, whitespace
/// collapsed — the one shape every lexicon reads.
String normalizeCheckInDictation(String transcript) => transcript
    .toLowerCase()
    .replaceAll(RegExp('[’‘`´]'), "'")
    .replaceAll(RegExp('[–—]'), '-')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

sealed class _Outcome<T> {
  const _Outcome();
}

class _Undecided<T> extends _Outcome<T> {
  const _Undecided();
}

class _Conflict<T> extends _Outcome<T> {
  const _Conflict();
}

class _Decided<T> extends _Outcome<T> {
  const _Decided(this.value);
  final T value;
}

/// One value from distinct candidates: none, one, or a conflict.
_Outcome<T> _single<T>(Iterable<T> candidates) {
  final distinct = candidates.toSet();
  if (distinct.isEmpty) return _Undecided<T>();
  if (distinct.length > 1) return _Conflict<T>();
  return _Decided<T>(distinct.single);
}

_Outcome<DateTime> _resolveStart(
  CheckInDictationReading reading, {
  required DateTime now,
}) {
  final clocks = [
    ...reading.clocks,
    for (final range in reading.ranges) range.start,
  ];
  if (clocks.isEmpty) return const _Undecided();
  if (reading.dayOffsets.length > 1) return const _Conflict();
  final dayOffset = reading.dayOffsets.isEmpty
      ? null
      : reading.dayOffsets.single;
  // A day still to come: this is a plan, not the check-in.
  if (dayOffset != null && dayOffset < 0) return const _Conflict();
  final period = reading.periods.length == 1 ? reading.periods.single : null;

  final resolved = <DateTime>[];
  for (final clock in clocks) {
    final start = _placeClock(
      clock,
      period: period,
      dayOffset: dayOffset,
      now: now,
    );
    if (start == null) return const _Conflict();
    resolved.add(start);
  }
  return _single(resolved);
}

/// The local time [clock] names, on the day [dayOffset] days before [now] —
/// or, with no day named, the most recent such time not after [now]. Null
/// when the named day puts it in the future.
DateTime? _placeClock(
  CheckInClockMention clock, {
  required CheckInDayPeriod? period,
  required int? dayOffset,
  required DateTime now,
}) {
  final hour = resolveCheckInHour(clock, period: period);
  final today = DateTime(now.year, now.month, now.day, hour, clock.minute);
  // Tolerate the minute being spoken: "at 3" said at 3:00:40.
  final latest = now.add(const Duration(minutes: 1));
  if (dayOffset != null) {
    final placed = DateTime(
      now.year,
      now.month,
      now.day - dayOffset,
      hour,
      clock.minute,
    );
    return placed.isAfter(latest) ? null : placed;
  }
  if (!today.isAfter(latest)) return today;
  return DateTime(now.year, now.month, now.day - 1, hour, clock.minute);
}

/// The 24-hour hour [clock] means.
///
/// An explicit am/pm decides. Otherwise a 24-hour reading (13–23, 0, or a
/// zero-padded "08:30") stands; then the part of the day spoken around it;
/// then the hours people keep — 1 to 7 in the afternoon or evening, 8 to 12
/// as said.
int resolveCheckInHour(
  CheckInClockMention clock, {
  CheckInDayPeriod? period,
}) {
  final hour = clock.hour;
  switch (clock.meridiem) {
    case CheckInMeridiem.am:
      return hour == 12 ? 0 : hour;
    case CheckInMeridiem.pm:
      return hour < 12 ? hour + 12 : hour;
    case null:
      break;
  }
  if (hour >= 13 || hour == 0 || clock.twentyFourHour) return hour;
  switch (period) {
    case CheckInDayPeriod.morning:
      return hour == 12 ? 12 : hour;
    case CheckInDayPeriod.afternoon || CheckInDayPeriod.evening:
      return hour < 12 ? hour + 12 : hour;
    case null:
      break;
  }
  return hour <= 7 ? hour + 12 : hour;
}

_Outcome<Duration> _resolveLength(CheckInDictationReading reading) {
  final lengths = [
    for (final duration in reading.durations)
      if (_plausible(duration)) duration,
  ];
  if (lengths.isNotEmpty) return _single(lengths);
  // No spoken length: a single clock range says it instead.
  if (reading.ranges.length != 1) return const _Undecided();
  final range = reading.ranges.single;
  final period = reading.periods.length == 1 ? reading.periods.single : null;
  final start = _minutesOfDay(range.start, period);
  var end = _minutesOfDay(range.end, period);
  // "from 11 to 1" crosses noon; read the end as the next such hour.
  if (end <= start && range.end.meridiem == null) end += 12 * 60;
  final length = Duration(minutes: end - start);
  return _plausible(length) ? _Decided(length) : const _Conflict();
}

int _minutesOfDay(CheckInClockMention clock, CheckInDayPeriod? period) =>
    resolveCheckInHour(clock, period: period) * 60 + clock.minute;

bool _plausible(Duration duration) =>
    duration >= _minDuration && duration <= _maxDuration;

/// The channel the reading names. "A call … on video" is one video call, so
/// a call and a video channel together are a video call; in person beside
/// either is a contradiction.
_Outcome<CheckInInteractionType> _resolveChannel(
  CheckInDictationReading reading,
) {
  final channels = reading.channels.toSet();
  if (channels.length == 2 &&
      channels.contains(CheckInInteractionType.call) &&
      channels.contains(CheckInInteractionType.videoCall)) {
    return const _Decided(CheckInInteractionType.videoCall);
  }
  return _single(channels);
}
