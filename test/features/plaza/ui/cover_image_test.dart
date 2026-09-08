import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/cover_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

Completer<ImageInfo> _pendingCover(String url) {
  final provider = NetworkImage(url);
  final decoded = Completer<ImageInfo>();
  PaintingBinding.instance.imageCache.putIfAbsent(
    provider,
    () => OneFrameImageStreamCompleter(decoded.future),
  );
  addTearDown(provider.evict);
  return decoded;
}

Widget _host(String url, {double opacity = 1, VoidCallback? onLoaded}) =>
    makeTestableWidget2(
      SizedBox(
        width: 200,
        height: 100,
        child: CoverImage(url: url, opacity: opacity, onLoaded: onLoaded),
      ),
    );

void main() {
  late ui.Image image;
  setUpAll(() async {
    image = await createTestImage();
  });
  tearDownAll(() => image.dispose());

  testWidgets(
    'local cover paths use the file cache and report decoded pixels',
    (
      tester,
    ) async {
      final file = File('/tmp/plaza fixture/cover.png');
      final provider = FileImage(file);
      final decoded = Completer<ImageInfo>();
      PaintingBinding.instance.imageCache.putIfAbsent(
        provider,
        () => OneFrameImageStreamCompleter(decoded.future),
      );
      addTearDown(provider.evict);
      var loads = 0;
      await tester.pumpWidget(
        _host(file.uri.toString(), onLoaded: () => loads++),
      );
      expect(tester.widget<Image>(find.byType(Image)).image, provider);
      decoded.complete(ImageInfo(image: image.clone()));
      await tester.pump();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(loads, 1);
    },
  );

  testWidgets('a local cover arriving after sync replaces the error fallback', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'plaza-cover-arrival-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/cover.png');
    final provider = FileImage(file);
    final failed = Completer<ImageInfo>();
    PaintingBinding.instance.imageCache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(failed.future),
    );
    addTearDown(provider.evict);
    var loads = 0;
    await tester.pumpWidget(
      _host(file.uri.toString(), onLoaded: () => loads++),
    );
    failed.completeError(const FileSystemException('not downloaded'));
    await tester.pump();
    expect(loads, 1);
    expect(find.byType(RawImage), findsNothing);
    final arrived = Completer<ImageInfo>();
    PaintingBinding.instance.imageCache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(arrived.future),
    );
    file.writeAsBytesSync([1]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<Image>(find.byType(Image)).key,
      ValueKey((file.uri.toString(), 1)),
      reason: 'arrival must replace the failed Image stream',
    );
    arrived.complete(ImageInfo(image: image.clone()));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(loads, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reports once, after the frame that paints the picture', (
    tester,
  ) async {
    const url = 'https://demo.invalid/cover.webp';
    final decoded = _pendingCover(url);
    var loads = 0;
    await tester.pumpWidget(_host(url, opacity: 0.45, onLoaded: () => loads++));
    expect(loads, 0);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.45);
    decoded.complete(ImageInfo(image: image.clone()));
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(loads, 1);
    await tester.pump();
    await tester.pumpWidget(_host(url, opacity: 0.45, onLoaded: () => loads++));
    await tester.pump();
    expect(loads, 1, reason: 'a rebuild with the same picture is not a load');
  });

  testWidgets('a picture that fails still reports, and a new url again', (
    tester,
  ) async {
    const first = 'https://demo.invalid/first.webp';
    const second = 'https://demo.invalid/second.webp';
    final failing = _pendingCover(first);
    final landing = _pendingCover(second);
    var loads = 0;
    await tester.pumpWidget(_host(first, onLoaded: () => loads++));
    failing.completeError(StateError('no such cover'));
    await tester.pump();
    expect(loads, 1);
    expect(find.byType(RawImage), findsNothing);
    await tester.pumpWidget(_host(second, onLoaded: () => loads++));
    landing.complete(ImageInfo(image: image.clone()));
    await tester.pump();
    await tester.pump();
    expect(loads, 2);
  });
}
