import 'package:matrix/matrix.dart';

/// Ordering helpers for Matrix timeline events.
class TimelineEventOrdering {
  TimelineEventOrdering._();

  /// Returns the event timestamp (milliseconds since epoch).
  static num timestamp(Event event) =>
      event.originServerTs.millisecondsSinceEpoch;

  /// Returns a new list sorted by timestamp while preserving the original
  /// order for events that share the same timestamp.
  static List<Event> sortStableByTimestamp(List<Event> events) {
    final indexed = <({Event event, int index})>[];
    for (var i = 0; i < events.length; i++) {
      indexed.add((event: events[i], index: i));
    }
    indexed.sort((a, b) {
      final timestampComparison =
          timestamp(a.event).compareTo(timestamp(b.event));
      if (timestampComparison != 0) {
        return timestampComparison;
      }
      return a.index.compareTo(b.index);
    });
    return [for (final item in indexed) item.event];
  }

  /// Returns collision statistics for timestamps that appear more than once.
  /// `groupCount` is the number of distinct timestamps with collisions.
  /// `eventCount` is the total number of events that share those timestamps.
  /// `sample` includes up to `sampleLimit` timestamp/count pairs.
  static ({
    int groupCount,
    int eventCount,
    List<({num ts, int count})> sample,
  }) timestampCollisionStats(
    List<Event> events, {
    int sampleLimit = 8,
  }) {
    final counts = <num, int>{};
    for (final event in events) {
      final ts = timestamp(event);
      counts[ts] = (counts[ts] ?? 0) + 1;
    }
    final collisions = <({num ts, int count})>[];
    var eventCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > 1) {
        collisions.add((ts: entry.key, count: entry.value));
        eventCount += entry.value;
      }
    }
    collisions.sort((a, b) => a.ts.compareTo(b.ts));
    final sample = collisions.length > sampleLimit
        ? collisions.sublist(0, sampleLimit)
        : collisions;
    return (
      groupCount: collisions.length,
      eventCount: eventCount,
      sample: sample,
    );
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
