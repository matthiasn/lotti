import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:sqlite3/open.dart';

/// Returns the path to the test sqlite3+vec shared library, or null if it
/// doesn't exist on disk.
String? get _testSqliteVecPath {
  final root = Directory.current.path;
  final String ext;
  if (Platform.isMacOS) {
    ext = 'dylib';
  } else if (Platform.isWindows) {
    ext = 'dll';
  } else {
    ext = 'so';
  }
  final path = '$root/packages/sqlite_vec/test_sqlite3_with_vec.$ext';
  return File(path).existsSync() ? path : null;
}

/// Runs before every test file. Use this to set global test configuration
/// that keeps tests fast and deterministic across runners (flutter test,
/// very_good test, CI, etc.).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Allow opt-in font downloads locally via env var, default to hermetic.
  final allowFontDownloads =
      Platform.environment['ALLOW_FONT_DOWNLOADS']?.toLowerCase() == 'true';
  GoogleFonts.config.allowRuntimeFetching = allowFontDownloads;

  // Suppress drift multiple-database warnings when a single VM isolate
  // reuses executors across files (common with test optimizers).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Suppress DevLogger console output in tests by default.
  // Tests that need to verify logging can use DevLogger.capturedLogs.
  DevLogger.suppressOutput = true;

  // Override the sqlite3 library to use a custom build that includes
  // sqlite-vec statically linked. This MUST happen before the `sqlite3`
  // global getter is first accessed (which caches the library). In
  // very_good test all files share one process, so we set this here —
  // before any test's setUpAll — to guarantee correct ordering.
  final vecLibPath = _testSqliteVecPath;
  if (vecLibPath == null) {
    // ignore: avoid_print
    print('sqlite-vec library not found — vec features will use stock sqlite3');
  } else {
    final OperatingSystem os;
    if (Platform.isMacOS) {
      os = OperatingSystem.macOS;
    } else if (Platform.isWindows) {
      os = OperatingSystem.windows;
    } else {
      os = OperatingSystem.linux;
    }
    open.overrideFor(os, () => DynamicLibrary.open(vecLibPath));
  }

  await testMain();
}
