# Implementation Plan: Drift WAL Mode & Read Pools

## Context

We are preparing for the Actor-Based Sync Isolate (see `docs/implementation_plans/2026-02-12_actor_based_sync_isolate_plan.md`). The sync actor will open its own `JournalDb` and `SettingsDb` connections to the same SQLite files as the main isolate. Without WAL mode, this causes "Database is Locked" errors. Additionally, read pools offload heavy reads to background isolates, keeping the UI thread responsive during sync.

**Current state**: `openDbConnection()` in `common.dart` calls `NativeDatabase.createInBackground(file)` with no setup callback, no WAL, and no read pools. Drift 2.21.0 is declared (supports `readPool`, introduced in 2.20.0).

## Changes

### 1. Modify `openDbConnection()` in `lib/database/common.dart`

Add three new parameters: `background`, `readPool`, and a WAL setup callback.

**New signature:**
```dart
LazyDatabase openDbConnection(
  String fileName, {
  bool inMemoryDatabase = false,
  bool background = true,    // NEW: false for actor isolate use
  int readPool = 0,          // NEW: number of read-only isolates
  Future<Directory> Function()? documentsDirectoryProvider,
  Future<Directory> Function()? tempDirectoryProvider,
})
```

**New database creation logic** (replacing the single `createInBackground` call):
```dart
void setupDatabase(Database database) {
  database.execute('PRAGMA journal_mode = WAL;');
  database.execute('PRAGMA busy_timeout = 5000;');
  database.execute('PRAGMA synchronous = NORMAL;');
}

if (background) {
  return NativeDatabase.createInBackground(
    file,
    setup: setupDatabase,
    readPool: readPool,
  );
} else {
  return NativeDatabase(file, setup: setupDatabase);
}
```

**Rationale for each pragma:**
- `journal_mode = WAL` — concurrent readers + single writer, required for multi-isolate access
- `busy_timeout = 5000` — retry for 5s before returning SQLITE_BUSY (prevents transient lock errors)
- `synchronous = NORMAL` — recommended for WAL; safe under app crash, minor risk only on OS crash

The `Database` type is already imported from `package:sqlite3/sqlite3.dart`.

### 2. Update `JournalDb` constructor in `lib/database/database.dart`

Add `readPool`, `background`, `documentsDirectoryProvider`, and `tempDirectoryProvider` parameters:

```dart
JournalDb({
  this.inMemoryDatabase = false,
  String? overriddenFilename,
  int readPool = 4,
  bool background = true,
  Future<Directory> Function()? documentsDirectoryProvider,
  Future<Directory> Function()? tempDirectoryProvider,
}) : super(
        openDbConnection(
          overriddenFilename ?? journalDbFileName,
          inMemoryDatabase: inMemoryDatabase,
          readPool: readPool,
          background: background,
          documentsDirectoryProvider: documentsDirectoryProvider,
          tempDirectoryProvider: tempDirectoryProvider,
        ),
      );
```

- `readPool: 4` — JournalDb has the heaviest read traffic (dashboards, task lists, calendars, etc.)
- `PRAGMA foreign_keys = ON` stays in `beforeOpen` — it works there and the `setup` callback is for connection-level pragmas

### 3. Update `SettingsDb` constructor in `lib/database/settings_db.dart`

Add `background`, `documentsDirectoryProvider`, and `tempDirectoryProvider` (needed for actor isolate):

```dart
SettingsDb({
  this.inMemoryDatabase = false,
  bool background = true,
  Future<Directory> Function()? documentsDirectoryProvider,
  Future<Directory> Function()? tempDirectoryProvider,
}) : super(
        openDbConnection(
          settingsDbFileName,
          inMemoryDatabase: inMemoryDatabase,
          background: background,
          documentsDirectoryProvider: documentsDirectoryProvider,
          tempDirectoryProvider: tempDirectoryProvider,
        ),
      );
```

