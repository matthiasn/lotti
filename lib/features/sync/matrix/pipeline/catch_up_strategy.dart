import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart' as tu;
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Signature for a backfill function that attempts to paginate a [timeline]
/// until [lastEventId] is present or a limit is reached. Returns true if
/// pagination was attempted (or the event was already present).
typedef BackfillFn =
    Future<bool> Function({
      required Timeline timeline,
      required String? lastEventId,
      required int pageSize,
      required int? maxPages,
      required LoggingService logging,
      num? untilTimestamp,
    });

/// Default value for the [CatchUpStrategy.collectEventsForCatchUp]
/// `missingMarkerFallbackLimit` parameter.
const defaultMissingMarkerFallbackLimit = 1000;

class CatchUpCollection {
  const CatchUpCollection._({
    required this.events,
    required this.markerMissing,
    required this.timestampAnchored,
    required this.snapshotSize,
    required this.visibleTailCount,
    required this.fallbackLimit,
    required this.reachedTimestampBoundary,
  });

  const CatchUpCollection.complete({
    required List<Event> events,
    required int snapshotSize,
  }) : this._(
         events: events,
         markerMissing: false,
         timestampAnchored: false,
         snapshotSize: snapshotSize,
         visibleTailCount: 0,
         fallbackLimit: null,
         reachedTimestampBoundary: false,
       );

  const CatchUpCollection.timestampAnchored({
    required List<Event> events,
    required int snapshotSize,
  }) : this._(
         events: events,
         markerMissing: false,
         timestampAnchored: true,
         snapshotSize: snapshotSize,
         visibleTailCount: 0,
         fallbackLimit: null,
         reachedTimestampBoundary: true,
       );

  const CatchUpCollection.markerMissing({
    required int snapshotSize,
    required int visibleTailCount,
    required int fallbackLimit,
    required bool reachedTimestampBoundary,
  }) : this._(
         events: const [],
         markerMissing: true,
         timestampAnchored: false,
         snapshotSize: snapshotSize,
         visibleTailCount: visibleTailCount,
         fallbackLimit: fallbackLimit,
         reachedTimestampBoundary: reachedTimestampBoundary,
       );

  final List<Event> events;
  final bool markerMissing;
  final bool timestampAnchored;
  final int snapshotSize;
  final int visibleTailCount;
  final int? fallbackLimit;
  final bool reachedTimestampBoundary;
}

