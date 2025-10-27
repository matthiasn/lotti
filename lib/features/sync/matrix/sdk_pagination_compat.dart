import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// SDK pagination/backfill helper for Matrix 2.x Timeline API.
///
/// This implementation targets our pinned Matrix SDK (2.x) and uses the
/// strongly-typed `Timeline.canRequestHistory` and `Timeline.requestHistory` APIs
/// directly. No reflective/dynamic fallbacks are used.
class SdkPaginationCompat {
  /// Attempts to backfill the provided [timeline] in-place using SDK
  /// pagination until either [lastEventId] is present in the events or
  /// [maxPages] is reached or the SDK reports no more history.
  ///
  /// Returns true if the target event is already present (no pagination
  /// required) or if at least one pagination call was attempted. Returns false
  /// only if pagination could not be attempted at all (no suitable SDK method
  /// is available or invocation failed before any attempt).
  static Future<bool> backfillUntilContains({
    required Timeline timeline,
    required String? lastEventId,
    required int pageSize,
    required int maxPages,
    required LoggingService logging,
  }) async {
    if (lastEventId == null) return false;
    try {
      var pages = 0;
      var anyPaged = false;
      while (pages < maxPages) {
        final events = List<Event>.from(timeline.events)
          ..sort(TimelineEventOrdering.compare);
        final contains = events.any((e) => e.eventId == lastEventId);
        if (contains) return true;

        if (!timeline.canRequestHistory) break;

        // Mark that we attempted pagination regardless of the outcome.
        anyPaged = true;
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
