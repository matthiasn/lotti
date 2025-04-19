import 'package:flutter/foundation.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/repository/cloud_inference_config_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gemini_cloud_inference_repository.g.dart';

class GeminiCloudInferenceRepository {
  GeminiCloudInferenceRepository(this.ref) {
    init();
  }

  final Ref ref;

  Future<void> init() async {
    final config =
        await ref.read(cloudInferenceConfigRepositoryProvider).getConfig();
    Gemini.init(
      apiKey: config.geminiApiKey,
      disableAutoUpdateModelName: true,
    );
  }

  Stream<Candidates?> transcribeAudioStream({
    required String prompt,
    required String model,
    required String audioBase64,
  }) {
    final stream = Gemini.instance.promptStream(
      model: model,
      parts: [
        Part.text(prompt),
        Part.inline(
          InlineData(
            data: audioBase64,
            mimeType: 'audio/mp4',
          ),
        ),
      ],
    ).asBroadcastStream()
      ..listen((value) {
        debugPrint(value?.output);
      });

    return stream;
  }

  Future<Candidates?> transcribeAudio({
    required String prompt,
    required String model,
    required String audioBase64,
  }) {
    return Gemini.instance.prompt(
      model: model,
      parts: [
        Part.text(prompt),
        Part.inline(
          InlineData(
            data: audioBase64,
            mimeType: 'audio/mp4',
          ),
        ),
      ],
    );
  }
}

@riverpod
GeminiCloudInferenceRepository geminiCloudInferenceRepository(Ref ref) {
  return GeminiCloudInferenceRepository(ref);
}
