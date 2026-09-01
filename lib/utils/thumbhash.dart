// ThumbHash: a picture's dominant colours and rough composition in about
// thirty bytes, decoding to a blurred stand-in that can be drawn before the
// picture itself has arrived.
//
// This is a Dart port of the reference implementation by Evan Wallace,
// https://github.com/evanw/thumbhash, kept byte-for-byte compatible with it: a
// hash produced here decodes to the same raster in every other ThumbHash
// implementation, and theirs decode here. The algorithm is vendored rather
// than pulled from pub because the packages wrapping it are single-maintainer
// with a handful of downloads, this is render-path code, and the whole thing
// is two hundred lines that a test file can cover to the last branch.
//
// The reference implementation is distributed under the MIT License:
//
//   Copyright (c) 2023 Evan Wallace
//
//   Permission is hereby granted, free of charge, to any person obtaining a
//   copy of this software and associated documentation files (the
//   "Software"), to deal in the Software without restriction, including
//   without limitation the rights to use, copy, modify, merge, publish,
//   distribute, sublicense, and/or sell copies of the Software, and to permit
//   persons to whom the Software is furnished to do so, subject to the
//   following conditions:
//
//   The above copyright notice and this permission notice shall be included
//   in all copies or substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
//   NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//   DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//   OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
//   USE OR OTHER DEALINGS IN THE SOFTWARE.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Largest edge, in pixels, that [ThumbHash.encode] accepts.
///
/// The encoder is a full-image DCT; anything larger is slow for no gain in
/// a hash that only ever holds a handful of frequency terms. Callers resize
/// first.
const int thumbHashMaxInputExtent = 100;

/// Longest edge, in pixels, of the raster [ThumbHash.decode] produces.
///
/// The decoded image is meant to be scaled up with bilinear or better
/// filtering; the blur is what the raster's coarseness becomes on the way up.
const int thumbHashRasterExtent = 32;

/// A compact placeholder for one image, as produced by [ThumbHash.encode].
///
/// Immutable and cheap to compare: two hashes are equal when their bytes are,
/// which is what lets the image cache key on them.
@immutable
class ThumbHash {
  /// Wraps raw ThumbHash [bytes].
  ///
  /// Throws a [FormatException] when the bytes cannot be a ThumbHash — too
  /// short for the header, a length that disagrees with the term counts the
  /// header announces, or a zero DCT extent that would decode to an empty
  /// raster.
  ThumbHash(Uint8List bytes) : bytes = _validated(bytes);

  /// Parses the base64 form [toBase64] writes.
  ///
  /// Accepts missing padding and the URL-safe alphabet as well, so a hash
  /// pasted from any tool round-trips. Throws a [FormatException] for
  /// anything that is not base64 or does not decode to a ThumbHash.
  factory ThumbHash.fromBase64(String encoded) =>
      ThumbHash(base64.decode(base64.normalize(encoded)));

  /// Encodes a straight-alpha RGBA raster, row-major, `width × height × 4`
  /// bytes.
  ///
  /// Both edges must lie within `1..thumbHashMaxInputExtent`; anything else,
  /// or a byte count that does not match the dimensions, is an
  /// [ArgumentError].
  factory ThumbHash.encode({
    required int width,
    required int height,
    required Uint8List rgba,
  }) => ThumbHash(_encode(width, height, rgba));

  /// [ThumbHash.fromBase64] that answers `null` instead of throwing, for a
  /// hash read from storage: a placeholder is a hint, and a corrupt hint is
  /// simply no hint.
  static ThumbHash? tryParse(String? encoded) {
    if (encoded == null) return null;
    try {
      return ThumbHash.fromBase64(encoded);
    } on FormatException {
      return null;
    }
  }

  /// The hash bytes; an unmodifiable view.
  final Uint8List bytes;

  /// Whether the source image carried transparency.
  bool get hasAlpha => bytes[2] & 0x80 != 0;

  /// The source image's `width / height`, quantised to the DCT extents the
  /// header stores.
  double get aspectRatio {
    final (:lx, :ly) = _extents(bytes);
    return lx / ly;
  }

  /// The hash in its storage form.
  String toBase64() => base64.encode(bytes);

  /// Renders the hash into a raster whose longest edge is
  /// [thumbHashRasterExtent] pixels.
  ThumbHashPixels decode() => _decode(bytes);

  @override
  bool operator ==(Object other) =>
      other is ThumbHash &&
      const ListEquality<int>().equals(bytes, other.bytes);

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => 'ThumbHash(${toBase64()})';
}

