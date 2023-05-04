import 'dart:async';
import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:media_kit/media_kit.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();
  }

  final docDir = await findDocumentsDirectory();

  getIt
    ..registerSingleton<SecureStorage>(SecureStorage())
    ..registerSingleton<Directory>(docDir);

  await getIt.registerSingleton<Future<DriftIsolate>>(
    createDriftIsolate(settingsDbFileName),
    instanceName: settingsDbFileName,
  );
  getIt
    ..registerSingleton<SettingsDb>(getSettingsDb())
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
