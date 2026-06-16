// Provider declarations follow the repo convention for files whose generic
// provider types are unwieldy (see dashboards_page_controller.dart).
// ignore_for_file: specify_nonobvious_property_types

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/repository/insights_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/device_region.dart';

/// Repository over the app-wide [journalDbProvider] (overridden in `main`).
final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(ref.watch(journalDbProvider)),
  name: 'insightsRepositoryProvider',
);

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
final insightsBucketsProvider = StreamProvider.autoDispose
    .family<InsightsDayBuckets, InsightsWindow>(
      (ref, window) {
        ref.cacheFor(dashboardCacheDuration);
        final repository = ref.watch(insightsRepositoryProvider);
        final notifications = ref.watch(maybeUpdateNotificationsProvider);
        final refetchThrottle = ref.watch(insightsRefetchThrottleProvider);

        Future<InsightsDayBuckets> fetch() async {
          // End of tomorrow for current-year windows (read at fetch time so
          // notification-driven refetches track a moving "now"), capped at
          // January 1st after the window's end year — a past-year custom
          // range never loads every year through today.
          final movingEnd = dayStart(epochDay(clock.now()) + 2);
          final cappedEnd = DateTime(window.endYear + 1);
          final rows = await repository.fetchTimeRows(
            start: dayStart(window.startDay),
            end: cappedEnd.isBefore(movingEnd) ? cappedEnd : movingEnd,
          );
          return bucketize(rows, windowStartDay: window.startDay);
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

/// Selected analysis period. Defaults to month-to-date — a populated first
/// paint (the current month's elapsed days) that answers "where did my time
/// go this month?" without the near-empty look of the current week early on.
///
/// Weeks start on the device region's first weekday (Monday across most of
/// Europe, Sunday in the US), read from [firstDayOfWeekIndexProvider] so the
/// dashboard matches the rest of the app. The stepper drives this:
/// [selectUnit] re-derives the period for a new granularity (keeping the
/// current anchor), [step] browses prev/next by one whole period, and
/// [selectToDate] jumps to the current month-to-date / year-to-date.
class InsightsRangeController extends Notifier<InsightsPeriodSelection> {
  // 0 = Sunday … 6 = Saturday; Monday until the region resolves. Held in a
  // field rather than re-read in build() so the async region lookup
  // resolving does not re-run build() and clobber the user's navigation or
  // compare toggle (see [build]).
  int _firstDayOfWeekIndex = defaultFirstDayOfWeekIndex;

  @override
  InsightsPeriodSelection build() {
    // Read (don't watch): the region lookup is a FutureProvider whose first
    // frame is null → Monday, then resolves. Watching would re-run build()
    // on resolution and discard any step()/jumpTo()/toggleCompare() in
    // between. Instead we re-anchor through a listener, and only while the
    // selection is still the untouched default — never overwriting
    // navigation or comparison.
    _firstDayOfWeekIndex =
        ref.read(firstDayOfWeekIndexProvider).value ??
        defaultFirstDayOfWeekIndex;

    ref.listen(firstDayOfWeekIndexProvider, (previous, next) {
      final resolved = next.value;
      if (resolved == null || resolved == _firstDayOfWeekIndex) return;
      final previousIndex = _firstDayOfWeekIndex;
      _firstDayOfWeekIndex = resolved;
      // Re-anchor only while the user is still viewing the current period
      // (hasn't stepped or jumped away). Re-derive that period under the new
      // first weekday, preserving the chosen unit and compare toggle. For
      // non-week units periodContaining ignores the index, so this is a
      // no-op there.
      final onCurrentPeriod =
          state.range ==
          periodContaining(
            state.unit,
            clock.now(),
            firstDayOfWeekIndex: previousIndex,
          );
      if (onCurrentPeriod) {
        state = state.copyWith(
          range: periodContaining(
            state.unit,
            clock.now(),
            firstDayOfWeekIndex: resolved,
          ),
        );
      }
    });

    return _defaultSelection();
  }

  /// The default landing selection: month-to-date. A populated first paint —
  /// the current month's elapsed days — instead of a near-empty current week
  /// early in the week. Month bounds are weekday-independent, so this needs no
  /// first-weekday arg.
  InsightsPeriodSelection _defaultSelection() => InsightsPeriodSelection(
    unit: InsightsPeriodUnit.month,
    range: periodToDate(InsightsPeriodUnit.month, clock.now()),
  );

  /// Comparison baseline for the current selection — `null` unless compare is
  /// on. The current range is first clipped to its elapsed slice
  /// ([elapsedPortion]) so an in-progress period compares like-for-like: the
  /// current week-to-date against the same elapsed days of last week, never a
  /// single day against a complete prior week. [previousPeriod] then truncates
  /// the previous period to that same elapsed day count.
  ///
  /// Derived purely from the already-aligned `state.range` (week shifts the
  /// bounds directly), so it never re-snaps and stays in step with the current
  /// range even if the device-region first weekday resolves after the range was
  /// built. (The page used to re-derive this with a hardcoded Monday default,
  /// which misaligned the comparison for Sunday/Saturday regions.)
  InsightsRange? get previousComparisonRange => state.compareEnabled
      ? previousPeriod(
          elapsedPortion(state.range, clock.now()),
          state.unit,
        )
      : null;

  /// Switches the browsed granularity, re-deriving the period that contains
  /// the current range's start day.
  void selectUnit(InsightsPeriodUnit unit) {
    state = state.copyWith(
      unit: unit,
      range: periodContaining(
        unit,
        dayStart(state.range.startDay),
        firstDayOfWeekIndex: _firstDayOfWeekIndex,
      ),
    );
  }

  /// Jumps to the to-date portion of the current period of [unit] — month
  /// start through today for MTD, January 1st through today for YTD. The
  /// MTD/YTD shortcut pills call this.
  void selectToDate(InsightsPeriodUnit unit) {
    state = state.copyWith(
      unit: unit,
      range: periodToDate(
        unit,
        clock.now(),
        firstDayOfWeekIndex: _firstDayOfWeekIndex,
      ),
    );
  }

  /// Steps to the previous (`delta < 0`) or next (`delta > 0`) period of the
  /// current granularity.
  void step(int delta) {
    state = state.copyWith(
      range: shiftPeriod(state.range, state.unit, delta),
    );
  }

  /// Jumps to the period of the current granularity that contains [date].
  /// Used by the calendar picker to reach a far-off period directly.
  void jumpTo(DateTime date) {
    state = state.copyWith(
      range: periodContaining(
        state.unit,
        date,
        firstDayOfWeekIndex: _firstDayOfWeekIndex,
      ),
    );
  }

  /// Turns the previous-period comparison on or off.
  void toggleCompare() {
    state = state.copyWith(compareEnabled: !state.compareEnabled);
  }
}

/// Deliberately not autoDispose: the selection is tiny and should survive
/// tab switches, mirroring how pane selections behave elsewhere in the app.
final insightsRangeControllerProvider =
    NotifierProvider<InsightsRangeController, InsightsPeriodSelection>(
      InsightsRangeController.new,
      name: 'insightsRangeControllerProvider',
    );
