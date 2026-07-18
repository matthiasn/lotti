import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_swedish_text.dart';

void main() {
  test('localizes representative Swedish manual fixture copy', () {
    expect(
      manualScreenshotSwedishText('Inspect orbital penguin habitat'),
      'Inspektera pingvinernas omloppshabitat',
    );
    expect(manualScreenshotSwedishText('Unknown fixture'), isNull);
    expect(
      manualScreenshotSwedishText('"Run zero-gravity sardine feeder test"'),
      '"Kör sardinmatartest med nollvikt"',
    );
    expect(
      manualScreenshotSwedishText('45m → 1h 15m'),
      '45 m → 1 timme 15 min',
    );
  });

  test('localizes the Swedish manual agent report with Markdown intact', () {
    final report = manualScreenshotSwedishText(
      '## Latest assessment\n\n- Pressure seals A–F stayed stable across '
      'the night shift.\n- 840 sardines are loaded; feeder calibration '
      'still blocks sign-off.\n- Mission Control clearance is due before '
      'the 06:30 roll call.\n\n## Recommended next step\n\nRun the '
      'feeder test, attach the telemetry image, then request launch '
      'approval.\n',
    );

    expect(report, startsWith('## Senaste bedömningen'));
    expect(report, contains('\n## Rekommenderat nästa steg'));
  });
}
