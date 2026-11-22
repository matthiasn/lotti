import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

/// Opens the OS's settings for this app, where a refused microphone
/// permission is turned back on.
typedef AppSettingsOpener = Future<bool> Function();

/// The seam every recorder's *Open settings* goes through, so it is testable
/// without the platform channel behind it.
final appSettingsOpenerProvider = Provider<AppSettingsOpener>(
  (ref) => permissions.openAppSettings,
  name: 'appSettingsOpenerProvider',
);
