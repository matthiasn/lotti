part of 'catch_up_strategy.dart';

/// Streams the room's visible history through [sink] in oldest-
/// first pages, one page at a time. Used both by the "Fetch all
/// history" Sync-Settings action and by the queue bridge's
/// reconnect catch-up.
///
/// Terminates when any of these is true:
/// - The sink returns `false` from [BootstrapSink.onPage] (user
///   cancelled the bootstrap).
/// - [untilTimestamp] is supplied AND a page crossed the boundary
///   AND the sink accepted ≥ 1 event. The guard on accepted count
///   is the reconnect-gap fix: after a long-offline wake-up the
///   SDK's local timeline cache can be stale — a page whose oldest
///   event is older than the marker but whose contents are all
///   dupes/filtered means the SDK cache hasn't loaded the events
///   in the `[untilTimestamp, now]` window yet. Paging further
///   (up to [boundaryContinuationCap]) gives the SDK a chance to
///   bring more history into its cache. If the sink still can't
///   accept anything after the cap, we genuinely have nothing new
///   in this walk and stop.
/// - The SDK's timeline reports no more history.
/// - [overallTimeout] elapses.
///
/// Our bookkeeping stays O(1) across pages: we dedup via a single
/// `(oldest emitted timestamp, oldest emitted event id)` anchor
/// rather than an ever-growing seen-set of every event id. The
/// anchor advances monotonically — older pages can only deliver
/// events strictly older than it — which matches what
/// `requestHistory()` guarantees. Note: the underlying
/// `timeline.events` list is owned by the Matrix SDK and keeps
/// growing as more history loads; bounding that is out of our hands
/// without a Timeline API that we do not have in 7.0.0. What we
/// control — our own per-run state — stays constant regardless of
/// total history depth.
///
/// [boundaryContinuationCap] bounds how many extra pages are pulled
/// past the boundary when the sink keeps reporting `accepted=0`.
/// Each extra page costs one `requestHistory` round-trip. Five is
/// a compromise between "pull enough history to populate the SDK
/// cache for the wake-up window" and "don't walk indefinitely on
/// a steady-state bridge run."
Future<BootstrapResult> collectHistoryForBootstrapImpl({
  required Room room,
  required BootstrapSink sink,
  required DomainLogger logging,
  int pageSize = 200,
  num? untilTimestamp,
  Duration? overallTimeout,
  int boundaryContinuationCap = 5,
  DateTime Function()? now,
}) async {
  final nowFn = now ?? DateTime.now;
  final start = nowFn();
  final timeline = await room.getTimeline(limit: pageSize);
  var pageIndex = 0;
  var totalEventsSoFar = 0;
  num? oldestTsSoFar;
  String? oldestEventIdSoFar;
  var stopReason = BootstrapStopReason.serverExhausted;
  // Counts pages emitted past the `untilTimestamp` boundary when
  // the sink reported `accepted=0`. Guards against unbounded
  // pagination while still letting the walk go deeper to close
  // reconnect gaps where the SDK's cache was incomplete.
  var boundaryContinuations = 0;

  try {
    while (true) {
      if (overallTimeout != null &&
          nowFn().difference(start) >= overallTimeout) {
        stopReason = BootstrapStopReason.error;
        break;
      }

      final sorted = TimelineEventOrdering.sortStableByTimestamp(
        timeline.events,
      );
      // Build the page by filtering to events strictly older than
      // the anchor. On the first pass the anchor is null so every
      // event is included; on subsequent passes only the rows that
      // `requestHistory()` just loaded (which must be older than the
      // previous oldest) pass the predicate. This replaces the old
      // per-event seen-set.
      final page = <Event>[];
      for (final event in sorted) {
        if (CatchUpStrategy._isStrictlyOlder(
          event,
          anchorTs: oldestTsSoFar,
          anchorEventId: oldestEventIdSoFar,
        )) {
          page.add(event);
        }
      }

      if (page.isNotEmpty) {
        totalEventsSoFar += page.length;
        final firstTs = TimelineEventOrdering.timestamp(page.first);
        if (oldestTsSoFar == null || firstTs < oldestTsSoFar) {
          oldestTsSoFar = firstTs;
          oldestEventIdSoFar = page.first.eventId;
        } else if (firstTs == oldestTsSoFar) {
          // Timestamps tied but the first event advanced — keep the
          // earliest (ts, eventId) pair as the anchor.
          final firstId = page.first.eventId;
          if (oldestEventIdSoFar == null ||
              firstId.compareTo(oldestEventIdSoFar) < 0) {
            oldestEventIdSoFar = firstId;
          }
        }
        final info = BootstrapPageInfo(
          pageIndex: pageIndex,
          totalEventsSoFar: totalEventsSoFar,
          oldestTimestampSoFar: oldestTsSoFar,
          serverHasMore: timeline.canRequestHistory,
          elapsed: nowFn().difference(start),
        );
        final shouldContinue = await sink.onPage(page, info);
        pageIndex++;
        if (!shouldContinue) {
          stopReason = BootstrapStopReason.sinkCancelled;
          break;
        }
        // Bridge reconnect path: when a page crosses the timestamp
        // marker, the default assumption is "anything older is
        // already in the local DB — stop." We relax that when the
        // sink accepted zero events from the boundary-crossing
        // page: all-dupes-or-filtered means the SDK's local
        // timeline cache didn't include anything new in the target
        // window, which on a wake-up from a long-offline period is
        // exactly the signal that events in `[untilTimestamp, now]`
        // haven't been pulled into the cache yet. Keep paginating
        // up to [boundaryContinuationCap] extra pages so subsequent
        // `requestHistory` calls bring more of the server's
        // history into the cache — including any pages the SDK
        // hadn't loaded on the initial `room.getTimeline`.
        final crossedBoundary =
            untilTimestamp != null &&
            TimelineEventOrdering.timestamp(page.first) <= untilTimestamp;
        if (crossedBoundary) {
          final accepted = sink.lastAcceptedCount;
          if (accepted != null && accepted > 0) {
            stopReason = BootstrapStopReason.boundaryReached;
            break;
          }
          // Cap N => N continuation attempts (N extra requestHistory
          // calls past the boundary-crossing page). Check before
          // incrementing so the counter reflects attempts already
          // issued, not attempts about to fire.
          if (boundaryContinuations >= boundaryContinuationCap) {
            logging.log(
              LogDomain.sync,
              'bootstrap.boundaryContinuation.exhausted '
              'pages=$boundaryContinuations cap=$boundaryContinuationCap',
              subDomain: 'bootstrap',
            );
            stopReason = BootstrapStopReason.boundaryReached;
            break;
          }
          boundaryContinuations++;
          logging.log(
            LogDomain.sync,
            'bootstrap.boundaryContinuation '
            'attempt=$boundaryContinuations cap=$boundaryContinuationCap '
            'reason=accepted=0 oldestTs='
            '${TimelineEventOrdering.timestamp(page.first)}',
            subDomain: 'bootstrap',
          );
        }
      }

      if (!timeline.canRequestHistory) {
        stopReason = BootstrapStopReason.serverExhausted;
        break;
      }

      try {
        await timeline.requestHistory(historyCount: pageSize);
      } catch (error, stackTrace) {
        logging.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'bootstrap.requestHistory',
        );
        stopReason = BootstrapStopReason.error;
        break;
      }
    }
  } finally {
    // The SDK timeline retains resources until cancelled; make sure
    // a bootstrap finishing early does not leak the subscription.
    try {
      timeline.cancelSubscriptions();
    } catch (_) {
      // cancelSubscriptions is best-effort; swallow so callers see
      // the BootstrapResult rather than a late cleanup error.
    }
  }

  return BootstrapResult(
    totalPages: pageIndex,
    totalEvents: totalEventsSoFar,
    oldestTimestampReached: oldestTsSoFar,
    stopReason: stopReason,
  );
}
