import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_portuguese_text.dart';

void main() {
  test('localizes representative Portuguese manual fixture copy', () {
    expect(
      manualScreenshotPortugueseText('Inspect orbital penguin habitat'),
      'Inspecione o habitat orbital dos pinguins',
    );
    expect(manualScreenshotPortugueseText('Unknown fixture'), isNull);
  });
}
