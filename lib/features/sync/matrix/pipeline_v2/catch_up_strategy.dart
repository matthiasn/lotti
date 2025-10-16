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
    int rewindCount = 0,
    int? thresholdTsMillis,
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

      // If a time threshold is provided, ensure history includes or precedes it
      // by paging back until the earliest event is at or before threshold.
      if (thresholdTsMillis != null) {
        while (events.isNotEmpty &&
            events.first.originServerTs.millisecondsSinceEpoch >
                thresholdTsMillis &&
            snapshot.canRequestHistory) {
          try {
            await snapshot.requestHistory();
          } catch (e, st) {
            logging.captureException(
              e,
              domain: 'MATRIX_SYNC_V2',
              subDomain: 'catchup.requestHistory.ts',
              stackTrace: st,
            );
            break;
          }
          events
            ..clear()
            ..addAll(snapshot.events)
            ..sort(TimelineEventOrdering.compare);
          idx = tu.findLastIndexByEventId(events, lastEventId);
        }
      }
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
        final start = (idx + 1 - rewindCount).clamp(0, events.length);
        if (rewindCount > 0) {
          logging.captureEvent(
            'catchUp: rewinding $rewindCount from marker (idx=$idx → start=$start, size=${events.length})',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'catchup.rewind',
          );
        }
        return events.sublist(start);
      }
      // If no marker id known or not found, and a threshold timestamp exists,
      // slice from the first event whose ts >= threshold.
      if (thresholdTsMillis != null && events.isNotEmpty) {
        var s = 0;
        while (s < events.length &&
            events[s].originServerTs.millisecondsSinceEpoch <
                thresholdTsMillis) {
          s++;
        }
        logging.captureEvent(
          'catchUp: ts slice start=$s (threshold=$thresholdTsMillis, size=${events.length})',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'catchup.rewindTs',
        );
        return events.sublist(s);
      }
      return events;
    } finally {
      try {
        snapshot.cancelSubscriptions();
      } catch (_) {}
    }
  }
}
