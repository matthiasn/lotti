import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('blue-hour scenery assets', () {
    const layerNames = [
      'city_bridge',
      'yacht',
      'foreground',
    ];

    test(
      'base plate and derived layers share one full-frame coordinate space',
      () async {
        final master = await _readPng('assets/scenery/blue_hour_master.png');
        expect(master.width, 2560);
        expect(master.height, 1440);

        for (final name in layerNames) {
          final layer = await _readPng('assets/scenery/$name.png');
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
          await _readPng('assets/scenery/city_bridge.png'),
        );
        final yacht = _alphaStats(await _readPng('assets/scenery/yacht.png'));
        final foreground = _alphaStats(
          await _readPng('assets/scenery/foreground.png'),
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

Future<_DecodedPng> _readPng(String path) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final decoded = frame.image;
  final data = await decoded.toByteData();
  final png = _DecodedPng(
    width: decoded.width,
    height: decoded.height,
    bytes: data!.buffer.asUint8List(),
  );
  codec.dispose();
  decoded.dispose();
  return png;
}

_AlphaStats _alphaStats(_DecodedPng png) {
  var transparent = 0;
  var opaque = 0;
  var left = png.width;
  var top = png.height;
  var right = -1;
  var bottom = -1;

  for (var y = 0; y < png.height; y++) {
    for (var x = 0; x < png.width; x++) {
      final alpha = png.bytes[(y * png.width + x) * 4 + 3];
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

class _DecodedPng {
  const _DecodedPng({
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
