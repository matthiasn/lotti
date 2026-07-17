import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_french_text.dart';

void main() {
  test('French fixture catalog localizes Project Waddle copy', () {
    expect(
      manualScreenshotFrenchText('Inspect orbital penguin habitat'),
      'Inspecter l’habitat orbital des manchots',
    );
    expect(
      manualScreenshotFrenchText('Automatic updates'),
      'Mises à jour automatiques',
    );
    expect(manualScreenshotFrenchText('Unknown fixture'), isNull);
  });
}
