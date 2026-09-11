import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/repository/cloud_inference_generate.dart';
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_ocr_repository.dart';
import 'package:lotti/features/ai/repository/openai_compat_adapter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _FakeLottiInferenceRequest extends Fake
    implements LottiInferenceRequest {}

class _FakeGeminiThinkingConfig extends Fake implements GeminiThinkingConfig {}

class _FakeMeliousInferenceRepository extends MeliousInferenceRepository {
  final textCalls =
      <
        ({
          String prompt,
          String model,
          String baseUrl,
          LottiReasoningEffort? reasoningEffort,
        })
      >[];
  final imageCalls =
      <({String prompt, String model, String baseUrl, List<String> images})>[];

  @override
  Stream<LottiInferenceChunk> generateText({
    required String prompt,
    required String model,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    double? temperature,
    int? maxCompletionTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
    LottiReasoningEffort? reasoningEffort,
    InferenceImpactCollector? impactCollector,
  }) {
    textCalls.add((
      prompt: prompt,
      model: model,
      baseUrl: baseUrl,
      reasoningEffort: reasoningEffort,
    ));
    return Stream.value(_chunk('melious text'));
  }

  @override
  Stream<LottiInferenceChunk> generateWithImages({
    required String prompt,
    required String model,
    required String baseUrl,
    required String apiKey,
    required List<String> images,
    String? systemMessage,
    double? temperature,
    int? maxCompletionTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
    InferenceImpactCollector? impactCollector,
  }) {
    imageCalls.add((
      prompt: prompt,
      model: model,
      baseUrl: baseUrl,
      images: images,
    ));
    return Stream.value(_chunk('melious vision'));
  }

  static LottiInferenceChunk _chunk(String content) {
    return LottiInferenceChunk(
      id: 'melious-response-id',
      created: DateTime(2024, 3, 15).millisecondsSinceEpoch ~/ 1000,
      choices: [
        LottiChunkChoice(index: 0, delta: LottiDelta(content: content)),
      ],
    );
  }
}

class _FakeMistralInferenceRepository extends MistralInferenceRepository {
  final textCalls =
      <
        ({String prompt, String model, LottiReasoningEffort? reasoningEffort})
      >[];

  @override
  Stream<LottiInferenceChunk> generateText({
    required String prompt,
    required String model,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    double? temperature,
    int? maxCompletionTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
    LottiReasoningEffort? reasoningEffort,
  }) {
    textCalls.add((
      prompt: prompt,
      model: model,
      reasoningEffort: reasoningEffort,
    ));
    return Stream.value(_FakeMeliousInferenceRepository._chunk('mistral text'));
  }
}

class _FakeMistralOcrRepository extends MistralOcrRepository {
  final calls =
      <({String model, String baseUrl, String apiKey, List<String> images})>[];

