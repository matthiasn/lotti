import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/cover_image.dart';

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
    expect(loads, 2);
  });
}
