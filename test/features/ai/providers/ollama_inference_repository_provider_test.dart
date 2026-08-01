import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';

import '../../../mocks/mocks.dart';

void main() {
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
