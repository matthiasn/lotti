import 'dart:async';

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// SDK pagination helper for Matrix 2.x Timeline API.
///
/// This implementation targets our pinned Matrix SDK (2.x) and uses the
/// strongly-typed `Timeline.canRequestHistory` and `Timeline.requestHistory` APIs
/// directly. No reflective/dynamic fallbacks are used.
class SdkPaginationCompat {
  static bool _enableServerHistoryPaging(Timeline timeline) {
    final prevBatch = timeline.room.prev_batch;
    if (prevBatch == null || prevBatch.isEmpty) {
      return false;
    }

    // Startup catch-up must traverse the server-side gap that sits behind the
    // current /sync tail. The SDK timeline prefers the local event store until
    // it is exhausted, which can skip exactly the reconnect window we need.
    // Switching this disposable catch-up timeline into fragmented mode forces
    // requestHistory() to follow prev_batch on the server instead.
    timeline
      ..isFragmentedTimeline = true
      ..allowNewEvent = false;
    if (timeline.chunk.prevBatch.isEmpty) {
      timeline.chunk.prevBatch = prevBatch;
    }
    return true;
  }

  /// Attempts to page the provided [timeline] in-place until either the
  /// earliest visible event crosses [untilTimestamp], [lastEventId] is present,
  /// [maxPages] is reached, or the SDK reports no more history.
  ///
  /// The timestamp boundary is the primary reconnect anchor. [lastEventId] is
  /// retained only as a legacy early-stop hint while older installs may still
  /// have one stored.
  ///
  /// Returns true only when the requested timestamp boundary or [lastEventId]
  /// is visible after paging. Returns false when history was exhausted or
  /// pagination failed before the boundary was reached.
  static Future<bool> backfillUntilContains({
    required Timeline timeline,
    required String? lastEventId,
    required int pageSize,
    required int? maxPages,
    required LoggingService logging,
    num? untilTimestamp,
  }) async {
    if (lastEventId == null && untilTimestamp == null) return false;
    try {
      var pages = 0;
      var boundaryReached = false;
      var markerReached = false;
      final requireServerBoundaryPage =
          untilTimestamp != null && _enableServerHistoryPaging(timeline);
      logging.captureEvent(
        'backfill.start events=${timeline.events.length} '
        'requireServerBoundaryPage=$requireServerBoundaryPage '
        'lastEventId=$lastEventId '
        'untilTimestamp=$untilTimestamp',
        domain: syncLoggingDomain,
        subDomain: 'sdkPagination.backfill',
      );
      while (maxPages == null || pages < maxPages) {
        final events = TimelineEventOrdering.sortStableByTimestamp(
          timeline.events,
        );
        final tsBoundaryMet =
            untilTimestamp != null &&
            events.isNotEmpty &&
            TimelineEventOrdering.timestamp(events.first) <= untilTimestamp;
        if (tsBoundaryMet && (!requireServerBoundaryPage || boundaryReached)) {
          logging.captureEvent(
            'backfill.tsBoundary events=${events.length} pages=$pages',
            domain: syncLoggingDomain,
            subDomain: 'sdkPagination.backfill',
          );
          return true;
        }
        markerReached = events.any((e) => e.eventId == lastEventId);
        if (markerReached &&
            !requireServerBoundaryPage &&
            untilTimestamp == null) {
          logging.captureEvent(
            'backfill.markerReached events=${events.length} pages=$pages',
            domain: syncLoggingDomain,
            subDomain: 'sdkPagination.backfill',
          );
          return true;
        }

        if (!timeline.canRequestHistory) {
          logging.captureEvent(
            'backfill.cannotRequestHistory events=${events.length} '
            'pages=$pages boundaryReached=$boundaryReached '
            'tsBoundaryMet=$tsBoundaryMet',
            domain: syncLoggingDomain,
            subDomain: 'sdkPagination.backfill',
          );
          break;
        }

        final beforeCount = timeline.events.length;
        var ok = true;
        try {
          await timeline.requestHistory(historyCount: pageSize);
        } catch (e, st) {
          logging.captureException(
            e,
            domain: syncLoggingDomain,
            subDomain: 'sdkPagination.requestHistory',
            stackTrace: st,
          );
          ok = false;
        }
        if (!ok) break;
        if (timeline.events.length <= beforeCount) break;
        if (untilTimestamp != null) {
          final appended = timeline.events.sublist(beforeCount);
          if (appended.any(
            (event) => TimelineEventOrdering.timestamp(event) <= untilTimestamp,
          )) {
            boundaryReached = true;
          }
        }
        pages++;
      }
      if (untilTimestamp != null &&
          !requireServerBoundaryPage &&
          timeline.events.isNotEmpty) {
        final events = TimelineEventOrdering.sortStableByTimestamp(
          timeline.events,
        );
        if (TimelineEventOrdering.timestamp(events.first) <= untilTimestamp) {
          return true;
        }
      }
      if (untilTimestamp != null) {
        return boundaryReached;
      }
      return markerReached || boundaryReached;
    } catch (e, st) {
      logging.captureException(
        e,
        domain: syncLoggingDomain,
        subDomain: 'sdkPaginationCompat',
        stackTrace: st,
      );
      return false;
    }
  }
}
