import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
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
  /// requests — de-duplicated, and with the blood-pressure pair collapsed onto
  /// the one composite request that fetches both halves in a single pass.
  static Set<String> importRequestsFor(Iterable<GoalCriterion> criteria) => {
    for (final criterion in criteria)
      for (final dataType in goalCriterionMetricDataTypes(criterion))
        if (GoalHealthDataTypes.isPlatformHealthImported(dataType))
          _importRequest(dataType),
  };

  static String _importRequest(String dataType) => switch (dataType) {
    GoalHealthDataTypes.bloodPressureSystolic ||
    GoalHealthDataTypes.bloodPressureDiastolic => _bloodPressureRequest,
    _ => dataType,
  };

  /// `HealthImport.compositeStorageTypes`' key for the systolic/diastolic
  /// pair. Requesting the halves separately would queue two imports and raise
  /// the authorization question twice for what the user turned on once.
  static const _bloodPressureRequest = 'BLOOD_PRESSURE';

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
