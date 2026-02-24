import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vec/sqlite_vec.dart';

/// The filename for the embeddings database.
///
/// Stored separately from the main journal DB because it contains derived
/// data that can be rebuilt from source entries.
const kEmbeddingsDbFilename = 'embeddings.sqlite';

/// Returns the full file path for the embeddings database.
String embeddingsDbPath(String documentsPath) =>
    p.join(documentsPath, kEmbeddingsDbFilename);

/// Loads the sqlite-vec extension into the global [sqlite3] instance.
///
/// Must be called before any [EmbeddingsDb] is opened in production.
/// In tests, the extension is loaded differently via `flutter_test_config.dart`
/// (which statically links sqlite-vec into the test library).
///
/// Safe to call multiple times — `ensureExtensionLoaded` is idempotent.
void loadSqliteVecExtension() {
  sqlite3.ensureExtensionLoaded(
    SqliteExtension.inLibrary(vec0, 'sqlite3_vec_init'),
  );
}

/// Creates and opens an [EmbeddingsDb] at the standard file location.
///
/// The database is created at `<documentsPath>/embeddings.sqlite`.
/// Call [loadSqliteVecExtension] before this in production.
EmbeddingsDb createEmbeddingsDb({required String documentsPath}) {
  return EmbeddingsDb(path: embeddingsDbPath(documentsPath))..open();
}

/// Initializes the embeddings database for production use.
///
/// 1. Loads the sqlite-vec extension from the native FFI plugin.
/// 2. Creates and opens the database at `<documentsPath>/embeddings.sqlite`.
///
/// Returns the opened [EmbeddingsDb] ready for use.
EmbeddingsDb initProductionEmbeddingsDb({required String documentsPath}) {
  loadSqliteVecExtension();
  return createEmbeddingsDb(documentsPath: documentsPath);
}
