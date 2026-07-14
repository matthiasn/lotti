import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';

AiConfigInferenceProvider _provider({
  required String baseUrl,
  InferenceProviderType type = InferenceProviderType.genericOpenAi,
}) {
  return AiConfigInferenceProvider(
    id: 'provider',
    baseUrl: baseUrl,
    apiKey: '',
    name: 'Provider',
    createdAt: DateTime(2024, 3, 15),
    inferenceProviderType: type,
  );
}

void main() {
  group('dailyOsInferenceEndpointKind', () {
    for (final baseUrl in [
      'http://localhost:11434',
      'localhost:11434',
      'http://127.0.0.1:11434',
      '127.0.0.1:11434',
      'http://127.12.4.8:8080',
      'http://[::1]:8080',
    ]) {
      test('classifies $baseUrl as on-device', () {
        expect(
          dailyOsInferenceEndpointKind(_provider(baseUrl: baseUrl)),
          DailyOsInferenceEndpointKind.onDevice,
        );
      });
    }

    test('classifies a remote Ollama endpoint as remote', () {
      expect(
        dailyOsInferenceEndpointKind(
          _provider(
            baseUrl: 'https://ollama.example.com',
            type: InferenceProviderType.ollama,
          ),
        ),
        DailyOsInferenceEndpointKind.remote,
      );
    });

    test('classifies the embedded MLX Audio provider as on-device', () {
      expect(
        dailyOsInferenceEndpointKind(
          _provider(baseUrl: '', type: InferenceProviderType.mlxAudio),
        ),
        DailyOsInferenceEndpointKind.onDevice,
      );
    });

    test('does not filter or special-case Google endpoints', () {
      expect(
        dailyOsInferenceEndpointKind(
          _provider(
            baseUrl: 'https://generativelanguage.googleapis.com',
            type: InferenceProviderType.gemini,
          ),
        ),
        DailyOsInferenceEndpointKind.remote,
      );
    });
  });

  test('setup status distinguishes required inference from optional name', () {
    const status = DailyOsSetupStatus(
      hasInferenceRoute: true,
      hasPreferredName: false,
    );

    expect(status.needsAttention, isTrue);
    expect(status.hasInferenceRoute, isTrue);
    expect(status.hasPreferredName, isFalse);
  });
}
