import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
// ignore_for_file: public_member_api_docs

const _kDefaultAudioModel = 'gemini-2.5-flash';
const _kTranscriptionPrompt = 'Transcribe the audio to natural text.';

class AudioTranscriptionService {
  AudioTranscriptionService(this.ref);

  final Ref ref;

  /// Transcribe audio from a local file using the currently configured provider.
  ///
  /// NOTE: Uses base64 encoding as required by current API; this can be
  /// revisited when streaming is supported.
  Future<String> transcribe(String filePath) async {
    final aiRepo = ref.read(aiConfigRepositoryProvider);
    final models = await aiRepo.getConfigsByType(AiConfigType.model);

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
    final providers =
        await aiRepo.getConfigsByType(AiConfigType.inferenceProvider);
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
