import 'package:lotti/classes/check_in_data.dart';

/// What a spoken capture about a person sorts into: a conversation to log, a
/// note to keep, a meeting to plan or a task to do. The model proposes them
/// (`parsePersonCaptureSortToolCall`); the user reviews every one before
/// anything is filed. Sentiment is never among the fields: how a
/// conversation felt is the user's to say (ADR 0038).
sealed class PersonCaptureItem {
  const PersonCaptureItem();
}

/// A conversation that took place, to log as a check-in. The [summary] is
/// its narrative; the recording it was spoken in is attached when filed.
final class PersonCaptureCheckIn extends PersonCaptureItem {
  const PersonCaptureCheckIn({
    required this.interactionType,
    required this.summary,
    this.startedAt,
    this.duration,
    this.topics = const [],
    this.bringUp,
    this.avoid,
  });

  final CheckInInteractionType interactionType;
  final String summary;

  /// When it started, or null for "when the capture was spoken".
  final DateTime? startedAt;
  final Duration? duration;
  final List<String> topics;

  /// What to bring up next time, and what to leave alone.
  final String? bringUp;
  final String? avoid;

  PersonCaptureCheckIn copyWith({
    CheckInInteractionType? interactionType,
    DateTime? startedAt,
    Duration? duration,
  }) => PersonCaptureCheckIn(
    interactionType: interactionType ?? this.interactionType,
    summary: summary,
    startedAt: startedAt ?? this.startedAt,
    duration: duration ?? this.duration,
    topics: topics,
    bringUp: bringUp,
    avoid: avoid,
  );
}

/// Something to remember about the person. Filed, it is the voice note the
/// capture already is, its transcript as its words.
final class PersonCaptureNote extends PersonCaptureItem {
  const PersonCaptureNote({required this.text});

  final String text;
}

/// A meeting to plan. A start the model could not state as a real date is
/// null, and the review asks for one.
final class PersonCaptureMeeting extends PersonCaptureItem {
  const PersonCaptureMeeting({required this.title, this.start, this.duration});

  final String title;
  final DateTime? start;
  final Duration? duration;

  PersonCaptureMeeting copyWith({DateTime? start, Duration? duration}) =>
      PersonCaptureMeeting(
        title: title,
        start: start ?? this.start,
        duration: duration ?? this.duration,
      );
}

/// Something the user means to do for or about the person.
final class PersonCaptureTask extends PersonCaptureItem {
  const PersonCaptureTask({required this.title, this.due});

  final String title;

  /// The day it is due, at midnight, or null.
  final DateTime? due;
}

/// The most items one capture sorts into: a capture is a minute of speech,
/// and a review of more than three is a form, not a glance.
const personCaptureMaxItems = 3;

/// The longest a spoken conversation, or a planned meeting, may claim to
/// last; anything outside 1 minute..12 hours is a misheard number and drops.
const personCaptureMaxMinutes = 720;

/// Parses a local wall-clock time the model wrote as `YYYY-MM-DDTHH:MM`
/// (seconds allowed), or null when it is not one. Round-trips the
/// components, so a date Dart would quietly roll over — 30 February, 25:00 —
/// is refused rather than moved (the `relationshipTaskProposalError`
/// precedent). A zone suffix is refused too: the prompt asks for local time.
DateTime? parsePersonCaptureLocalTime(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final parts = [
    for (var i = 1; i <= 6; i++) int.parse(match.group(i) ?? '0'),
  ];
  final parsed = DateTime(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  final roundTrips =
      parsed.year == parts[0] &&
      parsed.month == parts[1] &&
      parsed.day == parts[2] &&
      parsed.hour == parts[3] &&
      parsed.minute == parts[4] &&
      parsed.second == parts[5];
  return roundTrips ? parsed : null;
}

/// Parses a calendar day written as `YYYY-MM-DD`, round-tripped like
/// [parsePersonCaptureLocalTime], or null.
DateTime? parsePersonCaptureDay(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day
      ? parsed
      : null;
}

/// A whole number of minutes in 1..[personCaptureMaxMinutes], as a
/// [Duration], or null.
Duration? parsePersonCaptureMinutes(Object? value) {
  final minutes = switch (value) {
    final int whole => whole,
    final double real when real == real.roundToDouble() => real.toInt(),
    _ => null,
  };
  if (minutes == null || minutes < 1 || minutes > personCaptureMaxMinutes) {
    return null;
  }
  return Duration(minutes: minutes);
}
