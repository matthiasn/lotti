import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Awaits the same ordered teardown used by window-manager close events.
/// Returning before that shared future completes would allow the Flutter
/// engine to tear down SQLite's Dart FFI callbacks while handles are live.
Future<AppExitResponse> _handleAppExitRequested() async {
  await getIt<WindowService>().shutdown();
  return AppExitResponse.exit;
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
