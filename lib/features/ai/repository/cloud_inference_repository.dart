import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_inference_repository.g.dart';

class CloudInferenceRepository {
  CloudInferenceRepository(this.ref);

  final Ref ref;

  Stream<CreateChatCompletionStreamResponse> generate(
    String prompt, {
    required String model,
    required double temperature,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    OpenAIClient? overrideClient,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    final res = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        frequencyPenalty: null,
        messages: [
          if (systemMessage != null)
            ChatCompletionMessage.system(content: systemMessage),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(prompt),
          ),
        ],
        model: ChatCompletionModel.modelId(model),
        temperature: temperature,
        stream: true,
      ),
    );

    return res.asBroadcastStream();
  }

  Stream<CreateChatCompletionStreamResponse> generateWithImages(
    String prompt, {
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required List<String> images,
    OpenAIClient? overrideClient,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    final res = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        frequencyPenalty: null,
        messages: [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.parts(
              [
                ChatCompletionMessageContentPart.text(text: prompt),
                ...images.map(
                  (image) {
                    return ChatCompletionMessageContentPart.image(
                      imageUrl: ChatCompletionMessageImageUrl(
                        url: 'data:image/jpeg;base64,$image',
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
        stream: true,
      ),
    );

    return res.asBroadcastStream();
  }

  Stream<CreateChatCompletionStreamResponse> generateWithAudio(
    String prompt, {
    required String baseUrl,
    required String apiKey,
    required String model,
    required String audioBase64,
    OpenAIClient? overrideClient,
  }) {
    if (baseUrl.contains('localhost:8000')) {
      // Direct call to FastWhisper
      final uri = Uri.parse('$baseUrl/transcribe');
      final body = jsonEncode({
        'audio': audioBase64,
        'model': 'base',
        'language': 'auto',
      });
      final headers = {'Content-Type': 'application/json'};
      return Stream.fromFuture(
        http.post(uri, headers: headers, body: body).then((response) {
          if (response.statusCode != 200) {
            throw Exception(
                'Failed to transcribe audio: \\${response.statusCode}');
          }
          // Cast the decoded JSON to Map<String, dynamic>
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          // Ensure the response has a 'choices' field, or wrap it in a valid structure
          if (!decoded.containsKey('choices')) {
            decoded['choices'] = [
              {
                'delta': {'content': decoded['text'] ?? ''},
                'finish_reason': null,
                'index': 0
              }
            ];
          }
          return CreateChatCompletionStreamResponse.fromJson(decoded);
        }),
      );
    }

    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    // Default handling for other providers
    return client
        .createChatCompletionStream(
          request: CreateChatCompletionRequest(
            frequencyPenalty: null,
            messages: [
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.parts(
                  [
                    ChatCompletionMessageContentPart.text(text: prompt),
                    ChatCompletionMessageContentPart.audio(
                      inputAudio: ChatCompletionMessageInputAudio(
                        data: audioBase64,
                        format: ChatCompletionMessageInputAudioFormat.mp3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            model: ChatCompletionModel.modelId(model),
            stream: true,
          ),
        )
        .asBroadcastStream();
  }
}

@riverpod
CloudInferenceRepository cloudInferenceRepository(Ref ref) {
  return CloudInferenceRepository(ref);
}
