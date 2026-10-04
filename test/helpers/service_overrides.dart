import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Provider overrides for the core services a test registered in getIt.
///
/// Production wires these providers in `buildProviderOverrides`; a test that
/// sets its services up through `setUpTestGetIt` (or registers its own mocks)
/// spreads this into its `ProviderContainer` / `ProviderScope` overrides so
/// code reading the providers sees the same instances the test stubs.
List<Override> getItServiceOverrides() => [
  if (getIt.isRegistered<JournalDb>())
    journalDbProvider.overrideWithValue(getIt<JournalDb>()),
  if (getIt.isRegistered<SettingsDb>())
    settingsDbProvider.overrideWithValue(getIt<SettingsDb>()),
  if (getIt.isRegistered<PersistenceLogic>())
    persistenceLogicProvider.overrideWithValue(getIt<PersistenceLogic>()),
  if (getIt.isRegistered<NavService>())
    navServiceProvider.overrideWithValue(getIt<NavService>()),
  if (getIt.isRegistered<TimeService>())
    timeServiceProvider.overrideWithValue(getIt<TimeService>()),
  if (getIt.isRegistered<VectorClockService>())
    vectorClockServiceProvider.overrideWithValue(getIt<VectorClockService>()),
];
