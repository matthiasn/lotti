import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    hide aiConfigRepositoryProvider;
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/utils/fd_limits.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:media_kit/media_kit.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';

class AppConstants {
  const AppConstants._();

  static const Size defaultWindowSize = Size(1280, 720);
  static const Size minimumWindowSize = Size(360, 640);
}

/// Held for the lifetime of the process so the listener stays subscribed and
/// `onExitRequested` is invoked when macOS / desktop OS asks the app to quit.
// ignore: unused_element
late final AppLifecycleListener _appLifecycleListener;

/// Closes every Drift database before the engine tears down isolates.
///
/// Without this, Drift databases are closed via Dart `Finalizer` during VM
/// shutdown. SQLite's `sqlite3_close_v2` then walks registered application
/// functions and invokes their `xDestroy` FFI callbacks back into Dart — but
/// the VM is already in cleanup, so `DLRT_GetFfiCallbackMetadata` asserts and
/// the process aborts with SIGABRT. Closing here drains writer + read-pool
/// isolates while the VM is still healthy.
///
/// The close list itself lives in [ServiceDisposer.disposeDatabases] — the
/// single source of truth shared with the window-close path in
/// `WindowService` — so a database added there is covered on every exit path.
Future<AppExitResponse> _handleAppExitRequested() async {
  await ServiceDisposer(getIt, _logExitDisposalError).disposeDatabases();

  // Flush logs last so any close-time entries (errors caught above, drift
  // teardown messages) make it to disk before the engine tears down.
  if (getIt.isRegistered<LoggingService>()) {
    try {
      await getIt<LoggingService>().flush();
    } catch (_) {
      // Best-effort: the process is exiting; swallow to avoid masking exit.
    }
  }

  return AppExitResponse.exit;
}

void _logExitDisposalError(
  dynamic error,
  StackTrace stackTrace,
  String service,
) {
  try {
    getIt<DomainLogger>().error(
      LogDomain.general,
      error as Object,
      stackTrace: stackTrace,
      subDomain: 'onExitRequested:$service',
    );
  } catch (_) {
    // Logging may already be torn down while the app is exiting.
  }
}

Future<void> main() async {
  // Raise the file descriptor soft limit before anything opens an FD. On
  // macOS, GUI apps inherit launchd's legacy soft limit of 256, which is
  // trivially exhausted (sockets, SQLite, attachments, logs). Captured
  // synchronously so we can log the outcome once LoggingService exists.
  final fdAdjustment = ensureFileDescriptorSoftLimit();

  await runZonedGuarded(
    () async {
      // Register DomainLogger immediately after its LoggingService sink so the
      // startup diagnostics below — and the runZonedGuarded error handler — can
      // resolve it before registerSingletons() runs. registerSingletons() then
      // reuses this instance instead of re-registering.
      final loggingService = LoggingService();
      getIt
        ..registerSingleton<LoggingService>(
          loggingService,
          dispose: (service) => service.dispose(),
        )
        ..registerSingleton<DomainLogger>(
          DomainLogger(loggingService: loggingService),
        );

      getIt<DomainLogger>().log(
        LogDomain.general,
        fdAdjustment.toString(),
        subDomain: 'fdLimits',
      );

      WidgetsFlutterBinding.ensureInitialized();
      try {
        MediaKit.ensureInitialized();
      } catch (e) {
        getIt<DomainLogger>().error(
          LogDomain.general,
          e,
          subDomain:
              'MediaKit initialization failed - continuing without media support',
        );
      }
      Animate.restartOnHotReload = true;

      if (isDesktop) {
        await windowManager.ensureInitialized();
        await hotKeyManager.unregisterAll();

        // Configure window options for flatpak compatibility
        const windowOptions = WindowOptions(
          size: AppConstants.defaultWindowSize,
          minimumSize: AppConstants.minimumWindowSize,
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
        );
        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }

      final docDir = await findDocumentsDirectory();

      getIt
        ..registerSingleton<SecureStorage>(SecureStorage())
        ..registerSingleton<Directory>(docDir)
        ..registerSingleton<SettingsDb>(SettingsDb())
        ..registerSingleton<WindowService>(WindowService());

      await getIt<WindowService>().restore();
      tz.initializeTimeZones();

      await registerSingletons();

      _appLifecycleListener = AppLifecycleListener(
        onExitRequested: _handleAppExitRequested,
      );

      FlutterError.onError = (FlutterErrorDetails details) {
        getIt<DomainLogger>().error(
          LogDomain.general,
          details.exception,
          stackTrace: details.stack,
          subDomain: details.library,
        );
      };

      runApp(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(getIt<MatrixService>()),
            maintenanceProvider.overrideWithValue(getIt<Maintenance>()),
            journalDbProvider.overrideWithValue(getIt<JournalDb>()),
            syncDatabaseProvider.overrideWithValue(getIt<SyncDatabase>()),
            loggingServiceProvider.overrideWithValue(getIt<LoggingService>()),
            outboxServiceProvider.overrideWithValue(getIt<OutboxService>()),
            aiConfigRepositoryProvider.overrideWithValue(
              getIt<AiConfigRepository>(),
            ),
          ],
          child: const MyBeamerApp(),
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      // Defensive: an error thrown before DomainLogger is registered must not be
      // masked by a GetIt lookup failure in the handler itself.
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.general,
          error,
          stackTrace: stackTrace,
          subDomain: 'runZonedGuarded',
        );
      } else {
        debugPrint(
          'Unhandled startup error before logging init: $error\n'
          '$stackTrace',
        );
      }
    },
  );
}
