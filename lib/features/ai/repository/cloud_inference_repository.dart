import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_inference_repository.g.dart';

class CloudInferenceRepository {
  CloudInferenceRepository(this.ref, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final Ref ref;
  final http.Client _httpClient;

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

  /// Generates AI responses with audio input using different providers
  ///
  /// This method handles different inference providers:
  /// - FastWhisper: Uses local FastWhisper server for transcription
  /// - Whisper: Uses OpenAI's Whisper API via our Python proxy server
  /// - Other providers: Uses standard OpenAI-compatible format
  ///
  /// Args:
  ///   prompt: The text prompt to send with the audio
  ///   model: The model identifier to use
  ///   audioBase64: Base64 encoded audio data
  ///   baseUrl: The base URL for the API
  ///   apiKey: The API key for authentication
  ///   provider: The inference provider configuration
  ///   maxCompletionTokens: Maximum tokens for completion
  ///   overrideClient: Optional client override for testing
  ///
  /// Returns:
  ///   Stream of chat completion responses
  Stream<CreateChatCompletionStreamResponse> generateWithAudio(
    String prompt, {
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    // For Whisper, we need to handle the audio transcription using our Python server
    if (provider.inferenceProviderType == InferenceProviderType.whisper) {
      // Whisper uses our Python server that calls OpenAI's API
      // Create a stream that performs the async operation
      return Stream.fromFuture(
        () async {
          final response = await _httpClient.post(
            Uri.parse('$baseUrl/v1/audio/transcriptions'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          );

          if (response.statusCode != 200) {
            developer.log('Failed to transcribe audio: ${response.body}',
                name: 'CloudInferenceRepository');
            throw Exception('Failed to transcribe audio: ${response.body}');
          }

          final result = jsonDecode(response.body) as Map<String, dynamic>;
          final text = result['text'] as String;

          // Create a mock stream response to match the expected format
          return CreateChatCompletionStreamResponse(
            id: 'whisper-${DateTime.now().millisecondsSinceEpoch}',
            choices: [
              ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: text,
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
        }(),
      ).asBroadcastStream();
    }

    // For other providers, use the standard OpenAI-compatible format
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
