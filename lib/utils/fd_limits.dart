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

typedef _MallocNative = Pointer<Void> Function(IntPtr);
typedef _Malloc = Pointer<Void> Function(int);

typedef _FreeNative = Void Function(Pointer<Void>);
typedef _Free = void Function(Pointer<Void>);

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
  if (!Platform.isMacOS && !Platform.isLinux) {
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
    final libc = DynamicLibrary.process();
    final getrlimit = libc.lookupFunction<_RlimitSyscallNative, _RlimitSyscall>(
      'getrlimit',
    );
    final setrlimit = libc.lookupFunction<_RlimitSyscallNative, _RlimitSyscall>(
      'setrlimit',
    );
    final malloc = libc.lookupFunction<_MallocNative, _Malloc>('malloc');
    final free = libc.lookupFunction<_FreeNative, _Free>('free');

    final resource = _rlimitNofile();
    final ptr = malloc(sizeOf<_Rlimit>()).cast<_Rlimit>();
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
      if (getrlimit(resource, ptr) != 0) {
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

      // Clamp to the hard limit. RLIM_INFINITY is (rlim_t)-1 == UINT64_MAX,
      // which is always > target, so `target < hardBefore` picks target.
      final newSoft = target < hardBefore ? target : hardBefore;

      ptr.ref.rlimCur = newSoft;
      ptr.ref.rlimMax = hardBefore;

      if (setrlimit(resource, ptr) != 0) {
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
      if (getrlimit(resource, ptr) != 0) {
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
      free(ptr.cast());
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
  if (!Platform.isMacOS && !Platform.isLinux) return null;
  try {
    final libc = DynamicLibrary.process();
    final getrlimit = libc.lookupFunction<_RlimitSyscallNative, _RlimitSyscall>(
      'getrlimit',
    );
    final malloc = libc.lookupFunction<_MallocNative, _Malloc>('malloc');
    final free = libc.lookupFunction<_FreeNative, _Free>('free');

    final ptr = malloc(sizeOf<_Rlimit>()).cast<_Rlimit>();
    if (ptr.address == 0) return null;
    try {
      if (getrlimit(_rlimitNofile(), ptr) != 0) return null;
      return (soft: ptr.ref.rlimCur, hard: ptr.ref.rlimMax);
    } finally {
      free(ptr.cast());
    }
  } catch (_) {
    return null;
  }
}
