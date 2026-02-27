import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Returns the platform-specific path to the test sqlite3+vec library.
///
/// Built via `make build_test_sqlite_vec` before running tests.
String get testSqliteVecLibPath {
  final root = Directory.current.path;
  final String ext;
  if (Platform.isMacOS) {
    ext = 'dylib';
  } else if (Platform.isWindows) {
    ext = 'dll';
  } else {
    ext = 'so';
  }
  return '$root/packages/sqlite_vec/test_sqlite3_with_vec.$ext';
}

/// Whether the native sqlite-vec test library is available.
bool get sqliteVecAvailable => File(testSqliteVecLibPath).existsSync();

/// Loads the sqlite-vec extension into the global [sqlite3] instance for tests.
///
/// The library override (`open.overrideFor`) is set in
/// `flutter_test_config.dart` so it runs before any test accesses `sqlite3`.
/// This function registers the extension so new connections get vec0 support.
///
/// Use in `setUpAll` for test files that create real `EmbeddingsDb` instances.
void loadSqliteVecForTests() {
  final path = testSqliteVecLibPath;
  if (!File(path).existsSync()) {
    throw StateError(
      'Test library not found at $path.\n'
      'Run `make build_test_sqlite_vec` first.',
    );
  }

  final customLib = DynamicLibrary.open(path);
  sqlite3.ensureExtensionLoaded(
    SqliteExtension.inLibrary(customLib, 'sqlite3_vec_init'),
  );
}
