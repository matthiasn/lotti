// ignore_for_file: avoid_dynamic_calls

import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Best-effort SDK pagination/backfill helper.
///
/// Some versions of the Matrix Dart SDK expose timeline pagination via
/// requestHistory/canRequestHistory on the Timeline snapshot, but the exact
/// API surface may differ. This helper uses dynamic calls to preserve
/// compatibility across versions and falls back gracefully.
class SdkPaginationCompat {
  /// Attempts to backfill the provided [timeline] in-place using SDK
  /// pagination until either [lastEventId] is present in the events or
  /// [maxPages] is reached or the SDK reports no more history.
  ///
  /// Returns true if pagination was attempted (regardless of whether the
  /// target event was found), false if pagination could not be attempted.
  static Future<bool> backfillUntilContains({
    required Timeline timeline,
    required String? lastEventId,
    required int pageSize,
    required int maxPages,
    required LoggingService logging,
  }) async {
    if (lastEventId == null) return false;
    try {
      // Use dynamic to tolerate SDK surface differences.
      final dyn = timeline as dynamic;
      var pages = 0;
      while (pages < maxPages) {
        final events = List<Event>.from(dyn.events as List<Event>)
          ..sort(TimelineEventOrdering.compare);
        final contains = events.any((e) => e.eventId == lastEventId);
        if (contains) return true;

        final canMore = _canRequestHistory(dyn);
        if (!canMore) break;

        final ok = await _requestMoreHistory(dyn, pageSize, logging);
        if (!ok) break;

        pages++;
      }
      return true; // we attempted pagination even if not found
    } catch (e, st) {
      logging.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'sdkPaginationCompat',
        stackTrace: st,
      );
      return false;
    }
  }

  static bool _canRequestHistory(dynamic timeline) {
    try {
      // Common conventions tried in order; default to true if unknown.
      if (timeline.canRequestHistory is bool) {
        return timeline.canRequestHistory as bool;
      }
      if (timeline.hasMoreHistory is bool) {
        return timeline.hasMoreHistory as bool;
      }
    } catch (_) {}
    return true;
  }

  static Future<bool> _requestMoreHistory(
    dynamic timeline,
    int pageSize,
    LoggingService logging,
  ) async {
    try {
      // Try the common API names. If one exists, use it.
      if (timeline.requestHistory is Function) {
        final result = await timeline.requestHistory(pageSize);
        if (result is bool) return result;
        return true; // treat void as success
      }
      if (timeline.paginateBackwards is Function) {
        final result = await timeline.paginateBackwards(pageSize);
        if (result is bool) return result;
        return true; // treat void as success
      }
    } catch (e, st) {
      logging.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'sdkPaginationCompat.request',
        stackTrace: st,
      );
      return false;
    }
    // No known pagination method found.
    logging.captureEvent(
      'SDK timeline pagination not available',
      domain: 'MATRIX_SYNC_V2',
      subDomain: 'sdkPaginationCompat',
    );
    return false;
  }
}
