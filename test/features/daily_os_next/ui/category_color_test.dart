import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/ui/category_color.dart';

/// Generator mixing valid hex characters with `#`, whitespace and junk so
/// every branch of [categoryColorFromHex] (trim, hash-strip, truncate,
/// parse, fallback) is exercised.
extension _AnyHexish on glados.Any {
  glados.Generator<String> get hexish =>
      glados.any.stringOf('0123456789abcdefABCDEF# gxz');
}

void main() {
  group('categoryColorFromHex — properties', () {
    glados.Glados<String>(
      glados.any.hexish,
      glados.ExploreConfig(numRuns: 180),
    ).test('always returns a fully opaque colour for any input', (hex) {
      final color = categoryColorFromHex(hex);
      expect((color.toARGB32() >> 24) & 0xFF, 0xFF, reason: 'hex="$hex"');
    }, tags: 'glados');
  });

  group('categoryColorFromHex — worked examples', () {
    test('parses a 6-digit hex into the matching opaque colour', () {
      expect(categoryColorFromHex('ff0000').toARGB32(), 0xFFFF0000);
      expect(categoryColorFromHex('00ff00').toARGB32(), 0xFF00FF00);
    });
    test('strips a leading hash and trims surrounding whitespace', () {
      expect(categoryColorFromHex('  #0000ff  ').toARGB32(), 0xFF0000FF);
    });
    test('truncates input longer than 6 hex chars to the first 6', () {
      expect(categoryColorFromHex('123456789a').toARGB32(), 0xFF123456);
    });
    test('falls back to grey on malformed or empty input', () {
      expect(categoryColorFromHex('zzz'), Colors.grey);
      expect(categoryColorFromHex(''), Colors.grey);
    });
  });
}
