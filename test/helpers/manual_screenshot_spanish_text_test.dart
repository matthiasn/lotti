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
    expect(
      manualScreenshotSpanishText(
        'Project Waddle is on track for the orbital habitat demo. Clear '
        'the fish-feeder blocker before the emperor penguin roll call.',
      ),
      'Project Waddle avanza según lo previsto para la demostración del '
      'hábitat orbital. Resuelve el bloqueo del alimentador de peces antes '
      'del recuento de pingüinos emperador.',
    );
    expect(
      manualScreenshotSpanishText('Europa sardine cold chain'),
      'Cadena de frío de sardinas de Europa',
    );
    expect(
      manualScreenshotSpanishText(
        'Project Waddle mission log — pressure seals green, 37 emperor '
        'penguins present, and the sardine cargo is cold.',
      ),
      'Registro de misión de Project Waddle: los sellos de presión están en '
      'verde, los 37 pingüinos emperador están presentes y la carga de '
      'sardinas está fría.',
    );
    expect(manualScreenshotSpanishText('Unknown fixture'), isNull);
  });
}
