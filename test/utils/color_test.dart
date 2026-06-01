import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/color.dart';

class _GeneratedColorChannels {
  const _GeneratedColorChannels({
    required this.red,
    required this.green,
    required this.blue,
    required this.alpha,
  });

  final int red;
  final int green;
  final int blue;
  final int alpha;

  Color get color => Color.fromARGB(alpha, red, green, blue);

  String get rgbHex => '#${_hex(red)}${_hex(green)}${_hex(blue)}';

  String get rgbaHex => '$rgbHex${_hex(alpha)}';

  String get expectedCssHex =>
      alpha == 255 ? rgbHex.toUpperCase() : rgbaHex.toUpperCase();

  @override
  String toString() {
    return '_GeneratedColorChannels('
        'red: $red, '
        'green: $green, '
        'blue: $blue, '
        'alpha: $alpha)';
  }
}

String _hex(int channel) => channel.toRadixString(16).padLeft(2, '0');

extension _AnyColorChannels on glados.Any {
  glados.Generator<int> get _channel => glados.IntAnys(this).intInRange(0, 256);

  glados.Generator<_GeneratedColorChannels> get colorChannels =>
      glados.CombinableAny(this).combine4(
        _channel,
        _channel,
        _channel,
        _channel,
        (int red, int green, int blue, int alpha) => _GeneratedColorChannels(
          red: red,
          green: green,
          blue: blue,
          alpha: alpha,
        ),
      );
}

void main() {
  group('CSS color to Color', () {
    test('Valid CSS color is parsed correctly', () {
      expect(colorFromCssHex('#FF0000'), const Color.fromRGBO(255, 0, 0, 1));
    });

    test('Valid CSS color with alpha is parsed correctly', () {
      expect(
        colorFromCssHex('#FF000080'),
        isSameColorAs(const Color.fromRGBO(255, 0, 0, 0.502)),
      );
    });

    test('Invalid CSS color returns substitute', () {
      expect(colorFromCssHex('#invalid'), Colors.pink);
    });

    test('Invalid CSS color with embedded valid color returns substitute', () {
      expect(colorFromCssHex('prefix#FF0000suffix'), Colors.pink);
    });

    glados.Glados(
      glados.any.colorChannels,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'parses generated RGB and RGBA CSS hex exactly',
      (channels) {
        expect(colorFromCssHex(channels.rgbHex), channels.color.withAlpha(255));
        expect(colorFromCssHex(channels.rgbaHex), channels.color);
      },
      tags: 'glados',
    );
  });

  group('Color to CSS color', () {
    test('Valid CSS color is parsed correctly', () {
      expect(colorToCssHex(const Color.fromRGBO(255, 0, 0, 1)), '#FF0000');
    });

    test('Valid CSS color with alpha is parsed correctly', () {
      expect(colorToCssHex(const Color.fromRGBO(255, 0, 0, 0.5)), '#FF000080');
    });

    glados.Glados(
      glados.any.colorChannels,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'formats generated colors as canonical CSS hex and round-trips',
      (channels) {
        final cssHex = colorToCssHex(channels.color);

        expect(cssHex, channels.expectedCssHex, reason: '$channels');
        expect(colorFromCssHex(cssHex), channels.color, reason: '$channels');
      },
      tags: 'glados',
    );
  });
}
