import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';

const _kDefaultAudioModel = 'gemini-2.5-flash';
const _kTranscriptionPrompt = 'Transcribe the audio to natural text.';

/// Service that transcribes a local audio file to text using the
/// configured cloud inference provider and selected audio-capable model.
class AudioTranscriptionService {
  /// Creates an [AudioTranscriptionService] backed by Riverpod [Ref].
  AudioTranscriptionService(this.ref);

  final Ref ref;

  /// Transcribes audio from a local file at [filePath] to natural text.
  ///
  /// The appropriate provider and model are resolved from persisted AI configs
  /// by selecting an audio-capable model, preferring `gemini-2.5-flash` when
  /// available, and then routing the request to the matching provider.
  /// Returns the full transcription as a single concatenated string.
  ///
  /// Note: The audio payload is base64-encoded to match current API
  /// requirements; this can be revisited once streaming uploads are supported.
  Future<String> transcribe(String filePath) async {
    final aiRepo = ref.read(aiConfigRepositoryProvider);
    // Fetch models and providers in parallel to reduce I/O latency
    final modelsFuture = aiRepo.getConfigsByType(AiConfigType.model);
    final providersFuture =
        aiRepo.getConfigsByType(AiConfigType.inferenceProvider);
    final models = await modelsFuture;
    final providers = await providersFuture;

    // Find all audio-capable models across all providers
    final audioModels = models
        .whereType<AiConfigModel>()
        .where(
          (m) => m.inputModalities.contains(Modality.audio),
        )
        .toList();

    if (audioModels.isEmpty) {
      throw Exception('No audio-capable models configured');
    }

    // Try to find a model matching the default, otherwise use the first available
    final model = audioModels.firstWhere(
      (m) => m.providerModelId.contains(_kDefaultAudioModel),
      orElse: () => audioModels.first,
    );

    // Get the provider for the selected model
    final provider = providers
        .whereType<AiConfigInferenceProvider>()
        .firstWhere((p) => p.id == model.inferenceProviderId,
            orElse: () =>
                throw Exception('Provider not found for audio model'));

    final bytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(bytes);

    final cloud = ref.read(cloudInferenceRepositoryProvider);
    final buffer = StringBuffer();
    final stream = cloud.generateWithAudio(
      _kTranscriptionPrompt,
      model: model.providerModelId,
      audioBase64: audioBase64,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      provider: provider,
      maxCompletionTokens: model.maxCompletionTokens,
    );

    await for (final chunk in stream) {
      final content = chunk.choices?.firstOrNull?.delta?.content ?? '';
      if (content.isNotEmpty) buffer.write(content);
    }
    return buffer.toString();
  }
}

final Provider<AudioTranscriptionService> audioTranscriptionServiceProvider =
    Provider<AudioTranscriptionService>((ref) {
  return AudioTranscriptionService(ref);
});
