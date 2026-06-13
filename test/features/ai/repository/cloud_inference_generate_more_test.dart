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
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart'
    show OllamaPullProgress;
import 'package:lotti/features/ai/repository/openai_transcription_repository.dart';
import 'package:lotti/features/ai/repository/voxtral_inference_repository.dart';
import 'package:lotti/features/ai/repository/whisper_inference_repository.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:lotti/utils/uuid.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://example.com'));
    registerFallbackValue(FakeAiConfigInferenceProvider());
  });

  late MockHttpClient httpClient;
  late MockOllamaInferenceRepository ollamaRepo;
  late MockGeminiInferenceRepository geminiRepo;
  late MockDashScopeInferenceRepository dashScopeRepo;
  late MistralInferenceRepository mistralRepo;
  late MistralTranscriptionRepository mistralTranscriptionRepo;
  late WhisperInferenceRepository whisperRepo;
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

  setUp(() {
    httpClient = MockHttpClient();
    ollamaRepo = MockOllamaInferenceRepository();
    geminiRepo = MockGeminiInferenceRepository();
    dashScopeRepo = MockDashScopeInferenceRepository();
    mistralRepo = MistralInferenceRepository(httpClient: httpClient);
    mistralTranscriptionRepo = MistralTranscriptionRepository(
      httpClient: httpClient,
    );
    whisperRepo = WhisperInferenceRepository(httpClient: httpClient);
    voxtralRepo = VoxtralInferenceRepository(httpClient: httpClient);
    openAiTranscriptionRepo = OpenAiTranscriptionRepository(
      httpClient: httpClient,
    );
    container = ProviderContainer();
    final ref = container.read(testRefProvider);
    generateMore = CloudInferenceGenerateMore(
      ref: ref,
      ollamaRepository: ollamaRepo,
      geminiRepository: geminiRepo,
      dashScopeRepository: dashScopeRepo,
      mistralRepository: mistralRepo,
      mistralTranscriptionRepository: mistralTranscriptionRepo,
      whisperRepository: whisperRepo,
      voxtralRepository: voxtralRepo,
      openAiTranscriptionRepository: openAiTranscriptionRepo,
      helpers: const CloudInferenceRequestHelpers(),
    );
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
