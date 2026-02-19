# Local Vector Database via sqlite-vec Integration

## Context

Lotti is transitioning to goal-oriented autonomous AI agents that need semantic search
over journal entries, tasks, and agent messages. The app is strictly offline-first -- all
data stays on-device. We need a local vector database to store embeddings (e.g., 2048-dim)
and perform k-nearest-neighbor search.

**Decision:** Integrate [sqlite-vec](https://github.com/asg017/sqlite-vec) (MIT/Apache-2.0,
pure C, zero dependencies) as a local Flutter FFI plugin (Path 2). This keeps the existing
SQLite/Drift setup completely unchanged and only compiles the small sqlite-vec.c file as a
separate shared library.

**Why not Drift for the embeddings DB:** Drift doesn't natively support vec0 virtual tables
or binary vector parameters. The embeddings DB will use raw `package:sqlite3` (v2.4.5,
already a dependency). This follows the principle that the embeddings DB is derived,
rebuildable infrastructure -- not part of the core data model.

### Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| **sqlite-vss** | Dead | Abandoned by author; FAISS dependency made cross-compilation painful |
| **sqlite-vector (sqliteai)** | Rejected | Elastic License 2.0 -- requires commercial license for production |
| **sqlite_vec pub.dev package** | Rejected | Weekend project (21 lines of Dart, template placeholders, 86 downloads, broken include paths) |
| **ObjectBox** | Rejected | Replaces Drift entirely; massive migration for one feature |
| **local_hnsw (pure Dart)** | Not needed | In-memory only, 27 downloads; brute-force via sqlite-vec is adequate at our scale |
| **Custom amalgamation (Path 1)** | Rejected | Forces recompilation of sqlite3.c (~240K lines) on clean builds; Path 2 only compiles sqlite-vec.c |

### Performance at Our Scale

sqlite-vec uses brute-force KNN (no ANN index yet). Not all journal entries need embedding
-- only text-rich entries relevant for semantic search (journal text, task descriptions,
agent messages). Realistic embedding volume is a few thousand per year, reaching 10-20K
after several years of heavy use.

Brute-force benchmarks for 2048-dim float32 vectors:
- **10K vectors:** <10ms (imperceptible)
- **20K vectors:** ~20-30ms (instant)
- **100K vectors:** ~130-160ms (noticeable but usable; int8 quantization cuts this 4x)

ANN indexes (HNSW/IVF/DiskANN) are on the sqlite-vec roadmap but only matter at 100K+
scale. We won't need them for the foreseeable future.

## Deliverables

### 1. Local Flutter FFI Plugin: `packages/sqlite_vec/`

A minimal Flutter FFI plugin that compiles `sqlite-vec.c` per platform and exposes the
dynamic library handle to Dart.

```
packages/sqlite_vec/
  pubspec.yaml              # Flutter plugin, ffiPlugin: true
  lib/sqlite_vec.dart       # ~20 lines: DynamicLibrary loader
  src/
    sqlite-vec.c            # Vendored from upstream v0.1.6
    sqlite-vec.h            # Vendored from upstream v0.1.6
    CMakeLists.txt          # Shared CMake for Android/Linux/Windows
  android/
    CMakeLists.txt          # Android-specific CMake
  ios/
    sqlite_vec.podspec      # iOS podspec
    Classes/
      sqlite_vec.c          # Forwarder: #include "../../src/sqlite-vec.c"
  macos/
    sqlite_vec.podspec      # macOS podspec
    Classes/
      sqlite_vec.c          # Forwarder: #include "../../src/sqlite-vec.c"
  linux/
    CMakeLists.txt          # Linux CMake
  windows/
    CMakeLists.txt          # Windows CMake
```

**Dart API** (the entire library):
```dart
import 'dart:ffi';
import 'dart:io';

const String _libName = 'sqlite_vec';

/// Handle to the sqlite-vec shared library.
/// Use with sqlite3.ensureExtensionLoaded(
///   SqliteExtension.inLibrary(vec0, 'sqlite3_vec_init'),
/// )
final DynamicLibrary vec0 = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();
```

**Compilation flags** (from upstream Makefile):
- `-O3` optimization
- ARM64 (iOS/macOS Apple Silicon): `-DSQLITE_VEC_ENABLE_NEON`
- x86_64: `-DSQLITE_VEC_ENABLE_AVX` (where supported)
- Link `-lm` on Linux

### 2. Embeddings Database: `lib/features/ai/database/embeddings_db.dart`

A standalone database class using raw `package:sqlite3` (not Drift) to manage vector
storage and KNN queries via vec0 virtual tables.

