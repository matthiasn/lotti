import 'package:lotti/features/sync/matrix/pipeline/bootstrap_backward_strategy.dart';
import 'package:lotti/features/sync/matrix/pipeline/bootstrap_forward_strategy.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

/// Catch‑up helper used at attach time by the stream consumer.
class CatchUpStrategy {
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
    int forwardRoundTripCap = SyncTuning.forwardWalkRoundTripCap,
    int forwardEventCap = SyncTuning.forwardWalkEventCap,
    Duration? overallTimeout,
    DateTime Function()? now,
  }) => collectForwardForBootstrapImpl(
    room: room,
    sink: sink,
    logging: logging,
    anchorEventId: anchorEventId,
    pageSize: pageSize,
    forwardRoundTripCap: forwardRoundTripCap,
    forwardEventCap: forwardEventCap,
    overallTimeout: overallTimeout,
    now: now,
  );

  /// True when [event] sorts strictly after the anchor (timestamp, then event
  /// id as the deterministic tie-breaker). A null [anchorTs] means there is no
  /// anchor, so every event counts as after it.
  static bool isStrictlyAfter(
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

/// Per-page progress handed to a [BootstrapSink.onPage] call during a
/// bootstrap history walk: the 0-based [pageIndex], the running
/// [totalEventsSoFar], the [oldestTimestampSoFar] reached, whether the server
/// still has older pages ([serverHasMore]), and wall-clock [elapsed].
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

/// Summary of a completed bootstrap history walk: how many [totalPages] and
/// [totalEvents] were paged, and the [BootstrapStopReason] that ended paging.
class BootstrapResult {
  const BootstrapResult({
    required this.totalPages,
    required this.totalEvents,
    required this.stopReason,
  });

  final int totalPages;
  final int totalEvents;
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
  /// strictly below the boundary after exhausting its timestamp bucket — the
  /// caller has everything requested, with no need to page further into
  /// history.
  boundaryReached,

  /// Pagination threw or the overall timeout elapsed before the walk
  /// completed. Callers should treat this as incomplete and retry
  /// later.
  error,
}
