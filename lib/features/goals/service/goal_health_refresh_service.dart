import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
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
/// Automatic health-linked habit check-off (ticking "Measure Blood Pressure"
/// because a reading exists) is deliberately NOT here: it writes habit
/// completions on the user's behalf and is tracked as its own change.
class GoalHealthRefreshService {
  GoalHealthRefreshService(this._healthImport, [this._domainLogger]);

  final HealthImport _healthImport;

  /// Optional: a failed refresh is logged where a logger exists and swallowed
  /// where one does not. It must never take down the page it fired from.
  final DomainLogger? _domainLogger;

  /// The types [criteria] read from the platform health store, as import
  /// requests — de-duplicated, and with each composite family collapsed onto
  /// the one request that fetches all of its members in a single pass.
  static Set<String> importRequestsFor(Iterable<GoalCriterion> criteria) => {
    for (final criterion in criteria)
      for (final dataType in goalCriterionMetricDataTypes(criterion))
        ?importRequestFor(dataType),
  };

  /// The import [HealthImport] would have to run to freshen [dataType], or
  /// null where the type is not the platform health store's to give.
  ///
  /// Both tables are read off the importer rather than restated here: a fourth
  /// activity type or a second composite family added there must not leave the
  /// goal surfaces silently blind to it.
  static String? importRequestFor(String dataType) {
    for (final composite in HealthImport.compositeStorageTypes.entries) {
      // Only a composite that genuinely COLLAPSES several storage types: one
      // blood-pressure reading is two samples, and requesting the halves
      // separately would queue two imports for what the user authorized once.
      // A single-member composite (`BODY_MASS_INDEX` → weight) is an alias for
      // a dashboard's benefit, not a collapse — it fetches exactly the same
      // samples under a name a weight goal has no business asking for.
      if (composite.value.length > 1 && composite.value.contains(dataType)) {
        return composite.key;
      }
    }
    if (HealthImport.activityStorageTypes.contains(dataType) ||
        dataType.startsWith(_healthDataTypePrefix)) {
      return dataType;
    }
    return null;
  }

  /// The naming convention `HealthImport.resolveHealthDataTypes` resolves
  /// against — everything the `health` plugin owns arrives under it. A habit,
  /// a measurable or tracked time is written inside Lotti and is current by
  /// construction, so nothing outside this prefix is worth re-importing.
  static const _healthDataTypePrefix = 'HealthDataType.';

  /// Queues a delta import for every health signal [criteria] watch.
  ///
  /// Never throws: a failed import must leave the page it was opened from
  /// working, showing whatever was already stored.
  Future<void> refreshForCriteria(Iterable<GoalCriterion> criteria) =>
      refreshRequests(importRequestsFor(criteria));

  /// Queues a delta import for each already-resolved request.
  Future<void> refreshRequests(Iterable<String> requests) async {
    for (final request in requests) {
      try {
        await _healthImport.fetchHealthDataDelta(request);
      } catch (error, stackTrace) {
        _domainLogger?.error(
          LogDomain.health,
          error,
          message: 'refreshing goal health signal "$request" failed',
          stackTrace: stackTrace,
          subDomain: 'goalHealthRefresh',
        );
      }
    }
  }
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
