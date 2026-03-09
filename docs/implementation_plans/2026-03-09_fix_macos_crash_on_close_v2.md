# Fix: macOS Crash on Close (v2)

**Date:** 2026-03-09
**Branch:** `fix/macos-crash-on-close-v2`
**Status:** In progress

## Problem

The app crashes on macOS when the window is closed. The fix in #2764
(`ServiceDisposer` + 150ms FFI drain grace period) did not resolve the
issue.

### Crash analysis (`Lotti-2026-03-08-190111.ips`)

**Exception:** `EXC_CRASH (SIGABRT)` — `abort() called`

**Faulting thread (16, DartWorker):**
```
abort()
dart::Assert::Fail()              — assertion failure
DLRT_GetFfiCallbackMetadata()     — runtime_entry.cc:5103
functionDestroy()                 — SQLite FFI callback
sqlite3LeaveMutexAndCloseZombie()
sqlite3Close()
```

**Main thread (0):**
```
dart::Dart::WaitForIsolateShutdown()
dart::Dart::Cleanup()
flutter::DartVM::~DartVM()
flutter::Shell::~Shell()
flutter::EmbedderEngine::CollectShell()
```

**Other DartWorker threads (15, 18, 19, 21, 29, 51, 54):**
All stuck in various stages of `sqlite3Close` / `sqlite3PagerClose` /
`sqlite3BtreeClose` / `sqlite3WalClose` / `sqlite3WalCheckpoint`.

### Root cause

1. `ServiceDisposer.disposeAll()` calls Drift's `db.close()` for each
   database. Drift's `close()` sends a shutdown message to its FFI
   worker isolate and returns when the isolate acknowledges.
2. However, the native SQLite layer (`sqlite3Close`) runs *inside* that
   worker isolate and involves multi-step cleanup: WAL checkpoint,
   btree close, pager close, file unlink. These steps can block on
   mutex acquisition and disk I/O.
3. After `disposeAll()` completes and the 150ms grace period elapses,
   `windowManager.destroy()` is called, which tears down the Flutter
   engine and begins Dart VM cleanup (`DartVM::~DartVM()`).
4. The Dart VM destruction calls `Dart::Cleanup()` →
   `WaitForIsolateShutdown()`, which waits for isolates to exit, but
   the native SQLite threads inside those isolates are still running.
5. When a native SQLite thread calls `functionDestroy` during
   `sqlite3Close`, it tries to call `DLRT_GetFfiCallbackMetadata` to
   look up the Dart FFI closure. But the Dart VM is being torn down,
   so the metadata lookup hits a fatal assertion in `runtime_entry.cc`.

### Why 150ms is insufficient

The `JournalDb` uses `readPool: 4`, meaning Drift creates 1 write
isolate + 4 read isolates = 5 background isolates, each with its own
native SQLite connection. All 7 Drift databases together create many
background isolates. The native `sqlite3Close` on each connection must:
- Acquire the SQLite mutex (can block if another connection holds it)
- Checkpoint the WAL file (writes to disk)
- Close btree structures
- Unlink shared-memory files

With multiple connections closing concurrently and contending on the
same mutexes, 150ms is not nearly enough.

## Solution

**Do not use a fixed grace period.** Instead, avoid
`windowManager.destroy()` on macOS entirely. After Dart-level disposal
completes, terminate the process with `exit(0)` so the Flutter engine
teardown sequence that triggers the FFI race is skipped.

### Approach: Use `exit(0)` instead of `windowManager.destroy()` (macOS only)

After `disposeAll()` closes all databases at the Dart level, call
`exit(0)` to terminate the process cleanly. This bypasses the Flutter
engine's `Shell::~Shell()` destructor which triggers the problematic
`DartVM::~DartVM()` → `WaitForIsolateShutdown()` path that races with
native SQLite threads.

`exit(0)` calls C `_exit()` which terminates all threads immediately
without running destructors that race with in-flight FFI callbacks.

### Why this is safe

- All Dart-level resources (stream controllers, timers, outbox) have
  already been disposed by `ServiceDisposer`.
- All Drift databases have been sent their close commands and have
  acknowledged at the Dart level.
- SQLite's WAL mode with `PRAGMA synchronous = NORMAL` means data
  integrity is maintained even if the process exits during WAL
  checkpoint — the WAL file will be replayed on next open.
- The alternative (waiting for all native threads to finish) is not
  controllable from Dart, as Drift does not expose a "wait for native
  close to complete" API.

## Implementation steps

1. **`lib/services/window_service.dart`**: In `_handleClose()`, replace
   `await Future<void>.delayed(ffiDrainGracePeriod)` +
   `await windowManager.destroy()` with `exit(0)`.
2. **`lib/services/service_disposer.dart`**: Remove the
   `ffiDrainGracePeriod` constant (no longer used).
3. **Update tests** to verify the new shutdown behavior.
4. **Update CHANGELOG** and metainfo.

## Files changed

- `lib/services/window_service.dart`
- `lib/services/service_disposer.dart`
- `test/services/window_service_test.dart`
- `CHANGELOG.md`
- `flatpak/com.matthiasn.lotti.metainfo.xml`
