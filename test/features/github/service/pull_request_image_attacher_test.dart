import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/service/pull_request_image_attacher.dart';
import 'package:lotti/logic/image_analysis_trigger.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

/// One call of the import the attacher was given.
typedef _Import = ({
  Uint8List data,
  String fileExtension,
  String? linkedId,
  String? categoryId,
  ImageAnalysisTrigger? analysisTrigger,
  bool linkCollapsed,
});

void main() {
  const url = 'https://pub-example.r2.dev/shots/desktop-dark.png';
  const taskId = 'task-1';
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 1, 2]);
  final jpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2]);
  final gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
  final webp = Uint8List.fromList([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 1, //
  ]);
  final riff = Uint8List.fromList([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45, 1, //
  ]);
  final svg = Uint8List.fromList(
    '<svg xmlns="http://www.w3.org/2000/svg"/>'.codeUnits,
  );

  setUpAll(registerAllFallbackValues);

  group('pullRequestImageExtension', () {
    for (final (bytes, name, extension) in [
      (png, 'png', 'png'),
      (jpg, 'jpeg', 'jpg'),
      (gif, 'gif', 'gif'),
      (webp, 'webp', 'webp'),
    ]) {
      test('reads $name from its bytes, whatever the URL says', () {
        expect(
          pullRequestImageExtension(bytes, url: 'https://x.example/asset'),
          extension,
        );
        expect(
          pullRequestImageExtension(bytes, url: 'https://x.example/a.svg'),
          extension,
        );
      });
    }

    test('falls back to the path when the bytes are not telling', () {
      final plain = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
      expect(
        pullRequestImageExtension(plain, url: 'https://x.example/a.JPG'),
        'jpg',
      );
      expect(
        pullRequestImageExtension(plain, url: 'https://x.example/a.webp?x=1'),
        'webp',
      );
      expect(
        pullRequestImageExtension(plain, url: 'https://x.example/a.svg'),
        isNull,
      );
      expect(
        pullRequestImageExtension(plain, url: 'https://x.example/a'),
        isNull,
      );
    });

    test('a RIFF that is not WEBP is not an image', () {
      expect(
        pullRequestImageExtension(riff, url: 'https://x.example/a'),
        isNull,
      );
    });

    test('bytes shorter than a signature are not an image', () {
      expect(
        pullRequestImageExtension(
          Uint8List.fromList([0x89, 0x50]),
          url: 'https://x.example/a',
        ),
        isNull,
      );
    });
  });

  group('PullRequestImageAttacher', () {
    late List<_Import> imports;
    late MockAutomaticImageAnalysisTrigger trigger;
    late MockDomainLogger logger;

    setUp(() {
      imports = [];
      trigger = MockAutomaticImageAnalysisTrigger();
      logger = MockDomainLogger();
    });

    PullRequestImageAttacher attacher({
      Future<ImportedImage?> Function()? result,
      String? categoryId = 'category-1',
    }) => PullRequestImageAttacher(
      categoryOf: (id) async => id == taskId ? categoryId : null,
      analysisTrigger: trigger,
      logger: logger,
      import:
          ({
            required data,
            required fileExtension,
            linkedId,
            categoryId,
            analysisTrigger,
            linkCollapsed = false,
          }) {
            imports.add((
              data: data,
              fileExtension: fileExtension,
              linkedId: linkedId,
              categoryId: categoryId,
              analysisTrigger: analysisTrigger,
              linkCollapsed: linkCollapsed,
            ));
            return result?.call() ??
                Future.value((id: 'image-1', created: true));
          },
    );

    test('imports the bytes as a pasted picture of the task, with the analysis '
        'trigger and the category', () async {
      expect(
        await attacher().attach(bytes: png, url: url, taskId: taskId),
        isTrue,
      );

      expect(imports.single, (
        data: png,
        fileExtension: 'png',
        linkedId: taskId,
        categoryId: 'category-1',
        analysisTrigger: trigger,
        linkCollapsed: false,
      ));
    });

    test('a task without a category imports without one', () async {
      expect(
        await attacher(
          categoryId: null,
        ).attach(bytes: jpg, url: url, taskId: taskId),
        isTrue,
      );

      expect(imports.single.categoryId, isNull);
      expect(imports.single.fileExtension, 'jpg');
    });

    test('bytes the app cannot store are not imported', () async {
      expect(
        await attacher().attach(
          bytes: svg,
          url: 'https://x.example/a.svg',
          taskId: taskId,
        ),
        isFalse,
      );

      expect(imports, isEmpty);
      verifyNever(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      );
    });

    test('an import that writes nothing is a failure', () async {
      expect(
        await attacher(
          result: () async => null,
        ).attach(bytes: png, url: url, taskId: taskId),
        isFalse,
      );
    });

    test('an import that throws is a failure, and is logged', () async {
      const error = FileSystemException('disk full');
      expect(
        await attacher(
          result: () => Future.error(error),
        ).attach(bytes: png, url: url, taskId: taskId),
        isFalse,
      );

      verify(
        () => logger.error(
          LogDomain.persistence,
          error,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'pullRequestImageAttach',
        ),
      ).called(1);
    });
  });

  group('pullRequestImageFile', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('pull_request_image_file_');
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('writes the bytes under a name from the URL, with the format as its '
        'extension', () {
      final file = pullRequestImageFile(png, url: url, root: root);

      expect(file.path, startsWith('${root.path}/lotti_pull_request_images/'));
      expect(file.path, endsWith('.png'));
      expect(file.readAsBytesSync(), png);
      expect(file.path, isNot(contains('desktop-dark')));
    });

    test('the same URL lands on the same file; another URL on another', () {
      final first = pullRequestImageFile(png, url: url, root: root);
      final again = pullRequestImageFile(png, url: url, root: root);
      final other = pullRequestImageFile(png, url: '$url?v=2', root: root);

      expect(again.path, first.path);
      expect(other.path, isNot(first.path));
    });

    test('bytes it cannot name get a neutral extension', () {
      final file = pullRequestImageFile(
        svg,
        url: 'https://x.example/a',
        root: root,
      );

      expect(file.path, endsWith('.img'));
      expect(file.readAsBytesSync(), svg);
    });
  });
}
