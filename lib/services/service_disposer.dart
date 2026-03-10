import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
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
/// 4. Close application Drift databases
/// 5. Close the ObjectBox embedding store
class ServiceDisposer {
  ServiceDisposer(this._getIt, this._logError);

  final GetIt _getIt;
  final void Function(dynamic error, StackTrace stackTrace, String service)
  _logError;

  /// Disposes all services and databases. Used on non-macOS platforms.
  Future<void> disposeAll() async {
    await _disposeServices();
    await _disposeDatabases();
  }

  /// Disposes only non-database services. Used on macOS where calling
  /// sqlite3_close_v2 triggers a fatal FFI assertion (SIGABRT) during
  /// VM teardown — see window_service.dart for details.
  Future<void> disposeServicesOnly() async {
    await _disposeServices();
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
  }

  Future<void> _disposeDatabases() async {
    // 4. Close Drift databases so no WAL/lock files are left dangling.
    await _disposeAsyncSafely<JournalDb>((db) => db.close(), 'JournalDb');
    await _disposeAsyncSafely<SyncDatabase>((db) => db.close(), 'SyncDatabase');
    await _disposeAsyncSafely<AgentDatabase>(
      (db) => db.close(),
      'AgentDatabase',
    );
    await _disposeAsyncSafely<EditorDb>((db) => db.close(), 'EditorDb');
    await _disposeAsyncSafely<Fts5Db>((db) => db.close(), 'Fts5Db');
    await _disposeAsyncSafely<SettingsDb>((db) => db.close(), 'SettingsDb');

    // 5. Close the ObjectBox embedding store.
    _disposeSyncSafely<EmbeddingStore>(
      (s) => s.close(),
      'EmbeddingStore',
    );
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
