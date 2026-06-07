// Provider declarations follow the repo convention for files whose generic
// provider types are unwieldy (see dashboards_page_controller.dart).
// ignore_for_file: specify_nonobvious_property_types

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/repository/insights_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Repository over the app-wide [journalDbProvider] (overridden in `main`).
final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(ref.watch(journalDbProvider)),
  name: 'insightsRepositoryProvider',
);

/// Bucketized time data for the window starting at the given epoch day.
///
/// Architecture decisions (each from the adversarial design review):
///
/// - **Family-keyed windows.** The window key is January 1st of the
///   range-start year (see [windowStartDayFor]), so every preset within a
///   year shares one in-memory bucket cache and range switching never
///   touches the database. A different year is a *new provider instance* —
///   no in-place mutable window, hence no stale-write races.
/// - **[notificationDrivenItemStream]** serializes refetches (an update
///   arriving mid-fetch queues exactly one follow-up) and cancels its
///   subscription when the last listener goes away.
/// - **[CacheForExtension.cacheFor]** keeps recently used windows alive
///   across tab switches so returning to the dashboard doesn't cold-reload.
/// - **Deep value equality** on [InsightsDayBuckets] means a refetch with
///   unchanged data emits an equal value and dependents don't rebuild —
///   background refreshes never flash the UI.
/// Throttle for notification-driven window refetches.
///
/// Active typing fires a notification batch every ~100ms; without a
/// throttle every batch re-runs the full window query (~35-130ms at
/// 10k-50k entries — measured). Trailing-edge, mirroring the Daily OS
/// time-history throttle, so the last change in a burst always lands.
/// Overridable in tests (set to `null` for immediate refetches).
final insightsRefetchThrottleProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 5),
  name: 'insightsRefetchThrottleProvider',
);

final insightsBucketsProvider = StreamProvider.autoDispose
    .family<InsightsDayBuckets, int>(
      (ref, windowStartDay) {
        ref.cacheFor(dashboardCacheDuration);
        final repository = ref.watch(insightsRepositoryProvider);
        final notifications = ref.watch(maybeUpdateNotificationsProvider);
        final refetchThrottle = ref.watch(insightsRefetchThrottleProvider);

        Future<InsightsDayBuckets> fetch() async {
          final rows = await repository.fetchTimeRows(
            start: dayStart(windowStartDay),
            // End of tomorrow: the dashboard analyzes recorded time, and
            // every preset range ends today. Read at fetch time so
            // notification-driven refetches track a moving "now".
            end: dayStart(epochDay(clock.now()) + 2),
          );
          return bucketize(rows, windowStartDay: windowStartDay);
        }

        if (notifications == null) {
          return Stream.fromFuture(fetch());
        }
        // Tasks are subscribed because category attribution follows task
        // links — and standalone link create/unlink fires only
        // linkNotification, so re-linking a time entry to another task
        // refreshes attribution too. Audio is irrelevant (JournalAudio
        // carries no tracked time here). The private toggle changes which
        // rows the query may return, so it refetches as well.
        return notificationDrivenItemStream<InsightsDayBuckets>(
          notifications: notifications,
          notificationKeys: const {
            textEntryNotification,
            taskNotification,
            linkNotification,
            privateToggleNotification,
          },
          fetcher: fetch,
          refetchThrottle: refetchThrottle,
        ).map((buckets) => buckets ?? InsightsDayBuckets.empty);
      },
      name: 'insightsBucketsProvider',
    );

/// Selected analysis range. Defaults to the trailing 7 days — the range
/// that answers "where did my time go this week?".
class InsightsRangeController extends Notifier<InsightsRange> {
  @override
  InsightsRange build() => resolvePreset(InsightsRangePreset.d7, clock.now());

  void selectPreset(InsightsRangePreset preset) {
    state = resolvePreset(preset, clock.now());
  }

  /// Applies a custom day range picked in the calendar (inclusive bounds,
  /// any order).
  void selectCustom(DateTime a, DateTime b) {
    state = customRange(a, b);
  }
}

/// Deliberately not autoDispose: the selection is tiny and should survive
/// tab switches, mirroring how pane selections behave elsewhere in the app.
final insightsRangeControllerProvider =
    NotifierProvider<InsightsRangeController, InsightsRange>(
      InsightsRangeController.new,
      name: 'insightsRangeControllerProvider',
    );
