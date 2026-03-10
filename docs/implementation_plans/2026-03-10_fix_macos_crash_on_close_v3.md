# Fix: macOS Crash on Close (v3)

**Date:** 2026-03-10
**Branch:** `fix/macos-crash-on-quit-v3`
**Status:** Completed

## Problem

The v2 fix (PRs #2767, #2769) replaced `windowManager.destroy()` with
`exit(0)` and skipped explicit SQLite `db.close()` on macOS. Crashes
persisted in both the dev app and TestFlight builds.

### Why v2 failed

The v2 plan incorrectly stated that "exit(0) calls C `_exit()`". This
is wrong:

- Dart's `exit(0)` calls C **`exit()`** (not `_exit()`)
- C `exit()` runs atexit handlers → Dart VM teardown → GC finalizers
- During VM teardown, native threads (mpv, SQLite) try FFI callbacks →
  `DLRT_GetFfiCallbackMetadata` assertion → SIGABRT

### Crash evidence (two distinct vectors)

**Dev app crash (build 3774, `*/mpv core` thread):**
```text
abort → dart::Assert::Fail → DLRT_GetFfiCallbackMetadata
→ append_event → send_event → mp_shutdown_clients → core_thread
```
mpv's core thread sends events through FFI callbacks while the Dart VM
is being torn down by `exit()`.

**TestFlight crash (build 3772, `DartWorker` thread):**
```text
abort → dart::Assert::Fail → DLRT_GetFfiCallbackMetadata
→ functionDestroy → sqlite3LeaveMutexAndCloseZombie → sqlite3Close
→ FinalizableDatabase.dispose
```
Dart VM teardown runs GC `NativeFinalizer` on `FinalizableDatabase`
objects, triggering `sqlite3_close_v2` → `functionDestroy` → FFI
callback into dying VM.

## Solution

Two changes to the macOS shutdown path:

1. **Explicitly dispose media_kit Player** while the Dart VM is alive —
   this cleanly stops mpv's core thread before it can crash.
2. **Replace `exit(0)` with POSIX `_exit(0)` via `dart:ffi`** — `_exit()`
   terminates immediately without atexit handlers, GC finalizers, or
   Dart VM teardown.

### Why `_exit(0)` is safe

- Non-DB services are already stopped by `ServiceDisposer`
- media_kit Player is explicitly disposed (mpv threads stopped cleanly)
- SQLite WAL mode guarantees data integrity on abrupt exit
- OS reclaims all file handles and memory
- Exit code 0 = no crash reports or "quit unexpectedly" dialogs

### Key difference: `exit()` vs `_exit()`

| Behavior                   | `exit()` | `_exit()` |
|----------------------------|----------|-----------|
| Runs atexit handlers       | Yes      | No        |
| Flushes stdio buffers      | Yes      | No        |
| Runs C++ destructors       | Yes      | No        |
| Triggers Dart VM teardown  | Yes      | No        |
| Runs GC finalizers         | Yes      | No        |

## Files changed

- `lib/utils/immediate_exit.dart` — NEW: POSIX `_exit()` via FFI
- `lib/features/speech/state/audio_player_controller.dart` — static
  Player tracking + `disposeActivePlayer()`
- `lib/services/window_service.dart` — injectable exit/disposal,
  corrected shutdown sequence
- `test/utils/immediate_exit_test.dart` — FFI resolution test
- `test/services/window_service_test.dart` — shutdown sequence tests
- `test/features/speech/state/audio_player_controller_test.dart` —
  `disposeActivePlayer()` tests
- `docs/implementation_plans/2026-03-09_fix_macos_crash_on_close_v2.md`
  — marked superseded, corrected false claim
- `CHANGELOG.md`
- `flatpak/com.matthiasn.lotti.metainfo.xml`
