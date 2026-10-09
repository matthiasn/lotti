import 'package:flutter/foundation.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_facts.dart';

/// The context chips a dictation can fill.
enum CheckInContextField { type, start, duration }

/// What the composer's context chips hold: how, when and for how long.
@immutable
class CheckInContext {
  const CheckInContext({
    required this.type,
    required this.start,
    required this.duration,
  });

  final CheckInInteractionType type;
  final DateTime start;
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is CheckInContext &&
      other.type == type &&
      other.start == start &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(type, start, duration);

  @override
  String toString() => 'CheckInContext($type, $start, $duration)';
}

/// The chips after a dictation filled them, and which ones it filled.
class CheckInDictationFill {
  const CheckInDictationFill({required this.context, required this.filled});

  final CheckInContext context;
  final Set<CheckInContextField> filled;
}

/// Fills [current] from the words of the composer's takes.
///
/// [takeWords] are the takes' transcripts in the order the takes were made,
/// null for a take whose words have not arrived. Each field takes the newest
/// take that names it ([extractCheckInDictationFacts]), so the result depends
/// only on which takes have words — never on the order those words arrived
/// in. A field in [held] is the user's and is returned unchanged, whatever
/// the words say.
CheckInDictationFill fillCheckInContextFromTakes({
  required CheckInContext current,
  required Iterable<String?> takeWords,
  required Set<CheckInContextField> held,
  required DateTime now,
}) {
  DateTime? start;
  Duration? duration;
  CheckInInteractionType? type;
  for (final words in takeWords) {
    if (words == null) continue;
    final facts = extractCheckInDictationFacts(words, now: now);
    start = facts.startedAt ?? start;
    duration = facts.duration ?? duration;
    type = facts.interactionType ?? type;
  }

  final filled = <CheckInContextField>{};
  bool fills(CheckInContextField field, Object? value) {
    if (value == null || held.contains(field)) return false;
    filled.add(field);
    return true;
  }

  return CheckInDictationFill(
    context: CheckInContext(
      type: fills(CheckInContextField.type, type) ? type! : current.type,
      start: fills(CheckInContextField.start, start) ? start! : current.start,
      duration: fills(CheckInContextField.duration, duration)
          ? duration!
          : current.duration,
    ),
    filled: filled,
  );
}
