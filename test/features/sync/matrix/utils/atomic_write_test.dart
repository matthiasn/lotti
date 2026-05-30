import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../../mocks/mocks.dart';

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
    ).thenAnswer((_) async {});
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
}
