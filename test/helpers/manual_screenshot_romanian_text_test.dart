import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_romanian_text.dart';

void main() {
  test('Romanian fixture catalog localizes Project Waddle copy', () {
    expect(
      manualScreenshotRomanianText('Inspect orbital penguin habitat'),
      'Inspectați habitatul orbital al pinguinilor',
    );
    expect(
      manualScreenshotRomanianText('Automatic updates'),
      'Actualizări automate',
    );
    expect(manualScreenshotRomanianText('Unknown fixture'), isNull);
  });
}