/// Catch‑up helper used at attach time by the stream consumer.
class CatchUpStrategy {
  /// Collects ordered events for catch‑up without rewinding before the last
  /// processed marker. If [lastEventId] cannot be located but pagination reaches
  /// [preContextSinceTs], returns a timestamp-anchored replay window instead of
  /// falling back to sparse live recovery. Only returns an incomplete-recovery
  /// result when neither anchor can be re-established.
  static Future<CatchUpCollection> collectEventsForCatchUp({
    required Room room,
    required String? lastEventId,
    required BackfillFn backfill,
    required LoggingService logging,
    int initialLimit = 200,
    int maxLookback = 4000,
    int missingMarkerFallbackLimit = defaultMissingMarkerFallbackLimit,
    num? preContextSinceTs,
    int preContextCount = 0,
  }) async {
    var limit = initialLimit;
    final snapshot = await room.getTimeline(limit: limit);
    try {
      if (lastEventId == null) {
        final events = TimelineEventOrdering.sortStableByTimestamp(
          snapshot.events,
        );
        return CatchUpCollection.complete(
          events: events,
          snapshotSize: events.length,
        );
      }

      final attempted = await backfill(
        timeline: snapshot,
        lastEventId: lastEventId,
        pageSize: 200,
        // When reconnecting after offline use, we must be able to keep paging
        // until we either re-anchor on the stored marker or prove we have
        // walked back past the last processed timestamp. A fixed page cap is
        // what turned ordinary offline backlog into synthetic "missing" gaps.
        maxPages: null,
        logging: logging,
        untilTimestamp: preContextSinceTs,
      );
      final events = TimelineEventOrdering.sortStableByTimestamp(
        snapshot.events,
      );
      var idx = tu.findLastIndexByEventId(events, lastEventId);

      // Escalate snapshot size when:
      // - The marker is not present (idx < 0 and no SDK pagination attempted)
      // - OR we need additional pre-context (by count or by timestamp)
      bool needsMore() {
        // If we haven't located the marker and we haven't tried SDK backfill
        // yet, escalate immediately.
        if (idx < 0 && !attempted) return true;

        if (idx < 0 &&
            preContextSinceTs != null &&
            events.isNotEmpty &&
            TimelineEventOrdering.timestamp(events.first) > preContextSinceTs) {
          return true;
        }

        // If the marker is still not found even after backfill attempted,
        // escalate while the snapshot appears full. This avoids truncating
        // catch-up when there are more events than the current snapshot limit.
        if (idx < 0) return events.length >= limit;

        // Marker found: ensure requested pre-context by count and/or since-ts.
        final availablePre = idx + 1; // events before (and including) marker
        final needCount = preContextCount > 0 && availablePre < preContextCount;
        final needSinceTs =
            preContextSinceTs != null &&
            (events.isEmpty ||
                TimelineEventOrdering.timestamp(events.first) >
                    preContextSinceTs);
        if (needCount || needSinceTs) return true;

        // If the snapshot is full, there may be more events after the marker.
        // Keep escalating until the snapshot is not full or we hit the cap.
        return events.length >= limit;
      }

      while (needsMore()) {
        final reachedStart = events.length < limit;
        final reachedCap = limit >= maxLookback;
        if (reachedStart || reachedCap) break;
        final doubled = limit * 2;
        limit = doubled > maxLookback ? maxLookback : doubled;
        final next = await room.getTimeline(limit: limit);
        try {
          final nextEvents = TimelineEventOrdering.sortStableByTimestamp(
            next.events,
          );
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

      if (idx >= 0) {
        // Compute a start index that ensures a pre-context by count and/or by
        // timestamp since the stored last sync ts (when provided).
        var startByCount = idx + 1;
        if (preContextCount > 0) {
          // Include exactly [preContextCount] events BEFORE the marker, and
          // also include the marker itself. That means rewinding by
          // preContextCount from the marker index (idx).
          startByCount = idx - preContextCount;
          if (startByCount < 0) startByCount = 0;
          if (startByCount > events.length) startByCount = events.length;
        }
        var startByTs = idx + 1;
        if (preContextSinceTs != null) {
          // Find the first index whose timestamp is >= preContextSinceTs.
          var i = 0;
          while (i < events.length &&
              TimelineEventOrdering.timestamp(events[i]) < preContextSinceTs) {
            i++;
          }
          startByTs = i;
        }
        var start = startByCount < startByTs ? startByCount : startByTs;
        if (start < 0) start = 0;
        if (start > events.length) start = events.length;
        return CatchUpCollection.complete(
          events: events.sublist(start),
          snapshotSize: events.length,
        );
      }
      final reachedTimestampBoundary =
          preContextSinceTs != null &&
          events.isNotEmpty &&
          TimelineEventOrdering.timestamp(events.first) <= preContextSinceTs;
      if (reachedTimestampBoundary) {
        var start = 0;
        if (preContextSinceTs != null) {
          while (start < events.length &&
              TimelineEventOrdering.timestamp(events[start]) <
                  preContextSinceTs) {
            start++;
          }
          // Rewind a small bounded overlap before the timestamp anchor so
          // replay remains stable around same-timestamp collisions and marker
          // debounce skew without reprocessing an unbounded tail.
          start -= preContextCount;
          if (start < 0) start = 0;
          if (start > events.length) start = events.length;
        }
        logging.captureEvent(
          'catchup.markerMissing lastEventId=$lastEventId '
          'snapshot=${events.length} visibleTail=0 '
          'fallbackLimit=$missingMarkerFallbackLimit '
          'processingSuppressed=false '
          'recoveredBy=timestampBoundary '
          'startIndex=$start '
          'reachedTimestampBoundary=true',
          domain: syncLoggingDomain,
          subDomain: 'catchup.markerMissing',
        );
        return CatchUpCollection.timestampAnchored(
          events: events.sublist(start),
          snapshotSize: events.length,
        );
      }
      final visibleTailCount = events.length <= missingMarkerFallbackLimit
          ? events.length
          : missingMarkerFallbackLimit;
      logging.captureEvent(
        'catchup.markerMissing lastEventId=$lastEventId '
        'snapshot=${events.length} visibleTail=$visibleTailCount '
        'fallbackLimit=$missingMarkerFallbackLimit '
        'processingSuppressed=true '
        'reachedTimestampBoundary=$reachedTimestampBoundary',
        domain: syncLoggingDomain,
        subDomain: 'catchup.markerMissing',
      );
      return CatchUpCollection.markerMissing(
        snapshotSize: events.length,
        visibleTailCount: visibleTailCount,
        fallbackLimit: missingMarkerFallbackLimit,
        reachedTimestampBoundary: reachedTimestampBoundary,
      );
    } finally {
      try {
        snapshot.cancelSubscriptions();
      } catch (_) {}
    }
  }
}
