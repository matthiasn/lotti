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
      final timestampComparison = timestamp(
        a.event,
      ).compareTo(timestamp(b.event));
      if (timestampComparison != 0) {
        return timestampComparison;
      }
      return a.index.compareTo(b.index);
    });
    return [for (final item in indexed) item.event];
  }
}
