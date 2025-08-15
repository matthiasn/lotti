import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:media_kit/media_kit.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    getIt
      ..registerSingleton<LoggingDb>(LoggingDb())
      ..registerSingleton<LoggingService>(LoggingService());

    WidgetsFlutterBinding.ensureInitialized();
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'MAIN',
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
        size: Size(1280, 720),
        minimumSize: Size(320, 568),
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

    FlutterError.onError = (FlutterErrorDetails details) {
      getIt<LoggingService>().captureException(
        details.exception,
        domain: 'MAIN',
        subDomain: details.library,
        stackTrace: details.stack,
      );
    };

    runApp(
      const ProviderScope(
        child: MyBeamerApp(),
      ),
    );
  }, (Object error, StackTrace stackTrace) {
    getIt<LoggingService>().captureException(
      error,
      domain: 'MAIN',
      subDomain: 'runZonedGuarded',
      stackTrace: stackTrace,
    );
  });
}
