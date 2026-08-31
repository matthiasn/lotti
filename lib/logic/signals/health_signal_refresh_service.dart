import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/domain_logging.dart';

/// Pulls journal-backed health signals forward from the platform health store.
///
/// Goal and habit surfaces read imported journal rows, and the Daily OS
/// timeline projects imported workouts onto its recorded lane. This service
/// owns the platform-type mapping and failure containment they share, without
/// making the always-available Habits feature depend on the Goals feature.
class HealthSignalRefreshService {
  HealthSignalRefreshService(
    this._healthImport, [
    this._domainLogger,
    this._logSubDomain = 'healthSignalRefresh',
  ]);

  final HealthImport _healthImport;
  final DomainLogger? _domainLogger;
  final String _logSubDomain;

  /// The import requests needed to refresh [dataTypes], de-duplicated and
  /// with composite families collapsed to their single platform request.
  static Set<String> importRequestsFor(Iterable<String> dataTypes) => {
    for (final dataType in dataTypes) ?importRequestFor(dataType),
  };

  /// The request [HealthImport] uses to refresh [dataType], or null when the
  /// type is stored inside Lotti rather than owned by the platform health API.
  static String? importRequestFor(String dataType) {
    for (final composite in HealthImport.compositeStorageTypes.entries) {
      // Only a composite that genuinely collapses several storage types. A
      // single-member composite is an alias, not a reason to rename a request.
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

  static const _healthDataTypePrefix = 'HealthDataType.';

  /// Queues each distinct entry in [requests] and contains import failures so
  /// one unavailable sensor cannot prevent the remaining signals refreshing.
  Future<void> refreshRequests(Iterable<String> requests) async {
    for (final request in requests.toSet()) {
      try {
        await _healthImport.fetchHealthDataDelta(request);
      } catch (error, stackTrace) {
        _domainLogger?.error(
          LogDomain.health,
          error,
          message: 'refreshing health signal "$request" failed',
          stackTrace: stackTrace,
          subDomain: _logSubDomain,
        );
      }
    }
  }

  /// Pulls workouts recorded since the newest stored one forward.
  ///
  /// Workouts are not a `HealthDataType` request — they have their own delta,
  /// throttled inside [HealthImport] — so a surface that shows recorded
  /// sessions (the Daily OS timeline) calls this rather than
  /// [refreshRequests]. Failures are contained the same way: the surface keeps
  /// painting what is stored.
  Future<void> refreshWorkouts() async {
    try {
      await _healthImport.getWorkoutsHealthDataDelta();
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.health,
        error,
        message: 'refreshing workouts failed',
        stackTrace: stackTrace,
        subDomain: _logSubDomain,
      );
    }
  }
}

/// Resolves the device importer where the current profile supports one.
/// Desktop, demo profiles, and tests without [HealthImport] get a no-op null.
final healthSignalRefreshServiceProvider =
    Provider<HealthSignalRefreshService?>(
      (ref) => getIt.isRegistered<HealthImport>()
          ? HealthSignalRefreshService(
              getIt<HealthImport>(),
              ref.watch(domainLoggerProvider),
            )
          : null,
      name: 'healthSignalRefreshServiceProvider',
    );
