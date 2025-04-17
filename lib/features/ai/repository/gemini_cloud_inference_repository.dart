import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/cloud_inference_config.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gemini_cloud_inference_repository.g.dart';

class GeminiCloudInferenceRepository {
  GeminiCloudInferenceRepository() {
    init();
  }

  Future<void> init() async {
    final config = await getConfig();
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

  Future<CloudInferenceConfig> getConfig() async {
    final docDir = getDocumentsDirectory();
    final jsonFile = File(join(docDir.path, 'cloud_inference_config.json'));
    final jsonString = await jsonFile.readAsString();

    return CloudInferenceConfig.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

@riverpod
GeminiCloudInferenceRepository geminiCloudInferenceRepository(Ref ref) {
  return GeminiCloudInferenceRepository();
}
