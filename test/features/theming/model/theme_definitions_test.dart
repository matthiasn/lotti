import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';

void main() {
  group('LightModeSurfaces', () {
    test('surface is pure white', () {
      expect(
        LightModeSurfaces.surface.toARGB32(),
        equals(0xFFFFFFFF),
      );
    });

    test('surfaceContainerLowest is pure white', () {
      expect(
        LightModeSurfaces.surfaceContainerLowest.toARGB32(),
        equals(0xFFFFFFFF),
      );
    });

    test('surface colors have decreasing brightness', () {
      // Each surface level should be slightly darker than the previous
      final surfaces = [
        LightModeSurfaces.surfaceContainerLowest,
        LightModeSurfaces.surfaceContainerLow,
        LightModeSurfaces.surfaceContainer,
        LightModeSurfaces.surfaceContainerHigh,
        LightModeSurfaces.surfaceContainerHighest,
      ];

      for (var i = 0; i < surfaces.length - 1; i++) {
        final current = surfaces[i].computeLuminance();
        final next = surfaces[i + 1].computeLuminance();
        expect(
          current >= next,
          isTrue,
          reason:
              'Surface $i luminance ($current) should be >= surface ${i + 1} luminance ($next)',
        );
      }
    });
  });
}
