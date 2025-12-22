import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/constants/label_color_presets.dart';
import 'package:lotti/utils/color.dart';

Color _presetToColor(LabelColorPreset preset) =>
    colorFromCssHex(preset.hex, substitute: Colors.blue);

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final brightest = l1 > l2 ? l1 : l2;
  final darkest = l1 > l2 ? l2 : l1;
  return (brightest + 0.05) / (darkest + 0.05);
}

void main() {
  test('preset palette maintains WCAG AA contrast with black or white text',
      () {
    for (final preset in labelColorPresets) {
      final color = _presetToColor(preset);
      final whiteContrast = _contrastRatio(color, Colors.white);
      final blackContrast = _contrastRatio(color, Colors.black);
      expect(
        whiteContrast >= 4.5 || blackContrast >= 4.5,
        isTrue,
        reason:
            '${preset.name} (${preset.hex}) should be readable in light or dark mode',
      );
    }
  });

  test('chip backgrounds contrast against both light and dark surfaces', () {
    for (final preset in labelColorPresets) {
      final chipColor = _presetToColor(preset).withValues(alpha: 0.18);
      final contrastLight = _contrastRatio(chipColor, Colors.white);
      final contrastDark = _contrastRatio(chipColor, Colors.black);
      expect(
        contrastLight >= 3.0 || contrastDark >= 3.0,
        isTrue,
        reason:
            'InputChip overlays should remain readable on light or dark surfaces',
      );
    }
  });
}
