import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();
  }

  getIt
    ..registerSingleton<SecureStorage>(SecureStorage())
    ..registerSingleton<WindowService>(WindowService());

  await getIt<WindowService>().restore();
  tz.initializeTimeZones();

  await runZonedGuarded(() async {
    await registerSingletons();

    FlutterError.onError = (FlutterErrorDetails details) {
      getIt<LoggingDb>().captureException(
        details,
        domain: 'MAIN',
        subDomain: 'onError',
      );
    };

    await registerScreenshotHotkey();
    runApp(MyBeamerApp());
  }, (Object error, StackTrace stackTrace) {
    getIt<LoggingDb>().captureException(
      error,
      domain: 'MAIN',
      subDomain: 'runZonedGuarded',
      stackTrace: stackTrace,
    );
  });
}
