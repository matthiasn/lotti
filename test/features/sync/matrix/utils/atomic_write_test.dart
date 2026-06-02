// ignore_for_file: avoid_slow_async_io
// (The injected File wrappers must mirror production's async File.exists()
// signature, so the async dart:io API is intentional here.)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../../mocks/mocks.dart';

/// Minimal base subclass of [IOOverrides] that lets the outer [IOOverrides]
/// scope call the default (real) file factory without re-entering the zone and
/// causing infinite recursion.
base class _BaseIO extends IOOverrides {}

/// A [File] wrapper that throws a [FileSystemException] on the first [rename]
/// call and then delegates to the real [File] on every subsequent call.
///
/// This is used to drive the rename-failure recovery branch of
/// [atomicWriteBytes]: the very first `tmpFile.rename(dest)` fails, which sends
/// execution into the `on FileSystemException catch` block, while the retry
/// rename inside that block succeeds because it forwards to the real file.
class _FailFirstRenameFile implements File {
  _FailFirstRenameFile(this._real);
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
class _AlwaysFailRenameFile implements File {
  _AlwaysFailRenameFile(this._real);
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
class _UndeletableFile implements File {
  _UndeletableFile(this._real);
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

void main() {
  late Directory tempDir;
  late MockDomainLogger logging;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('atomic_write_test');
    logging = MockDomainLogger();
    when(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => logging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('atomicWriteBytes writes new file and content', () async {
    final path = p.join(tempDir.path, 'nested', 'file.bin');
    await atomicWriteBytes(
      bytes: [1, 2, 3, 4],
      filePath: path,
      logging: logging,
    );
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(await file.readAsBytes(), [1, 2, 3, 4]);

    // No leftover tmp/bak files
    final dir = Directory(p.dirname(path));
    final leftovers = dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where(
          (name) =>
              name.startsWith('file.bin.tmp.') ||
              name.startsWith('file.bin.bak.'),
        )
        .toList();
    expect(leftovers, isEmpty);
  });

  test('atomicWriteBytes overwrites existing file', () async {
    final path = p.join(tempDir.path, 'file.txt');
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('OLD');

    await atomicWriteBytes(
      bytes: 'NEW'.codeUnits,
      filePath: path,
      logging: logging,
    );

    expect(await File(path).readAsString(), 'NEW');
  });

  test('atomicWriteString writes text content', () async {
    final path = p.join(tempDir.path, 'doc.json');
    await atomicWriteString(
      text: '{"a":1}',
      filePath: path,
      logging: logging,
    );
    expect(await File(path).readAsString(), '{"a":1}');
  });

  test(
    'atomicWriteBytes logs and rethrows when destination is a directory',
    () async {
      // Create a directory at the destination path so rename will fail
      final path = p.join(tempDir.path, 'dest');
      Directory(path).createSync(recursive: true);

      await expectLater(
        () => atomicWriteBytes(
          bytes: [1, 2, 3],
          filePath: path, // points to an existing directory
          logging: logging,
        ),
        throwsA(isA<FileSystemException>()),
      );

      // We expect an exception capture for the failed rename fallback
      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);

      // Ensure no temp leftovers remain alongside the directory
      final leftovers = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((name) => name.startsWith('dest.tmp.'))
          .toList();
      expect(leftovers, isEmpty);
    },
  );

  test(
    'atomicWriteBytes rethrows and cleans up when logging is null',
    () async {
      final path = p.join(tempDir.path, 'no_log_dest');
      Directory(path).createSync(recursive: true);

      await expectLater(
        () => atomicWriteBytes(
          bytes: [9, 8, 7],
          filePath: path,
          // logging omitted — must not throw a null-dereference
        ),
        throwsA(isA<FileSystemException>()),
      );

      final leftovers = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((name) => name.startsWith('no_log_dest.tmp.'))
          .toList();
      expect(leftovers, isEmpty);
    },
  );

  test(
    'atomicWriteBytes forwards custom subDomain to logging.error',
    () async {
      final path = p.join(tempDir.path, 'sub_dest');
      Directory(path).createSync(recursive: true);

      await expectLater(
        () => atomicWriteBytes(
          bytes: [1],
          filePath: path,
          logging: logging,
          subDomain: 'myFeature',
        ),
        throwsA(isA<FileSystemException>()),
      );

      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'myFeature',
        ),
      ).called(1);
    },
  );

  test('atomicWriteBytes round-trips binary data faithfully', () async {
    final bytes = List<int>.generate(512, (i) => i % 256);
    final path = p.join(tempDir.path, 'binary.bin');

    await atomicWriteBytes(bytes: bytes, filePath: path);

    expect(await File(path).readAsBytes(), bytes);
  });

  test('atomicWriteBytes handles empty bytes', () async {
    final path = p.join(tempDir.path, 'empty.bin');
    await atomicWriteBytes(bytes: [], filePath: path);
    expect(await File(path).readAsBytes(), isEmpty);
  });

