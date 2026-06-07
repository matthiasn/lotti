/// Fake [File]/[IOOverrides] doubles for `atomic_write_test.dart`: each one
/// drives a specific failure branch of `atomicWriteBytes` (first-rename
/// failure with successful retry, persistent rename failure, undeletable
/// tmp file).
library;

// ignore_for_file: avoid_slow_async_io
// (The injected File wrappers must mirror production's async File.exists()
// signature, so the async dart:io API is intentional here.)

import 'dart:io';

/// Minimal base subclass of [IOOverrides] that lets the outer [IOOverrides]
/// scope call the default (real) file factory without re-entering the zone and
/// causing infinite recursion.
base class BaseIOOverrides extends IOOverrides {}

/// A [File] wrapper that throws a [FileSystemException] on the first [rename]
/// call and then delegates to the real [File] on every subsequent call.
///
/// This is used to drive the rename-failure recovery branch of
/// [atomicWriteBytes]: the very first `tmpFile.rename(dest)` fails, which sends
/// execution into the `on FileSystemException catch` block, while the retry
/// rename inside that block succeeds because it forwards to the real file.
class FailFirstRenameFile implements File {
  FailFirstRenameFile(this._real);
  final File _real;
  var _failedOnce = false;

  @override
  String get path => _real.path;

  @override
  Directory get parent => _real.parent;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _real.writeAsBytes(bytes, mode: mode, flush: flush);

  @override
  Future<bool> exists() => _real.exists();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      _real.delete(recursive: recursive);

  @override
  Future<File> rename(String newPath) async {
    if (!_failedOnce) {
      _failedOnce = true;
      throw FileSystemException('injected first-rename failure', path);
    }
    return _real.rename(newPath);
  }

  @override
  dynamic noSuchMethod(Invocation i) => _real.noSuchMethod(i);
}

/// A [File] wrapper whose [rename] always throws a [FileSystemException]. All
/// other calls are forwarded to the real delegate.
class AlwaysFailRenameFile implements File {
  AlwaysFailRenameFile(this._real);
  final File _real;

  @override
  String get path => _real.path;

  @override
  Directory get parent => _real.parent;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _real.writeAsBytes(bytes, mode: mode, flush: flush);

  @override
  Future<bool> exists() => _real.exists();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      _real.delete(recursive: recursive);

  @override
  Future<File> rename(String newPath) async =>
      throw FileSystemException('injected always-rename failure', path);

  @override
  dynamic noSuchMethod(Invocation i) => _real.noSuchMethod(i);
}

/// A [File] wrapper whose [delete] always throws a [FileSystemException]. Used
/// to drive the inner cleanup-failure log branch when the tmp delete fails.
class UndeletableFile implements File {
  UndeletableFile(this._real);
  final File _real;

  @override
  String get path => _real.path;

  @override
  Directory get parent => _real.parent;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _real.writeAsBytes(bytes, mode: mode, flush: flush);

  @override
  Future<bool> exists() => _real.exists();

  @override
  Future<File> rename(String newPath) => _real.rename(newPath);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('injected delete failure', path);

  @override
  dynamic noSuchMethod(Invocation i) => _real.noSuchMethod(i);
}
