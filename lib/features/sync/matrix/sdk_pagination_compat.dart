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
  /// Attempts to page the provided [timeline] in-place until either the
  /// earliest visible event crosses [untilTimestamp], [lastEventId] is present,
  /// [maxPages] is reached, or the SDK reports no more history.
  ///
  /// The timestamp boundary is the primary reconnect anchor. [lastEventId] is
  /// retained only as a legacy early-stop hint while older installs may still
  /// have one stored.
  ///
  /// Returns true if pagination was attempted or the boundary/marker was
  /// already visible. Returns false only if pagination could not be attempted
  /// at all.
  static Future<bool> backfillUntilContains({
    required Timeline timeline,
    required String? lastEventId,
    required int pageSize,
    required int? maxPages,
    required LoggingService logging,
    num? untilTimestamp,
  }) async {
    if (lastEventId == null) return false;
    try {
      var pages = 0;
      var anyPaged = false;
      while (maxPages == null || pages < maxPages) {
        final events = TimelineEventOrdering.sortStableByTimestamp(
          timeline.events,
        );
        if (untilTimestamp != null &&
            events.isNotEmpty &&
            TimelineEventOrdering.timestamp(events.first) <= untilTimestamp) {
          return anyPaged || events.isNotEmpty;
        }
        final contains = events.any((e) => e.eventId == lastEventId);
        if (contains) return true;

        if (!timeline.canRequestHistory) break;

        // Mark that we attempted pagination regardless of the outcome.
        anyPaged = true;
        final beforeCount = timeline.events.length;
        var ok = true;
        try {
          await timeline.requestHistory();
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
        pages++;
      }
      return anyPaged;
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
