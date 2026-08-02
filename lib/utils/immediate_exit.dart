import 'dart:ffi';

/// Calls POSIX `_exit()` to terminate the process immediately.
///
/// Unlike Dart's `exit()` (which calls C `exit()`), POSIX `_exit()` does NOT:
/// - Run atexit handlers
/// - Flush stdio buffers
/// - Run C++ static destructors
/// - Trigger Dart VM teardown or GC finalizers
///
/// This is needed on macOS because Dart's `exit()` triggers VM teardown,
/// which runs `NativeFinalizer` callbacks on SQLite `FinalizableDatabase`
/// objects and races with native threads (mpv, SQLite workers) that try
/// to invoke Dart FFI callbacks — hitting a fatal assertion in
/// `DLRT_GetFfiCallbackMetadata` → SIGABRT.
///
/// Safety: all Dart-level services must be disposed before calling this.
/// SQLite WAL mode guarantees data integrity on abrupt exit.
void immediateExit(int code) {
  _posixExit(code);
}

/// The resolved POSIX `_exit` function, lazily initialized.
final void Function(int) _posixExit = _lookupPosixExit();

void Function(int) _lookupPosixExit() {
  final dylib = DynamicLibrary.process();
  return dylib.lookupFunction<Void Function(Int32), void Function(int)>(
    '_exit',
  );
}
