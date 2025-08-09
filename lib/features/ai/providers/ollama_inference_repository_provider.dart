import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';

/// Provider for a shared http client to prevent resource leaks
final httpClientProvider = Provider<http.Client>((ref) {
  // Create a single http client that will be reused
  final client = http.Client();

  // Ensure the client is closed when the provider is disposed
  ref.onDispose(client.close);

  return client;
});

/// Provider for OllamaInferenceRepository
final ollamaInferenceRepositoryProvider =
    Provider<OllamaInferenceRepository>((ref) {
  // Use the shared http client
  final httpClient = ref.watch(httpClientProvider);

  return OllamaInferenceRepository(httpClient: httpClient);
});
