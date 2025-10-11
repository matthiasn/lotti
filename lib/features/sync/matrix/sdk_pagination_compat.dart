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
      // Use dynamic to tolerate SDK surface differences.
      final dyn = timeline as dynamic;
      var pages = 0;
      var anyPaged = false;
      while (pages < maxPages) {
        final events = List<Event>.from(dyn.events as List<Event>)
          ..sort(TimelineEventOrdering.compare);
        final contains = events.any((e) => e.eventId == lastEventId);
        if (contains) return true;

        final canMore = _canRequestHistory(dyn);
        if (!canMore) break;

        // Mark that we attempted pagination regardless of the outcome.
        anyPaged = true;
        final ok = await _requestMoreHistory(dyn, pageSize, logging);
        if (!ok) break;
        pages++;
      }
      return anyPaged;
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
    // Try requestHistory(pageSize) then requestHistory()
    try {
      if (timeline.requestHistory is Function) {
        try {
          final result = await timeline.requestHistory(pageSize);
          if (result is bool) return result;
          return true; // treat void as success
        } catch (e, st) {
          logging.captureException(
            e,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'sdkPaginationCompat.request',
            stackTrace: st,
          );
        }
        try {
          final result = await timeline.requestHistory();
          if (result is bool) return result;
          return true;
        } catch (e, st) {
          logging.captureException(
            e,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'sdkPaginationCompat.request.noarg',
            stackTrace: st,
          );
        }
      }
    } catch (_) {}

    // Try paginateBackwards(pageSize) then paginateBackwards()
    try {
      if (timeline.paginateBackwards is Function) {
        try {
          final result = await timeline.paginateBackwards(pageSize);
          if (result is bool) return result;
          return true;
        } catch (e, st) {
          logging.captureException(
            e,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'sdkPaginationCompat.backwards',
            stackTrace: st,
          );
        }
        try {
          final result = await timeline.paginateBackwards();
          if (result is bool) return result;
          return true;
        } catch (e, st) {
          logging.captureException(
            e,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'sdkPaginationCompat.backwards.noarg',
            stackTrace: st,
          );
        }
      }
    } catch (_) {}

    // No known pagination method found or all attempts failed.
    logging.captureEvent(
      'SDK timeline pagination not available',
      domain: 'MATRIX_SYNC_V2',
      subDomain: 'sdkPaginationCompat',
    );
    return false;
  }
}
