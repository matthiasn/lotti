import 'package:collection/collection.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

part 'bootstrap_backward_strategy.dart';
part 'bootstrap_forward_strategy.dart';

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
      required DomainLogger logging,
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
    required DomainLogger logging,
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
            } catch (e, st) {
              logging.error(
                LogDomain.sync,
                e,
                stackTrace: st,
                subDomain: 'catchup.noAnchor.cleanup',
              );
            }
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

      // When backfill alone didn't reach the boundary (either because the SDK
      // reported end-of-timeline prematurely, or there was no server gap),
      // expand the local timeline with larger limits. The SDK may have cached
      // more events locally than the initial limit returned.
      // Skip when pagingSatisfied: server backfill already loaded events into
      // the snapshot; creating new timelines would overwrite them with fewer
      // local-only events.
      while (!boundarySatisfied && !pagingSatisfied && needsMore(ordered)) {
        final doubled = limit * 2;
        limit = doubled > maxLookback ? maxLookback : doubled;
        final next = await room.getTimeline(limit: limit);
        try {
          if (!pagingSatisfied) {
            pagingSatisfied = await pageUntilBoundary(next);
          }
          ordered = TimelineEventOrdering.sortStableByTimestamp(next.events);
          boundarySatisfied = reachedTimestampBoundary(ordered);
        } finally {
          try {
            next.cancelSubscriptions();
          } catch (_) {}
        }
      }

      if (boundarySatisfied) {
        final start = _startIndexForTimestampBoundary(
          ordered,
          preContextSinceTs: preContextSinceTs,
          preContextCount: preContextCount,
        );
        logging.log(
          LogDomain.sync,
          'catchup.timestampBoundary '
          'snapshot=${ordered.length} '
          'lastEventId=${lastEventId ?? 'null'} '
          'startIndex=$start '
          'pagingSatisfied=$pagingSatisfied '
          'requiresServerBoundary=$requiresServerBoundary',
          subDomain: 'catchup.timestampBoundary',
        );
        return CatchUpCollection.timestampAnchored(
          events: ordered.sublist(start),
          snapshotSize: ordered.length,
        );
      }

      // The timestamp boundary was not reached, but we exhausted all
      // available history (backfill + local expansion). Rather than returning
      // empty and stalling the pipeline, return all visible events as a
      // best-effort catch-up. The pipeline's deduplication and vector clock
      // logic will handle any overlap, and marking catch-up as complete lets
      // live scans take over for subsequent events.
      if (ordered.isNotEmpty) {
        logging.log(
          LogDomain.sync,
          'catchup.bestEffort lastEventId=$lastEventId '
          'snapshot=${ordered.length} '
          'reason=timestampBoundaryUnreachable '
          'reachedTimestampBoundary=$boundarySatisfied '
          'requiresServerBoundary=$requiresServerBoundary '
          'pagingSatisfied=$pagingSatisfied',
          subDomain: 'catchup.bestEffort',
        );
        return CatchUpCollection.timestampAnchored(
          events: ordered,
          snapshotSize: ordered.length,
        );
      }

      final visibleTailCount = ordered.length <= missingMarkerFallbackLimit
          ? ordered.length
          : missingMarkerFallbackLimit;
      logging.log(
        LogDomain.sync,
        'catchup.incomplete lastEventId=$lastEventId '
        'snapshot=${ordered.length} visibleTail=$visibleTailCount '
        'fallbackLimit=$missingMarkerFallbackLimit '
        'reason=timestampBoundaryUnreachable '
        'reachedTimestampBoundary=$boundarySatisfied '
        'requiresServerBoundary=$requiresServerBoundary '
        'pagingSatisfied=$pagingSatisfied',
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

  /// Returns true when [event] is strictly older than the supplied
  /// anchor under lexicographic `(ts, eventId)` ordering. When the
  /// anchor is null (first-pass bootstrap), every event is considered
  /// older so the initial page is emitted in full.
  static bool _isStrictlyOlder(
    Event event, {
    required num? anchorTs,
    required String? anchorEventId,
  }) {
    if (anchorTs == null) return true;
    final ts = TimelineEventOrdering.timestamp(event);
    if (ts < anchorTs) return true;
    if (ts > anchorTs) return false;
    if (anchorEventId == null) return false;
    return event.eventId.compareTo(anchorEventId) < 0;
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

  /// See [collectHistoryForBootstrapImpl] in
  /// `bootstrap_backward_strategy.dart`.
  static Future<BootstrapResult> collectHistoryForBootstrap({
    required Room room,
    required BootstrapSink sink,
    required DomainLogger logging,
    int pageSize = 200,
    num? untilTimestamp,
    Duration? overallTimeout,
    int boundaryContinuationCap = 5,
    DateTime Function()? now,
  }) => collectHistoryForBootstrapImpl(
    room: room,
    sink: sink,
    logging: logging,
    pageSize: pageSize,
    untilTimestamp: untilTimestamp,
    overallTimeout: overallTimeout,
    boundaryContinuationCap: boundaryContinuationCap,
    now: now,
  );

  /// See [collectForwardForBootstrapImpl] in
  /// `bootstrap_forward_strategy.dart`.
  static Future<BootstrapResult> collectForwardForBootstrap({
    required Room room,
    required BootstrapSink sink,
    required DomainLogger logging,
    required String anchorEventId,
    int pageSize = 200,
    int forwardPageCap = 50,
    Duration? overallTimeout,
    DateTime Function()? now,
  }) => collectForwardForBootstrapImpl(
    room: room,
    sink: sink,
    logging: logging,
    anchorEventId: anchorEventId,
    pageSize: pageSize,
    forwardPageCap: forwardPageCap,
    overallTimeout: overallTimeout,
    now: now,
  );

  static bool _isStrictlyAfter(
    Event event, {
    required num? anchorTs,
    required String? anchorEventId,
  }) {
    if (anchorTs == null) return true;
    final ts = TimelineEventOrdering.timestamp(event);
    if (ts > anchorTs) return true;
    if (ts < anchorTs) return false;
    if (anchorEventId == null) return false;
    return event.eventId.compareTo(anchorEventId) > 0;
  }
}

/// Sink contract for [CatchUpStrategy.collectHistoryForBootstrap].
/// Implementations receive one page of events per call, oldest-first
/// within each page, and decide whether paging should continue.
///
/// Modelled as a one-method abstract class rather than a typedef so
/// concrete sinks (the queue's bootstrap sink, future progress-
/// reporting wrappers) can carry their own state and lifecycle.
abstract class BootstrapSink {
  /// Called once per page. Returning `false` stops paging (user
  /// cancel, back-pressure timeout, etc.). Implementations must not
  /// retain the [events] list across calls.
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info);

  /// Number of events the sink actually accepted on the most recent
  /// [onPage] call. Returns null when the sink does not track
  /// acceptance (e.g. pure progress-forwarding wrappers that don't
  /// themselves mutate state).
  ///
  /// [CatchUpStrategy.collectHistoryForBootstrap] reads this after
  /// each page when `untilTimestamp` is set. If the oldest event in
  /// a page crosses the boundary but the sink accepted zero events,
  /// that's the reconnect-gap signal: the SDK's local timeline cache
  /// may have a stale window that doesn't yet include the events
  /// between `untilTimestamp` and `now`. The strategy keeps
  /// paginating (up to a bounded cap) to give the SDK a chance to
  /// pull more history into the cache — which is where the missing
  /// events live after a long-offline wake-up.
  int? get lastAcceptedCount => null;
}

