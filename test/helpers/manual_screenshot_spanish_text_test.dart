import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_spanish_text.dart';

void main() {
  test('Spanish fixture catalog localizes Project Waddle copy', () {
    expect(
      manualScreenshotSpanishText('Inspect orbital penguin habitat'),
      'Inspeccionar hábitat orbital de pingüinos',
    );
    expect(
      manualScreenshotSpanishText('Automatic updates'),
      'Actualizaciones automáticas',
    );
    expect(manualScreenshotSpanishText('Unknown fixture'), isNull);
  });
}
