import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_inference_repository.g.dart';

class CloudInferenceRepository {
  CloudInferenceRepository(this.ref);

  final Ref ref;

  /// Filters out Anthropic ping messages from the stream
  Stream<CreateChatCompletionStreamResponse> _filterAnthropicPings(
    Stream<CreateChatCompletionStreamResponse> stream,
  ) {
    // Use where to filter out errors instead of handleError
    final controller = StreamController<CreateChatCompletionStreamResponse>();

    stream.listen(
      controller.add,
      onError: (Object error, StackTrace stackTrace) {
        // Check if this is specifically an Anthropic ping message error
        final errorString = error.toString();

        // Anthropic ping messages cause a specific null subtype error when parsing choices
        final isAnthropicPingError = errorString.contains(
                "type 'Null' is not a subtype of type 'List<dynamic>'") &&
            errorString.contains('choices');

        if (isAnthropicPingError) {
          // Log but don't propagate the error
          developer.log(
            'Skipping Anthropic ping message',
            name: 'CloudInferenceRepository',
            error: error,
            stackTrace: stackTrace,
          );
          return;
        }
        // Propagate other errors
        controller.addError(error, stackTrace);
      },
      onDone: controller.close,
    );

    return controller.stream;
  }

  Stream<CreateChatCompletionStreamResponse> generate(
    String prompt, {
    required String model,
    required double temperature,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    final res = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        messages: [
          if (systemMessage != null)
            ChatCompletionMessage.system(content: systemMessage),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(prompt),
          ),
        ],
        model: ChatCompletionModel.modelId(model),
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        stream: true,
      ),
    );

    return _filterAnthropicPings(res).asBroadcastStream();
  }

  Stream<CreateChatCompletionStreamResponse> generateWithImages(
    String prompt, {
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required List<String> images,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
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
        maxTokens: maxCompletionTokens,
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
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    return client
        .createChatCompletionStream(
          request: CreateChatCompletionRequest(
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
            maxCompletionTokens: maxCompletionTokens,
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
