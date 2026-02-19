# Local Vector Database via sqlite-vec Integration

## Context

Lotti is transitioning to goal-oriented autonomous AI agents that need semantic search
over journal entries, tasks, and agent messages. The app is strictly offline-first -- all
data stays on-device. We need a local vector database to store embeddings (e.g., 2048-dim)
and perform k-nearest-neighbor search.

**Decision:** Integrate [sqlite-vec](https://github.com/asg017/sqlite-vec) (MIT/Apache-2.0,
pure C, zero dependencies) by compiling the vendored `sqlite-vec.c` together with the
sqlite3 amalgamation into a single shared library. This approach avoids any Flutter plugin
dependency, keeps the existing SQLite/Drift setup unchanged, and works identically in
production and tests.

**Why not Drift for the embeddings DB:** Drift doesn't natively support vec0 virtual tables
or binary vector parameters. The embeddings DB will use raw `package:sqlite3` (v2.4.5,
already a dependency). This follows the principle that the embeddings DB is derived,
rebuildable infrastructure -- not part of the core data model.

**Why not a Flutter FFI plugin:** macOS system SQLite is compiled with
`SQLITE_OMIT_LOAD_EXTENSION`, which prevents `sqlite3_auto_extension` from working. A
separate FFI plugin would still require the host SQLite to support extension loading.
Compiling sqlite-vec statically into a custom sqlite3 build sidesteps this entirely and
works uniformly across platforms and in tests.

### Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| **Flutter FFI plugin (Path 2)** | Rejected | Requires host SQLite to support extension loading; macOS system SQLite blocks this |
| **sqlite-vss** | Dead | Abandoned by author; FAISS dependency made cross-compilation painful |
| **sqlite-vector (sqliteai)** | Rejected | Elastic License 2.0 -- requires commercial license for production |
| **sqlite_vec pub.dev package** | Rejected | Weekend project (21 lines of Dart, template placeholders, 86 downloads, broken include paths) |
| **ObjectBox** | Rejected | Replaces Drift entirely; massive migration for one feature |
| **local_hnsw (pure Dart)** | Not needed | In-memory only, 27 downloads; brute-force via sqlite-vec is adequate at our scale |
| **Custom amalgamation (Path 1 - full replacement)** | Rejected | Would replace *all* sqlite3 usage in the app; too invasive |

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

## Architecture

### How sqlite-vec is compiled

The vendored `sqlite-vec.c` is compiled **statically into a custom sqlite3 build** by
linking it together with the sqlite3 amalgamation into a single shared library. This
library is then loaded via `package:sqlite3`'s `open.overrideFor()` API, replacing the
system SQLite for the embeddings database.

```text
sqlite3.c (amalgamation, downloaded at build time)
  +
sqlite-vec.c (vendored in packages/sqlite_vec/src/)
  =
test_sqlite3_with_vec.{dylib,so}  (platform-specific shared library)
```

The extension is then activated via:
```dart
sqlite3.ensureExtensionLoaded(
  SqliteExtension.staticallyLinked('sqlite3_vec_init'),
);
```

### Build target

`make build_test_sqlite_vec` downloads the sqlite3 amalgamation and compiles the combined
library for the current platform. This runs:
- Locally before tests (developer responsibility)
- In CI before the test step (automated in GitHub Actions workflow)

Compilation flags auto-detect the platform:
- `-O3` optimization
- ARM64 (macOS Apple Silicon, Linux aarch64): `-DSQLITE_VEC_ENABLE_NEON`
- x86_64 (Linux CI): `-DSQLITE_VEC_ENABLE_AVX`
- `-DSQLITE_ENABLE_FTS5` (for future hybrid search)
- `-lm` (math library)

## Implementation Status

### Done (PR 1)

- [x] **Vendored sqlite-vec source** — `packages/sqlite_vec/src/sqlite-vec.{c,h}` from
  upstream v0.1.6
- [x] **EmbeddingsDb class** — `lib/features/ai/database/embeddings_db.dart` with full
  CRUD + KNN search API
- [x] **EmbeddingSearchResult data model** — returned by `search()`
- [x] **18 tests** — `test/features/ai/database/embeddings_db_test.dart` covering all
  operations (lifecycle, upsert, update, delete, search by distance, k-limit, entity type
  filter, sequential vector ranking)