  test('atomicWriteString encodes UTF-8 text correctly', () async {
    const text = 'héllo wörld — emoji: 🙂';
    final path = p.join(tempDir.path, 'utf8.txt');
    await atomicWriteString(text: text, filePath: path);
    expect(await File(path).readAsString(), text);
  });

  test('atomicWriteString works without a logger', () async {
    final path = p.join(tempDir.path, 'no_log.txt');
    await atomicWriteString(text: 'hello', filePath: path);
    expect(await File(path).readAsString(), 'hello');
  });

  test(
    'atomicWriteString rethrows when destination is a directory (no logger)',
    () async {
      final path = p.join(tempDir.path, 'str_dest_dir');
      Directory(path).createSync(recursive: true);

      await expectLater(
        () => atomicWriteString(text: 'data', filePath: path),
        throwsA(isA<FileSystemException>()),
      );

      final leftovers = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((name) => name.startsWith('str_dest_dir.tmp.'))
          .toList();
      expect(leftovers, isEmpty);
    },
  );

  test('atomicWriteBytes creates deeply nested parent directories', () async {
    final path = p.join(tempDir.path, 'a', 'b', 'c', 'd', 'deep.txt');
    await atomicWriteBytes(bytes: [42], filePath: path);
    expect(await File(path).readAsBytes(), [42]);
  });

  test('atomicWriteString overwrites existing file', () async {
    final path = p.join(tempDir.path, 'overwrite.txt');
    await atomicWriteString(text: 'first', filePath: path);
    await atomicWriteString(text: 'second', filePath: path);
    expect(await File(path).readAsString(), 'second');
  });