class BootstrapPageInfo {
  const BootstrapPageInfo({
    required this.pageIndex,
    required this.totalEventsSoFar,
    required this.oldestTimestampSoFar,
    required this.serverHasMore,
    required this.elapsed,
  });

  final int pageIndex;
  final int totalEventsSoFar;
  final num? oldestTimestampSoFar;
  final bool serverHasMore;
  final Duration elapsed;
}

class BootstrapResult {
  const BootstrapResult({
    required this.totalPages,
    required this.totalEvents,
    required this.oldestTimestampReached,
    required this.stopReason,
  });

  final int totalPages;
  final int totalEvents;
  final num? oldestTimestampReached;
  final BootstrapStopReason stopReason;
}

enum BootstrapStopReason {
  /// `timeline.canRequestHistory` returned false — the server has no
  /// more history to page into the room.
  serverExhausted,

  /// The sink returned `false` from [BootstrapSink.onPage] (user
  /// cancelled, back-pressure timeout, etc.).
  sinkCancelled,

  /// An `untilTimestamp` was supplied to
  /// [CatchUpStrategy.collectHistoryForBootstrap] and a page crossed
  /// the boundary — the callers has everything they asked for, no
  /// need to page further into history.
  boundaryReached,

  /// Pagination threw or the overall timeout elapsed before the walk
  /// completed. Callers should treat this as incomplete and retry
  /// later.
  error,
}
