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

  test('localizes multiline Portuguese agent reports', () {
    expect(
      manualScreenshotPortugueseText(
        '\n## Latest assessment\n\n- Pressure seals A–F stayed stable across '
        'the night shift.\n- 840 sardines are loaded; feeder calibration '
        'still blocks sign-off.\n- Mission Control clearance is due before '
        'the 06:30 roll call.\n\n## Recommended next step\n\nRun the '
        'feeder test, attach the telemetry image, then request launch '
        'approval.\n',
      ),
      contains('## Última avaliação'),
    );
  });

  test('uses Portuguese task and habitat terminology', () {
    final expectedTranslations = <String, String>{
      'Inspect habitat seals': 'Inspecione as vedações do habitat',
      'The penguins are currently technically cargo':
          'Os pinguins são, tecnicamente, carga',
    };

    for (final entry in expectedTranslations.entries) {
      expect(manualScreenshotPortugueseText(entry.key), entry.value);
    }
  });
}
