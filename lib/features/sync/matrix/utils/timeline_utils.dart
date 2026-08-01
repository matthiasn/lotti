import 'package:matrix/matrix.dart';

/// Finds the last index of an event by its ID in an ordered list, or -1.
int findLastIndexByEventId(List<Event> ordered, String? id) {
  if (id == null) return -1;
  for (var i = ordered.length - 1; i >= 0; i--) {
    if (ordered[i].eventId == id) return i;
  }
  return -1;
}

/// Deduplicates events by eventId while preserving the original order.
List<Event> dedupEventsByIdPreserveOrder(List<Event> events) {
  final seen = <String>{};
  final result = <Event>[];
  for (final e in events) {
    if (seen.add(e.eventId)) {
      result.add(e);
    }
  }
  return result;
}

// Media downloading has been removed.
