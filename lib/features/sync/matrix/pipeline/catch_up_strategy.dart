import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
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
    required this.incomplete,
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
         incomplete: false,
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
         incomplete: false,
         timestampAnchored: true,
         snapshotSize: snapshotSize,
         visibleTailCount: 0,
         fallbackLimit: null,
         reachedTimestampBoundary: true,
       );

  const CatchUpCollection.incomplete({
    required int snapshotSize,
    required int visibleTailCount,
    required int fallbackLimit,
    required bool reachedTimestampBoundary,
  }) : this._(
         events: const [],
         incomplete: true,
         timestampAnchored: false,
         snapshotSize: snapshotSize,
         visibleTailCount: visibleTailCount,
         fallbackLimit: fallbackLimit,
         reachedTimestampBoundary: reachedTimestampBoundary,
       );

  final List<Event> events;
  final bool incomplete;
  final bool timestampAnchored;
  final int snapshotSize;
  final int visibleTailCount;
  final int? fallbackLimit;
  final bool reachedTimestampBoundary;
}

/// Catch‑up helper used at attach time by the stream consumer.
class CatchUpStrategy {
  /// Collects ordered events for catch-up using the stored timestamp as the
  /// canonical replay anchor.
  ///
  /// When [preContextSinceTs] is available, catch-up keeps paging until the
  /// earliest visible event is older than that boundary, then replays forward
  /// from a bounded overlap around the boundary. [lastEventId] is accepted only
  /// as legacy/debug context; recovery no longer depends on locating it.
  ///
  /// Returns an incomplete-recovery result only when the timestamp boundary
  /// cannot be reached.
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
      final events = TimelineEventOrdering.sortStableByTimestamp(
        snapshot.events,
      );
      if (preContextSinceTs == null) {
        return CatchUpCollection.complete(
          events: events,
          snapshotSize: events.length,
        );
      }

      Future<void> pageUntilBoundary(Timeline timeline) async {
        await backfill(
          timeline: timeline,
          lastEventId: lastEventId,
          pageSize: 200,
          // Reconnect catch-up must keep paging until the timestamp boundary is
          // reached or the SDK proves there is no more history to request.
          maxPages: null,
          logging: logging,
          untilTimestamp: preContextSinceTs,
        );
      }

      bool reachedTimestampBoundary(List<Event> ordered) =>
          ordered.isNotEmpty &&
          TimelineEventOrdering.timestamp(ordered.first) <= preContextSinceTs;

      var ordered = events;
      if (!reachedTimestampBoundary(ordered)) {
        await pageUntilBoundary(snapshot);
        ordered = TimelineEventOrdering.sortStableByTimestamp(snapshot.events);
      }

      bool needsMore(List<Event> current) =>
          !reachedTimestampBoundary(current) &&
          current.length >= limit &&
          limit < maxLookback;

      while (needsMore(ordered)) {
        final doubled = limit * 2;
        limit = doubled > maxLookback ? maxLookback : doubled;
        final next = await room.getTimeline(limit: limit);
        try {
          await pageUntilBoundary(next);
          ordered = TimelineEventOrdering.sortStableByTimestamp(next.events);
        } finally {
          try {
            next.cancelSubscriptions();
          } catch (_) {}
        }
      }

      if (reachedTimestampBoundary(ordered)) {
        final start = _startIndexForTimestampBoundary(
          ordered,
          preContextSinceTs: preContextSinceTs,
          preContextCount: preContextCount,
        );
        logging.captureEvent(
          'catchup.timestampBoundary '
          'snapshot=${ordered.length} '
          'lastEventId=${lastEventId ?? 'null'} '
          'startIndex=$start',
          domain: syncLoggingDomain,
          subDomain: 'catchup.timestampBoundary',
        );
        return CatchUpCollection.timestampAnchored(
          events: ordered.sublist(start),
          snapshotSize: ordered.length,
        );
      }

      final visibleTailCount = ordered.length <= missingMarkerFallbackLimit
          ? ordered.length
          : missingMarkerFallbackLimit;
      logging.captureEvent(
        'catchup.incomplete lastEventId=$lastEventId '
        'snapshot=${ordered.length} visibleTail=$visibleTailCount '
        'fallbackLimit=$missingMarkerFallbackLimit '
        'reason=timestampBoundaryUnreachable '
        'reachedTimestampBoundary=false',
        domain: syncLoggingDomain,
        subDomain: 'catchup.incomplete',
      );
      return CatchUpCollection.incomplete(
        snapshotSize: ordered.length,
        visibleTailCount: visibleTailCount,
        fallbackLimit: missingMarkerFallbackLimit,
        reachedTimestampBoundary: false,
      );
    } finally {
      try {
        snapshot.cancelSubscriptions();
      } catch (_) {}
    }
  }

  static int _startIndexForTimestampBoundary(
    List<Event> events, {
    required num preContextSinceTs,
    required int preContextCount,
  }) {
    var start = 0;
    while (start < events.length &&
        TimelineEventOrdering.timestamp(events[start]) < preContextSinceTs) {
      start++;
    }
    // Rewind a bounded overlap before the time anchor so catch-up absorbs
    // same-timestamp collisions and small marker debounce skew.
    start -= preContextCount;
    if (start < 0) start = 0;
    if (start > events.length) start = events.length;
    return start;
  }
}
