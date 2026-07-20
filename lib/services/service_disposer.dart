import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';

/// Per-operation deadline so a single hung service cannot block the entire
/// shutdown sequence.
const _perOperationTimeout = Duration(seconds: 3);

/// Disposes long-running services and databases in dependency-safe order.
///
/// Each disposal is guarded independently so a failure or timeout in one does
/// not prevent the next service from being torn down.
///
/// Order matters:
/// 1. Stop periodic timers (BackfillRequestService, EmbeddingService)
/// 2. Stop the outbox (depends on MatrixService being alive)
/// 3. Stop Matrix sync and close its FFI-backed database
/// 4. Close the ObjectBox embedding store (no FFI-callback issue, safe on macOS)
/// 5. Close repositories that own private Drift databases
/// 6. Close all registered application Drift databases
class ServiceDisposer {
  ServiceDisposer(this._getIt, this._logError);

  final GetIt _getIt;
  final void Function(dynamic error, StackTrace stackTrace, String service)
  _logError;

  /// Disposes all services and databases during application shutdown.
  Future<void> disposeAll() async {
    await _disposeServices();
    await _disposeDatabases();
  }

  Future<void> _disposeServices() async {
    // 1. Stop periodic background services.
    _disposeSyncSafely<BackfillRequestService>(
      (s) => s.dispose(),
      'BackfillRequestService',
    );

    await _disposeAsyncSafely<EmbeddingService>(
      (s) => s.stop(),
      'EmbeddingService',
    );

    // 2. Dispose OutboxService (depends on MatrixService).
    await _disposeAsyncSafely<OutboxService>(
      (s) => s.dispose(),
      'OutboxService',
    );

    // 3. Dispose MatrixService (owns sync engine, streams, FFI database).
    await _disposeAsyncSafely<MatrixService>(
      (s) => s.dispose(),
      'MatrixService',
    );

    // 4. Close the ObjectBox embedding store. ObjectBox holds a native lock
    // file and does not register Dart NativeFinalizers, so it's safe to close
    // on macOS — unlike Drift/sqlite which is deferred to _disposeDatabases.
    _disposeSyncSafely<EmbeddingStore>(
      (s) => s.close(),
      'EmbeddingStore',
    );
  }

  Future<void> _disposeDatabases() async {
    // 5. Close repositories that own databases not registered directly.
    await _disposeAsyncSafely<AiConfigRepository>(
      (repository) => repository.close(),
      'AiConfigRepository',
    );

    // 6. Close every registered Drift database so no native handle is left
    // for a Dart finalizer to release after the Flutter engine starts tearing
    // down FFI callback metadata.
    await _disposeAsyncSafely<JournalDb>((db) => db.close(), 'JournalDb');
    await _disposeAsyncSafely<SyncDatabase>((db) => db.close(), 'SyncDatabase');
    await _disposeAsyncSafely<AgentDatabase>(
      (db) => db.close(),
      'AgentDatabase',
    );
    await _disposeAsyncSafely<EditorDb>((db) => db.close(), 'EditorDb');
    await _disposeAsyncSafely<Fts5Db>((db) => db.close(), 'Fts5Db');
    await _disposeAsyncSafely<ConsumptionDatabase>(
      (db) => db.close(),
      'ConsumptionDatabase',
    );
    await _disposeAsyncSafely<NotificationsDb>(
      (db) => db.close(),
      'NotificationsDb',
    );
    await _disposeAsyncSafely<OnboardingMetricsDb>(
      (db) => db.close(),
      'OnboardingMetricsDb',
    );
    await _disposeAsyncSafely<SettingsDb>((db) => db.close(), 'SettingsDb');
  }

  void _disposeSyncSafely<T extends Object>(
    void Function(T) action,
    String name,
  ) {
    if (!_getIt.isRegistered<T>()) return;
    try {
      action(_getIt<T>());
    } catch (e, s) {
      _logError(e, s, name);
    }
  }

  Future<void> _disposeAsyncSafely<T extends Object>(
    Future<void> Function(T) action,
    String name,
  ) async {
    if (!_getIt.isRegistered<T>()) return;
    try {
      await action(_getIt<T>()).timeout(_perOperationTimeout);
    } catch (e, s) {
      _logError(e, s, name);
    }
  }
}
