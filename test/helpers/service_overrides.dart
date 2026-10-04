import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Marks the overrides [getItServiceOverrides] builds, so
/// [withServiceOverrides] can tell them apart from a test's own.
final _generated = Expando<bool>('getItServiceOverride');

/// Provider overrides that resolve the core services from getIt.
///
/// Production wires these providers in `buildProviderOverrides`. Tests set
/// their services up in getIt (`setUpTestGetIt` or their own mocks), often
/// after building the container, so each override reads getIt lazily — on the
/// provider's first read, exactly where the code used to call `getIt<T>()` —
/// and an unregistered service fails the same way a getIt lookup did.
List<Override> getItServiceOverrides() => [
  for (final override in <Override>[
    journalDbProvider.overrideWith((ref) => getIt<JournalDb>()),
    settingsDbProvider.overrideWith((ref) => getIt<SettingsDb>()),
    persistenceLogicProvider.overrideWith((ref) => getIt<PersistenceLogic>()),
    navServiceProvider.overrideWith((ref) => getIt<NavService>()),
    timeServiceProvider.overrideWith((ref) => getIt<TimeService>()),
    vectorClockServiceProvider.overrideWith(
      (ref) => getIt<VectorClockService>(),
    ),
    loggingServiceProvider.overrideWith((ref) => getIt<LoggingService>()),
    outboxServiceProvider.overrideWith((ref) => getIt<OutboxService>()),
    maintenanceProvider.overrideWith((ref) => getIt<Maintenance>()),
    syncDatabaseProvider.overrideWith((ref) => getIt<SyncDatabase>()),
  ])
    _mark(override),
];

Override _mark(Override override) {
  _generated[override] = true;
  return override;
}

/// [overrides] plus [getItServiceOverrides] for every service [overrides]
/// does not already override — a provider overridden twice is an error.
///
/// Idempotent: service overrides an inner call already added are dropped and
/// derived again, so nesting — a helper that wraps, spread into a list that
/// also overrides a service explicitly — never overrides a provider twice, and
/// an explicit override always wins.
///
/// The shared widget harnesses (`makeTestableWidget*`, the test benches) route
/// their overrides through this, so a widget test gets the services it
/// registered in getIt without listing them.
List<Override> withServiceOverrides(List<Override> overrides) {
  final explicit = [
    for (final override in overrides)
      if (_generated[override] != true) override,
  ];
  final taken = {for (final override in explicit) override.origin};
  return [
    for (final override in getItServiceOverrides())
      if (!taken.contains(override.origin)) override,
    ...explicit,
  ];
}
