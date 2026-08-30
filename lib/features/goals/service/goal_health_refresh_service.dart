import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/signals/health_signal_refresh_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Pulls a goal's health signals forward when the user opens a goal surface.
///
/// A goal that watches steps, weight or blood pressure reads *journal* rows,
/// and those rows only exist for samples Lotti has already imported. Nothing
/// else on the goals surfaces triggers an import — the background wake tiers
/// evaluate what is stored, they do not fetch — so without this a goal page
/// could show yesterday's weight beside today's date and be entirely correct
/// about the database while wrong about the user.
///
/// Deliberately fire-and-forget: [HealthImport.fetchHealthDataDelta] queues
/// the type and returns, one import runs at a time behind the shared
/// authorization gate, and the page paints from what is stored while the
/// delta lands. The resulting journal write notifies the projections, which is
/// what refreshes the cards.
///
/// This only refreshes imported rows. Habit completion remains owned by the
/// habit auto-completion service, which reacts to the resulting journal write.
class GoalHealthRefreshService extends HealthSignalRefreshService {
  GoalHealthRefreshService(HealthImport healthImport, [DomainLogger? logger])
    : super(healthImport, logger, 'goalHealthRefresh');

  /// The types [criteria] read from the platform health store, as import
  /// requests — de-duplicated, and with each composite family collapsed onto
  /// the one request that fetches all of its members in a single pass.
  static Set<String> importRequestsFor(Iterable<GoalCriterion> criteria) =>
      HealthSignalRefreshService.importRequestsFor(
        criteria.expand(goalCriterionMetricDataTypes),
      );

  /// Queues a delta import for every health signal [criteria] watch.
  ///
  /// Never throws: a failed import must leave the page it was opened from
  /// working, showing whatever was already stored.
  Future<void> refreshForCriteria(Iterable<GoalCriterion> criteria) =>
      refreshRequests(importRequestsFor(criteria));
}

/// The goal surfaces' health refresher.
///
/// Resolves [HealthImport] from GetIt, but tolerates its absence: on a
/// platform or in a test where no importer is registered the refresh is a
/// no-op rather than an exception thrown out of a page's first frame.
final goalHealthRefreshServiceProvider = Provider<GoalHealthRefreshService?>(
  (ref) => getIt.isRegistered<HealthImport>()
      ? GoalHealthRefreshService(
          getIt<HealthImport>(),
          ref.watch(domainLoggerProvider),
        )
      : null,
  name: 'goalHealthRefreshServiceProvider',
);

/// Re-imports a goal surface's health signals once per visit.
///
/// The subtle half of "refresh on entry" is not the fan-out — the service owns
/// that — but *when*: the goal pages rebuild on every provider tick, and their
/// specs resolve asynchronously, so the request has to be de-duplicated across
/// rebuilds and deferred past the frame that discovered it. Both goal surfaces
/// mix this in rather than keeping a copy of it each.
mixin GoalHealthRefreshOnEntry<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  final Set<String> _refreshedHealthRequests = {};

  /// Queues a delta import for every health signal [criteria] watch, skipping
  /// anything already requested this visit.
  ///
  /// Safe to call from `build`: the import is a side effect of ARRIVING here,
  /// not of painting, so it is fired after the frame and never awaited. The
  /// page renders from what is already stored while the delta lands.
  void refreshHealthSignals(Iterable<GoalCriterion> criteria) {
    final pending = GoalHealthRefreshService.importRequestsFor(
      criteria,
    ).difference(_refreshedHealthRequests);
    if (pending.isEmpty) return;
    _refreshedHealthRequests.addAll(pending);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = ref.read(goalHealthRefreshServiceProvider);
      if (service == null) return;
      unawaited(service.refreshRequests(pending));
    });
  }
}