  @override
  Stream<LottiInferenceChunk> extractText({
    required String model,
    required List<String> images,
    required String baseUrl,
    required String apiKey,
    Duration timeout = MistralOcrRepository.defaultTimeout,
  }) {
    calls.add((
      model: model,
      baseUrl: baseUrl,
      apiKey: apiKey,
      images: images,
    ));
    return Stream.value(
      const LottiInferenceChunk(
        id: 'mistral-ocr-response-id',
        created: 0,
        choices: [
          LottiChunkChoice(
            index: 0,
            delta: LottiDelta(content: 'ocr markdown'),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeLottiInferenceRequest());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(_FakeGeminiThinkingConfig());
    registerFallbackValue(<LottiTool>[]);
  });

  late MockOllamaInferenceRepository ollamaRepo;
  late MockGeminiInferenceRepository geminiRepo;
  late MeliousInferenceRepository meliousRepo;
  late MistralInferenceRepository mistralRepo;
  late MistralOcrRepository mistralOcrRepo;
  late MockLottiInferenceClient client;
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

  LottiInferenceChunk chunk(String content) {
    return LottiInferenceChunk(
      id: 'response-id',
      created: DateTime(2024, 3, 15).millisecondsSinceEpoch ~/ 1000,
      choices: [
        LottiChunkChoice(index: 0, delta: LottiDelta(content: content)),
      ],
    );
  }

  setUp(() {
    ollamaRepo = MockOllamaInferenceRepository();
    geminiRepo = MockGeminiInferenceRepository();
    meliousRepo = MeliousInferenceRepository();
    mistralRepo = MistralInferenceRepository();
    mistralOcrRepo = MistralOcrRepository();
    client = MockLottiInferenceClient();
    generate = CloudInferenceGenerate(
      ollamaRepository: ollamaRepo,
      geminiRepository: geminiRepo,
      meliousRepository: meliousRepo,
      mistralRepository: mistralRepo,
      mistralOcrRepository: mistralOcrRepo,
      helpers: const CloudInferenceRequestHelpers(),
    );
  });

  tearDown(() {
    meliousRepo.close();
    mistralRepo.close();
    mistralOcrRepo.close();
  });

  test(
    'sherpa rejects text and image input without invoking an HTTP client',
    () {
      final provider = providerOfType(InferenceProviderType.sherpa);
      expect(
        () => generate.generate(
          prompt,
          model: 'tiny',
          temperature: null,
          baseUrl: baseUrl,
          apiKey: apiKey,
          provider: provider,
          overrideClient: client,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => generate.generateWithImages(
          prompt,
          model: 'tiny',
          temperature: null,
          baseUrl: baseUrl,
          apiKey: apiKey,
          images: ['image'],
          provider: provider,
          overrideClient: client,
        ),
        throwsUnsupportedError,
      );
      verifyNever(
        () => client.createChatCompletionStream(any()),
      );
    },
  );

  group('generate', () {
    test(
      'OpenAI-compatible path builds a user request and filters pings into a '
      'broadcast stream',
      () async {
        when(
          () => client.createChatCompletionStream(any()),
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
                  () => client.createChatCompletionStream(captureAny()),
                ).captured.single
                as LottiInferenceRequest;
        // system + user message, temperature forwarded, streaming on.
        expect(request.messages, hasLength(2));
        expect(request.messages.first.role, LottiMessageRole.system);
        expect(request.messages.last.role, LottiMessageRole.user);
        expect(request.temperature, 0.7);
        expect(request.messages.last.textContent, contains(prompt));
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
        () => client.createChatCompletionStream(any()),
      );
    });

    test('routes Melious provider to the Melious repository', () async {
      final fakeMeliousRepo = _FakeMeliousInferenceRepository();
      generate = CloudInferenceGenerate(
        ollamaRepository: ollamaRepo,
        geminiRepository: geminiRepo,
        meliousRepository: fakeMeliousRepo,
        mistralRepository: mistralRepo,
        mistralOcrRepository: mistralOcrRepo,
        helpers: const CloudInferenceRequestHelpers(),
      );
      final meliousProvider = providerOfType(InferenceProviderType.melious);

      final chunks = await generate
          .generate(
            prompt,
            model: 'qwen/qwen3-vl-plus',
            temperature: 0.2,
            baseUrl: 'https://api.melious.ai/v1',
            apiKey: 'sk-mel-test',
            provider: meliousProvider,
            systemMessage: 'be brief',
            maxCompletionTokens: 512,
            reasoningEffort: LottiReasoningEffort.high,
          )
          .toList();

      expect(chunks.single.choices?.single.delta?.content, 'melious text');
      expect(fakeMeliousRepo.textCalls, hasLength(1));
      expect(fakeMeliousRepo.textCalls.single.prompt, prompt);
      expect(fakeMeliousRepo.textCalls.single.model, 'qwen/qwen3-vl-plus');
      expect(
        fakeMeliousRepo.textCalls.single.reasoningEffort,
        LottiReasoningEffort.high,
      );
      expect(
        fakeMeliousRepo.textCalls.single.baseUrl,
        'https://api.melious.ai/v1',
      );
      verifyNever(
        () => client.createChatCompletionStream(any()),
      );
    });

    test('routes reasoning effort to the Mistral repository', () async {
      final fakeMistralRepo = _FakeMistralInferenceRepository();
      addTearDown(fakeMistralRepo.close);
      generate = CloudInferenceGenerate(
        ollamaRepository: ollamaRepo,
        geminiRepository: geminiRepo,
        meliousRepository: meliousRepo,
        mistralRepository: fakeMistralRepo,
        mistralOcrRepository: mistralOcrRepo,
        helpers: const CloudInferenceRequestHelpers(),
      );

      final chunks = await generate
          .generate(
            prompt,
            model: 'mistral-small-latest',
            temperature: 0.2,
            baseUrl: 'https://api.mistral.ai/v1',
            apiKey: 'sk-mistral-test',
            provider: providerOfType(InferenceProviderType.mistral),
            reasoningEffort: LottiReasoningEffort.high,
          )
          .toList();

      expect(chunks.single.choices?.single.delta?.content, 'mistral text');
      expect(fakeMistralRepo.textCalls, hasLength(1));
      expect(fakeMistralRepo.textCalls.single.prompt, prompt);
      expect(
        fakeMistralRepo.textCalls.single.reasoningEffort,
        LottiReasoningEffort.high,
      );
    });
  });

  group('generateWithImages', () {
    test(
      'maps Gemini 3 thinking mode to reasoning effort on the OpenAI path',
      () async {
        final geminiProvider = providerOfType(InferenceProviderType.gemini);
        when(
          () => client.createChatCompletionStream(any()),
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
                  () => client.createChatCompletionStream(captureAny()),
                ).captured.single
                as LottiInferenceRequest;
        expect(request.reasoningEffort, LottiReasoningEffort.high);
        // Image content is encoded as a data URI in the request payload.
        expect(
          jsonEncode(openAiRequestJson(request)),
          contains('data:image/jpeg;base64,'),
        );
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
        () => client.createChatCompletionStream(any()),
      );
    });

    test('routes Melious provider to the Melious vision repository', () async {
      final fakeMeliousRepo = _FakeMeliousInferenceRepository();
      generate = CloudInferenceGenerate(
        ollamaRepository: ollamaRepo,
        geminiRepository: geminiRepo,
        meliousRepository: fakeMeliousRepo,
        mistralRepository: mistralRepo,
        mistralOcrRepository: mistralOcrRepo,
        helpers: const CloudInferenceRequestHelpers(),
      );
      final meliousProvider = providerOfType(InferenceProviderType.melious);

      final chunks = await generate
          .generateWithImages(
            prompt,
            baseUrl: 'https://api.melious.ai/v1',
            apiKey: 'sk-mel-test',
            model: 'qwen/qwen3-vl-plus',
            temperature: 0.5,
            images: const ['image-a', 'image-b'],
            provider: meliousProvider,
            overrideClient: client,
          )
          .toList();

      expect(chunks.single.choices?.single.delta?.content, 'melious vision');
      expect(fakeMeliousRepo.imageCalls, hasLength(1));
      expect(fakeMeliousRepo.imageCalls.single.prompt, prompt);
      expect(fakeMeliousRepo.imageCalls.single.model, 'qwen/qwen3-vl-plus');
      expect(
        fakeMeliousRepo.imageCalls.single.images,
        const ['image-a', 'image-b'],
      );
      verifyNever(
        () => client.createChatCompletionStream(any()),
      );
    });

    test(
      'routes a Mistral OCR model to the OCR endpoint, not chat completions',
      () async {
        final fakeOcrRepo = _FakeMistralOcrRepository();
        generate = CloudInferenceGenerate(
          ollamaRepository: ollamaRepo,
          geminiRepository: geminiRepo,
          meliousRepository: meliousRepo,
          mistralRepository: mistralRepo,
          mistralOcrRepository: fakeOcrRepo,
          helpers: const CloudInferenceRequestHelpers(),
        );
        final mistralProvider = providerOfType(InferenceProviderType.mistral);

        final chunks = await generate
            .generateWithImages(
              prompt,
              baseUrl: 'https://api.mistral.ai/v1',
              apiKey: apiKey,
              model: 'mistral-ocr-2512',
              temperature: null,
              images: const ['letter-scan'],
              provider: mistralProvider,
            )
            .toList();

        expect(chunks.single.choices?.single.delta?.content, 'ocr markdown');
        expect(fakeOcrRepo.calls, hasLength(1));
        expect(fakeOcrRepo.calls.single.model, 'mistral-ocr-2512');
        expect(fakeOcrRepo.calls.single.images, const ['letter-scan']);
        expect(fakeOcrRepo.calls.single.baseUrl, 'https://api.mistral.ai/v1');
        // Crucially, the OCR model must NOT hit chat completions.
        verifyNever(
          () => client.createChatCompletionStream(any()),
        );
      },
    );

    test(
      'a non-OCR Mistral vision model still uses chat completions',
      () async {
        final fakeOcrRepo = _FakeMistralOcrRepository();
        generate = CloudInferenceGenerate(
          ollamaRepository: ollamaRepo,
          geminiRepository: geminiRepo,
          meliousRepository: meliousRepo,
          mistralRepository: mistralRepo,
          mistralOcrRepository: fakeOcrRepo,
          helpers: const CloudInferenceRequestHelpers(),
        );
        when(
          () => client.createChatCompletionStream(any()),
        ).thenAnswer((_) => Stream.fromIterable([chunk('pixtral vision')]));

        final chunks = await generate
            .generateWithImages(
              prompt,
              baseUrl: 'https://api.mistral.ai/v1',
              apiKey: apiKey,
              model: 'pixtral-large-latest',
              temperature: null,
              images: const ['photo'],
              provider: providerOfType(InferenceProviderType.mistral),
              overrideClient: client,
            )
            .toList();

        expect(chunks.single.choices?.single.delta?.content, 'pixtral vision');
        // The OCR repository is bypassed for non-OCR models.
        expect(fakeOcrRepo.calls, isEmpty);
      },
    );
  });
}
