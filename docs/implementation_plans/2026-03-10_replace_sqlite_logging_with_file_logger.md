# Replace SQLite Logging Database with File-Based Domain Logger

**Date:** 2026-03-10
**Branch:** `refactor/replace-sqlite-logging-with-domain-logger`

## Motivation

The SQLite logging database (`logging_db.sqlite`) can grow to 11GB and provides
little value over focused, searchable text files. File-based logs are easier to
grep, review in Console.app, and feed directly to AI tools for debugging.

The `DomainLogger` and general file sink already exist inside `LoggingService`.
This plan removes the SQLite DB sink, making file-based logging the sole
persistence mechanism.

## Design Decisions

- **LoggingService API stays the same.** `captureEvent()` and `captureException()`
  signatures do not change, so the 117+ call sites across the codebase need zero
  modifications.
- **DomainLogger is untouched.** It already delegates to `LoggingService` and writes
  per-domain files independently.
- **Log Viewer UI** switches from querying SQLite to reading/searching the daily
  text log files on disk.
- **No migration needed.** Old logs in the SQLite DB are abandoned. Users can
  manually delete the `logging_db.sqlite` file to reclaim space.

## Step-by-Step Plan

### Step 1: Remove DB Sink from LoggingService

**File:** `lib/services/logging_service.dart`

- Remove `import 'package:lotti/database/logging_db.dart'` (keep `InsightLevel`
  and `InsightType` — move them out first).
- Remove all `getIt<LoggingDb>().log(...)` calls and their try/catch/fallback
  blocks from `_captureEventAsync` and `_captureExceptionAsync`.
- Keep the file-sink logic (`_appendToFile`, `_flushPendingLines`,
  `_appendToFileSync`, `_formatLine`) exactly as-is.

### Step 2: Extract InsightLevel & InsightType

These enums are currently defined in `logging_db.dart` and imported by many files.
Move them to a standalone file so removing `logging_db.dart` doesn't break imports.

**New file:** `lib/database/logging_types.dart`
- Move `InsightLevel` and `InsightType` here.
- Update imports across the codebase.

### Step 3: Remove LoggingDb

**Files to delete:**
- `lib/database/logging_db.dart` (the Drift DB class)
- `lib/database/logging_db.drift` (the SQL schema)
- `lib/database/logging_db.g.dart` (generated code)

**Files to update:**
- `lib/main.dart` — Remove `LoggingDb` registration in GetIt and
  `loggingDbProvider` override.
- `lib/providers/service_providers.dart` — Remove `loggingDbProvider`.
- `lib/services/service_disposer.dart` — Remove `LoggingDb` disposal.
- `lib/database/maintenance.dart` — Remove `deleteLoggingDb()`.
- `lib/features/settings/ui/pages/advanced/maintenance_page.dart` — Remove
  "Delete Logging DB" button/action.
- `lib/get_it.dart` — No direct LoggingDb registration here (it's in main.dart).

### Step 4: Rewrite Log Viewer UI

**File:** `lib/features/settings/ui/pages/advanced/logging_page.dart`

Replace the SQLite-backed list with a file-based reader:
- Read `{documentsDir}/logs/lotti-YYYY-MM-DD.log` (and optionally domain files).
- Parse each line back into display-friendly format (timestamp, level, domain,
  message).
- Support text search via simple string matching on file lines.
- Support date picker to browse older log files.
- Remove the `LogDetailPage` (or rework it to show a single parsed line).

### Step 5: Update Tests

- **`test/services/logging_service_test.dart`** — Remove all `verify(() =>
  loggingDb.log(...))` assertions. Assert only on file content.
- **`test/database/logging_db_test.dart`** — Delete entirely.
- **`test/features/settings/ui/pages/advanced/logging_page_test.dart`** — Update
  to match new file-based UI.
- **Various test setUp/tearDown** — Remove `MockLoggingDb` registration where no
  longer needed.

### Step 6: Clean Up

- Remove `MockLoggingDb` from `test/mocks/mocks.dart` if no longer used.
- Remove `loggingDbFileName` constant references.
- Remove any leftover `LogEntry` fallback values from test helpers.
- Run `make analyze` and `make test` to verify zero warnings.

### Step 7: Update CHANGELOG & Metainfo

- Add entry under current version in `CHANGELOG.md`.
- Update `flatpak/com.matthiasn.lotti.metainfo.xml` with matching release note.

## Risk Assessment

- **Low risk:** LoggingService API is unchanged, so 117+ call sites are unaffected.
- **Medium risk:** Log Viewer UI rewrite — needs careful testing.
- **User impact:** Old SQLite logs become inaccessible. Users can still
  open the file manually if needed, or delete `logging_db.sqlite` to reclaim space.

## Files Affected (Summary)

| Action | File |
|--------|------|
| Modify | `lib/services/logging_service.dart` |
| Create | `lib/database/logging_types.dart` |
| Delete | `lib/database/logging_db.dart` |
| Delete | `lib/database/logging_db.drift` |
| Delete | `lib/database/logging_db.g.dart` |
| Modify | `lib/main.dart` |
| Modify | `lib/providers/service_providers.dart` |
| Modify | `lib/services/service_disposer.dart` |
| Modify | `lib/database/maintenance.dart` |
| Modify | `lib/features/settings/ui/pages/advanced/maintenance_page.dart` |
| Modify | `lib/features/settings/ui/pages/advanced/logging_page.dart` |
| Modify | Multiple test files |
| Delete | `test/database/logging_db_test.dart` |
