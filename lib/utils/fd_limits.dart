import 'dart:ffi';
import 'dart:io';

import 'package:meta/meta.dart';

/// Immutable snapshot of the result of [ensureFileDescriptorSoftLimit].
///
/// Fields are `-1` when the platform is unsupported or a call failed before a
/// value could be read.
@immutable
class FdLimitAdjustment {
  const FdLimitAdjustment({
    required this.softBefore,
    required this.hardBefore,
    required this.softAfter,
    required this.hardAfter,
    required this.target,
    required this.raised,
    this.error,
  });

  final int softBefore;
  final int hardBefore;
  final int softAfter;
  final int hardAfter;
  final int target;
  final bool raised;
  final Object? error;

  @override
  String toString() {
    if (error != null) {
      return 'FdLimitAdjustment(target=$target, error=$error)';
    }
    return 'FdLimitAdjustment(soft $softBefore -> $softAfter, '
        'hard=$hardAfter, target=$target, raised=$raised)';
  }
}

// POSIX RLIMIT_NOFILE resource id: 8 on Darwin/BSD, 7 on Linux/glibc.
int _rlimitNofile() {
  if (Platform.isMacOS) return 8;
  if (Platform.isLinux) return 7;
  throw UnsupportedError(
    'RLIMIT_NOFILE is undefined for ${Platform.operatingSystem}',
  );
}

final class _Rlimit extends Struct {
  @Uint64()
  external int rlimCur;

  @Uint64()
  external int rlimMax;
}

typedef _RlimitSyscallNative = Int32 Function(Int32, Pointer<_Rlimit>);
typedef _RlimitSyscall = int Function(int, Pointer<_Rlimit>);

typedef _Malloc = Pointer<Void> Function(int);
typedef _Free = void Function(Pointer<Void>);

class _Libc {
  const _Libc({
    required this.getrlimit,
    required this.setrlimit,
    required this.malloc,
    required this.free,
  });

  final _RlimitSyscall getrlimit;
  final _RlimitSyscall setrlimit;
  final _Malloc malloc;
  final _Free free;
}

// Cached libc bindings. Top-level `final`s are lazily initialized in Dart, so
// symbol resolution runs at most once per process even when
// [readFileDescriptorLimits] is called repeatedly (e.g. on every EMFILE
// caught in the sync pipeline).
final _Libc? _libc = _resolveLibc();

_Libc? _resolveLibc() {
  if (!Platform.isMacOS && !Platform.isLinux) return null;
  try {
    final lib = DynamicLibrary.process();
    return _Libc(
      getrlimit: lib.lookupFunction<_RlimitSyscallNative, _RlimitSyscall>(
        'getrlimit',
      ),
      setrlimit: lib.lookupFunction<_RlimitSyscallNative, _RlimitSyscall>(
        'setrlimit',
      ),
      malloc: lib.lookupFunction<Pointer<Void> Function(IntPtr), _Malloc>(
        'malloc',
      ),
      free: lib.lookupFunction<Void Function(Pointer<Void>), _Free>('free'),
    );
  } catch (_) {
    return null;
  }
}

// On Linux, `RLIM_INFINITY == (rlim_t)-1 == 0xFFFFFFFFFFFFFFFF`, which Dart
// reads from a Uint64 field as `-1` in its signed 64-bit `int`. On macOS,
// `RLIM_INFINITY == INT64_MAX`, which reads as a large positive value. This
// helper treats any negative reading as "no cap" so the clamp logic works
// identically on both platforms.
bool _isUnlimited(int value) => value < 0;

