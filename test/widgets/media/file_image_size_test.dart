import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/media/file_image_size.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('readImageFileSize', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('file_image_size_');
    });

    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('reads the pixel size from the header of a real picture, and '
        'decodes nothing into the image cache', (tester) async {
      final picture = File('${dir.path}/pic.png')
        ..writeAsBytesSync(
          File('assets/design_system/avatar_placeholder.png').readAsBytesSync(),
        );

      final size = await tester.runAsync(() => readImageFileSize(picture.path));

      expect(size, const Size(160, 160));
      expect(
        PaintingBinding.instance.imageCache.currentSize,
        0,
        reason:
            'learning a size must not park the decoded picture in the cache '
            'under a key nothing draws with',
      );
    });

    testWidgets('throws for bytes that are not a picture', (tester) async {
      final junk = File('${dir.path}/junk.jpg')
        ..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xE0]);

      // Inside runAsync: the codec fails on real IO, and runAsync itself
      // would report an escaping error rather than rethrow it.
      await tester.runAsync(
        () => expectLater(readImageFileSize(junk.path), throwsException),
      );
    });
  });

  group('FileImageSize', () {
    /// Reads the test completes by hand, so "not known yet" and "known" are
    /// two frames the test controls rather than a decode it waits on.
    late Map<String, Completer<Size>> reads;
    late List<Size?> seen;

    Future<Size> read(String path) =>
        (reads[path] ??= Completer<Size>()).future;

    setUp(() {
      reads = {};
      seen = [];
    });

    Future<void> pump(WidgetTester tester, String path) => tester.pumpWidget(
      MaterialApp(
        home: FileImageSize(
          path: path,
          read: read,
          builder: (context, size) {
            seen.add(size);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    /// Completes the read for [path] and lets the widget react: the
    /// continuation is a microtask, and the frame its `setState` asks for
    /// is drawn by the pump after that.
    Future<void> deliver(WidgetTester tester, String path, Size size) async {
      reads[path]!.complete(size);
      await tester.pumpAndSettle();
    }

    testWidgets('hands the builder null until the size is known, then the '
        'size — once', (tester) async {
      await pump(tester, 'a.png');
      expect(seen, [null], reason: 'nothing is known before the read');

      await deliver(tester, 'a.png', const Size(160, 90));

      expect(seen, [null, const Size(160, 90)]);
    });

    testWidgets('a new path forgets the old size and asks for the new one', (
      tester,
    ) async {
      await pump(tester, 'a.png');
      await deliver(tester, 'a.png', const Size(160, 90));
      expect(seen.last, const Size(160, 90));

      seen.clear();
      await pump(tester, 'b.png');
      expect(
        seen,
        [null],
        reason:
            "the previous picture's size must not be reported for the new one",
      );

      await deliver(tester, 'b.png', const Size(30, 40));
      expect(seen.last, const Size(30, 40));
    });

    testWidgets('a read that finishes after the path has moved on is dropped', (
      tester,
    ) async {
      await pump(tester, 'a.png');
      await pump(tester, 'b.png');
      seen.clear();

      await deliver(tester, 'a.png', const Size(160, 90));
      expect(
        seen,
        isEmpty,
        reason: "a stale picture's size is nobody's answer",
      );

      await deliver(tester, 'b.png', const Size(30, 40));
      expect(seen, [const Size(30, 40)]);
    });

    testWidgets('a picture whose header cannot be read keeps the size '
        'unknown, quietly', (tester) async {
      await pump(tester, 'junk.jpg');
      reads['junk.jpg']!.completeError(Exception('Invalid image data'));
      await tester.pumpAndSettle();

      expect(seen, [null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a read that finishes after the widget is gone touches '
        'nothing', (tester) async {
      await pump(tester, 'a.png');
      await tester.pumpWidget(const SizedBox.shrink());

      reads['a.png']!.complete(const Size(160, 90));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