  group('rename-failure recovery (IOOverrides injection)', () {
    test(
      'moves existing destination aside, retries rename, and deletes the backup',
      () async {
        final path = p.join(tempDir.path, 'recover.bin');
        // Existing destination that will be moved aside to a .bak.
        File(path)
          ..createSync(recursive: true)
          ..writeAsStringSync('OLD');

        final baseIO = _BaseIO();

        // The tmp file's first rename throws (driving into the catch block);
        // every other file — including the dest move-aside, the tmp retry
        // rename, and the .bak delete — uses the real implementation so the
        // happy recovery path completes.
        await IOOverrides.runZoned(
          () => atomicWriteBytes(
            bytes: 'NEW'.codeUnits,
            filePath: path,
            logging: logging,
          ),
          createFile: (filePath) {
            final real = baseIO.createFile(filePath);
            if (filePath.startsWith('$path.tmp.')) {
              return _FailFirstRenameFile(real);
            }
            return real;
          },
        );

        // The retry rename succeeded: destination holds the new content.
        expect(await File(path).readAsString(), 'NEW');

        // No tmp or bak leftovers — the backup was deleted.
        final leftovers = Directory(tempDir.path)
            .listSync()
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .where(
              (name) =>
                  name.startsWith('recover.bin.tmp.') ||
                  name.startsWith('recover.bin.bak.'),
            )
            .toList();
        expect(leftovers, isEmpty);

        // No error was logged — recovery succeeded cleanly.
        verifyNever(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        );
      },
    );

    test(
      'logs moveAside.failed when moving the destination aside throws, '
      'yet the retry rename still succeeds',
      () async {
        final path = p.join(tempDir.path, 'moveaside.bin');
        File(path)
          ..createSync(recursive: true)
          ..writeAsStringSync('OLD');

        final baseIO = _BaseIO();

        await IOOverrides.runZoned(
          () => atomicWriteBytes(
            bytes: 'NEW'.codeUnits,
            filePath: path,
            logging: logging,
          ),
          createFile: (filePath) {
            final real = baseIO.createFile(filePath);
            // tmp: first rename fails, retry succeeds.
            if (filePath.startsWith('$path.tmp.')) {
              return _FailFirstRenameFile(real);
            }
            // dest: the move-aside (dest.rename(bak)) fails, so `movedAside`
            // stays false and the moveAside.failed branch is logged. The
            // dest file still exists for the retry rename to overwrite.
            if (filePath == path) {
              return _AlwaysFailRenameFile(real);
            }
            return real;
          },
        );

        // Retry rename overwrote the existing destination with the new bytes.
        expect(await File(path).readAsString(), 'NEW');

        // The move-aside failure was logged.
        verify(
          () => logging.log(
            LogDomain.sync,
            any<String>(that: contains('moveAside.failed')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);

        // No top-level error: the write succeeded despite the move-aside fail.
        verifyNever(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        );

        // No bak leftovers (none was ever created since move-aside failed).
        final leftovers = Directory(tempDir.path)
            .listSync()
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .where(
              (name) =>
                  name.startsWith('moveaside.bin.tmp.') ||
                  name.startsWith('moveaside.bin.bak.'),
            )
            .toList();
        expect(leftovers, isEmpty);
      },
    );

    test(
      'logs cleanup.bakDelete.failed when deleting the backup throws',
      () async {
        final path = p.join(tempDir.path, 'bakdel.bin');
        File(path)
          ..createSync(recursive: true)
          ..writeAsStringSync('OLD');

        final baseIO = _BaseIO();

        await IOOverrides.runZoned(
          () => atomicWriteBytes(
            bytes: 'NEW'.codeUnits,
            filePath: path,
            logging: logging,
          ),
          createFile: (filePath) {
            final real = baseIO.createFile(filePath);
            if (filePath.startsWith('$path.tmp.')) {
              return _FailFirstRenameFile(real);
            }
            // The backup file (created by moving the dest aside) cannot be
            // deleted — drives the cleanup.bakDelete.failed log branch.
            if (filePath.startsWith('$path.bak.')) {
              return _UndeletableFile(real);
            }
            return real;
          },
        );

        // Retry rename still succeeded: destination holds the new content.
        expect(await File(path).readAsString(), 'NEW');

        // The bak-delete failure was logged (recovery still succeeded).
        verify(
          () => logging.log(
            LogDomain.sync,
            any<String>(that: contains('cleanup.bakDelete.failed')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);

        // No top-level error: the write itself succeeded.
        verifyNever(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        );
      },
    );

    test(
      'restores backup and rethrows when the retry rename also fails',
      () async {
        final path = p.join(tempDir.path, 'restore.bin');
        File(path)
          ..createSync(recursive: true)
          ..writeAsStringSync('ORIGINAL');

        final baseIO = _BaseIO();

        // The tmp file always fails to rename — both the initial attempt and
        // the retry inside the catch — driving the restore-and-rethrow path.
        // The dest move-aside uses a real rename so the backup genuinely holds
        // the original content and can be restored.
        await expectLater(
          () => IOOverrides.runZoned(
            () => atomicWriteBytes(
              bytes: 'NEW'.codeUnits,
              filePath: path,
              logging: logging,
            ),
            createFile: (filePath) {
              final real = baseIO.createFile(filePath);
              if (filePath.startsWith('$path.tmp.')) {
                return _AlwaysFailRenameFile(real);
              }
              return real;
            },
          ),
          throwsA(isA<FileSystemException>()),
        );

        // The original content was restored from the backup.
        expect(await File(path).readAsString(), 'ORIGINAL');

        // The top-level error was logged before rethrow.
        verify(
          () => logging.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);

        // No bak/tmp leftovers (backup was renamed back to the destination).
        final leftovers = Directory(tempDir.path)
            .listSync()
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .where(
              (name) =>
                  name.startsWith('restore.bin.tmp.') ||
                  name.startsWith('restore.bin.bak.'),
            )
            .toList();
        expect(leftovers, isEmpty);
      },
    );

    test(
      'logs cleanup.tmpDelete.failed and restore.failed when both cleanups fail',
      () async {
        final path = p.join(tempDir.path, 'doublefail.bin');
        File(path)
          ..createSync(recursive: true)
          ..writeAsStringSync('ORIGINAL');

        final baseIO = _BaseIO();

        // tmp: retry rename always fails AND its delete fails (tmpDelete log).
        // bak: its restore rename fails (restore.failed log).
        await expectLater(
          () => IOOverrides.runZoned(
            () => atomicWriteBytes(
              bytes: 'NEW'.codeUnits,
              filePath: path,
              logging: logging,
            ),
            createFile: (filePath) {
              final real = baseIO.createFile(filePath);
              if (filePath.startsWith('$path.tmp.')) {
                // Rename always fails (first + retry) and delete fails too.
                return _UndeletableAlwaysFailRenameFile(real);
              }
              if (filePath.startsWith('$path.bak.')) {
                // The dest move-aside (dest.rename(bak)) is real, but the
                // restore (bak.rename(dest)) is driven through this wrapper and
                // fails — exercising the restore.failed branch.
                return _AlwaysFailRenameFile(real);
              }
              return real;
            },
          ),
          throwsA(isA<FileSystemException>()),
        );

        // Both nested cleanup-failure events were logged.
        verify(
          () => logging.log(
            LogDomain.sync,
            any<String>(that: contains('cleanup.tmpDelete.failed')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
        verify(
          () => logging.log(
            LogDomain.sync,
            any<String>(that: contains('restore.failed')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);

        // The top-level error was still logged before rethrow.
        verify(
          () => logging.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
      },
    );
  });
}

/// A [File] wrapper whose [rename] always throws and whose [delete] also always
/// throws — used to exercise both the retry-rename-failure path and the nested
/// `cleanup.tmpDelete.failed` log branch on the tmp file at once.
class _UndeletableAlwaysFailRenameFile implements File {
  _UndeletableAlwaysFailRenameFile(this._real);
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
  Future<File> rename(String newPath) async =>
      throw FileSystemException('injected always-rename failure', path);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('injected delete failure', path);

  @override
  dynamic noSuchMethod(Invocation i) => _real.noSuchMethod(i);
}
