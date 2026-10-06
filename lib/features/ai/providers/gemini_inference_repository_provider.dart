import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/providers/service_providers.dart';

/// Provider for GeminiInferenceRepository using the shared HTTP client
final geminiInferenceRepositoryProvider = Provider<GeminiInferenceRepository>((
  ref,
) {
  final httpClient = ref.watch(httpClientProvider);
  return GeminiInferenceRepository(
    domainLogger: ref.watch(domainLoggerProvider),
    httpClient: httpClient,
  );
});
