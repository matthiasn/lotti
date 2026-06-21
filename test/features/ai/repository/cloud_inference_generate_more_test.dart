import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_generate_more.dart';
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart'
    show GeneratedImage;
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart'
    show OllamaPullProgress;
import 'package:lotti/features/ai/repository/omlx_transcription_repository.dart';
import 'package:lotti/features/ai/repository/openai_transcription_repository.dart';
import 'package:lotti/features/ai/repository/voxtral_inference_repository.dart';
import 'package:lotti/features/ai/repository/whisper_inference_repository.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:lotti/utils/uuid.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://example.com'));
    registerFallbackValue(FakeBaseRequest());
    registerFallbackValue(FakeAiConfigInferenceProvider());
  });

  late MockHttpClient httpClient;
  late MockOllamaInferenceRepository ollamaRepo;
  late MockGeminiInferenceRepository geminiRepo;
  late MockDashScopeInferenceRepository dashScopeRepo;
  late MistralInferenceRepository mistralRepo;
  late MeliousInferenceRepository meliousRepo;
  late MistralTranscriptionRepository mistralTranscriptionRepo;
  late WhisperInferenceRepository whisperRepo;
  late OmlxTranscriptionRepository omlxTranscriptionRepo;
  late VoxtralInferenceRepository voxtralRepo;
  late OpenAiTranscriptionRepository openAiTranscriptionRepo;
  late ProviderContainer container;
  late CloudInferenceGenerateMore generateMore;

  const baseUrl = 'http://localhost:8084';
  const model = 'gpt-4';
  const prompt = 'transcribe this';

  AiConfigInferenceProvider providerOfType(InferenceProviderType type) {
    return AiConfig.inferenceProvider(
          id: 'provider-$type',
          name: 'Provider',
          baseUrl: baseUrl,
          apiKey: 'key',
          createdAt: DateTime(2024, 3, 15),
          inferenceProviderType: type,
        )
        as AiConfigInferenceProvider;
  }

  CloudInferenceGenerateMore createGenerateMore({
    MeliousInferenceRepository? meliousRepository,
    OmlxTranscriptionRepository? omlxRepository,
  }) {
    return CloudInferenceGenerateMore(
      ref: container.read(testRefProvider),
      ollamaRepository: ollamaRepo,
      geminiRepository: geminiRepo,
      dashScopeRepository: dashScopeRepo,
      mistralRepository: mistralRepo,
      meliousRepository: meliousRepository ?? meliousRepo,
      mistralTranscriptionRepository: mistralTranscriptionRepo,
      whisperRepository: whisperRepo,
      omlxTranscriptionRepository: omlxRepository ?? omlxTranscriptionRepo,
      voxtralRepository: voxtralRepo,
      openAiTranscriptionRepository: openAiTranscriptionRepo,
      helpers: const CloudInferenceRequestHelpers(),
    );
  }

  setUp(() {
    httpClient = MockHttpClient();
    ollamaRepo = MockOllamaInferenceRepository();
    geminiRepo = MockGeminiInferenceRepository();
    dashScopeRepo = MockDashScopeInferenceRepository();
    mistralRepo = MistralInferenceRepository(httpClient: httpClient);
    meliousRepo = MeliousInferenceRepository(httpClient: httpClient);
    mistralTranscriptionRepo = MistralTranscriptionRepository(
      httpClient: httpClient,
    );
    whisperRepo = WhisperInferenceRepository(httpClient: httpClient);
    omlxTranscriptionRepo = OmlxTranscriptionRepository(
      httpClient: httpClient,
    );
    voxtralRepo = VoxtralInferenceRepository(httpClient: httpClient);
    openAiTranscriptionRepo = OpenAiTranscriptionRepository(
      httpClient: httpClient,
    );
    container = ProviderContainer();
    generateMore = createGenerateMore();
  });

  tearDown(() {
    httpClient.close();
    container.dispose();
  });

  group('generateWithAudio routing', () {
    test(
      'routes Whisper provider through the transcription endpoint',
      () async {
        const audioBase64 = 'audio-base64';
        const transcript = 'the whisper transcript';
        final whisperProvider = providerOfType(InferenceProviderType.whisper);

        when(
          () => httpClient.post(
            Uri.parse('$baseUrl/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'model': model, 'audio': audioBase64}),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'text': transcript}), 200),
        );

        final response = await generateMore
            .generateWithAudio(
              prompt,
              model: model,
              audioBase64: audioBase64,
              baseUrl: whisperProvider.baseUrl,
              apiKey: whisperProvider.apiKey,
              provider: whisperProvider,
            )
            .first;

        expect(response.id, startsWith('whisper-'));
        expect(response.choices?.single.delta?.content, transcript);
        verify(
          () => httpClient.post(
            Uri.parse('$baseUrl/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'model': model, 'audio': audioBase64}),
          ),
        ).called(1);
      },
    );

    test(
      'routes oMLX Whisper through the OpenAI-compatible transcription endpoint',
      () async {
        const audioBase64 = 'audio-base64';
        const transcript = 'the oMLX whisper transcript';
        final omlxProvider = providerOfType(
          InferenceProviderType.omlx,
        ).copyWith(baseUrl: 'http://127.0.0.1:8003/v1');

        when(() => httpClient.send(any())).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'text': transcript}))),
            200,
          );
        });

        final response = await generateMore
            .generateWithAudio(
              prompt,
              model: omlxWhisperLargeV3ModelId,
              audioBase64: audioBase64,
              baseUrl: omlxProvider.baseUrl,
              apiKey: omlxProvider.apiKey,
              provider: omlxProvider,
            )
            .first;

        expect(response.id, startsWith('omlx-transcription-'));
        expect(response.choices?.single.delta?.content, transcript);

        final captured = verify(
          () => httpClient.send(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final request = captured.single as http.MultipartRequest;
        expect(
          request.url.toString(),
          equals('http://127.0.0.1:8003/v1/audio/transcriptions'),
        );
        expect(request.headers['Authorization'], equals('Bearer key'));
        expect(request.fields['model'], equals(omlxWhisperLargeV3ModelId));
      },
    );

    test('routes MLX Audio through the native channel', () async {
      final originalIsMacOS = platform.isMacOS;
      platform.isMacOS = true;
      addTearDown(() => platform.isMacOS = originalIsMacOS);

      const methodChannel = MethodChannel('com.matthiasn.lotti/mlx_audio');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () => messenger.setMockMethodCallHandler(methodChannel, null),
      );
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.method, 'transcribeBase64Audio');
        expect(call.arguments, containsPair('audioBase64', 'local-audio'));
        return <String, Object?>{'text': 'local transcript'};
      });

      final mlxProvider = providerOfType(InferenceProviderType.mlxAudio);
      final chunks = await generateMore
          .generateWithAudio(
            prompt,
            model: 'mlx-qwen',
            audioBase64: 'local-audio',
            baseUrl: '',
            apiKey: '',
            provider: mlxProvider,
          )
          .toList();

      expect(chunks, hasLength(1));
      const idPrefix = 'mlx-audio-';
      final id = chunks.single.id;
      expect(id, startsWith(idPrefix));
      expect(isUuid(id!.substring(idPrefix.length)), isTrue);
      expect(chunks.single.choices?.single.delta?.content, 'local transcript');
    });

    test(
      'routes Melious transcription models through Melious repository',
      () async {
        final meliousRepository = _FakeMeliousInferenceRepository();
        final meliousGenerateMore = createGenerateMore(
          meliousRepository: meliousRepository,
        );
        final meliousProvider = providerOfType(InferenceProviderType.melious);

        final chunks = await meliousGenerateMore
            .generateWithAudio(
              prompt,
              model: 'openai/whisper-large-v3',
              audioBase64: 'melious-audio',
              baseUrl: meliousProvider.baseUrl,
              apiKey: meliousProvider.apiKey,
              provider: meliousProvider,
            )
            .toList();

        expect(chunks.single.id, 'melious-transcription');
        expect(chunks.single.choices?.single.delta?.content, 'melious text');
        expect(meliousRepository.audioCalls, hasLength(1));
        expect(
          meliousRepository.audioCalls.single,
          (
            model: 'openai/whisper-large-v3',
            audioBase64: 'melious-audio',
            baseUrl: baseUrl,
            apiKey: 'key',
          ),
        );
      },
    );
  });

  group('generateWithMessages routing', () {
    test('routes Melious provider to the Melious repository', () async {
      final meliousRepository = _FakeMeliousInferenceRepository();
      final meliousGenerateMore = createGenerateMore(
        meliousRepository: meliousRepository,
      );
      final meliousProvider = providerOfType(InferenceProviderType.melious);
      const messages = [
        ChatCompletionMessage.system(content: 'answer tersely'),
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('hello'),
        ),
      ];

      final chunks = await meliousGenerateMore
          .generateWithMessages(
            messages: messages,
            model: 'minimax/m2.7',
            temperature: 0.2,
            provider: meliousProvider,
            maxCompletionTokens: 256,
          )
          .toList();

      expect(chunks.single.id, 'melious-messages');
      expect(chunks.single.choices?.single.delta?.content, 'melious messages');
      expect(meliousRepository.messageCalls, hasLength(1));
      final call = meliousRepository.messageCalls.single;
      expect(call.messages, same(messages));
      expect(call.model, 'minimax/m2.7');
      expect(call.baseUrl, baseUrl);
      expect(call.apiKey, 'key');
      expect(call.temperature, 0.2);
      expect(call.maxCompletionTokens, 256);
    });
  });

  group('generateImage routing', () {
    test('routes Alibaba provider to the DashScope repository', () async {
      final alibabaProvider = providerOfType(InferenceProviderType.alibaba);
      when(
        () => dashScopeRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          referenceImages: any(named: 'referenceImages'),
        ),
      ).thenAnswer(
        (_) async => const GeneratedImage(
          bytes: [1, 2, 3],
          mimeType: 'image/png',
        ),
      );

      final image = await generateMore.generateImage(
        prompt: 'a cat',
        model: 'wan2.6-image',
        provider: alibabaProvider,
      );

      expect(image.bytes, const [1, 2, 3]);
      expect(image.mimeType, 'image/png');
      verify(
        () => dashScopeRepo.generateImage(
          prompt: 'a cat',
          model: 'wan2.6-image',
          provider: alibabaProvider,
        ),
      ).called(1);
    });

    test('routes Melious provider to the Melious repository', () async {
      final meliousRepository = _FakeMeliousInferenceRepository();
      final meliousGenerateMore = createGenerateMore(
        meliousRepository: meliousRepository,
      );
      final meliousProvider = providerOfType(InferenceProviderType.melious);

      final image = await meliousGenerateMore.generateImage(
        prompt: 'a solar-powered tram',
        model: 'black-forest-labs/flux-2-klein',
        provider: meliousProvider,
      );

      expect(image.bytes, const [9, 8, 7]);
      expect(image.mimeType, 'image/png');
      expect(meliousRepository.imageCalls, hasLength(1));
      expect(
        meliousRepository.imageCalls.single,
        (
          prompt: 'a solar-powered tram',
          model: 'black-forest-labs/flux-2-klein',
          provider: meliousProvider,
        ),
      );
    });

    test('throws UnsupportedError for providers without image generation', () {
      expect(
        () => generateMore.generateImage(
          prompt: 'x',
          model: model,
          provider: providerOfType(InferenceProviderType.openAi),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('installModel', () {
    test('delegates to the Ollama repository', () {
      final progress = Stream.fromIterable([
        const OllamaPullProgress(status: 'pulling', progress: 0.5),
      ]);
      when(
        () => ollamaRepo.installModel('llama3', baseUrl),
      ).thenAnswer((_) => progress);

      final result = generateMore.installModel('llama3', baseUrl);

      expect(result, same(progress));
      verify(() => ollamaRepo.installModel('llama3', baseUrl)).called(1);
    });
  });
}

class _FakeMeliousInferenceRepository extends MeliousInferenceRepository {
  final audioCalls =
      <
        ({
          String model,
          String audioBase64,
          String baseUrl,
          String apiKey,
        })
      >[];
  final messageCalls =
      <
        ({
          List<ChatCompletionMessage> messages,
          String model,
          String baseUrl,
          String apiKey,
          double? temperature,
          int? maxCompletionTokens,
        })
      >[];
  final imageCalls =
      <
        ({
          String prompt,
          String model,
          AiConfigInferenceProvider provider,
        })
      >[];

  @override
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    String responseFormat = 'json',
    Duration? timeout,
  }) {
    audioCalls.add(
      (
        model: model,
        audioBase64: audioBase64,
        baseUrl: baseUrl,
        apiKey: apiKey,
      ),
    );
    return Stream.value(
      _chunk(id: 'melious-transcription', content: 'melious text'),
    );
  }

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) {
    messageCalls.add(
      (
        messages: messages,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
      ),
    );
    return Stream.value(
      _chunk(id: 'melious-messages', content: 'melious messages'),
    );
  }

  @override
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
    List<ProcessedReferenceImage>? referenceImages,
  }) async {
    imageCalls.add((prompt: prompt, model: model, provider: provider));
    return const GeneratedImage(bytes: [9, 8, 7], mimeType: 'image/png');
  }

  static CreateChatCompletionStreamResponse _chunk({
    required String id,
    required String content,
  }) {
    return CreateChatCompletionStreamResponse(
      id: id,
      choices: [
        ChatCompletionStreamResponseChoice(
          delta: ChatCompletionStreamResponseDelta(content: content),
          index: 0,
        ),
      ],
      object: 'chat.completion.chunk',
      created: 0,
    );
  }
}
