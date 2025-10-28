import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/services/logging_service.dart';

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

/// Provides the shared [LoggingDb] instance. Must be overridden in [ProviderScope].
final loggingDbProvider = Provider<LoggingDb>(
  (ref) => throw UnimplementedError(
    'loggingDbProvider must be overridden before use.',
  ),
  name: 'loggingDbProvider',
);

/// Provides the shared [LoggingService]. Must be overridden in [ProviderScope].
final loggingServiceProvider = Provider<LoggingService>(
  (ref) => throw UnimplementedError(
    'loggingServiceProvider must be overridden before use.',
  ),
  name: 'loggingServiceProvider',
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

/// Provides the shared [AiConfigRepository]. Must be overridden in [ProviderScope].
final aiConfigRepositoryProvider = Provider<AiConfigRepository>(
  (ref) => throw UnimplementedError(
    'aiConfigRepositoryProvider must be overridden before use.',
  ),
  name: 'aiConfigRepositoryProvider',
);

/// Tracks Matrix events emitted by this device so echo responses can be
/// suppressed.
final sentEventRegistryProvider = Provider<SentEventRegistry>(
  (ref) => throw UnimplementedError(
    'sentEventRegistryProvider must be overridden before use.',
  ),
  name: 'sentEventRegistryProvider',
);