- [x] **Makefile target** — `make build_test_sqlite_vec` builds the combined sqlite3+vec
  library for the current platform
- [x] **CI integration** — `flutter-test-linux-faster.yml` runs the build step before tests
- [x] **Analyzer zero warnings, formatter clean**

### TODO (future PRs)

- [ ] **App startup wiring** — Load extension + register `EmbeddingsDb` as GetIt singleton
  in `lib/get_it.dart`
- [ ] **Production build** — Platform-specific compilation of the combined library for
  release builds (Podspec/CMake integration or pre-built binaries)
- [ ] Embedding generation pipeline (provider interface, background worker)
- [ ] Integration with agent tools (`resolve_task_reference`, memory retrieval)
- [ ] Hybrid search (FTS5 + embedding fusion)
- [ ] Dimension optimization (int8 quantization, Matryoshka truncation)
- [ ] Multiple embedding tables for different models/dimensions

## Deliverables

### 1. Vendored Source: `packages/sqlite_vec/src/`

```text
packages/sqlite_vec/src/
  sqlite-vec.c    # Vendored from upstream v0.1.6 (305 KB)
  sqlite-vec.h    # Vendored from upstream v0.1.6
```

Upstream updates = copy two files from a new release's amalgamation archive.

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
  void open();
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

**Implementation note:** vec0 virtual tables don't support `INSERT OR REPLACE`. The
`upsertEmbedding` method uses delete-then-insert for the vec0 table.

**KNN query** (using sqlite-vec syntax):
```sql
SELECT v.entity_id, v.distance, m.entity_type
FROM vec_embeddings v
JOIN embedding_metadata m ON v.entity_id = m.entity_id
WHERE v.embedding MATCH ?       -- query vector as Float32List blob
  AND k = ?                     -- number of results
ORDER BY v.distance
```

### 3. Data Model

```dart
class EmbeddingSearchResult {
  final String entityId;
  final double distance;
  final String entityType;
}
```

### 4. Build & CI

**Makefile target:**
```makefile
make build_test_sqlite_vec
```

Downloads sqlite3 amalgamation, compiles `sqlite3.c + sqlite-vec.c` into a single shared
library at `packages/sqlite_vec/test_sqlite3_with_vec.{dylib,so}`. Auto-detects platform
and CPU architecture.

**CI workflow** (`flutter-test-linux-faster.yml`):
```yaml
- name: Build sqlite-vec test library
  run: make build_test_sqlite_vec
```

## Key Files

| File | Purpose |
|------|---------|
| `packages/sqlite_vec/src/sqlite-vec.c` | Vendored sqlite-vec source (v0.1.6) |
| `packages/sqlite_vec/src/sqlite-vec.h` | Vendored sqlite-vec header |
| `lib/features/ai/database/embeddings_db.dart` | Vector database class |
| `test/features/ai/database/embeddings_db_test.dart` | 18 tests |
| `Makefile` | `build_test_sqlite_vec` target |
| `.github/workflows/flutter-test-linux-faster.yml` | CI build step |

## Design Decisions

- **Not Drift**: vec0 virtual tables and binary vector params aren't Drift-compatible.
  Raw sqlite3 is simpler and avoids schema version coupling.
- **Separate file (`embeddings.sqlite`)**: Embeddings are derived data. They can be
  deleted and rebuilt without data loss. No sync needed across devices.
- **Statically linked into sqlite3**: Avoids the `SQLITE_OMIT_LOAD_EXTENSION` problem on
  macOS and works identically in tests and production. No Flutter plugin dependency needed.
- **No pubspec.yaml dependency**: The vendored source is only consumed by the Makefile
  build step. The Dart code depends only on `package:sqlite3` which is already a dependency.
- **Vendored C source**: We own the build. No dependency on a third-party pub.dev package.
  Upstream updates = copy two files from a new release's amalgamation archive.
- **Dimension in schema**: Hardcoded to 2048 in the vec0 table. If different models use
  different dimensions, we'd create separate vec0 tables per dimension (sqlite-vec requires
  fixed dimensions per table).
