import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class FakeLottiTool extends Fake implements LottiTool {}

void main() {
  late CloudInferenceWrapper wrapper;
  late MockCloudInferenceRepository mockCloudRepository;
  late AiConfigInferenceProvider provider;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeLottiTool());
    registerFallbackValue(<LottiMessage>[]);
    registerFallbackValue(<String, String>{});
    registerFallbackValue(ThoughtSignatureCollector());
  });

  setUp(() {
    mockCloudRepository = MockCloudInferenceRepository();
    wrapper = CloudInferenceWrapper(cloudRepository: mockCloudRepository);
    provider = AiConfigInferenceProvider(
      id: 'test-provider',
      name: 'Test Provider',
      baseUrl: 'https://api.test.com',
      apiKey: 'test-key',
      createdAt: DateTime(2024, 3, 15, 10, 30),
      inferenceProviderType: InferenceProviderType.openAi,
    );
  });

  group('CloudInferenceWrapper', () {
    group('generateText', () {
      test('delegates to cloud repository with correct parameters', () async {
        final responseStream = Stream.value(
          LottiInferenceChunk(
            id: 'test-response',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            choices: const [
              LottiChunkChoice(
                index: 0,
                delta: LottiDelta(content: 'Test response'),
              ),
            ],
          ),
        );

        when(
          () => mockCloudRepository.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseStream);

        final tools = [
          const LottiTool(
            name: 'test_function',
            description: 'A test function',
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

        verify(
          () => mockCloudRepository.generate(
            'Test prompt',
            model: 'gpt-4',
            temperature: 0.7,
            baseUrl: 'https://api.test.com',
            apiKey: 'test-key',
            systemMessage: 'You are helpful',
            maxCompletionTokens: 1000,
            provider: provider,
            tools: tools,
            // ignore: avoid_redundant_argument_values
            reasoningEffort: null,
          ),
        ).called(1);
      });

      test('works without optional parameters', () async {
        const responseStream = Stream<LottiInferenceChunk>.empty();

        when(
          () => mockCloudRepository.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseStream);

        final result = wrapper.generateText(
          prompt: 'Test prompt',
          model: 'gpt-3.5-turbo',
          temperature: 0.5,
          systemMessage: null,
          provider: provider,
        );

        expect(result, equals(responseStream));

        verify(
          () => mockCloudRepository.generate(
            'Test prompt',
            model: 'gpt-3.5-turbo',
            temperature: 0.5,
            baseUrl: 'https://api.test.com',
            apiKey: 'test-key',
            provider: provider,
            // ignore: avoid_redundant_argument_values
            reasoningEffort: null,
          ),
        ).called(1);
      });
    });

    group('generateTextWithMessages', () {
      test('delegates to cloud repository generateWithMessages', () async {
        final messages = [
          const LottiMessage.system('You are a helpful assistant'),
          LottiMessage.userText('Hello'),
          const LottiMessage.assistant(content: 'Hi there!'),
          LottiMessage.userText('How are you?'),
        ];

        final responseStream = Stream.value(
          LottiInferenceChunk(
            id: 'test-response',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            choices: const [
              LottiChunkChoice(
                index: 0,
                delta: LottiDelta(content: "I'm doing well, thank you!"),
              ),
            ],
          ),
        );

        wrapper = CloudInferenceWrapper(
          cloudRepository: mockCloudRepository,
          reasoningEffort: LottiReasoningEffort.high,
        );

        when(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseStream);

        final result = await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        expect(result.length, 1);
        expect(
          result.first.choices?.first.delta?.content,
          "I'm doing well, thank you!",
        );

        verify(
          () => mockCloudRepository.generateWithMessages(
            messages: messages,
            model: 'gpt-4',
            temperature: 0.7,
            provider: provider,
            reasoningEffort: LottiReasoningEffort.high,
          ),
        ).called(1);
      });

      test('handles messages with tool and function responses', () async {
        final messages = [
          LottiMessage.userText('Use a tool'),
          const LottiMessage.tool(
            toolCallId: 'tool-1',
            content: 'Tool result: 42',
          ),
        ];

        const responseStream = Stream<LottiInferenceChunk>.empty();

        when(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        verify(
          () => mockCloudRepository.generateWithMessages(
            messages: messages,
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).called(1);
      });

      test('detects and logs concatenated JSON in tool calls', () async {
        final messages = [
          LottiMessage.userText('Call functions'),
        ];

        final responseController = StreamController<LottiInferenceChunk>();

        when(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseController.stream);

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
          LottiInferenceChunk(
            id: 'test-response',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            choices: const [
              LottiChunkChoice(
                index: 0,
                delta: LottiDelta(
                  toolCalls: [
                    LottiToolCallChunk(
                      id: 'tool-1',
                      index: 0,
                      name: 'function1',
                      arguments: '{"a": 1}{"b": 2}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        await responseController.close();
        final result = await resultFuture;

        expect(result.length, 1);
        // The malformed JSON is passed through but logged as a warning
        expect(
          result.first.choices?.first.delta?.toolCalls?.first.arguments,
          contains('}{'),
        );
      });

      test('handles empty messages list', () async {
        final messages = <LottiMessage>[];

        const responseStream = Stream<LottiInferenceChunk>.empty();

        when(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
            )
            .toList();

        verify(
          () => mockCloudRepository.generateWithMessages(
            messages: messages,
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).called(1);
      });

      test('preserves tools parameter', () async {
        final messages = [
          LottiMessage.userText('Use tools'),
        ];

        final tools = [
          const LottiTool(name: 'tool1', description: 'First tool'),
          const LottiTool(name: 'tool2', description: 'Second tool'),
        ];

        const responseStream = Stream<LottiInferenceChunk>.empty();

        when(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
              tools: tools,
            )
            .toList();

        verify(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: tools,
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).called(1);
      });

      test('passes through signature collector and signatures', () async {
        final collector = ThoughtSignatureCollector();
        final signatures = {'tool_0': 'sig-abc123'};

        final messages = [
          LottiMessage.userText('Hello'),
        ];

        const responseStream = Stream<LottiInferenceChunk>.empty();

        when(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseStream);

        // Pass signatures through method parameters (not constructor)
        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gpt-4',
              temperature: 0.7,
              provider: provider,
              thoughtSignatures: signatures,
              signatureCollector: collector,
            )
            .toList();

        verify(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: signatures,
            signatureCollector: collector,
            // ignore: avoid_redundant_argument_values
            reasoningEffort: null,
          ),
        ).called(1);
      });

      test('handles different provider types', () async {
        final geminiProvider = AiConfigInferenceProvider(
          id: 'gemini-provider',
          name: 'Gemini Provider',
          baseUrl: 'https://generativelanguage.googleapis.com',
          apiKey: 'gemini-key',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.gemini,
        );

        final messages = [
          LottiMessage.userText('Test gemini'),
        ];

        const responseStream = Stream<LottiInferenceChunk>.empty();

        when(
          () => mockCloudRepository.generateWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            tools: any(named: 'tools'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            reasoningEffort: any(named: 'reasoningEffort'),
          ),
        ).thenAnswer((_) => responseStream);

        await wrapper
            .generateTextWithMessages(
              messages: messages,
              model: 'gemini-pro',
              temperature: 0.7,
              provider: geminiProvider,
            )
            .toList();

        verify(
          () => mockCloudRepository.generateWithMessages(
            messages: messages,
            model: 'gemini-pro',
            temperature: 0.7,
            provider: geminiProvider,
            // ignore: avoid_redundant_argument_values
            reasoningEffort: null,
          ),
        ).called(1);
      });
    });
  });
}