/// Raises the soft limit for open file descriptors to at least [target] on
/// macOS and Linux, never exceeding the current hard limit.
///
/// GUI apps launched from Finder/Spotlight on macOS inherit launchd's legacy
/// soft limit of 256, which is trivially exhausted by a real-world client
/// (sockets, SQLite handles, attachment writes, log files). Call this at the
/// very top of `main()` — before anything opens an FD — so later startup code
/// gets the raised ceiling.
///
/// Returns an [FdLimitAdjustment] describing before/after values so the caller
/// can emit a single structured log entry. Never throws; all errors are
/// captured in [FdLimitAdjustment.error].
FdLimitAdjustment ensureFileDescriptorSoftLimit({int target = 10240}) {
  final libc = _libc;
  if (libc == null) {
    return FdLimitAdjustment(
      softBefore: -1,
      hardBefore: -1,
      softAfter: -1,
      hardAfter: -1,
      target: target,
      raised: false,
    );
  }

  try {
    final resource = _rlimitNofile();
    final ptr = libc.malloc(sizeOf<_Rlimit>()).cast<_Rlimit>();
    if (ptr.address == 0) {
      return FdLimitAdjustment(
        softBefore: -1,
        hardBefore: -1,
        softAfter: -1,
        hardAfter: -1,
        target: target,
        raised: false,
        error: StateError('malloc returned null'),
      );
    }

    try {
      if (libc.getrlimit(resource, ptr) != 0) {
        return FdLimitAdjustment(
          softBefore: -1,
          hardBefore: -1,
          softAfter: -1,
          hardAfter: -1,
          target: target,
          raised: false,
          error: StateError('getrlimit failed'),
        );
      }

      final softBefore = ptr.ref.rlimCur;
      final hardBefore = ptr.ref.rlimMax;

      if (softBefore >= target) {
        return FdLimitAdjustment(
          softBefore: softBefore,
          hardBefore: hardBefore,
          softAfter: softBefore,
          hardAfter: hardBefore,
          target: target,
          raised: false,
        );
      }

      // Clamp to the hard limit, treating RLIM_INFINITY (negative when read
      // as Dart int on Linux) as "no cap".
      final newSoft = (_isUnlimited(hardBefore) || target < hardBefore)
          ? target
          : hardBefore;

      ptr.ref.rlimCur = newSoft;
      ptr.ref.rlimMax = hardBefore;

      if (libc.setrlimit(resource, ptr) != 0) {
        return FdLimitAdjustment(
          softBefore: softBefore,
          hardBefore: hardBefore,
          softAfter: softBefore,
          hardAfter: hardBefore,
          target: target,
          raised: false,
          error: StateError('setrlimit failed'),
        );
      }

      // Re-read to report the authoritative post-state.
      if (libc.getrlimit(resource, ptr) != 0) {
        return FdLimitAdjustment(
          softBefore: softBefore,
          hardBefore: hardBefore,
          softAfter: newSoft,
          hardAfter: hardBefore,
          target: target,
          raised: true,
        );
      }
      return FdLimitAdjustment(
        softBefore: softBefore,
        hardBefore: hardBefore,
        softAfter: ptr.ref.rlimCur,
        hardAfter: ptr.ref.rlimMax,
        target: target,
        raised: true,
      );
    } finally {
      libc.free(ptr.cast());
    }
  } catch (e) {
    return FdLimitAdjustment(
      softBefore: -1,
      hardBefore: -1,
      softAfter: -1,
      hardAfter: -1,
      target: target,
      raised: false,
      error: e,
    );
  }
}

/// Reads the current file descriptor soft/hard limits without modifying them.
///
/// Returns `null` on unsupported platforms or on syscall failure. Intended for
/// diagnostic logging (e.g. when an `EMFILE` error is caught at runtime) —
/// pairs well with an `lsof` inspection to diagnose whether the process was
/// at its ceiling when a resource request failed.
({int soft, int hard})? readFileDescriptorLimits() {
  final libc = _libc;
  if (libc == null) return null;
  try {
    final ptr = libc.malloc(sizeOf<_Rlimit>()).cast<_Rlimit>();
    if (ptr.address == 0) return null;
    try {
      if (libc.getrlimit(_rlimitNofile(), ptr) != 0) return null;
      return (soft: ptr.ref.rlimCur, hard: ptr.ref.rlimMax);
    } finally {
      libc.free(ptr.cast());
    }
  } catch (_) {
    return null;
  }
}
