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

/// Provider overrides that resolve the core services from getIt.
///
/// Production wires these providers in `buildProviderOverrides`. Tests set
/// their services up in getIt (`setUpTestGetIt` or their own mocks), often
/// after building the container, so each override reads getIt lazily — on the
/// provider's first read, exactly where the code used to call `getIt<T>()` —
/// and an unregistered service fails the same way a getIt lookup did.
List<Override> getItServiceOverrides() => [
  journalDbProvider.overrideWith((ref) => getIt<JournalDb>()),
  settingsDbProvider.overrideWith((ref) => getIt<SettingsDb>()),
  persistenceLogicProvider.overrideWith((ref) => getIt<PersistenceLogic>()),
  navServiceProvider.overrideWith((ref) => getIt<NavService>()),
  timeServiceProvider.overrideWith((ref) => getIt<TimeService>()),
  vectorClockServiceProvider.overrideWith((ref) => getIt<VectorClockService>()),
  loggingServiceProvider.overrideWith((ref) => getIt<LoggingService>()),
  outboxServiceProvider.overrideWith((ref) => getIt<OutboxService>()),
  maintenanceProvider.overrideWith((ref) => getIt<Maintenance>()),
  syncDatabaseProvider.overrideWith((ref) => getIt<SyncDatabase>()),
];

/// [overrides] plus [getItServiceOverrides] for every service [overrides]
/// does not already override — a provider overridden twice is an error.
///
/// The shared widget harness (`makeTestableWidget*`) routes its overrides
/// through this, so a widget test gets the services it registered in getIt
/// without listing them, and keeps any explicit override it does list.
List<Override> withServiceOverrides(List<Override> overrides) {
  final taken = {for (final override in overrides) override.origin};
  return [
    for (final override in getItServiceOverrides())
      if (!taken.contains(override.origin)) override,
    ...overrides,
  ];
}
