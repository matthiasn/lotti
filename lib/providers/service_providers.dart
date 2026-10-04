import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/outbox_service.dart';

/// Provides the configured [MatrixService]. Must be overridden in [ProviderScope].
final matrixServiceProvider = Provider<MatrixService>(
  (ref) => throw UnimplementedError(
    'matrixServiceProvider must be overridden before use.',
  ),
  name: 'matrixServiceProvider',
);

/// Provides the shared [Maintenance] service. Must be overridden in [ProviderScope].
final maintenanceProvider = Provider<Maintenance>(
  (ref) => throw UnimplementedError(
    'maintenanceProvider must be overridden before use.',
  ),
  name: 'maintenanceProvider',
);

/// Provides the shared [JournalDb] instance. Must be overridden in [ProviderScope].
final journalDbProvider = Provider<JournalDb>(
  (ref) => throw UnimplementedError(
    'journalDbProvider must be overridden before use.',
  ),
  name: 'journalDbProvider',
);

/// Provides the shared [SyncDatabase] instance. Must be overridden in [ProviderScope].
final syncDatabaseProvider = Provider<SyncDatabase>(
  (ref) => throw UnimplementedError(
    'syncDatabaseProvider must be overridden before use.',
  ),
  name: 'syncDatabaseProvider',
);

/// Provides the shared [LoggingService]. Must be overridden in [ProviderScope].
final loggingServiceProvider = Provider<LoggingService>(
  (ref) => throw UnimplementedError(
    'loggingServiceProvider must be overridden before use.',
  ),
  name: 'loggingServiceProvider',
);

/// The shared [DomainLogger].
///
/// `buildProviderOverrides` overrides it with the generation's instance, whose
/// domain flags `DomainLogger.listenToDomainFlags` keeps current. A scope
/// built without those overrides — a test — reads the getIt instance if one is
/// registered, else a standalone logger: no domain is enabled on it, and its
/// [LoggingService] writes nothing in a test environment, so code that only
/// logs needs no wiring at all.
final domainLoggerProvider = Provider<DomainLogger>(
  (ref) => getIt.isRegistered<DomainLogger>()
      ? getIt<DomainLogger>()
      : DomainLogger(loggingService: LoggingService()),
  name: 'domainLoggerProvider',
);

/// The shared [EntitiesCacheService], or `null` in a world without one.
///
/// `buildProviderOverrides` supplies the registered instance. Readers treat
/// `null` as "no cached definitions" — a category then has no settings of its
/// own — so a test wires one only when it needs categories.
final entitiesCacheServiceProvider = Provider<EntitiesCacheService?>(
  (ref) => null,
  name: 'entitiesCacheServiceProvider',
);

/// Provides the shared [OutboxService]. Must be overridden in [ProviderScope].
final outboxServiceProvider = Provider<OutboxService>(
  (ref) => throw UnimplementedError(
    'outboxServiceProvider must be overridden before use.',
  ),
  name: 'outboxServiceProvider',
);

/// Emits an event whenever the Outbox hits the login gate during a send attempt.
final outboxLoginGateStreamProvider = StreamProvider<void>(
  (ref) => ref.watch(outboxServiceProvider).notLoggedInGateStream,
  name: 'outboxLoginGateStreamProvider',
);
