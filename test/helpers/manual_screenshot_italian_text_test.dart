import 'package:flutter_test/flutter_test.dart';

import 'manual_screenshot_italian_text.dart';

void main() {
  test('localizes representative Italian manual fixture copy', () {
    expect(
      manualScreenshotItalianText('Inspect orbital penguin habitat'),
      'Ispeziona l’habitat orbitale dei pinguini',
    );
    expect(manualScreenshotItalianText('Unknown fixture'), isNull);
  });

  test('localizes the Italian manual agent report with Markdown intact', () {
    final report = manualScreenshotItalianText(
      '\n## Latest assessment\n\n- Pressure seals A–F stayed stable across '
      'the night shift.\n- 840 sardines are loaded; feeder calibration '
      'still blocks sign-off.\n- Mission Control clearance is due before '
      'the 06:30 roll call.\n\n## Recommended next step\n\nRun the '
      'feeder test, attach the telemetry image, then request launch '
      'approval.\n',
    );

    expect(report, startsWith('\n## Ultima valutazione'));
    expect(report, contains('\n## Prossimo passo consigliato'));
  });
}
