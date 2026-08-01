import 'package:collection/collection.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

/// Forward-walks the server's timeline from [anchorEventId] to the
/// current tip and streams each page through [sink]. Use this on
/// reconnect whenever the local queue marker points at a known
/// `$`-prefixed event id — it is the Matrix-canonical way to close
/// a post-offline gap and, unlike [CatchUpStrategy.collectHistoryForBootstrap], it
/// does NOT reuse the SDK's cached backward-walking timeline.
///
/// How it works:
/// - `room.getTimeline(eventContextId: anchorEventId, limit: 0)` asks the
///   server for a fragmented timeline centred on the anchor via
///   `/rooms/{roomId}/context/{eventId}`. The returned chunk
///   carries `prev_batch` / `next_batch` tokens independent of
///   whatever the client has cached from prior sessions — so a
///   client whose cached oldest event is months below the gap
///   still gets a fresh server-side window here.
///   The zero database limit is essential: Matrix SDK 7.0.0 skips
///   the context request when the anchor is already present in its
///   local event cache, producing a non-fragmented timeline without
///   the forward token needed to close the reconnect gap.
/// - `timeline.requestFuture(historyCount: pageSize)` walks
///   forward via `/messages?dir=f`, one page at a time, emitting
///   each page through the sink until the server reports no more
///   future (`!canRequestFuture`) or a safety budget trips. Some
///   homeservers can return a non-empty context
///   window without a usable `next_batch` token, or a stale empty
///   `/messages` page after advertising a forward token. In either
///   case the walk probes another context window from the newest
///   emitted event; an empty probe is the authoritative
///   end-of-timeline signal.
///
/// The budget has two dimensions, and both are load-bearing:
/// [forwardRoundTripCap] bounds `/messages` requests and
/// [forwardEventCap] bounds events emitted. Counting only emitted
/// *pages* — as this did until a walk that had caught up to a live
/// burst was observed spending 50 round trips on 51 events — is
/// wrong in both directions. A page can hold a single event, so a
/// walk that reaches the tip while the peer is still sending gets
/// one event per round trip and burns a page budget sized for
/// [pageSize]-event pages; conversely a page that filters down to
/// empty never increments the page counter at all, so a server
/// returning nothing but already-emitted overlap could spin
/// indefinitely. Requests are the honest unit for the network
/// bound and events for the work bound.
///
/// Only events that sort strictly after the anchor under the
/// `(timestamp, eventId)` ordering are emitted, so the anchor itself
/// and any already-emitted overlap are filtered while same-millisecond
/// events retain deterministic ordering.
///
/// Returns `BootstrapStopReason.serverExhausted` when the walk
/// reaches the tip, `boundaryReached` when a budget trips,
/// `sinkCancelled` on sink return=false, and `error` on throw /
/// timeout.
///
/// `boundaryReached` from this walk always means "budget exhausted
/// while the server still had more" — a device that is genuinely
/// caught up stops with `serverExhausted`. Callers must therefore
/// treat it as an incomplete pass and schedule a retry; reporting
/// it as completed strands whatever is left of the gap until some
/// unrelated trigger happens along.
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
  int forwardRoundTripCap = SyncTuning.forwardWalkRoundTripCap,
  int forwardEventCap = SyncTuning.forwardWalkEventCap,
  Duration? overallTimeout,
  DateTime Function()? now,
}) async {
  final nowFn = now ?? DateTime.now;
  final start = nowFn();
  late Timeline timeline;
  try {
    timeline = await room.getTimeline(
      eventContextId: anchorEventId,
      limit: 0,
    );
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
      stopReason: BootstrapStopReason.error,
    );
  }
  final anchorTs = TimelineEventOrdering.timestamp(anchor);

  // What the context actually returned. A forward walk that emits nothing is
  // indistinguishable from a healthy "already at the tip" unless we can see
  // whether the server gave us events after the anchor at all, and whether it
  // handed back a forward token. `anchorTs == newestTs` is the signature of a
  // genuinely caught-up device; a missing forward window is not.
  //
  // What the context actually returned, so an empty walk can be told apart
  // from a healthy one.
  //
  // `strictlyAfter` is the load-bearing number, not `newestTs`. Ordering here
  // is by `(timestamp, eventId)`, so a burst can put later events on the same
  // millisecond as the anchor — and then `newestTs == anchorTs` even though
  // events genuinely sort after it. Reporting timestamps alone would show the
  // "caught up" signature for precisely the missing-forward-window case this
  // exists to identify. Counting through the same predicate the page filter
  // uses cannot drift from it.
  //
  // Unguarded on purpose: Dart builds the message eagerly, but the list is one
  // `/context` window (`Room.defaultHistoryCount` is 30) and it follows the
  // network round trip that produced it, so the cost is noise.
  num? newestTs;
  String? newestEventId;
  var strictlyAfter = 0;
  for (final event in timeline.events) {
    final ts = TimelineEventOrdering.timestamp(event);
    if (newestTs == null ||
        ts > newestTs ||
        (ts == newestTs &&
            (newestEventId == null ||
                event.eventId.compareTo(newestEventId) > 0))) {
      newestTs = ts;
      newestEventId = event.eventId;
    }
    if (CatchUpStrategy.isStrictlyAfter(
      event,
      anchorTs: anchorTs,
      anchorEventId: anchorEventId,
    )) {
      strictlyAfter++;
    }
  }
  logging.log(
    LogDomain.sync,
    'bootstrap.forward.context '
    'anchor=$anchorEventId '
    'events=${timeline.events.length} '
    'strictlyAfter=$strictlyAfter '
    'canRequestFuture=${timeline.canRequestFuture} '
    'anchorTs=$anchorTs '
    'newestTs=$newestTs newestEventId=$newestEventId',
    subDomain: 'bootstrap.forward',
  );

  var pageIndex = 0;
  var totalEventsSoFar = 0;
  // Every `/messages` and `/context` call the walk makes, starting at 1 for
  // the anchor context fetch above. Distinct from `pageIndex`, which only
  // counts pages that survived the strictly-after filter and reached the sink
  // — a request whose events all filter out costs the same network round trip
  // but no page.
  var roundTrips = 1;
  num? newestTsSoFar;
  String? newestEventIdSoFar;
  var contextAnchorEventId = anchorEventId;
  var stopReason = BootstrapStopReason.serverExhausted;

  String budgetLog() =>
      'roundTrips=$roundTrips cap=$forwardRoundTripCap '
      'events=$totalEventsSoFar eventCap=$forwardEventCap '
      'pages=$pageIndex';
  bool budgetExhausted() =>
      roundTrips >= forwardRoundTripCap || totalEventsSoFar >= forwardEventCap;

  try {
    while (true) {
      if (overallTimeout != null &&
          nowFn().difference(start) >= overallTimeout) {
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
        if (!CatchUpStrategy.isStrictlyAfter(
          event,
          anchorTs: anchorTs,
          anchorEventId: anchorEventId,
        )) {
          continue;
        }
        if (newestTsSoFar != null &&
            !CatchUpStrategy.isStrictlyAfter(
              event,
              anchorTs: newestTsSoFar,
              anchorEventId: newestEventIdSoFar,
            )) {
          continue;
        }
        page.add(event);
      }

      // The budget bounds fetching, but a budget-capped context response
      // without a forward token gets one final, un-emitted context
      // probe. That distinguishes a genuine server tip from a
      // homeserver's silently truncated context window.
      if (budgetExhausted()) {
        if (page.isNotEmpty) {
          logging.log(
            LogDomain.sync,
            'bootstrap.forward.capReached ${budgetLog()}',
            subDomain: 'bootstrap.forward',
          );
          stopReason = BootstrapStopReason.boundaryReached;
        } else {
          stopReason = BootstrapStopReason.serverExhausted;
        }
        break;
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
          // When the context contains a productive final window but
          // omits its forward token, we probe a new context from its
          // newest event before declaring the server exhausted.
          serverHasMore: timeline.canRequestFuture || page.isNotEmpty,
          elapsed: nowFn().difference(start),
        );
        final shouldContinue = await sink.onPage(page, info);
        pageIndex++;
        if (!shouldContinue) {
          stopReason = BootstrapStopReason.sinkCancelled;
          break;
        }
      }

      if (!timeline.canRequestFuture) {
        // Matrix SDK timelines only expose `canRequestFuture` when
        // `/context` includes a next_batch token. Dendrite and other
        // homeservers can return a capped `events_after` window
        // without one, which used to strand the tail after that first
        // window. Re-anchor on the newest event and make one more
        // server-context request. A context with no strictly newer
        // events proves that we have reached the tip.
        // A terminal context whose anchor already matches the newest
        // emitted event is our confirmation that the server has no
        // more events. Otherwise the immediately preceding
        // `requestFuture` may have returned an empty/stale page even
        // though a fresh `/context` call can still advance us.
        if (newestEventIdSoFar == null ||
            contextAnchorEventId == newestEventIdSoFar) {
          stopReason = BootstrapStopReason.serverExhausted;
          break;
        }

        try {
          timeline.cancelSubscriptions();
          final nextContextAnchorEventId = newestEventIdSoFar;
          roundTrips++;
          timeline = await room.getTimeline(
            eventContextId: nextContextAnchorEventId,
            limit: 0,
          );
          contextAnchorEventId = nextContextAnchorEventId;
        } catch (error, stackTrace) {
          logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: 'bootstrap.forward.getTimeline',
          );
          stopReason = BootstrapStopReason.error;
          break;
        }
        continue;
      }

      if (budgetExhausted()) {
        logging.log(
          LogDomain.sync,
          'bootstrap.forward.capReached ${budgetLog()}',
          subDomain: 'bootstrap.forward',
        );
        // The server still has more (`canRequestFuture` is true here),
        // so this is an incomplete pass, not a finished one. The caller
        // schedules a bounded retry that resumes from the new anchor.
        stopReason = BootstrapStopReason.boundaryReached;
        break;
      }

      try {
        roundTrips++;
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
    stopReason: stopReason,
  );
}
