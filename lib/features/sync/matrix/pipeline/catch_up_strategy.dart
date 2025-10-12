import 'dart:math' as math;

import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart' as tu;
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

typedef BackfillFn = Future<bool> Function({
  required Timeline timeline,
  required String? lastEventId,
  required int pageSize,
  required int maxPages,
  required LoggingService logging,
});

class CatchUpStrategy {
  static Future<List<Event>> collectEventsForCatchUp({
    required Room room,
    required String? lastEventId,
    required BackfillFn backfill,
    required LoggingService logging,
    int initialLimit = 200,
    int maxLookback = 4000,
  }) async {
    var limit = initialLimit;
    final snapshot = await room.getTimeline(limit: limit);
    try {
      final attempted = await backfill(
        timeline: snapshot,
        lastEventId: lastEventId,
        pageSize: 200,
        maxPages: 20,
        logging: logging,
      );
      final events = List<Event>.from(snapshot.events)
        ..sort(TimelineEventOrdering.compare);
      var idx = tu.findLastIndexByEventId(events, lastEventId);
      if (idx < 0 && !attempted) {
        while (true) {
          final reachedStart = events.length < limit;
          final reachedCap = limit >= maxLookback;
          if (idx >= 0 || reachedStart || reachedCap) break;
          limit = math.min(limit * 2, maxLookback);
          final next = await room.getTimeline(limit: limit);
          try {
            final nextEvents = List<Event>.from(next.events)
              ..sort(TimelineEventOrdering.compare);
            events
              ..clear()
              ..addAll(nextEvents);
            idx = tu.findLastIndexByEventId(events, lastEventId);
          } finally {
            try {
              next.cancelSubscriptions();
            } catch (_) {}
          }
        }
      }
      return idx >= 0 ? events.sublist(idx + 1) : events;
    } finally {
      try {
        snapshot.cancelSubscriptions();
      } catch (_) {}
    }
  }
}
