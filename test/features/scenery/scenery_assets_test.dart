import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('blue-hour scenery assets', () {
    const layerNames = [
      'city_bridge',
      'clouds_far',
      'clouds_mid',
      'clouds_near',
      'yacht',
      'foreground',
    ];

    test(
      'base plate and derived layers share one full-frame coordinate space',
      () async {
        final master = await _readImage('assets/scenery/blue_hour_master.webp');
        final cloudless = await _readImage(
          'assets/scenery/blue_hour_cloudless.webp',
        );
        expect(master.width, 2560);
        expect(master.height, 1440);
        expect(cloudless.width, master.width);
        expect(cloudless.height, master.height);
        expect(_alphaStats(cloudless).transparent, 0);

        for (final name in layerNames) {
          final layer = await _readImage('assets/scenery/$name.webp');
          expect(layer.width, master.width, reason: name);
          expect(layer.height, master.height, reason: name);
          expect(
            _alphaStats(layer),
            isA<_AlphaStats>()
                .having((s) => s.transparent, '$name transparent', isPositive)
                .having((s) => s.opaque, '$name opaque', isPositive),
          );
        }
      },
    );

    test(
      'foreground can occlude dancers while yacht and city stay mid-ground',
      () async {
        final city = _alphaStats(
          await _readImage('assets/scenery/city_bridge.webp'),
        );
        final yacht = _alphaStats(
          await _readImage('assets/scenery/yacht.webp'),
        );
        final foreground = _alphaStats(
          await _readImage('assets/scenery/foreground.webp'),
        );

        expect(city.bounds.top, lessThan(360));
        expect(city.bounds.bottom, lessThan(930));
        expect(yacht.bounds.left, greaterThan(1500));
        expect(yacht.bounds.bottom, lessThan(930));
        expect(foreground.bounds.bottom, 1439);
        expect(foreground.bounds.top, 0);
      },
    );
  });
}

Future<_DecodedImage> _readImage(String path) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final decoded = frame.image;
  final data = await decoded.toByteData();
  final image = _DecodedImage(
    width: decoded.width,
    height: decoded.height,
    bytes: data!.buffer.asUint8List(),
  );
  codec.dispose();
  decoded.dispose();
  return image;
}

_AlphaStats _alphaStats(_DecodedImage image) {
  var transparent = 0;
  var opaque = 0;
  var left = image.width;
  var top = image.height;
  var right = -1;
  var bottom = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final alpha = image.bytes[(y * image.width + x) * 4 + 3];
      if (alpha == 0) transparent++;
      if (alpha > 0) {
        if (alpha == 255) opaque++;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }

  return _AlphaStats(
    transparent: transparent,
    opaque: opaque,
    bounds: _Bounds(left: left, top: top, right: right, bottom: bottom),
  );
}

class _DecodedImage {
  const _DecodedImage({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final Uint8List bytes;
}

class _AlphaStats {
  const _AlphaStats({
    required this.transparent,
    required this.opaque,
    required this.bounds,
  });

  final int transparent;
  final int opaque;
  final _Bounds bounds;
}

class _Bounds {
  const _Bounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
}
