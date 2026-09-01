import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/thumbhash.dart';

/// Deterministic pixels shared with the JavaScript reference run that
/// produced the goldens below: xorshift32 noise per byte, seeded from the
/// dimensions, with the alpha channel shaped by [mode] — 0 opaque, 1 noisy,
/// 2 fully transparent, 3 a flat opaque colour.
Uint8List _synthetic(int width, int height, int mode) {
  var x = (width * 1000003 + height * 7919 + mode) & 0xFFFFFFFF;
  if (x == 0) x = 1;
  final rgba = Uint8List(width * height * 4);
  for (var i = 0; i < rgba.length; i++) {
    x = (x ^ (x << 13)) & 0xFFFFFFFF;
    x = x ^ (x >> 17);
    x = (x ^ (x << 5)) & 0xFFFFFFFF;
    var value = x & 255;
    if (i % 4 == 3) {
      if (mode == 0) value = 255;
      if (mode == 2) value = 0;
    }
    if (mode == 3) value = i % 4 == 3 ? 255 : 77;
    rgba[i] = value;
  }
  return rgba;
}

/// A 40×30 opaque picture, red on the left half and blue on the right.
Uint8List _splitPicture() {
  const width = 40;
  const height = 30;
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final left = x < width ~/ 2;
      rgba[i] = left ? 220 : 20;
      rgba[i + 1] = 30;
      rgba[i + 2] = left ? 20 : 220;
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Reference hashes from evanw/thumbhash's JavaScript encoder over
/// [_synthetic] pixels of the named size and mode.
const _referenceOpaque7x5 = '6237061d8ad857528d079c60899b3dcbb6783f0726';
const _referenceAlpha100x10 = '2008820182081f7ceabc74f95b04456b7e33efb567aaba';
const _referencePortrait10x100 = 'e0f7010902fc93d87768674f406065f744';

/// What the JavaScript encoder writes for the flat 9×9 picture: the varying
/// nibbles are floating-point noise, and the decoder never reads them.
const _referenceFlat9x9 = '1308020700785d168887788677e888787886000000000000';

/// The reference decoder's raster for [_referencePortrait10x100]: 5×32
/// pixels, RGBA.
const _referencePortraitRaster =
    '737997ff787a90ff7e7c8aff817b87ff817a88ff737997ff787b90ff7e7c89ff'
    '817b87ff817a87ff747996ff787b90ff7e7c89ff817b87ff827a87ff747996ff'
    '797b90ff7e7c89ff817c86ff827a87ff757995ff797b8fff7f7c88ff827c86ff'
    '827b86ff757995ff7a7b8eff7f7c87ff827c85ff837b86ff767994ff7b7b8dff'
    '807d87ff837c84ff837b85ff777a93ff7b7b8dff807d86ff837d83ff837c84ff'
    '777a92ff7c7c8cff817d85ff837d83ff847c83ff787a91ff7d7c8bff827e84ff'
    '847d82ff847d82ff797a90ff7d7c8aff827e83ff847e81ff847d82ff7a7b8fff'
    '7e7d89ff827f82ff857f80ff847e81ff7a7b8eff7e7d88ff837f81ff857f7fff'
    '857f80ff7b7c8dff7f7e87ff838080ff85807eff847f7fff7b7c8cff7f7e86ff'
    '83817fff85817eff84807fff7b7d8bff7f7f85ff83817fff84827dff84817eff'
    '7b7e8aff7f8084ff83827eff84837cff84827dff7b7e89ff7f8183ff83837dff'
    '84847cff83837dff7b7f89ff7f8183ff82847dff83857bff82847dff7b8088ff'
    '7e8282ff82857dff82867bff81857cff7b8188ff7e8382ff81867cff82877bff'
    '81867cff7a8187ff7d8482ff80877cff81887bff80887cff7a8287ff7d8582ff'
    '80887cff80897bff7f897cff798387ff7c8681ff7f887cff7f8a7bff7e8a7cff'
    '788487ff7b8681ff7e897cff7e8b7bff7d8b7cff788487ff7b8781ff7d8a7cff'
    '7d8b7bff7c8b7cff778587ff7a8881ff7c8b7cff7c8c7bff7b8c7cff778587ff'
    '7a8881ff7c8b7cff7b8d7bff7a8d7cff768687ff798981ff7b8c7cff7b8d7bff'
    '798d7cff768687ff798981ff7b8c7cff7a8e7bff798e7dff768687ff788981ff'
    '7b8c7cff7a8e7bff788e7dff768787ff788981ff7a8d7cff7a8e7bff788e7dff';

/// Mean of one channel over a run of pixels.
double _mean(Uint8List rgba, int channel, {int from = 0, int? to}) {
  final end = to ?? rgba.length ~/ 4;
  var sum = 0;
  for (var i = from; i < end; i++) {
    sum += rgba[i * 4 + channel];
  }
  return sum / (end - from);
}

Matcher _isRaster(int width, int height) => isA<ThumbHashPixels>()
    .having((p) => p.width, 'width', width)
    .having((p) => p.height, 'height', height)
    .having((p) => p.rgba.length, 'rgba.length', width * height * 4);

void main() {
  group('ThumbHash.encode', () {
    test('matches the reference implementation byte for byte on an opaque '
        'image', () {
      final hash = ThumbHash.encode(
        width: 7,
        height: 5,
        rgba: _synthetic(7, 5, 0),
      );

      expect(_hex(hash.bytes), _referenceOpaque7x5);
      expect(hash.hasAlpha, isFalse);
    });

    test('matches the reference implementation on an image with alpha', () {
      final hash = ThumbHash.encode(
        width: 100,
        height: 10,
        rgba: _synthetic(100, 10, 1),
      );

      expect(_hex(hash.bytes), _referenceAlpha100x10);
      expect(hash.hasAlpha, isTrue);
    });

    test('matches the reference implementation on a portrait image', () {
      final hash = ThumbHash.encode(
        width: 10,
        height: 100,
        rgba: _synthetic(10, 100, 0),
      );

      expect(_hex(hash.bytes), _referencePortrait10x100);
    });

    test('writes zero varying terms for a flat colour, so the bytes do not '
        'depend on the platform', () {
      final flat = ThumbHash.encode(
        width: 9,
        height: 9,
        rgba: _synthetic(9, 9, 3),
      );

      // Same five header bytes as the reference, zeros where it wrote noise …
      expect(_hex(flat.bytes), startsWith(_referenceFlat9x9.substring(0, 10)));
      expect(flat.bytes.length, _referenceFlat9x9.length ~/ 2);
      expect(_hex(flat.bytes.sublist(5)), '0' * (flat.bytes.length - 5) * 2);
      // … and the same picture, because the decoder scales those terms by
      // a quantised magnitude that is zero either way.
      final reference = ThumbHash(_bytes(_referenceFlat9x9));
      expect(flat.decode().rgba, reference.decode().rgba);
      final pixels = flat.decode();
      final first = pixels.rgba.sublist(0, 4);
      for (var i = 0; i < pixels.rgba.length; i += 4) {
        expect(pixels.rgba.sublist(i, i + 4), first);
      }
    });

    test('stores the aspect ratio as the luminance grid it fits', () {
      ThumbHash encode(int width, int height) => ThumbHash.encode(
        width: width,
        height: height,
        rgba: _synthetic(width, height, 0),
      );

      expect(encode(100, 10).aspectRatio, 7 / 1);
      expect(encode(10, 100).aspectRatio, 1 / 7);
      expect(encode(16, 16).aspectRatio, 1);
      expect(encode(32, 20).aspectRatio, 7 / 4);
    });

    test('records alpha only when some pixel is not opaque', () {
      ThumbHash encode(int mode) =>
          ThumbHash.encode(width: 6, height: 6, rgba: _synthetic(6, 6, mode));

      expect(encode(0).hasAlpha, isFalse);
      expect(encode(3).hasAlpha, isFalse);
      expect(encode(1).hasAlpha, isTrue);
      expect(encode(2).hasAlpha, isTrue);
    });

    test('rejects an image outside 1×1 … 100×100', () {
      expect(
        () => ThumbHash.encode(width: 101, height: 1, rgba: Uint8List(404)),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('got 101×1'),
          ),
        ),
      );
      expect(
        () => ThumbHash.encode(width: 1, height: 101, rgba: Uint8List(404)),
        throwsArgumentError,
      );
      expect(
        () => ThumbHash.encode(width: 0, height: 5, rgba: Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => ThumbHash.encode(width: 5, height: 0, rgba: Uint8List(0)),
        throwsArgumentError,
      );
    });

    test('rejects a byte count that does not match the dimensions', () {
      expect(
        () => ThumbHash.encode(width: 3, height: 2, rgba: Uint8List(23)),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Expected 24 RGBA bytes for 3×2, got 23',
          ),
        ),
      );
    });
  });

  group('ThumbHash.decode', () {
    test('decodes the reference raster pixel for pixel', () {
      final pixels = ThumbHash(_bytes(_referencePortrait10x100)).decode();

      expect(pixels.width, 5);
      expect(pixels.height, thumbHashRasterExtent);
      expect(_hex(pixels.rgba), _referencePortraitRaster);
    });

    test('sizes the raster to 32 pixels on its longest edge', () {
      expect(
        ThumbHash(_bytes(_referenceOpaque7x5)).decode(),
        _isRaster(32, 23),
      );
      expect(
        ThumbHash(_bytes(_referenceAlpha100x10)).decode(),
        _isRaster(32, 6),
      );
      expect(
        ThumbHash.encode(
          width: 16,
          height: 16,
          rgba: _synthetic(16, 16, 0),
        ).decode(),
        _isRaster(32, 32),
      );
    });

    test('keeps the average colour and the composition of the source', () {
      final source = _splitPicture();
      final pixels = ThumbHash.encode(
        width: 40,
        height: 30,
        rgba: source,
      ).decode();

      for (var channel = 0; channel < 3; channel++) {
        expect(
          _mean(pixels.rgba, channel),
          closeTo(_mean(source, channel), 20),
          reason: 'channel $channel',
        );
      }
      expect(_mean(pixels.rgba, 3), 255);

      // Left third is red, right third is blue — not a uniform smear.
      final row = pixels.height ~/ 2;
      final third = pixels.width ~/ 3;
      final leftFrom = row * pixels.width;
      final leftTo = leftFrom + third;
      final rightTo = (row + 1) * pixels.width;
      final rightFrom = rightTo - third;
      expect(
        _mean(pixels.rgba, 0, from: leftFrom, to: leftTo),
        greaterThan(_mean(pixels.rgba, 0, from: rightFrom, to: rightTo) + 80),
      );
      expect(
        _mean(pixels.rgba, 2, from: rightFrom, to: rightTo),
        greaterThan(_mean(pixels.rgba, 2, from: leftFrom, to: leftTo) + 80),
      );
    });

    test('a fully transparent image decodes fully transparent', () {
      final hash = ThumbHash.encode(
        width: 12,
        height: 8,
        rgba: _synthetic(12, 8, 2),
      );

      expect(hash.hasAlpha, isTrue);
      final pixels = hash.decode();
      for (var i = 3; i < pixels.rgba.length; i += 4) {
        expect(pixels.rgba[i], 0);
      }
    });
  });

  group('ThumbHash parsing', () {
    test('round-trips through base64', () {
      final hash = ThumbHash(_bytes(_referenceAlpha100x10));

      final parsed = ThumbHash.fromBase64(hash.toBase64());

      expect(parsed, hash);
      expect(parsed.hashCode, hash.hashCode);
      expect(parsed.bytes, isNot(same(hash.bytes)));
    });

    test('accepts unpadded and URL-safe base64', () {
      const padded = 'juYJFIImeYqKeZdwiYb6kZ8/+Q==';

      expect(
        ThumbHash.fromBase64('juYJFIImeYqKeZdwiYb6kZ8_-Q'),
        ThumbHash.fromBase64(padded),
      );
      expect(ThumbHash.fromBase64(padded).toBase64(), padded);
    });

    test('rejects bytes too short for a header', () {
      expect(
        () => ThumbHash(Uint8List(4)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'A ThumbHash is at least 5 bytes, got 4',
          ),
        ),
      );
    });

    test('rejects a header that stores a zero extent', () {
      expect(
        () => ThumbHash(Uint8List(5)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'A ThumbHash header cannot store a 0 extent',
          ),
        ),
      );
    });

    test('rejects a length that disagrees with the header', () {
      final reference = _bytes(_referenceOpaque7x5);

      expect(
        () => ThumbHash(reference.sublist(0, reference.length - 1)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'This ThumbHash header announces ${reference.length} bytes, '
                'got ${reference.length - 1}',
          ),
        ),
      );
      expect(
        () => ThumbHash(Uint8List.fromList([...reference, 0])),
        throwsFormatException,
      );
      // With alpha the header is one byte longer and announces more terms.
      final alpha = _bytes(_referenceAlpha100x10);
      expect(alpha.length, greaterThan(reference.length));
      expect(
        () => ThumbHash(alpha.sublist(0, alpha.length - 1)),
        throwsFormatException,
      );
    });

    test('fromBase64 rejects text that is not base64', () {
      expect(() => ThumbHash.fromBase64('not base64!'), throwsFormatException);
    });

    test('tryParse answers null for anything that is not a hash', () {
      final hash = ThumbHash(_bytes(_referenceOpaque7x5));

      expect(ThumbHash.tryParse(null), isNull);
      expect(ThumbHash.tryParse(''), isNull);
      expect(ThumbHash.tryParse('not base64!'), isNull);
      expect(ThumbHash.tryParse('AAAAAA=='), isNull);
      expect(ThumbHash.tryParse(hash.toBase64()), hash);
    });

    test('equality follows the bytes and toString shows the base64', () {
      final a = ThumbHash(_bytes(_referenceOpaque7x5));
      final b = ThumbHash(_bytes(_referenceOpaque7x5));
      final other = ThumbHash(_bytes(_referencePortrait10x100));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(other));
      expect(a == Object(), isFalse);
      expect(a.toString(), 'ThumbHash(${a.toBase64()})');
    });

    test('exposes its bytes read-only, detached from the input', () {
      final input = _bytes(_referenceOpaque7x5);
      final hash = ThumbHash(input);

      input[0] = 0;

      expect(hash.bytes[0], isNot(0));
      expect(() => hash.bytes[0] = 1, throwsUnsupportedError);
    });
  });

  group('properties', () {
    glados.Glados3(
      glados.any.intInRange(1, 25),
      glados.any.intInRange(1, 25),
      glados.any.intInRange(0, 4),
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'every picture encodes to a hash that validates, round-trips and '
      'decodes to a well-formed raster',
      (width, height, mode) {
        final rgba = _synthetic(width, height, mode);
        final hash = ThumbHash.encode(width: width, height: height, rgba: rgba);
        final reason = '$width×$height mode $mode: ${hash.toBase64()}';

        expect(ThumbHash(hash.bytes), hash, reason: reason);
        expect(ThumbHash.fromBase64(hash.toBase64()), hash, reason: reason);
        expect(hash.bytes.length, lessThanOrEqualTo(25), reason: reason);

        var translucent = false;
        for (var i = 3; i < rgba.length; i += 4) {
          translucent |= rgba[i] < 255;
        }
        expect(hash.hasAlpha, translucent, reason: reason);

        final pixels = hash.decode();
        expect(
          math.max(pixels.width, pixels.height),
          thumbHashRasterExtent,
          reason: reason,
        );
        expect(
          pixels.rgba.length,
          pixels.width * pixels.height * 4,
          reason: reason,
        );
        if (width > height) {
          expect(pixels.width, greaterThanOrEqualTo(pixels.height));
        } else if (height > width) {
          expect(pixels.height, greaterThanOrEqualTo(pixels.width));
        }
        expect(hash.aspectRatio, greaterThan(0), reason: reason);
      },
      tags: 'glados',
    );
  });
}