No read pool for SettingsDb — tiny database, minimal reads.

### 4. Update `SyncDatabase` constructor in `lib/database/sync_db.dart`

Add `documentsDirectoryProvider` and `tempDirectoryProvider` for consistency:

```dart
SyncDatabase({
  this.inMemoryDatabase = false,
  String? overriddenFilename,
  Future<Directory> Function()? documentsDirectoryProvider,
  Future<Directory> Function()? tempDirectoryProvider,
}) : super(
        openDbConnection(
          overriddenFilename ?? syncDbFileName,
          inMemoryDatabase: inMemoryDatabase,
          documentsDirectoryProvider: documentsDirectoryProvider,
          tempDirectoryProvider: tempDirectoryProvider,
        ),
      );
```

### 5. No changes needed for other databases

`EditorDb`, `LoggingDb`, `Fts5Db`, `AiConfigDb` — all get WAL automatically through the updated `openDbConnection()`. No constructor changes needed since they don't need read pools or actor isolate support.

### 6. Add WAL verification test in `test/database/open_db_connection_test.dart`

Add a test that opens a file-based database via `openDbConnection()` and verifies the pragmas:

```dart
test('openDbConnection enables WAL mode for file-based databases', () async {
  final base = Directory.systemTemp.createTempSync('wal_test_');
  addTearDown(() => base.deleteSync(recursive: true));

  final lazy = openDbConnection(
    'test_wal.sqlite',
    documentsDirectoryProvider: () async => base,
    tempDirectoryProvider: () async => base,
  );

  final db = SyncDatabase.connect(DatabaseConnection(lazy));

  final walResult = await db.customSelect('PRAGMA journal_mode').getSingle();
  expect(walResult.read<String>('journal_mode'), 'wal');

  final busyResult = await db.customSelect('PRAGMA busy_timeout').getSingle();
  expect(busyResult.read<int>('timeout'), 5000);

  final syncResult = await db.customSelect('PRAGMA synchronous').getSingle();
  expect(syncResult.read<int>('synchronous'), 1); // NORMAL = 1

  await db.close();
});
```

## Files Modified

| File | Change |
|------|--------|
| `lib/database/common.dart` | Add `background`, `readPool` params; add WAL setup callback |
| `lib/database/database.dart` | JournalDb: add `readPool=4`, `background`, directory providers |
| `lib/database/settings_db.dart` | SettingsDb: add `background`, directory providers |
| `lib/database/sync_db.dart` | SyncDatabase: add directory providers |
| `test/database/open_db_connection_test.dart` | Add WAL pragma verification test |

## What Does NOT Change

- No generated code (`.g.dart`, `.freezed.dart`)
- No schema/migration version bumps (WAL is a connection pragma, not schema)
- No changes to `getIt` registration or existing call sites
- No test infrastructure changes (in-memory DBs bypass all new code)
- `PRAGMA foreign_keys = ON` stays in JournalDb's `beforeOpen`

## Verification

1. **Run analyzer**: `dart-mcp.analyze_files` — must be zero warnings
2. **Run formatter**: `dart-mcp.dart_format`
3. **Run existing DB tests**: `dart-mcp.run_tests` on `test/database/`
4. **Run the new WAL test**: verify pragmas are applied
5. **Manual verification**: Run the app, check logs for any SQLITE_BUSY errors during sync
6. **WAL file check**: After running the app, verify `db.sqlite-wal` and `db.sqlite-shm` files exist alongside `db.sqlite` in the documents directory

## How This Prevents "Database is Locked" Errors

- **WAL mode** allows a single writer and multiple concurrent readers on the same file
- **busy_timeout = 5000** makes SQLite retry for 5 seconds instead of immediately failing
- **Read pools** (on JournalDb) distribute heavy reads across 4 isolates, reducing lock contention
- **`background: false`** for the actor isolate avoids nested isolates (isolate-within-isolate)
