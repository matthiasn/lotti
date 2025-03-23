import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/cloud_inference_config.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_inference_repository.g.dart';

class CloudInferenceRepository {
  CloudInferenceRepository();

  Stream<CreateChatCompletionStreamResponse> generate(
    String prompt, {
    required String model,
    required double temperature,
    required CloudInferenceConfig config,
  }) {
    final client = OpenAIClient(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
    );

    final res = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        messages: [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(prompt),
          ),
        ],
        model: ChatCompletionModel.modelId(model),
        temperature: temperature,
      ),
    );

    return res.asBroadcastStream();
  }

  Stream<CreateChatCompletionStreamResponse> generateWithImages(
    String prompt, {
    required CloudInferenceConfig config,
    required String model,
    required double temperature,
    required List<String> images,
  }) {
    final client = OpenAIClient(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
    );

    final res = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        messages: [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.parts(
              [
                ChatCompletionMessageContentPart.text(text: prompt),
                ...images.map(
                  (image) {
                    return ChatCompletionMessageContentPart.image(
                      imageUrl: ChatCompletionMessageImageUrl(
                        url: 'data:image;base64,{$image}',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        model: ChatCompletionModel.modelId(model),
        temperature: temperature,
      ),
    );

    return res.asBroadcastStream();
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
CloudInferenceRepository cloudInferenceRepository(Ref ref) {
  return CloudInferenceRepository();
}
