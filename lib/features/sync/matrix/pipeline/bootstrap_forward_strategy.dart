part of 'catch_up_strategy.dart';

/// Forward-walks the server's timeline from [anchorEventId] to the
/// current tip and streams each page through [sink]. Use this on
/// reconnect whenever the local queue marker points at a known
/// `$`-prefixed event id — it is the Matrix-canonical way to close
/// a post-offline gap and, unlike [CatchUpStrategy.collectHistoryForBootstrap], it
/// does NOT reuse the SDK's cached backward-walking timeline.
///
/// How it works:
/// - `room.getTimeline(eventContextId: anchorEventId)` asks the
///   server for a fragmented timeline centred on the anchor via
///   `/rooms/{roomId}/context/{eventId}`. The returned chunk
///   carries `prev_batch` / `next_batch` tokens independent of
///   whatever the client has cached from prior sessions — so a
///   client whose cached oldest event is months below the gap
///   still gets a fresh server-side window here.
/// - `timeline.requestFuture(historyCount: pageSize)` walks
///   forward via `/messages?dir=f`, one page at a time, emitting
///   each page through the sink until the server reports no more
///   future (`!canRequestFuture`) or the [forwardPageCap] safety
///   cap trips.
///
/// Only events whose timestamp is strictly greater than the
/// anchor's own timestamp are emitted — the anchor itself and any
/// events that happen to tie at the same ms on the first chunk are
/// filtered, since by definition we've already applied them.
///
/// Returns `BootstrapStopReason.serverExhausted` when the walk
/// reaches the tip, `boundaryReached` when the cap trips (so
/// callers treat the pass as "completed" and don't schedule a
/// bounded retry), `sinkCancelled` on sink return=false, and
/// `error` on throw / timeout.
///
/// When `getEventContext` returns null (anchor no longer resolvable
/// — rare, requires server-side compaction), the method returns a
/// `BootstrapResult` with `stopReason=error` and zero pages. The
/// caller is expected to fall back to
/// [CatchUpStrategy.collectHistoryForBootstrap] in that case.
Future<BootstrapResult> collectForwardForBootstrapImpl({
  required Room room,
  required BootstrapSink sink,
  required DomainLogger logging,
  required String anchorEventId,
  int pageSize = 200,
  int forwardPageCap = 50,
  Duration? overallTimeout,
}) async {
  final start = DateTime.now();
  final Timeline timeline;
  try {
    timeline = await room.getTimeline(eventContextId: anchorEventId);
  } catch (error, stackTrace) {
    logging.error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: 'bootstrap.forward.getTimeline',
    );
    return const BootstrapResult(
      totalPages: 0,
      totalEvents: 0,
      oldestTimestampReached: null,
      stopReason: BootstrapStopReason.error,
    );
  }

  // The context chunk may not actually contain the anchor (server
  // compacted it out, or the SDK's internal `getEventContext`
  // returned an empty chunk). In that case we cannot trust the
  // "events after the anchor" filter and must bail so the caller
  // can fall back to a different strategy.
  final anchor = timeline.events.firstWhereOrNull(
    (e) => e.eventId == anchorEventId,
  );
  if (anchor == null) {
    logging.log(
      LogDomain.sync,
      'bootstrap.forward.anchorMissing '
      'anchorEventId=$anchorEventId events=${timeline.events.length}',
      subDomain: 'bootstrap.forward',
    );
    try {
      timeline.cancelSubscriptions();
    } catch (_) {}
    return const BootstrapResult(
      totalPages: 0,
      totalEvents: 0,
      oldestTimestampReached: null,
      stopReason: BootstrapStopReason.error,
    );
  }
  final anchorTs = TimelineEventOrdering.timestamp(anchor);

  var pageIndex = 0;
  var totalEventsSoFar = 0;
  num? newestTsSoFar;
  String? newestEventIdSoFar;
  var stopReason = BootstrapStopReason.serverExhausted;

  try {
    while (true) {
      if (overallTimeout != null &&
          DateTime.now().difference(start) >= overallTimeout) {
        stopReason = BootstrapStopReason.error;
        break;
      }

      // Sort oldest-first for deterministic page ordering + the
      // sink's "events[].first = oldest" contract.
      final sorted = TimelineEventOrdering.sortStableByTimestamp(
        timeline.events,
      );

      // Build the page: events strictly newer than the anchor AND
      // strictly newer than what we've already emitted. On the
      // first iteration `newestTsSoFar` is null so the filter only
      // strips the anchor itself and ties; on subsequent
      // iterations the filter strips everything we already sent.
      final page = <Event>[];
      for (final event in sorted) {
        if (!CatchUpStrategy._isStrictlyAfter(
          event,
          anchorTs: anchorTs,
          anchorEventId: anchorEventId,
        )) {
          continue;
        }
        if (newestTsSoFar != null &&
            !CatchUpStrategy._isStrictlyAfter(
              event,
              anchorTs: newestTsSoFar,
              anchorEventId: newestEventIdSoFar,
            )) {
          continue;
        }
        page.add(event);
      }

      if (page.isNotEmpty) {
        totalEventsSoFar += page.length;
        final lastTs = TimelineEventOrdering.timestamp(page.last);
        if (newestTsSoFar == null || lastTs > newestTsSoFar) {
          newestTsSoFar = lastTs;
          newestEventIdSoFar = page.last.eventId;
        } else if (lastTs == newestTsSoFar) {
          final lastId = page.last.eventId;
          if (newestEventIdSoFar == null ||
              lastId.compareTo(newestEventIdSoFar) > 0) {
            newestEventIdSoFar = lastId;
          }
        }
        final info = BootstrapPageInfo(
          pageIndex: pageIndex,
          totalEventsSoFar: totalEventsSoFar,
          oldestTimestampSoFar: newestTsSoFar,
          serverHasMore: timeline.canRequestFuture,
          elapsed: DateTime.now().difference(start),
        );
        final shouldContinue = await sink.onPage(page, info);
        pageIndex++;
        if (!shouldContinue) {
          stopReason = BootstrapStopReason.sinkCancelled;
          break;
        }
      }

      if (!timeline.canRequestFuture) {
        stopReason = BootstrapStopReason.serverExhausted;
        break;
      }

      if (pageIndex >= forwardPageCap) {
        logging.log(
          LogDomain.sync,
          'bootstrap.forward.capReached '
          'pages=$pageIndex cap=$forwardPageCap '
          'events=$totalEventsSoFar',
          subDomain: 'bootstrap.forward',
        );
        // Treat as completed rather than error — the cap is a
        // safety net against runaway walks, not a bug. The bridge
        // coordinator's retry-on-incomplete path would only thrash
        // here; instead we stop and let the next organic reconnect
        // trigger pick up any remaining tail.
        stopReason = BootstrapStopReason.boundaryReached;
        break;
      }

      try {
        await timeline.requestFuture(historyCount: pageSize);
      } catch (error, stackTrace) {
        logging.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'bootstrap.forward.requestFuture',
        );
        stopReason = BootstrapStopReason.error;
        break;
      }
    }
  } finally {
    try {
      timeline.cancelSubscriptions();
    } catch (_) {}
  }

  return BootstrapResult(
    totalPages: pageIndex,
    totalEvents: totalEventsSoFar,
    oldestTimestampReached: newestTsSoFar,
    stopReason: stopReason,
  );
}
