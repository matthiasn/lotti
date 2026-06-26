import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'fake_image_compress_platform.dart';

void main() {
  group('FakeImageCompressPlatform', () {
    late Directory tempDir;
    late FakeImageCompressPlatform platform;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'fake_image_compress_platform_test_',
      );
      platform = FakeImageCompressPlatform();
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('compressWithFile throws when source file is missing', () async {
      final missingPath = path.join(tempDir.path, 'missing.heic');

      await expectLater(
        platform.compressWithFile(missingPath),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('compressAndGetFile throws when source file is missing', () async {
      final missingPath = path.join(tempDir.path, 'missing.heic');
      final targetPath = path.join(tempDir.path, 'target.jpg');

      await expectLater(
        platform.compressAndGetFile(missingPath, targetPath),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('compressAndGetFile writes output for an existing source', () async {
      final sourceFile = File(path.join(tempDir.path, 'source.heic'));
      final targetPath = path.join(tempDir.path, 'target.jpg');
      await sourceFile.writeAsBytes([1, 2, 3]);

      final result = await platform.compressAndGetFile(
        sourceFile.path,
        targetPath,
      );

      expect(result, isNotNull);
      expect(result!.path, targetPath);
      expect(File(targetPath).existsSync(), isTrue);
      expect(await File(targetPath).readAsBytes(), isNotEmpty);
    });
  });
}
