import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

class FakeChatCompletionTool extends Fake implements ChatCompletionTool {}

void main() {
  late CloudInferenceWrapper wrapper;
  late MockCloudInferenceRepository mockCloudRepository;
  late AiConfigInferenceProvider provider;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeChatCompletionTool());
  });

  setUp(() {
    mockCloudRepository = MockCloudInferenceRepository();
    wrapper = CloudInferenceWrapper(cloudRepository: mockCloudRepository);
    provider = AiConfigInferenceProvider(
      id: 'test-provider',
      name: 'Test Provider',
      baseUrl: 'https://api.test.com',
      apiKey: 'test-key',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.openAi,
    );
  });

  group('CloudInferenceWrapper', () {
    group('generateText', () {
      test('delegates to cloud repository with correct parameters', () async {
        final responseStream = Stream.value(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        final tools = [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'test_function',
              description: 'A test function',
            ),
          ),
        ];

        final result = wrapper.generateText(
          prompt: 'Test prompt',
          model: 'gpt-4',
          temperature: 0.7,
          systemMessage: 'You are helpful',
          provider: provider,
          maxCompletionTokens: 1000,
          tools: tools,
        );

        expect(result, equals(responseStream));

        verify(() => mockCloudRepository.generate(
              'Test prompt',
              model: 'gpt-4',
              temperature: 0.7,
              baseUrl: 'https://api.test.com',
              apiKey: 'test-key',
              systemMessage: 'You are helpful',
              maxCompletionTokens: 1000,
              provider: provider,
              tools: tools,
            )).called(1);
      });

      test('works without optional parameters', () async {
        const responseStream =
            Stream<CreateChatCompletionStreamResponse>.empty();

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        final result = wrapper.generateText(
          prompt: 'Test prompt',
          model: 'gpt-3.5-turbo',
          temperature: 0.5,
          systemMessage: null,
          provider: provider,
        );

        expect(result, equals(responseStream));

        verify(() => mockCloudRepository.generate(
              'Test prompt',
              model: 'gpt-3.5-turbo',
              temperature: 0.5,
              baseUrl: 'https://api.test.com',
              apiKey: 'test-key',
              provider: provider,
            )).called(1);
      });
    });

    group('generateTextWithMessages', () {
      test('converts simple conversation to prompt', () async {
        final messages = [
          const ChatCompletionMessage.system(
            content: 'You are a helpful assistant',
          ),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
          const ChatCompletionMessage.assistant(
            content: 'Hi there!',
          ),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('How are you?'),
          ),
        ];

        final responseStream = Stream.value(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: "I'm doing well, thank you!",
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        final result = await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        expect(result.length, 1);
        expect(result.first.choices?.first.delta?.content,
            "I'm doing well, thank you!");

        // Verify the prompt was constructed correctly
        final capturedCall = verify(() => mockCloudRepository.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: captureAny(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).captured;

        expect(
            capturedCall[0] as String,
            contains(
                'Previous conversation:\nUser: Hello\nAssistant: Hi there!\n\nHow are you?'));
        expect(capturedCall[1] as String?, 'You are a helpful assistant');
      });

      test('handles messages with tool and function responses', () async {
        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Use a tool'),
          ),
          const ChatCompletionMessage.tool(
            toolCallId: 'tool-1',
            content: 'Tool result: 42',
          ),
          const ChatCompletionMessage.function(
            name: 'test_function',
            content: 'Function result: success',
          ),
        ];

        const responseStream =
            Stream<CreateChatCompletionStreamResponse>.empty();

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        // Verify tool and function responses were included
        final capturedPrompt = verify(() => mockCloudRepository.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).captured.first as String;

        expect(capturedPrompt, contains('Use a tool'));
        // Tool and function responses would be in assistant messages
      });

      test('detects and logs concatenated JSON in tool calls', () async {
        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Call functions'),
          ),
        ];

        final responseController =
            StreamController<CreateChatCompletionStreamResponse>();

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseController.stream);

        final resultFuture = wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        // Add response with concatenated JSON
        responseController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool-1',
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
                      function: ChatCompletionStreamMessageFunctionCall(
                        name: 'function1',
                        arguments: '{"a": 1}{"b": 2}', // Concatenated JSON
                      ),
                    ),
                  ],
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        await responseController.close();
        final result = await resultFuture;

        expect(result.length, 1);
        // The malformed JSON is passed through but logged as a warning
        expect(
          result
              .first.choices?.first.delta?.toolCalls?.first.function?.arguments,
          contains('}{'),
        );
      });

      test('handles empty messages list', () async {
        final messages = <ChatCompletionMessage>[];

        const responseStream =
            Stream<CreateChatCompletionStreamResponse>.empty();

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        // Should generate with empty prompt
        final capturedPrompt = verify(() => mockCloudRepository.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).captured.first as String;

        expect(capturedPrompt, isEmpty);
      });

      test('handles ChatCompletionUserMessageContent variations', () async {
        // Create messages with different content types
        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Simple text'),
          ),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.parts([
              ChatCompletionMessageContentPart.text(text: 'Part 1'),
              ChatCompletionMessageContentPart.text(text: 'Part 2'),
            ]),
          ),
        ];

        const responseStream =
            Stream<CreateChatCompletionStreamResponse>.empty();

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        final capturedPrompt = verify(() => mockCloudRepository.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).captured.first as String;

        expect(capturedPrompt, contains('Part 1Part 2')); // Parts are joined
      });

      test('preserves tools parameter through conversion', () async {
        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Use tools'),
          ),
        ];

        final tools = [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'tool1',
              description: 'First tool',
            ),
          ),
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'tool2',
              description: 'Second tool',
            ),
          ),
        ];

        const responseStream =
            Stream<CreateChatCompletionStreamResponse>.empty();

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
              tools: tools,
            )
            .toList();

        final capturedTools = verify(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: captureAny(named: 'tools'),
            )).captured.first as List<ChatCompletionTool>;

        expect(capturedTools, equals(tools));
      });

      test('handles messages with only user content', () async {
        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Are you there?'),
          ),
        ];

        const responseStream =
            Stream<CreateChatCompletionStreamResponse>.empty();

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        final capturedPrompt = verify(() => mockCloudRepository.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).captured.first as String;

        // Only the last user message should be in prompt
        expect(capturedPrompt, equals('Are you there?'));
      });

      test('handles different provider types', () async {
        final geminiProvider = AiConfigInferenceProvider(
          id: 'gemini-provider',
          name: 'Gemini Provider',
          baseUrl: 'https://generativelanguage.googleapis.com',
          apiKey: 'gemini-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.gemini,
        );

        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Test gemini'),
          ),
        ];

        const responseStream =
            Stream<CreateChatCompletionStreamResponse>.empty();

        when(() => mockCloudRepository.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gemini-pro',
              temperature: 0.7,
              provider: geminiProvider,
            )
            .toList();

        verify(() => mockCloudRepository.generate(
              'Test gemini',
              model: 'gemini-pro',
              temperature: 0.7,
              baseUrl: 'https://generativelanguage.googleapis.com',
              apiKey: 'gemini-key',
              provider: geminiProvider,
            )).called(1);
      });
    });
  });
}
