import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

/// Concrete test subclass that records received arguments and returns a fixed
/// stream from [generateTextWithMessages].
class _RecordingInferenceRepository extends InferenceRepositoryInterface {
  /// The messages passed to the last [generateTextWithMessages] call.
  List<ChatCompletionMessage>? lastMessages;

  /// The model passed to the last call.
  String? lastModel;

  /// The temperature passed to the last call.
  double? lastTemperature;

  /// The provider passed to the last call.
  AiConfigInferenceProvider? lastProvider;

  /// The maxCompletionTokens passed to the last call.
  int? lastMaxCompletionTokens;

  /// The tools passed to the last call.
  List<ChatCompletionTool>? lastTools;

  /// The thoughtSignatures passed to the last call.
  Map<String, String>? lastThoughtSignatures;

  /// The signatureCollector passed to the last call.
  ThoughtSignatureCollector? lastSignatureCollector;

  /// The turnIndex passed to the last call.
  int? lastTurnIndex;

  /// The stream to return from [generateTextWithMessages].
  Stream<CreateChatCompletionStreamResponse> streamToReturn =
      const Stream.empty();

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
    bool isReasoningModel = false,
  }) {
    lastMessages = messages;
    lastModel = model;
    lastTemperature = temperature;
    lastProvider = provider;
    lastMaxCompletionTokens = maxCompletionTokens;
    lastTools = tools;
    lastThoughtSignatures = thoughtSignatures;
    lastSignatureCollector = signatureCollector;
    lastTurnIndex = turnIndex;
    return streamToReturn;
  }
}

void main() {
  late _RecordingInferenceRepository repository;
  late AiConfigInferenceProvider testProvider;

  setUp(() {
    repository = _RecordingInferenceRepository();
    testProvider = AiConfigInferenceProvider(
      id: 'test-provider',
      name: 'Test Provider',
      baseUrl: 'https://api.test.com',
      apiKey: 'test-api-key',
      createdAt: DateTime(2024, 3, 15),
      inferenceProviderType: InferenceProviderType.anthropic,
    );
  });

  group('InferenceRepositoryInterface', () {
    group('generateText', () {
      test(
        'with systemMessage builds [system, user] messages and delegates',
        () {
          repository.generateText(
            prompt: 'Hello, world!',
            model: 'test-model',
            temperature: 0.7,
            systemMessage: 'You are a helpful assistant.',
            provider: testProvider,
          );

          expect(repository.lastMessages, hasLength(2));
          expect(
            repository.lastMessages![0],
            const ChatCompletionMessage.system(
              content: 'You are a helpful assistant.',
            ),
          );
          expect(
            repository.lastMessages![1],
            const ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(
                'Hello, world!',
              ),
            ),
          );
        },
      );

      test(
        'without systemMessage builds [user] message only and delegates',
        () {
          repository.generateText(
            prompt: 'Just a prompt',
            model: 'test-model',
            temperature: 0.5,
            systemMessage: null,
            provider: testProvider,
          );

          expect(repository.lastMessages, hasLength(1));
          expect(
            repository.lastMessages![0],
            const ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(
                'Just a prompt',
              ),
            ),
          );
        },
      );

      test(
        'passes all parameters through to generateTextWithMessages',
        () {
          const tools = [
            ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ];

          repository.generateText(
            prompt: 'test prompt',
            model: 'gpt-4',
            temperature: 0.9,
            systemMessage: 'system',
            provider: testProvider,
            maxCompletionTokens: 4096,
            tools: tools,
          );

          expect(repository.lastModel, 'gpt-4');
          expect(repository.lastTemperature, 0.9);
          expect(repository.lastProvider, testProvider);
          expect(repository.lastMaxCompletionTokens, 4096);
          expect(repository.lastTools, tools);
        },
      );

      test(
        'returns the stream from generateTextWithMessages',
        () async {
          final responses = [
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    content: 'Hello!',
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ];

          repository.streamToReturn = Stream.fromIterable(responses);

          final stream = repository.generateText(
            prompt: 'test',
            model: 'model',
            temperature: 0.5,
            systemMessage: null,
            provider: testProvider,
          );

          final collected = await stream.toList();
          expect(collected, hasLength(1));
          expect(collected[0].id, 'test-response');
          expect(
            collected[0].choices?.first.delta?.content,
            'Hello!',
          );
        },
      );
    });
  });
}
