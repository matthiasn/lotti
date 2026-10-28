import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/util/sampling_temperature.dart';

void main() {
  test('a reasoning request outside Mistral gets 1.0', () {
    for (final type in [
      InferenceProviderType.openAi,
      InferenceProviderType.gemini,
      null,
    ]) {
      expect(
        samplingTemperature(providerType: type, reasoning: true, fallback: 0.6),
        1.0,
        reason: '$type',
      );
    }
  });

  test('a Mistral reasoning request keeps the fallback', () {
    expect(
      samplingTemperature(
        providerType: InferenceProviderType.mistral,
        reasoning: true,
        fallback: 0.6,
      ),
      0.6,
    );
  });

  test('a request without reasoning keeps the fallback', () {
    expect(
      samplingTemperature(
        providerType: InferenceProviderType.openAi,
        reasoning: false,
        fallback: 0.3,
      ),
      0.3,
    );
  });
}
