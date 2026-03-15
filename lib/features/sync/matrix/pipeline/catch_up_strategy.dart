import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Signature for a reconnect backfill/pagination function.
///
/// Implementations page the provided [timeline] until one of these stopping
/// conditions becomes true:
///
/// - [lastEventId] is visible in the timeline
/// - [untilTimestamp] has been crossed by the earliest visible event
/// - [maxPages] pages were requested; `null` means unbounded paging
/// - the SDK reports that no more history is available
///
/// [pageSize] is the requested history batch size for each page. Returns
/// `true` only when the requested reconnect boundary is actually reachable
/// after paging. Returns `false` when history is exhausted or pagination fails
/// before [lastEventId] or [untilTimestamp] is reached.
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
  /// cannot be reached from the current sync tail plus any advertised server
  /// history behind it.
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
        // No anchor — first-ever catch-up. Expand the local timeline until
        // we have all available events so we don't miss events from other
        // devices when the latest page contains only self-sent events.
        var ordered = events;
        while (ordered.length >= limit && limit < maxLookback) {
          final doubled = limit * 2;
          limit = doubled > maxLookback ? maxLookback : doubled;
          final next = await room.getTimeline(limit: limit);
          try {
            final nextEvents = TimelineEventOrdering.sortStableByTimestamp(
              next.events,
            );
            if (nextEvents.length <= ordered.length) {
              break; // no more events available
            }
            ordered = nextEvents;
          } finally {
            try {
              next.cancelSubscriptions();
            } catch (_) {}
          }
        }
        return CatchUpCollection.complete(
          events: ordered,
          snapshotSize: ordered.length,
        );
      }

      Future<bool> pageUntilBoundary(Timeline timeline) async {
        return backfill(
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
      final requiresServerBoundary =
          room.prev_batch != null && room.prev_batch!.isNotEmpty;
      var boundarySatisfied = reachedTimestampBoundary(ordered);
      var pagingSatisfied = false;
      if (requiresServerBoundary || !boundarySatisfied) {
        pagingSatisfied = await pageUntilBoundary(snapshot);
        ordered = TimelineEventOrdering.sortStableByTimestamp(snapshot.events);
        boundarySatisfied = reachedTimestampBoundary(ordered);
      }

      bool needsMore(List<Event> current) =>
          !reachedTimestampBoundary(current) &&
          current.length >= limit &&
          limit < maxLookback;

      while (!requiresServerBoundary &&
          !pagingSatisfied &&
          needsMore(ordered)) {
        final doubled = limit * 2;
        limit = doubled > maxLookback ? maxLookback : doubled;
        final next = await room.getTimeline(limit: limit);
        try {
          pagingSatisfied = await pageUntilBoundary(next);
          ordered = TimelineEventOrdering.sortStableByTimestamp(next.events);
          boundarySatisfied = reachedTimestampBoundary(ordered);
        } finally {
          try {
            next.cancelSubscriptions();
          } catch (_) {}
        }
      }

      if (boundarySatisfied && (!requiresServerBoundary || pagingSatisfied)) {
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
        'reachedTimestampBoundary=$boundarySatisfied '
        'requiresServerBoundary=$requiresServerBoundary '
        'pagingSatisfied=$pagingSatisfied',
        domain: syncLoggingDomain,
        subDomain: 'catchup.incomplete',
      );
      return CatchUpCollection.incomplete(
        snapshotSize: ordered.length,
        visibleTailCount: visibleTailCount,
        fallbackLimit: missingMarkerFallbackLimit,
        reachedTimestampBoundary: boundarySatisfied,
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
