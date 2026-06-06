import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/providers/gemini_inference_repository_provider.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://fallback.example.invalid'));
  });

  group('geminiInferenceRepositoryProvider', () {
    test('builds a GeminiInferenceRepository wired to the http client from '
        'httpClientProvider', () async {
      final mockClient = MockHttpClient();
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response('{"error": "denied"}', 403),
      );

      final container = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(geminiInferenceRepositoryProvider);
      expect(repository, isA<GeminiInferenceRepository>());

      // Drive a method that uses the injected http client. The 403 stub
      // proves the call reached the overridden client and surfaced its
      // status code through the repository's error path.
      final provider =
          AiConfig.inferenceProvider(
                id: 'gemini-test',
                name: 'Gemini Test',
                baseUrl: 'https://gemini.example.invalid',
                apiKey: 'test-key',
                createdAt: DateTime(2024, 3, 15),
                inferenceProviderType: InferenceProviderType.gemini,
              )
              as AiConfigInferenceProvider;

      await expectLater(
        repository.generateImage(
          prompt: 'a test image',
          model: 'gemini-test-model',
          provider: provider,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('error 403'),
          ),
        ),
      );

      final captured = verify(
        () => mockClient.post(
          captureAny(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).captured;
      expect(captured, hasLength(1));
      expect(
        (captured.single as Uri).toString(),
        contains('gemini.example.invalid'),
      );
    });
  });
}
