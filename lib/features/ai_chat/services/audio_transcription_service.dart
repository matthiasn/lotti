import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
// ignore_for_file: public_member_api_docs

class AudioTranscriptionService {
  AudioTranscriptionService(this.ref);

  final Ref ref;

  /// Transcribe audio from a local file using the currently configured provider.
  ///
  /// NOTE: Uses base64 encoding as required by current API; this can be
  /// revisited when streaming is supported.
  Future<String> transcribe(String filePath) async {
    final aiRepo = ref.read(aiConfigRepositoryProvider);
    final providers =
        await aiRepo.getConfigsByType(AiConfigType.inferenceProvider);
    final provider = providers
        .whereType<AiConfigInferenceProvider>()
        .firstWhere(
            (p) => p.inferenceProviderType == InferenceProviderType.gemini,
            orElse: () => throw Exception('No Gemini provider configured'));

    final models = await aiRepo.getConfigsByType(AiConfigType.model);
    final geminiModels = models.whereType<AiConfigModel>().where(
          (m) =>
              m.inferenceProviderId == provider.id &&
              m.inputModalities.contains(Modality.audio),
        );
    final model = geminiModels.firstWhere(
      (m) => m.providerModelId.contains('gemini-2.5-flash'),
      orElse: () => geminiModels.isNotEmpty
          ? geminiModels.first
          : throw Exception('No audio-capable model configured'),
    );

    final bytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(bytes);

    final cloud = ref.read(cloudInferenceRepositoryProvider);
    final buffer = StringBuffer();
    final stream = cloud.generateWithAudio(
      'Transcribe the audio to natural text.',
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
