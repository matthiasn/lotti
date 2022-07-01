import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/color.dart';

void main() {
  group('CSS color to Color', () {
    test('Valid CSS color is parsed correctly', () {
      expect(colorFromCssHex('#FF0000'), const Color.fromRGBO(255, 0, 0, 1));
    });

    test('Valid CSS color with alpha is parsed correctly', () {
      expect(
        colorFromCssHex('#FF00007F'),
        const Color.fromRGBO(255, 0, 0, 0.5),
      );
    });

    test('Invalid CSS color returns substitute', () {
      expect(colorFromCssHex('#invalid'), Colors.pink);
    });
  });

  group('Color to CSS color', () {
    test('Valid CSS color is parsed correctly', () {
      expect(colorToCssHex(const Color.fromRGBO(255, 0, 0, 1)), '#FF0000');
    });

    test('Valid CSS color with alpha is parsed correctly', () {
      expect(colorToCssHex(const Color.fromRGBO(255, 0, 0, 0.5)), '#FF00007F');
    });
  });
}
