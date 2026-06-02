import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('httpClientProvider', () {
    test('returns a real http.Client and closes it on dispose', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final client = container.read(httpClientProvider);
      expect(client, isA<http.Client>());

      // Repeated reads return the same cached instance.
      expect(identical(container.read(httpClientProvider), client), isTrue);

      // Disposing the container triggers ref.onDispose(client.close); after
      // close the underlying client may not be reused. We can at least confirm
      // disposal does not throw.
      expect(container.dispose, returnsNormally);
    });
  });

  group('ollamaInferenceRepositoryProvider', () {
    test('builds an OllamaInferenceRepository wired to the http client from '
        'httpClientProvider', () async {
      final mockClient = MockHttpClient();
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{"done":true}', 200));

      final container = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(ollamaInferenceRepositoryProvider);
      expect(repository, isA<OllamaInferenceRepository>());

      // Drive a method that uses the injected http client. If the provider
      // wired the overridden client correctly, this call delegates to it.
      await repository.warmUpModel('gemma:2b', 'http://localhost:11434');

      final captured = verify(
        () => mockClient.post(
          captureAny(),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;

      // The repository hit the warm-up (chat) endpoint with the model name in
      // the request body, proving the overridden client was the one used.
      final uri = captured[0] as Uri;
      final body = captured[1] as String;
      expect(uri.toString(), 'http://localhost:11434/api/chat');
      expect(body, contains('gemma:2b'));
    });

    test('returns the cached repository instance on repeated reads', () {
      final container = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(MockHttpClient()),
        ],
      );
      addTearDown(container.dispose);

      final first = container.read(ollamaInferenceRepositoryProvider);
      final second = container.read(ollamaInferenceRepositoryProvider);
      expect(identical(first, second), isTrue);
    });
  });
}
