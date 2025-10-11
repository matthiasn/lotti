import 'package:matrix/matrix.dart';

/// Ordering helpers for Matrix timeline events.
class TimelineEventOrdering {
  TimelineEventOrdering._();

  /// Returns the event timestamp (milliseconds since epoch).
  static num timestamp(Event event) =>
      event.originServerTs.millisecondsSinceEpoch;

  /// Compares two events chronologically (oldest first). When timestamps are
  /// equal, falls back to lexicographical ordering on the event IDs.
  static int compare(Event a, Event b) {
    final timestampComparison = timestamp(a).compareTo(timestamp(b));
    if (timestampComparison != 0) {
      return timestampComparison;
    }
    final idA = a.eventId;
    final idB = b.eventId;
    return idA.compareTo(idB);
  }

  /// Returns whether the candidate event should advance the read marker given
  /// the latest timestamp and event ID recorded so far.
  static bool isNewer({
    required num candidateTimestamp,
    required String candidateEventId,
    required num? latestTimestamp,
    required String? latestEventId,
  }) {
    if (latestTimestamp == null || latestEventId == null) {
      return true;
    }
    if (candidateTimestamp > latestTimestamp) {
      return true;
    }
    if (candidateTimestamp < latestTimestamp) {
      return false;
    }
    return candidateEventId.compareTo(latestEventId) > 0;
  }
}
