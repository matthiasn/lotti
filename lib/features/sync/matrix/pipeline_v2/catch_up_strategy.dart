import 'dart:math' as math;

import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart' as tu;
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Signature for a backfill function that attempts to paginate a [timeline]
/// until [lastEventId] is present or a limit is reached. Returns true if
/// pagination was attempted (or the event was already present).
typedef BackfillFn = Future<bool> Function({
  required Timeline timeline,
  required String? lastEventId,
  required int pageSize,
  required int maxPages,
  required LoggingService logging,
});

/// Catch‑up helper used at attach time by the stream consumer.
///
/// Behaviour:
/// - Takes a live snapshot and asks backfill (SDK pagination seam) to ensure
///   the last processed event is present in the timeline.
/// - If the target is still missing and no SDK backfill was attempted, it
///   escalates snapshot limits (doubling) up to maxLookback.
/// - Returns only events strictly after lastEventId when it can be located;
///   otherwise returns the entire snapshot (oldest→newest).
class CatchUpStrategy {
  /// Collects ordered events for catch‑up without rewinding before the last
  /// processed marker. If [lastEventId] cannot be located, returns the entire
  /// snapshot ordered chronologically.
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
      if (idx >= 0) {
        var start = idx + 1;
        if (start < 0) start = 0;
        if (start > events.length) start = events.length;
        return events.sublist(start);
      }
      return events;
    } finally {
      try {
        snapshot.cancelSubscriptions();
      } catch (_) {}
    }
  }
}
