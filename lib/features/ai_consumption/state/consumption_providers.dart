// Provider declarations follow the repo convention for files whose generic
// provider types are unwieldy (see insights_providers.dart).
// ignore_for_file: specify_nonobvious_property_types

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai_consumption/logic/attribution_cost.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_bucketing.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show dayStart, epochDay;
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/utils/cache_extension.dart';

/// The app-wide [ConsumptionRepository] (registered in get_it at startup).
/// Overridable in tests.
final consumptionRepositoryProvider = Provider<ConsumptionRepository>(
  (ref) => getIt<ConsumptionRepository>(),
  name: 'consumptionRepositoryProvider',
);

class AiAttributionDetails {
  const AiAttributionDetails({
    required this.attribution,
    required this.interactions,
    required this.costTotals,
    this.costAssessments = const [],
  });

  final AiWorkAttribution attribution;
  final List<AiConsumptionEvent> interactions;
  final AiCostTotals costTotals;
  final List<AiInteractionCost> costAssessments;
}

Future<AiAttributionDetails?> _fetchAttributionDetails(
  ConsumptionRepository repository,
  AiWorkAttribution? attribution,
) async {
  if (attribution == null) return null;
  final interactions = await repository.interactionsForAttribution(
    attribution.id,
  );
  final costs = await repository.costsForAttribution(attribution.id);
  return AiAttributionDetails(
    attribution: attribution,
    interactions: interactions,
    costTotals: aggregateEffectiveCosts(costs),
    costAssessments: costs,
  );
}

final aiAttributionDetailsProvider = FutureProvider.autoDispose
    .family<AiAttributionDetails?, String>((ref, attributionId) async {
      final repository = ref.watch(consumptionRepositoryProvider);
      return _fetchAttributionDetails(
        repository,
        await repository.getAttribution(attributionId),
      );
    }, name: 'aiAttributionDetailsProvider');

final aiAttributionForArtifactProvider = FutureProvider.autoDispose
    .family<AiAttributionDetails?, AiArtifactReference>((ref, artifact) async {
      final repository = ref.watch(consumptionRepositoryProvider);
      return _fetchAttributionDetails(
        repository,
        await repository.getAttributionForArtifact(artifact),
      );
    }, name: 'aiAttributionForArtifactProvider');

/// Throttle for notification-driven consumption refetches. Consumption rows
/// arrive in bursts during agent wakes (one per turn); the trailing-edge
/// throttle keeps the dashboard from re-querying on every turn while still
/// landing the final state. Overridable in tests (`null` = immediate).
final consumptionRefetchThrottleProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 5),
  name: 'consumptionRefetchThrottleProvider',
);

/// Lifetime consumption totals for one task, refreshed whenever a consumption
/// event lands locally or via sync (`aiConsumptionNotification`).
final taskConsumptionTotalsProvider = StreamProvider.autoDispose
    .family<ConsumptionTotals, String>(
      (ref, taskId) {
        final repository = ref.watch(consumptionRepositoryProvider);
        final notifications = ref.watch(maybeUpdateNotificationsProvider);
        final refetchThrottle = ref.watch(consumptionRefetchThrottleProvider);

        Future<ConsumptionTotals> fetch() => repository.totalsForTask(taskId);

        if (notifications == null) {
          return Stream.fromFuture(fetch());
        }
        return notificationDrivenItemStream<ConsumptionTotals>(
          notifications: notifications,
          notificationKeys: const {aiConsumptionNotification},
          fetcher: fetch,
          refetchThrottle: refetchThrottle,
        ).map((totals) => totals ?? ConsumptionTotals.empty);
      },
      name: 'taskConsumptionTotalsProvider',
    );

/// Bucketized consumption for the window starting at the given epoch day.
///
/// A structural clone of `insightsBucketsProvider` (same year-window family
/// key, serialized notification-driven refetches, [CacheForExtension.cacheFor],
/// and deep value equality on [ConsumptionDayBuckets] so unchanged refetches
/// never rebuild dependents). Consumption rows carry a denormalized
/// `category_id`, so — unlike the time dashboard — no task/link notifications
/// are needed: only [aiConsumptionNotification] changes what this query
/// returns.
final consumptionBucketsProvider = StreamProvider.autoDispose
    .family<ConsumptionDayBuckets, InsightsWindow>(
      (ref, window) {
        ref.cacheFor(dashboardCacheDuration);
        final repository = ref.watch(consumptionRepositoryProvider);
        final notifications = ref.watch(maybeUpdateNotificationsProvider);
        final refetchThrottle = ref.watch(consumptionRefetchThrottleProvider);

        Future<ConsumptionDayBuckets> fetch() async {
          // End of tomorrow for current-year windows (read at fetch time so
          // notification-driven refetches track a moving "now"), capped at
          // January 1st after the window's end year.
          final movingEnd = dayStart(epochDay(clock.now()) + 2);
          final cappedEnd = DateTime(window.endYear + 1);
          final rows = await repository.metricRowsInRange(
            start: dayStart(window.startDay),
            end: cappedEnd.isBefore(movingEnd) ? cappedEnd : movingEnd,
          );
          return bucketize(rows, windowStartDay: window.startDay);
        }

        if (notifications == null) {
          return Stream.fromFuture(fetch());
        }
        return notificationDrivenItemStream<ConsumptionDayBuckets>(
          notifications: notifications,
          notificationKeys: const {aiConsumptionNotification},
          fetcher: fetch,
          refetchThrottle: refetchThrottle,
          // The fetcher always yields a value (failures surface via
          // addError), so the helper's nullable item type is asserted away
          // rather than carrying a dead fallback branch.
        ).map((buckets) => buckets!);
      },
      name: 'consumptionBucketsProvider',
    );

/// How many calls the ledger shows per period. The dashboard surfaces this
/// cap explicitly ("newest N of M") — never a silent truncation.
const kConsumptionLedgerLimit = 100;

/// The newest individual calls inside the selected range, newest first,
/// capped at [kConsumptionLedgerLimit] — feeds the per-call ledger table.
/// Family-keyed by the value-equal [InsightsRange] so period stepping swaps
/// cleanly between cached instances.
final consumptionLedgerProvider = StreamProvider.autoDispose
    .family<List<AiConsumptionEvent>, InsightsRange>(
      (ref, range) {
        ref.cacheFor(dashboardCacheDuration);
        final repository = ref.watch(consumptionRepositoryProvider);
        final notifications = ref.watch(maybeUpdateNotificationsProvider);
        final refetchThrottle = ref.watch(consumptionRefetchThrottleProvider);

        Future<List<AiConsumptionEvent>> fetch() =>
            repository.newestEventsInRange(
              start: dayStart(range.startDay),
              end: dayStart(range.endDayExclusive),
              limit: kConsumptionLedgerLimit,
            );

        if (notifications == null) {
          return Stream.fromFuture(fetch());
        }
        return notificationDrivenItemStream<List<AiConsumptionEvent>>(
          notifications: notifications,
          notificationKeys: const {aiConsumptionNotification},
          fetcher: fetch,
          refetchThrottle: refetchThrottle,
        ).map((events) => events ?? const []);
      },
      name: 'consumptionLedgerProvider',
    );

/// Selected analysis period for the impact dashboard. Reuses
/// [InsightsRangeController] wholesale — the period machinery (units, to-date
/// presets, stepping, first-weekday handling) is identical; only the state
/// instance is separate so the impact and time dashboards browse
/// independently.
final consumptionRangeControllerProvider =
    NotifierProvider<InsightsRangeController, InsightsPeriodSelection>(
      InsightsRangeController.new,
      name: 'consumptionRangeControllerProvider',
    );
