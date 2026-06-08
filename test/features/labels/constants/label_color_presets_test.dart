import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/constants/label_color_presets.dart';

void main() {
  group('labelColorPresets', () {
    test('is non-empty', () {
      expect(labelColorPresets, isNotEmpty);
    });

    test('every name is non-empty and trimmed', () {
      for (final preset in labelColorPresets) {
        expect(
          preset.name.trim(),
          isNotEmpty,
          reason: 'preset name "${preset.name}" must be non-empty',
        );
        expect(
          preset.name,
          preset.name.trim(),
          reason:
              'preset name "${preset.name}" must not have surrounding '
              'whitespace',
        );
      }
    });

    test('every hex is a valid 7-character #RRGGBB string', () {
      final hexPattern = RegExp(r'^#[0-9A-F]{6}$');
      for (final preset in labelColorPresets) {
        expect(
          preset.hex.length,
          7,
          reason: '${preset.name} hex "${preset.hex}" must be 7 characters',
        );
        expect(
          hexPattern.hasMatch(preset.hex),
          isTrue,
          reason:
              '${preset.name} hex "${preset.hex}" must match '
              '#RRGGBB with uppercase hex digits',
        );
      }
    });

    test('names are unique', () {
      final names = labelColorPresets.map((p) => p.name).toList();
      expect(
        names.toSet().length,
        names.length,
        reason: 'names must be unique',
      );
    });

    test('hex values are unique', () {
      final hexes = labelColorPresets.map((p) => p.hex).toList();
      expect(
        hexes.toSet().length,
        hexes.length,
        reason: 'hex values must be unique',
      );
    });
  });
}
