import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_generate.dart';
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';

class _FakeCreateChatCompletionRequest extends Fake
    implements CreateChatCompletionRequest {}

class _FakeGeminiThinkingConfig extends Fake implements GeminiThinkingConfig {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCreateChatCompletionRequest());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(_FakeGeminiThinkingConfig());
    registerFallbackValue(<ChatCompletionTool>[]);
  });

  late MockOllamaInferenceRepository ollamaRepo;
  late MockGeminiInferenceRepository geminiRepo;
  late MeliousInferenceRepository meliousRepo;
  late MistralInferenceRepository mistralRepo;
  late MockOpenAIClient client;
  late CloudInferenceGenerate generate;

  const baseUrl = 'https://api.openai.com/v1';
  const apiKey = 'test-api-key';
  const model = 'gpt-4';
  const prompt = 'Hello, AI!';

  AiConfigInferenceProvider providerOfType(InferenceProviderType type) {
    return AiConfig.inferenceProvider(
          id: 'provider-$type',
          name: 'Provider',
          baseUrl: baseUrl,
          apiKey: apiKey,
          createdAt: DateTime(2024, 3, 15),
          inferenceProviderType: type,
        )
        as AiConfigInferenceProvider;
  }

  CreateChatCompletionStreamResponse chunk(String content) {
    return CreateChatCompletionStreamResponse(
      id: 'response-id',
      choices: [
        ChatCompletionStreamResponseChoice(
          delta: ChatCompletionStreamResponseDelta(content: content),
          index: 0,
        ),
      ],
      object: 'chat.completion.chunk',
      created: DateTime(2024, 3, 15).millisecondsSinceEpoch ~/ 1000,
    );
  }

  setUp(() {
    ollamaRepo = MockOllamaInferenceRepository();
    geminiRepo = MockGeminiInferenceRepository();
    meliousRepo = MeliousInferenceRepository();
    mistralRepo = MistralInferenceRepository();
    client = MockOpenAIClient();
    generate = CloudInferenceGenerate(
      ollamaRepository: ollamaRepo,
      geminiRepository: geminiRepo,
      meliousRepository: meliousRepo,
      mistralRepository: mistralRepo,
      helpers: const CloudInferenceRequestHelpers(),
    );
  });

  tearDown(() {
    meliousRepo.close();
    mistralRepo.close();
  });

  group('generate', () {
    test(
      'OpenAI-compatible path builds a user request and filters pings into a '
      'broadcast stream',
      () async {
        when(
          () => client.createChatCompletionStream(
            request: any(named: 'request'),
          ),
        ).thenAnswer((_) => Stream.fromIterable([chunk('hi')]));

        final stream = generate.generate(
          prompt,
          model: model,
          temperature: 0.7,
          baseUrl: baseUrl,
          apiKey: apiKey,
          systemMessage: 'be brief',
          overrideClient: client,
        );

        expect(stream.isBroadcast, isTrue);
        final responses = await stream.toList();
        expect(responses.single.choices?.first.delta?.content, 'hi');

        final request =
            verify(
                  () => client.createChatCompletionStream(
                    request: captureAny(named: 'request'),
                  ),
                ).captured.single
                as CreateChatCompletionRequest;
        // system + user message, temperature forwarded, streaming on.
        expect(request.messages, hasLength(2));
        expect(request.messages.first.role, ChatCompletionMessageRole.system);
        expect(request.messages.last.role, ChatCompletionMessageRole.user);
        expect(request.temperature, 0.7);
        expect(request.stream, isTrue);
        expect(request.toString(), contains(prompt));
      },
    );

    test('routes Gemini provider to the Gemini repository', () {
      final geminiProvider = providerOfType(InferenceProviderType.gemini);
      when(
        () => geminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          provider: any(named: 'provider'),
          tools: any(named: 'tools'),
          toolChoice: any(named: 'toolChoice'),
          thinkingConfig: any(named: 'thinkingConfig'),
        ),
      ).thenAnswer((_) => Stream.fromIterable([chunk('gemini')]));

      generate.generate(
        prompt,
        model: model,
        temperature: null,
        baseUrl: baseUrl,
        apiKey: apiKey,
        provider: geminiProvider,
      );

      // Null temperature must be defaulted to 0.7 by the routing layer.
      verify(
        () => geminiRepo.generateText(
          prompt: prompt,
          model: model,
          temperature: 0.7,
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          provider: geminiProvider,
          tools: any(named: 'tools'),
          toolChoice: any(named: 'toolChoice'),
          thinkingConfig: any(named: 'thinkingConfig'),
        ),
      ).called(1);
      verifyNever(
        () => client.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      );
    });
  });

  group('generateWithImages', () {
    test(
      'maps Gemini 3 thinking mode to reasoning effort on the OpenAI path',
      () async {
        final geminiProvider = providerOfType(InferenceProviderType.gemini);
        when(
          () => client.createChatCompletionStream(
            request: any(named: 'request'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        await generate
            .generateWithImages(
              prompt,
              baseUrl: baseUrl,
              apiKey: apiKey,
              model: 'gemini-3-flash-preview',
              temperature: null,
              images: const ['base64-image'],
              provider: geminiProvider,
              overrideClient: client,
              geminiThinkingMode: GeminiThinkingMode.high,
            )
            .toList();

        final request =
            verify(
                  () => client.createChatCompletionStream(
                    request: captureAny(named: 'request'),
                  ),
                ).captured.single
                as CreateChatCompletionRequest;
        expect(request.reasoningEffort, ReasoningEffort.high);
        // Image content is encoded as a data URI in the request payload.
        expect(request.toString(), contains('data:image/jpeg;base64,'));
      },
    );

    test('routes Ollama provider to the Ollama repository', () {
      final ollamaProvider = providerOfType(InferenceProviderType.ollama);
      when(
        () => ollamaRepo.generateWithImages(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          images: any(named: 'images'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenAnswer((_) => Stream.fromIterable([chunk('ollama')]));

      generate.generateWithImages(
        prompt,
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        temperature: 0.5,
        images: const ['img'],
        provider: ollamaProvider,
        overrideClient: client,
      );

      verify(
        () => ollamaRepo.generateWithImages(
          prompt: prompt,
          model: model,
          temperature: 0.5,
          images: const ['img'],
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          provider: ollamaProvider,
          systemMessage: any(named: 'systemMessage'),
        ),
      ).called(1);
      verifyNever(
        () => client.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      );
    });
  });
}
