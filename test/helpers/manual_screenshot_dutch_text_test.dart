import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_dutch_text.dart';

void main() {
  test('localizes representative authored demo copy', () {
    expect(
      manualScreenshotDutchText('Inspect orbital penguin habitat'),
      'Inspecteer het orbitale pinguïnverblijf',
    );
    expect(manualScreenshotDutchText('Unknown fixture'), isNull);
  });
}