/// A decoded [ThumbHash]: straight-alpha RGBA bytes, row-major.
@immutable
class ThumbHashPixels {
  const ThumbHashPixels({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;

  /// `width × height × 4` bytes, RGBA, alpha not premultiplied.
  final Uint8List rgba;
}

/// The luminance DCT extents the header stores, before the `max(3, …)`
/// clamp the term loops apply. These raw values carry the aspect ratio.
({int lx, int ly}) _extents(Uint8List bytes) {
  final hasAlpha = bytes[2] & 0x80 != 0;
  final isLandscape = bytes[4] & 0x80 != 0;
  final stored = bytes[3] & 7;
  return isLandscape
      ? (lx: hasAlpha ? 5 : 7, ly: stored)
      : (lx: stored, ly: hasAlpha ? 5 : 7);
}

/// How many AC (non-constant) terms a `nx × ny` triangular DCT block holds.
///
/// Both the encoder and the decoder walk the block as "every `(cx, cy)` with
/// `cx * ny < nx * (ny - cy)`", minus the DC term at the origin.
int _acTermCount(int nx, int ny) {
  var count = 0;
  for (var cy = 0; cy < ny; cy++) {
    for (var cx = cy > 0 ? 0 : 1; cx * ny < nx * (ny - cy); cx++) {
      count++;
    }
  }
  return count;
}

Uint8List _validated(Uint8List bytes) {
  if (bytes.length < 5) {
    throw FormatException(
      'A ThumbHash is at least 5 bytes, got ${bytes.length}',
    );
  }
  final hasAlpha = bytes[2] & 0x80 != 0;
  final (:lx, :ly) = _extents(bytes);
  if (lx == 0 || ly == 0) {
    throw const FormatException('A ThumbHash header cannot store a 0 extent');
  }
  final acCount =
      _acTermCount(math.max(3, lx), math.max(3, ly)) +
      2 * _acTermCount(3, 3) +
      (hasAlpha ? _acTermCount(5, 5) : 0);
  final expected = (hasAlpha ? 6 : 5) + (acCount + 1) ~/ 2;
  if (bytes.length != expected) {
    throw FormatException(
      'This ThumbHash header announces $expected bytes, got ${bytes.length}',
    );
  }
  return Uint8List.fromList(bytes).asUnmodifiableView();
}

Uint8List _encode(int width, int height, Uint8List rgba) {
  if (width < 1 ||
      height < 1 ||
      width > thumbHashMaxInputExtent ||
      height > thumbHashMaxInputExtent) {
    throw ArgumentError(
      'ThumbHash input must be between 1×1 and '
      '$thumbHashMaxInputExtent×$thumbHashMaxInputExtent pixels, '
      'got $width×$height',
    );
  }
  final pixelCount = width * height;
  if (rgba.length != pixelCount * 4) {
    throw ArgumentError(
      'Expected ${pixelCount * 4} RGBA bytes for $width×$height, '
      'got ${rgba.length}',
    );
  }

  // The average colour, weighted by alpha.
  var avgR = 0.0;
  var avgG = 0.0;
  var avgB = 0.0;
  var avgA = 0.0;
  for (var i = 0, j = 0; i < pixelCount; i++, j += 4) {
    final alpha = rgba[j + 3] / 255;
    avgR += alpha / 255 * rgba[j];
    avgG += alpha / 255 * rgba[j + 1];
    avgB += alpha / 255 * rgba[j + 2];
    avgA += alpha;
  }
  if (avgA > 0) {
    avgR /= avgA;
    avgG /= avgA;
    avgB /= avgA;
  }

  final hasAlpha = avgA < pixelCount;
  // Fewer luminance terms when there is alpha, to leave room for it.
  final lLimit = hasAlpha ? 5 : 7;
  final longest = math.max(width, height);
  final lx = math.max(1, (lLimit * width / longest).round());
  final ly = math.max(1, (lLimit * height / longest).round());

  // RGBA → LPQA (luminance, yellow-blue, red-green, alpha), composited over
  // the average colour so transparent pixels do not drag the DCT to black.
  final l = Float64List(pixelCount);
  final p = Float64List(pixelCount);
  final q = Float64List(pixelCount);
  final a = Float64List(pixelCount);
  for (var i = 0, j = 0; i < pixelCount; i++, j += 4) {
    final alpha = rgba[j + 3] / 255;
    final r = avgR * (1 - alpha) + alpha / 255 * rgba[j];
    final g = avgG * (1 - alpha) + alpha / 255 * rgba[j + 1];
    final b = avgB * (1 - alpha) + alpha / 255 * rgba[j + 2];
    l[i] = (r + g + b) / 3;
    p[i] = (r + g) / 2 - b;
    q[i] = r - g;
    a[i] = alpha;
  }

  final lTerms = _encodeChannel(
    l,
    nx: math.max(3, lx),
    ny: math.max(3, ly),
    width: width,
    height: height,
  );
  final pTerms = _encodeChannel(p, nx: 3, ny: 3, width: width, height: height);
  final qTerms = _encodeChannel(q, nx: 3, ny: 3, width: width, height: height);
  final aTerms = hasAlpha
      ? _encodeChannel(a, nx: 5, ny: 5, width: width, height: height)
      : null;

  // The constants: DC terms and per-channel scales, then the aspect ratio.
  final isLandscape = width > height;
  final header24 =
      (63 * lTerms.dc).round() |
      ((31.5 + 31.5 * pTerms.dc).round() << 6) |
      ((31.5 + 31.5 * qTerms.dc).round() << 12) |
      ((31 * lTerms.scale).round() << 18) |
      ((hasAlpha ? 1 : 0) << 23);
  final header16 =
      (isLandscape ? ly : lx) |
      ((63 * pTerms.scale).round() << 3) |
      ((63 * qTerms.scale).round() << 9) |
      ((isLandscape ? 1 : 0) << 15);
  final hash = <int>[
    header24 & 255,
    (header24 >> 8) & 255,
    header24 >> 16,
    header16 & 255,
    header16 >> 8,
  ];
  if (aTerms != null) {
    hash.add((15 * aTerms.dc).round() | ((15 * aTerms.scale).round() << 4));
  }

  // The varying factors, one nibble each, low nibble first.
  final acStart = hash.length;
  var acIndex = 0;
  for (final ac in [
    lTerms.ac,
    pTerms.ac,
    qTerms.ac,
    if (aTerms != null) aTerms.ac,
  ]) {
    for (final f in ac) {
      final byteIndex = acStart + (acIndex >> 1);
      if (byteIndex == hash.length) hash.add(0);
      hash[byteIndex] |= (15 * f).round() << ((acIndex & 1) << 2);
      acIndex++;
    }
  }
  return Uint8List.fromList(hash);
}

/// Largest varying-term magnitude that is floating-point noise rather than
/// signal.
///
/// A perfectly flat channel has every varying term at zero in exact
/// arithmetic; in doubles they come out around 1e-16. The smallest magnitude a
/// real difference can produce — one pixel one level apart in a
/// [thumbHashMaxInputExtent]-square image — is on the order of 1e-8, so the
/// floor sits well clear of both.
const double _noiseFloor = 1e-12;

/// One channel through the DCT: its constant term, its varying terms
/// normalised into `0..1` around the largest magnitude, and that magnitude.
///
/// One deliberate departure from the reference implementation: a magnitude
/// under [_noiseFloor] is treated as zero. The reference normalises by it
/// regardless, blowing rounding noise up into arbitrary nibbles, so a flat
/// colour would hash differently on every libm; here its nibbles are zero
/// and the same pixels give the same bytes on every platform. The decoded
/// raster is identical either way, because the header's quantised scale is
/// zero and the decoder multiplies every varying term by it.
({double dc, List<double> ac, double scale}) _encodeChannel(
  Float64List channel, {
  required int nx,
  required int ny,
  required int width,
  required int height,
}) {
  var dc = 0.0;
  var scale = 0.0;
  final ac = <double>[];
  final fx = Float64List(width);
  for (var cy = 0; cy < ny; cy++) {
    for (var cx = 0; cx * ny < nx * (ny - cy); cx++) {
      var f = 0.0;
      for (var x = 0; x < width; x++) {
        fx[x] = math.cos(math.pi / width * cx * (x + 0.5));
      }
      for (var y = 0; y < height; y++) {
        final fy = math.cos(math.pi / height * cy * (y + 0.5));
        for (var x = 0; x < width; x++) {
          f += channel[x + y * width] * fx[x] * fy;
        }
      }
      f /= width * height;
      if (cx != 0 || cy != 0) {
        ac.add(f);
        scale = math.max(scale, f.abs());
      } else {
        dc = f;
      }
    }
  }
  if (scale > _noiseFloor) {
    for (var i = 0; i < ac.length; i++) {
      ac[i] = 0.5 + 0.5 / scale * ac[i];
    }
  } else {
    scale = 0;
    ac.fillRange(0, ac.length, 0);
  }
  return (dc: dc, ac: ac, scale: scale);
}

ThumbHashPixels _decode(Uint8List hash) {
  // The constants.
  final header24 = hash[0] | (hash[1] << 8) | (hash[2] << 16);
  final header16 = hash[3] | (hash[4] << 8);
  final lDc = (header24 & 63) / 63;
  final pDc = ((header24 >> 6) & 63) / 31.5 - 1;
  final qDc = ((header24 >> 12) & 63) / 31.5 - 1;
  final lScale = ((header24 >> 18) & 31) / 31;
  final hasAlpha = header24 >> 23 != 0;
  final pScale = ((header16 >> 3) & 63) / 63;
  final qScale = ((header16 >> 9) & 63) / 63;
  final (lx: rawLx, ly: rawLy) = _extents(hash);
  final lx = math.max(3, rawLx);
  final ly = math.max(3, rawLy);
  final aDc = hasAlpha ? (hash[5] & 15) / 15 : 1.0;
  final aScale = hasAlpha ? (hash[5] >> 4) / 15 : 0.0;

  // The varying factors. Chroma is boosted by 1.25× to make up for what the
  // four-bit quantisation took away.
  final acStart = hasAlpha ? 6 : 5;
  var acIndex = 0;
  List<double> decodeChannel(int nx, int ny, double scale) {
    final ac = <double>[];
    for (var cy = 0; cy < ny; cy++) {
      for (var cx = cy > 0 ? 0 : 1; cx * ny < nx * (ny - cy); cx++) {
        final nibble =
            (hash[acStart + (acIndex >> 1)] >> ((acIndex & 1) << 2)) & 15;
        acIndex++;
        ac.add((nibble / 7.5 - 1) * scale);
      }
    }
    return ac;
  }

  final lAc = decodeChannel(lx, ly, lScale);
  final pAc = decodeChannel(3, 3, pScale * 1.25);
  final qAc = decodeChannel(3, 3, qScale * 1.25);
  final aAc = hasAlpha ? decodeChannel(5, 5, aScale) : const <double>[];

  // The raster: the longest edge is thumbHashRasterExtent, the other follows
  // the stored aspect ratio.
  final ratio = rawLx / rawLy;
  final width =
      (ratio > 1 ? thumbHashRasterExtent : thumbHashRasterExtent * ratio)
          .round();
  final height =
      (ratio > 1 ? thumbHashRasterExtent / ratio : thumbHashRasterExtent)
          .round();
  final rgba = Uint8List(width * height * 4);
  final nx = math.max(lx, hasAlpha ? 5 : 3);
  final ny = math.max(ly, hasAlpha ? 5 : 3);
  final fx = Float64List(nx);
  final fy = Float64List(ny);
  var i = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++, i += 4) {
      var l = lDc;
      var p = pDc;
      var q = qDc;
      var a = aDc;

      for (var cx = 0; cx < nx; cx++) {
        fx[cx] = math.cos(math.pi / width * (x + 0.5) * cx);
      }
      for (var cy = 0; cy < ny; cy++) {
        fy[cy] = math.cos(math.pi / height * (y + 0.5) * cy);
      }

      // Luminance.
      var j = 0;
      for (var cy = 0; cy < ly; cy++) {
        final fy2 = fy[cy] * 2;
        for (var cx = cy > 0 ? 0 : 1; cx * ly < lx * (ly - cy); cx++, j++) {
          l += lAc[j] * fx[cx] * fy2;
        }
      }

      // Chroma.
      j = 0;
      for (var cy = 0; cy < 3; cy++) {
        final fy2 = fy[cy] * 2;
        for (var cx = cy > 0 ? 0 : 1; cx < 3 - cy; cx++, j++) {
          final f = fx[cx] * fy2;
          p += pAc[j] * f;
          q += qAc[j] * f;
        }
      }

      // Alpha.
      if (hasAlpha) {
        j = 0;
        for (var cy = 0; cy < 5; cy++) {
          final fy2 = fy[cy] * 2;
          for (var cx = cy > 0 ? 0 : 1; cx < 5 - cy; cx++, j++) {
            a += aAc[j] * fx[cx] * fy2;
          }
        }
      }

      // LPQ → RGB.
      final b = l - 2 / 3 * p;
      final r = (3 * l - b + q) / 2;
      final g = r - q;
      rgba[i] = _channelByte(r);
      rgba[i + 1] = _channelByte(g);
      rgba[i + 2] = _channelByte(b);
      rgba[i + 3] = _channelByte(a);
    }
  }
  return ThumbHashPixels(width: width, height: height, rgba: rgba);
}

/// `0..1` (clamped) to a byte, truncating the way a JavaScript `Uint8Array`
/// store does so the raster matches the reference implementation exactly.
int _channelByte(double value) =>
    math.max(0.0, 255 * math.min(1.0, value)).toInt();
