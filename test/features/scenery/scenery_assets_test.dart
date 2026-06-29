import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';

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

    const fullFrameAssets = [
      SceneryAssets.masterPlate,
      SceneryAssets.cloudlessPlate,
      SceneryAssets.cloudsFar,
      SceneryAssets.cloudsMid,
      SceneryAssets.cloudsNear,
      SceneryAssets.cityWindows,
      SceneryAssets.cityBridge,
      SceneryAssets.yacht,
      'assets/scenery/yacht_windows.webp',
      SceneryAssets.foreground,
    ];

    test('registered plates and lookup images are all full-frame', () async {
      for (final path in fullFrameAssets) {
        final image = await _readImage(path);

        expect(image.width, 2560, reason: path);
        expect(image.height, 1440, reason: path);
      }
    });

    test('city-window lookup only marks registered high-rise panes', () async {
      final image = await _readImage(SceneryAssets.cityWindows);

      final highRise = _countChannelAbove(
        image,
        channel: 0,
        threshold: 25,
        bounds: const _Bounds(left: 0, top: 216, right: 2559, bottom: 575),
      );
      final lowWaterfront = _countChannelAbove(
        image,
        channel: 0,
        threshold: 25,
        bounds: const _Bounds(left: 0, top: 576, right: 2559, bottom: 683),
      );
      final water = _countChannelAbove(
        image,
        channel: 0,
        threshold: 25,
        bounds: const _Bounds(left: 0, top: 684, right: 2559, bottom: 839),
      );
      final bridgeSpan = _countChannelAbove(
        image,
        channel: 0,
        threshold: 25,
        bounds: const _Bounds(left: 1362, top: 0, right: 2047, bottom: 1439),
      );
      final yachtSide = _countChannelAbove(
        image,
        channel: 0,
        threshold: 25,
        bounds: const _Bounds(left: 2048, top: 0, right: 2559, bottom: 1439),
      );

      expect(highRise, greaterThan(5000));
      expect(
        lowWaterfront,
        lessThan(highRise * 0.15),
        reason: 'low waterfront/bridge edges must not dominate city lights',
      );
      expect(water, 0);
      expect(bridgeSpan, 0);
      expect(yachtSide, 0);
    });

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

    test(
      'Lufthansa 747 overlay is a cropped transparent aircraft asset',
      () async {
        final jet = _alphaStats(
          await _readImage('assets/scenery/lufthansa_747.png'),
        );

        expect(jet.bounds.left, greaterThan(0));
        expect(jet.bounds.right, lessThan(1414));
        expect(jet.transparent, isPositive);
        expect(jet.opaque, isPositive);
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

int _countChannelAbove(
  _DecodedImage image, {
  required int channel,
  required int threshold,
  required _Bounds bounds,
}) {
  var count = 0;
  for (var y = bounds.top; y <= bounds.bottom; y++) {
    for (var x = bounds.left; x <= bounds.right; x++) {
      final value = image.bytes[(y * image.width + x) * 4 + channel];
      if (value > threshold) count++;
    }
  }
  return count;
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