**Schema** (created via raw SQL):
```sql
-- Metadata table (regular SQLite)
CREATE TABLE IF NOT EXISTS embedding_metadata (
  entity_id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,     -- 'journal_entry', 'task', 'agent_message', etc.
  model_id TEXT NOT NULL,        -- embedding model identifier
  dimensions INTEGER NOT NULL,   -- vector dimension count
  content_hash TEXT NOT NULL,    -- to detect when re-embedding is needed
  created_at TEXT NOT NULL
);

-- Vector table (sqlite-vec virtual table)
CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
  USING vec0(
    entity_id TEXT PRIMARY KEY,
    embedding float[2048]
  );
```

**API surface:**
```dart
class EmbeddingsDb {
  // Lifecycle
  Future<void> open();
  void close();

  // Write
  void upsertEmbedding({
    required String entityId,
    required String entityType,
    required String modelId,
    required int dimensions,
    required Float32List embedding,
    required String contentHash,
  });
  void deleteEmbedding(String entityId);

  // Read
  List<EmbeddingSearchResult> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
  });
  bool hasEmbedding(String entityId);
  String? getContentHash(String entityId);

  // Maintenance
  int get count;
  void deleteAll();
}
```

**KNN query** (using sqlite-vec syntax):
```sql
SELECT v.entity_id, v.distance, m.entity_type, m.model_id
FROM vec_embeddings v
JOIN embedding_metadata m ON v.entity_id = m.entity_id
WHERE v.embedding MATCH ?       -- query vector as Float32List blob
  AND k = ?                     -- number of results
ORDER BY v.distance
```

### 3. Extension Loading at App Startup

In `lib/get_it.dart` or app initialization, load the extension once:

```dart
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vec/sqlite_vec.dart' as sqlite_vec;

// Load sqlite-vec extension into the process-global SQLite engine
sqlite3.ensureExtensionLoaded(
  SqliteExtension.inLibrary(sqlite_vec.vec0, 'sqlite3_vec_init'),
);
```

Then register `EmbeddingsDb` as a GetIt singleton.

### 4. Root pubspec.yaml Changes

Add the local package as a path dependency:
```yaml
dependencies:
  sqlite_vec:
    path: packages/sqlite_vec
```

### 5. Data Model

```dart
class EmbeddingSearchResult {
  final String entityId;
  final double distance;
  final String entityType;
}
```

## Implementation Steps

1. **Create `packages/sqlite_vec/` plugin structure** with pubspec, platform configs
2. **Vendor `sqlite-vec.c` and `sqlite-vec.h`** from upstream v0.1.6 release
3. **Write platform build configs** (CMake, Podspec) with correct compiler flags
4. **Write the Dart loader** (~20 lines)
5. **Add path dependency** in root pubspec.yaml
6. **Create `EmbeddingsDb`** class with open/close/upsert/search/delete
7. **Load extension** in app startup (get_it.dart)
8. **Register `EmbeddingsDb`** as GetIt singleton
9. **Write tests** for EmbeddingsDb (in-memory sqlite3 with extension loaded)
10. **Run analyzer, formatter, tests** to verify everything compiles

## Key Files to Modify

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `sqlite_vec` path dependency |
| `lib/get_it.dart` | Load extension + register EmbeddingsDb |
| `test/widget_test_utils.dart` | Add EmbeddingsDb to test setup/teardown if needed |

## Key Files to Create

| File | Purpose |
|------|---------|
| `packages/sqlite_vec/` | Entire local FFI plugin (new directory tree) |
| `lib/features/ai/database/embeddings_db.dart` | Vector database class |
| `test/features/ai/database/embeddings_db_test.dart` | Tests |

## Verification

1. `dart analyze` / MCP analyzer -- zero warnings
2. `dart format` -- all formatted
3. Run embeddings_db_test.dart -- passes
4. Run full test suite -- no regressions (extension loading should be harmless)
5. Manual smoke test: `fvm flutter run -d macos` -- app launches without crash

## Design Decisions

- **Not Drift**: vec0 virtual tables and binary vector params aren't Drift-compatible.
  Raw sqlite3 is simpler and avoids schema version coupling.
- **Separate file (`embeddings.sqlite`)**: Embeddings are derived data. Can be deleted
  and rebuilt without data loss. No sync needed across devices.
- **Process-global extension**: `ensureExtensionLoaded` makes vec0 available on all
  connections. This is harmless -- vec0 only activates when you create vec0 virtual tables.
- **Vendored C source**: We own the build. No dependency on a third-party pub.dev package.
  Upstream updates = copy two files.
- **Dimension in schema**: Hardcoded to 2048 in the vec0 table. If different models use
  different dimensions, we'd create separate vec0 tables per dimension (sqlite-vec requires
  fixed dimensions per table).

## Out of Scope (future work)

- Embedding generation pipeline (provider interface, background worker)
- Integration with agent tools (`resolve_task_reference`, memory retrieval)
- Hybrid search (FTS5 + embedding fusion)
- Dimension optimization (int8 quantization, Matryoshka truncation)
- Multiple embedding tables for different models/dimensions
