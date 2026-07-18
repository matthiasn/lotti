import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_danish_text.dart';

void main() {
  test('localizes representative Danish manual fixture copy', () {
    expect(
      manualScreenshotDanishText('Inspect orbital penguin habitat'),
      'Undersøg pingvinhabitatet i kredsløb',
    );
    expect(manualScreenshotDanishText('Unknown fixture'), isNull);
    expect(
      manualScreenshotDanishText('45m → 1h 15m'),
      '45 m → 1 time 15 min',
    );
  });

  test('localizes the Danish manual agent report with Markdown intact', () {
    final report = manualScreenshotDanishText(
      '## Latest assessment\n\n- Pressure seals A–F stayed stable across '
      'the night shift.\n- 840 sardines are loaded; feeder calibration '
      'still blocks sign-off.\n- Mission Control clearance is due before '
      'the 06:30 roll call.\n\n## Recommended next step\n\nRun the '
      'feeder test, attach the telemetry image, then request launch '
      'approval.\n',
    );

    expect(report, startsWith('## Seneste vurdering'));
    expect(report, contains('\n## Anbefalet næste skridt'));
  });
}
