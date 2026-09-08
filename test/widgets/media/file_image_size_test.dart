import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/media/file_image_size.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory dir;
  late File picture;
  final pngBytes = File(
    'assets/design_system/avatar_placeholder.png',
  ).readAsBytesSync();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('file_image_size_');
    picture = File('${dir.path}/pic.png')..writeAsBytesSync(pngBytes);
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Decodes before mounting — a decode started under the fake clock never
  /// completes for a later listener — then pumps the probe over [path] and
  /// records every size the builder was handed.
  Future<List<Size?>> pump(WidgetTester tester, String path) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(key: ValueKey('warm'))),
    );
    await tester.runAsync(
      () => precacheImage(
        FileImage(File(path)),
        tester.element(find.byKey(const ValueKey('warm'))),
      ),
    );
    final seen = <Size?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: FileImageSize(
          path: path,
          builder: (context, size) {
            seen.add(size);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    // One frame for the post-frame start, one for the setState.
    await tester.pump();
    await tester.pump();
    return seen;
  }

  testWidgets('hands the builder null first, then the decoded size', (
    tester,
  ) async {
    final seen = await pump(tester, picture.path);

    expect(seen.first, isNull, reason: 'nothing is known before the decode');
    expect(seen.last, const Size(160, 160));
  });

  testWidgets('a new path forgets the old size and learns the new one', (
    tester,
  ) async {
    final other = File('${dir.path}/other.png')..writeAsBytesSync(pngBytes);
    final seen = await pump(tester, picture.path);
    expect(seen.last, const Size(160, 160));

    await tester.runAsync(
      () => precacheImage(
        FileImage(other),
        tester.element(find.byType(FileImageSize)),
      ),
    );
    seen.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: FileImageSize(
          path: other.path,
          builder: (context, size) {
            seen.add(size);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      seen.first,
      isNull,
      reason:
          "the previous picture's size must not be reported for the new one",
    );
    expect(seen.last, const Size(160, 160));
  });
}
