import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _FakeMlxAudioChannel extends MlxAudioChannel {
  String? transcribedFilePath;
  String? transcribedModelId;
  List<String>? transcribedSpeechDictionaryTerms;

  @override
  Future<MlxAudioTranscriptionResult> transcribeFile({
    required String filePath,
    required String modelId,
    List<String> speechDictionaryTerms = const [],
    String? language,
    bool enableSpeakerDiarization = false,
  }) async {
    transcribedFilePath = filePath;
    transcribedModelId = modelId;
    transcribedSpeechDictionaryTerms = speechDictionaryTerms;
    return const MlxAudioTranscriptionResult(text: 'local qwen');
  }
}

// Provider IDs used across batch guard tests
const _pMistral = 'p-mistral-guard';
const _pGemini = 'p-gemini-guard';

void main() {
  late AiConfigDb sharedDb;

  setUpAll(() {
    // Create a single shared database instance for all tests
    sharedDb = AiConfigDb(inMemoryDatabase: true);

    registerFallbackValue(
      AiConfig.inferenceProvider(
            id: 'p-fallback',
            baseUrl: 'http://localhost',
            apiKey: 'k',
            name: 'fallback',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            inferenceProviderType: InferenceProviderType.gemini,
          )
          as AiConfigInferenceProvider,
    );
  });

  tearDownAll(() async {
    await sharedDb.close();
  });

  test('aggregates stream chunks into a single transcript', () async {
    // Arrange config
    final aiRepo = AiConfigRepository(sharedDb);
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.gemini,
      ),
      fromSync: true,
    );
    await aiRepo.saveConfig(
      AiConfig.model(
        id: 'm1',
        name: 'gemini-2.5-flash',
        providerModelId: 'gemini-2.5-flash',
        inferenceProviderId: 'p1',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    // Create a temp audio file
    final dir = await Directory.systemTemp.createTemp('svc_test_');
    final file = File('${dir.path}/a.m4a');
    await file.writeAsBytes([1, 2, 3, 4]);

    // Mock cloud stream returning two chunks
    final mockCloud = MockCloudInferenceRepository();
    when(
      () => mockCloud.generateWithAudio(
        any(),
        model: any(named: 'model'),
        audioBase64: any(named: 'audioBase64'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        provider: any(named: 'provider'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        overrideClient: any(named: 'overrideClient'),
        tools: any(named: 'tools'),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer(
      (_) => Stream<AiStreamChunk>.fromIterable([
        const AiStreamChunk(
          id: '1',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'foo'),
            ),
          ],
        ),
        const AiStreamChunk(
          id: '2',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'bar'),
            ),
          ],
        ),
      ]),
    );

    // Build service with overrides
    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
        cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
      ],
    );
    addTearDown(container.dispose);

    final svc = container.read(audioTranscriptionServiceProvider);

    // Act
    final result = await svc.transcribe(file.path);

    // Assert
    expect(result, 'foobar');
    await dir.delete(recursive: true);
  });

  test(
    'forwards the model row thinking mode for Gemini 3 audio models',
    () async {
      // Isolated DB: the shared instance already carries a
      // 'gemini-2.5-flash' row from earlier tests, which would win the
      // batch-model selection over the Gemini 3 row under test.
      final isolatedDb = AiConfigDb(inMemoryDatabase: true);
      addTearDown(isolatedDb.close);
      final aiRepo = AiConfigRepository(isolatedDb);
      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: 'p-g3',
          baseUrl: 'http://localhost:1234',
          apiKey: 'k',
          name: 'Gemini',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-g3',
          name: 'gemini-3-flash',
          providerModelId: 'gemini-3-flash-preview',
          inferenceProviderId: 'p-g3',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: true,
          geminiThinkingMode: GeminiThinkingMode.medium,
        ),
        fromSync: true,
      );

      final dir = await Directory.systemTemp.createTemp('svc_test_');
      final file = File('${dir.path}/a.m4a');
      await file.writeAsBytes([1, 2, 3, 4]);

      final mockCloud = MockCloudInferenceRepository();
      when(
        () => mockCloud.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          overrideClient: any(named: 'overrideClient'),
          tools: any(named: 'tools'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
        ),
      ).thenAnswer(
        (_) => Stream<AiStreamChunk>.fromIterable([
          const AiStreamChunk(
            id: '1',
            created: 0,
            choices: [
              AiStreamChoice(
                index: 0,
                delta: AiStreamDelta(content: 'hi'),
              ),
            ],
          ),
        ]),
      );

      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
          cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(audioTranscriptionServiceProvider);
      final result = await svc.transcribe(file.path);

      expect(result, 'hi');
      // The Gemini 3 row's saved thinking mode reaches the cloud call.
      verify(
        () => mockCloud.generateWithAudio(
          any(),
          model: 'gemini-3-flash-preview',
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          geminiThinkingMode: GeminiThinkingMode.medium,
        ),
      ).called(1);
      await dir.delete(recursive: true);
    },
  );

  test('fallbacks to first audio-capable model when flash not found', () async {
    final aiRepo = AiConfigRepository(sharedDb);
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.gemini,
      ),
      fromSync: true,
    );
    await aiRepo.saveConfig(
      AiConfig.model(
        id: 'm2',
        name: 'gemini-other',
        providerModelId: 'gemini-audio',
        inferenceProviderId: 'p1',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_test_');
    final file = File('${dir.path}/b.m4a');
    await file.writeAsBytes([5, 6]);

    final mockCloud = MockCloudInferenceRepository();
    when(
      () => mockCloud.generateWithAudio(
        any(),
        model: any(named: 'model'),
        audioBase64: any(named: 'audioBase64'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        provider: any(named: 'provider'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        overrideClient: any(named: 'overrideClient'),
        tools: any(named: 'tools'),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer(
      (_) => Stream.value(
        const AiStreamChunk(
          id: '1',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'ok'),
            ),
          ],
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
        cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
      ],
    );
    addTearDown(container.dispose);

    final svc = container.read(audioTranscriptionServiceProvider);
    final result = await svc.transcribe(file.path);
    expect(result, 'ok');
    await dir.delete(recursive: true);
  });

  test('throws when no audio-capable model is configured', () async {
    final aiRepo = AiConfigRepository(sharedDb);
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.gemini,
      ),
      fromSync: true,
    );

    final container = ProviderContainer(
      overrides: [aiConfigRepositoryProvider.overrideWith((_) => aiRepo)],
    );

    final svc = container.read(audioTranscriptionServiceProvider);
    expect(
      () => svc.transcribe('/tmp/does-not-matter.m4a'),
      throwsA(isA<Exception>()),
    );
  });

  test('throws when provider for selected audio model is missing', () async {
    final aiRepo = AiConfigRepository(sharedDb);
    // Only a model without its provider
    await aiRepo.saveConfig(
      AiConfig.model(
        id: 'm1',
        name: 'gemini-2.5-flash',
        providerModelId: 'gemini-2.5-flash',
        inferenceProviderId: 'prov-missing',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final container = ProviderContainer(
      overrides: [aiConfigRepositoryProvider.overrideWith((_) => aiRepo)],
    );
    addTearDown(container.dispose);

    final svc = container.read(audioTranscriptionServiceProvider);
    await expectLater(
      () => svc.transcribe('/tmp/file.m4a'),
      throwsA(predicate((e) => e.toString().contains('Provider not found'))),
    );
  });

  test('ignores empty content chunks from cloud stream', () async {
    final aiRepo = AiConfigRepository(sharedDb);
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.gemini,
      ),
      fromSync: true,
    );
    await aiRepo.saveConfig(
      AiConfig.model(
        id: 'm1',
        name: 'gemini-2.5-flash',
        providerModelId: 'gemini-2.5-flash',
        inferenceProviderId: 'p1',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_more_');
    final file = File('${dir.path}/c.m4a');
    await file.writeAsBytes([7, 8, 9]);

    final mockCloud = MockCloudInferenceRepository();
    when(
      () => mockCloud.generateWithAudio(
        any(),
        model: any(named: 'model'),
        audioBase64: any(named: 'audioBase64'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        provider: any(named: 'provider'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        overrideClient: any(named: 'overrideClient'),
        tools: any(named: 'tools'),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer(
      (_) => Stream<AiStreamChunk>.fromIterable([
        const AiStreamChunk(
          id: '1',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: ''),
            ),
          ],
        ),
        const AiStreamChunk(
          id: '2',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'ok'),
            ),
          ],
        ),
      ]),
    );

    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
        cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
      ],
    );
    addTearDown(container.dispose);

    final svc = container.read(audioTranscriptionServiceProvider);
    final result = await svc.transcribe(file.path);
    expect(result, 'ok');
    await dir.delete(recursive: true);
  });

  test('transcribeStream yields chunks progressively', () async {
    final aiRepo = AiConfigRepository(sharedDb);
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.gemini,
      ),
      fromSync: true,
    );
    await aiRepo.saveConfig(
      AiConfig.model(
        id: 'm1',
        name: 'gemini-2.5-flash',
        providerModelId: 'gemini-2.5-flash',
        inferenceProviderId: 'p1',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_stream_');
    final file = File('${dir.path}/d.m4a');
    await file.writeAsBytes([10, 11, 12]);

    final mockCloud = MockCloudInferenceRepository();
    when(
      () => mockCloud.generateWithAudio(
        any(),
        model: any(named: 'model'),
        audioBase64: any(named: 'audioBase64'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        provider: any(named: 'provider'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        overrideClient: any(named: 'overrideClient'),
        tools: any(named: 'tools'),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer(
      (_) => Stream<AiStreamChunk>.fromIterable([
        const AiStreamChunk(
          id: '1',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'First '),
            ),
          ],
        ),
        const AiStreamChunk(
          id: '2',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'Second '),
            ),
          ],
        ),
        const AiStreamChunk(
          id: '3',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'Third'),
            ),
          ],
        ),
      ]),
    );

    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
        cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
      ],
    );
    addTearDown(container.dispose);

    final svc = container.read(audioTranscriptionServiceProvider);

    // Collect chunks as they're yielded
    final chunks = <String>[];
    await svc.transcribeStream(file.path).forEach(chunks.add);

    // Verify chunks were yielded progressively (not all at once)
    expect(chunks, hasLength(3));
    expect(chunks[0], 'First ');
    expect(chunks[1], 'Second ');
    expect(chunks[2], 'Third');

    // Verify concatenation matches full transcription
    expect(chunks.join(), 'First Second Third');

    await dir.delete(recursive: true);
  });

  group('batch guard: excludes realtime models', () {
    test('excludes Mistral realtime model from batch selection', () async {
      final aiRepo = AiConfigRepository(sharedDb);

      // Mistral provider
      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: _pMistral,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'k',
          name: 'Mistral',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.mistral,
        ),
        fromSync: true,
      );
      // Gemini provider
      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: _pGemini,
          baseUrl: 'https://api.gemini.test',
          apiKey: 'k',
          name: 'Gemini',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
        fromSync: true,
      );

      // Realtime-only model (should be excluded)
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-realtime',
          name: 'Voxtral Realtime',
          providerModelId: 'voxtral-mini-transcribe-realtime-2602',
          inferenceProviderId: _pMistral,
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );
      // Gemini batch model (should be included)
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-batch',
          name: 'gemini-2.5-flash',
          providerModelId: 'gemini-2.5-flash',
          inferenceProviderId: _pGemini,
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final dir = await Directory.systemTemp.createTemp('guard_test_');
      final file = File('${dir.path}/test.m4a');
      await file.writeAsBytes([1, 2, 3]);

      final mockCloud = MockCloudInferenceRepository();
      when(
        () => mockCloud.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          overrideClient: any(named: 'overrideClient'),
          tools: any(named: 'tools'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer(
        (_) => Stream.value(
          const AiStreamChunk(
            id: '1',
            created: 0,
            choices: [
              AiStreamChoice(
                index: 0,
                delta: AiStreamDelta(content: 'batch ok'),
              ),
            ],
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
          cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(audioTranscriptionServiceProvider);
      final result = await svc.transcribe(file.path);

      // Should use the Gemini batch model, not the realtime one
      expect(result, 'batch ok');

      // Verify the model used was gemini, not voxtral
      final captured = verify(
        () => mockCloud.generateWithAudio(
          any(),
          model: captureAny(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          overrideClient: any(named: 'overrideClient'),
          tools: any(named: 'tools'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).captured;
      expect(captured.first, 'gemini-2.5-flash');

      await dir.delete(recursive: true);
    });

    test('throws when only realtime models exist (all excluded)', () async {
      // Use a fresh DB to avoid interference from configs saved by other tests.
      final freshDb = AiConfigDb(inMemoryDatabase: true);
      addTearDown(freshDb.close);
      final aiRepo = AiConfigRepository(freshDb);

      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: _pMistral,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'k',
          name: 'Mistral',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.mistral,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-rt-only',
          name: 'Voxtral Realtime',
          providerModelId: 'voxtral-mini-transcribe-realtime-2602',
          inferenceProviderId: _pMistral,
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(audioTranscriptionServiceProvider);
      expect(
        () => svc.transcribe('/tmp/test.m4a'),
        throwsA(isA<Exception>()),
      );
    });

    test('keeps non-realtime Mistral models for batch', () async {
      final aiRepo = AiConfigRepository(sharedDb);

      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: _pMistral,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'k',
          name: 'Mistral',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.mistral,
        ),
        fromSync: true,
      );
      // Batch Mistral model (not realtime) — should be kept
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-mistral-batch',
          name: 'Mistral Batch Audio',
          providerModelId: 'mistral-large-audio',
          inferenceProviderId: _pMistral,
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final dir = await Directory.systemTemp.createTemp('guard_keep_');
      final file = File('${dir.path}/test.m4a');
      await file.writeAsBytes([1, 2, 3]);

      final mockCloud = MockCloudInferenceRepository();
      when(
        () => mockCloud.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          overrideClient: any(named: 'overrideClient'),
          tools: any(named: 'tools'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer(
        (_) => Stream.value(
          const AiStreamChunk(
            id: '1',
            created: 0,
            choices: [
              AiStreamChoice(
                index: 0,
                delta: AiStreamDelta(
                  content: 'mistral batch',
                ),
              ),
            ],
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
          cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(audioTranscriptionServiceProvider);
      final result = await svc.transcribe(file.path);
      expect(result, 'mistral batch');

      await dir.delete(recursive: true);
    });
  });

  test('transcribeStream handles null choices in response chunk', () async {
    final aiRepo = AiConfigRepository(sharedDb);
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.gemini,
      ),
      fromSync: true,
    );
    await aiRepo.saveConfig(
      AiConfig.model(
        id: 'm1',
        name: 'gemini-2.5-flash',
        providerModelId: 'gemini-2.5-flash',
        inferenceProviderId: 'p1',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_null_');
    final file = File('${dir.path}/null_choices.m4a');
    await file.writeAsBytes([1, 2, 3]);

    final mockCloud = MockCloudInferenceRepository();
    when(
      () => mockCloud.generateWithAudio(
        any(),
        model: any(named: 'model'),
        audioBase64: any(named: 'audioBase64'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        provider: any(named: 'provider'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        overrideClient: any(named: 'overrideClient'),
        tools: any(named: 'tools'),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer(
      (_) => Stream<AiStreamChunk>.fromIterable([
        // Chunk with empty choices list (handled gracefully)
        const AiStreamChunk(
          id: '1',
          created: 0,
          choices: [],
        ),
        // Chunk with empty choices list
        const AiStreamChunk(
          id: '2',
          created: 0,
          choices: [],
        ),
        // Chunk with null delta content
        const AiStreamChunk(
          id: '3',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(),
            ),
          ],
        ),
        // Normal chunk with content
        const AiStreamChunk(
          id: '4',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'hello'),
            ),
          ],
        ),
      ]),
    );

    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
        cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
      ],
    );
    addTearDown(container.dispose);

    final svc = container.read(audioTranscriptionServiceProvider);
    final chunks = <String>[];
    await svc.transcribeStream(file.path).forEach(chunks.add);

    // Only the valid chunk should be yielded
    expect(chunks, hasLength(1));
    expect(chunks[0], 'hello');

    await dir.delete(recursive: true);
  });

  test('transcribeStream skips empty chunks', () async {
    final aiRepo = AiConfigRepository(sharedDb);
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.gemini,
      ),
      fromSync: true,
    );
    await aiRepo.saveConfig(
      AiConfig.model(
        id: 'm1',
        name: 'gemini-2.5-flash',
        providerModelId: 'gemini-2.5-flash',
        inferenceProviderId: 'p1',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_empty_');
    final file = File('${dir.path}/e.m4a');
    await file.writeAsBytes([13, 14, 15]);

    final mockCloud = MockCloudInferenceRepository();
    when(
      () => mockCloud.generateWithAudio(
        any(),
        model: any(named: 'model'),
        audioBase64: any(named: 'audioBase64'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        provider: any(named: 'provider'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        overrideClient: any(named: 'overrideClient'),
        tools: any(named: 'tools'),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer(
      (_) => Stream<AiStreamChunk>.fromIterable([
        const AiStreamChunk(
          id: '1',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: ''),
            ),
          ],
        ),
        const AiStreamChunk(
          id: '2',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: 'content'),
            ),
          ],
        ),
        const AiStreamChunk(
          id: '3',
          created: 0,
          choices: [
            AiStreamChoice(
              index: 0,
              delta: AiStreamDelta(content: ''),
            ),
          ],
        ),
      ]),
    );

    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
        cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
      ],
    );
    addTearDown(container.dispose);

    final svc = container.read(audioTranscriptionServiceProvider);

    final chunks = <String>[];
    await svc.transcribeStream(file.path).forEach(chunks.add);

    // Should only yield non-empty chunks
    expect(chunks, hasLength(1));
    expect(chunks[0], 'content');

    await dir.delete(recursive: true);
  });

  group('offline bias-capable model selection', () {
    test('prefers Mistral offline over MLX Qwen when both exist', () async {
      final freshDb = AiConfigDb(inMemoryDatabase: true);
      addTearDown(freshDb.close);
      final aiRepo = AiConfigRepository(freshDb);

      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: 'p-mistral-default-choice',
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'mistral-key',
          name: 'Mistral',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.mistral,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-mistral-default-choice',
          name: 'Voxtral Mini Transcribe',
          providerModelId: 'voxtral-mini-latest',
          inferenceProviderId: 'p-mistral-default-choice',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: 'p-mlx-default-choice',
          baseUrl: '',
          apiKey: '',
          name: 'MLX Audio',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.mlxAudio,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-mlx-default-choice',
          name: 'Qwen3 ASR',
          providerModelId: mlxAudioQwenAsrModelId,
          inferenceProviderId: 'p-mlx-default-choice',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final dir = await Directory.systemTemp.createTemp(
        'svc_mistral_default_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/mistral-default.m4a');
      await file.writeAsBytes([1, 2, 3]);
      final mlxAudioChannel = _FakeMlxAudioChannel();

      final mockCloud = MockCloudInferenceRepository();
      when(
        () => mockCloud.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          overrideClient: any(named: 'overrideClient'),
          tools: any(named: 'tools'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer(
        (_) => Stream.value(
          const AiStreamChunk(
            id: '1',
            created: 0,
            choices: [
              AiStreamChoice(
                index: 0,
                delta: AiStreamDelta(
                  content: 'mistral default',
                ),
              ),
            ],
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
          cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
          mlxAudioChannelProvider.overrideWithValue(mlxAudioChannel),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(audioTranscriptionServiceProvider);
      final result = await svc.transcribe(file.path);

      expect(result, 'mistral default');
      expect(mlxAudioChannel.transcribedFilePath, isNull);
      final captured = verify(
        () => mockCloud.generateWithAudio(
          any(),
          model: captureAny(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          overrideClient: any(named: 'overrideClient'),
          tools: any(named: 'tools'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).captured;
      expect(captured.single, 'voxtral-mini-latest');
    });

    test('prefers MLX Qwen and forwards speech dictionary terms', () async {
      final freshDb = AiConfigDb(inMemoryDatabase: true);
      addTearDown(freshDb.close);
      final aiRepo = AiConfigRepository(freshDb);

      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: 'p-gemini-qwen-choice',
          baseUrl: 'https://api.gemini.test',
          apiKey: 'k',
          name: 'Gemini',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-gemini-qwen-choice',
          name: 'gemini-2.5-flash',
          providerModelId: 'gemini-2.5-flash',
          inferenceProviderId: 'p-gemini-qwen-choice',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: 'p-mlx-qwen-choice',
          baseUrl: '',
          apiKey: '',
          name: 'MLX Audio',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.mlxAudio,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'm-mlx-qwen-choice',
          name: 'Qwen3 ASR',
          providerModelId: mlxAudioQwenAsrModelId,
          inferenceProviderId: 'p-mlx-qwen-choice',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final dir = await Directory.systemTemp.createTemp('svc_qwen_bias_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/qwen.m4a');
      await file.writeAsBytes([1, 2, 3]);
      final mlxAudioChannel = _FakeMlxAudioChannel();

      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
          mlxAudioChannelProvider.overrideWithValue(mlxAudioChannel),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(audioTranscriptionServiceProvider);
      final result = await svc.transcribe(
        file.path,
        speechDictionaryTerms: const ['Claude Code', 'macOS'],
      );

      expect(result, 'local qwen');
      expect(mlxAudioChannel.transcribedFilePath, file.path);
      expect(mlxAudioChannel.transcribedModelId, mlxAudioQwenAsrModelId);
      expect(
        mlxAudioChannel.transcribedSpeechDictionaryTerms,
        ['Claude Code', 'macOS'],
      );
    });

    test(
      'uses configured MLX Qwen 1.7B with speech dictionary terms',
      () async {
        final freshDb = AiConfigDb(inMemoryDatabase: true);
        addTearDown(freshDb.close);
        final aiRepo = AiConfigRepository(freshDb);

        await aiRepo.saveConfig(
          AiConfig.inferenceProvider(
            id: 'p-mlx-qwen17-choice',
            baseUrl: '',
            apiKey: '',
            name: 'MLX Audio',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            inferenceProviderType: InferenceProviderType.mlxAudio,
          ),
          fromSync: true,
        );
        await aiRepo.saveConfig(
          AiConfig.model(
            id: 'm-mlx-qwen17-choice',
            name: 'Qwen3 ASR 1.7B',
            providerModelId: mlxAudioQwenAsr17B8BitModelId,
            inferenceProviderId: 'p-mlx-qwen17-choice',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            inputModalities: const [Modality.audio],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
          ),
          fromSync: true,
        );

        final dir = await Directory.systemTemp.createTemp('svc_qwen17_bias_');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/qwen17.m4a');
        await file.writeAsBytes([1, 2, 3]);
        final mlxAudioChannel = _FakeMlxAudioChannel();

        final container = ProviderContainer(
          overrides: [
            aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
            mlxAudioChannelProvider.overrideWithValue(mlxAudioChannel),
          ],
        );
        addTearDown(container.dispose);

        final svc = container.read(audioTranscriptionServiceProvider);
        final result = await svc.transcribe(
          file.path,
          speechDictionaryTerms: const ['Brunsberg', 'Seembinderstrasse'],
        );

        expect(result, 'local qwen');
        expect(mlxAudioChannel.transcribedFilePath, file.path);
        expect(
          mlxAudioChannel.transcribedModelId,
          mlxAudioQwenAsr17B8BitModelId,
        );
        expect(
          mlxAudioChannel.transcribedSpeechDictionaryTerms,
          ['Brunsberg', 'Seembinderstrasse'],
        );
      },
    );

    test(
      'uses Mistral offline context bias when Qwen is unavailable',
      () async {
        final freshDb = AiConfigDb(inMemoryDatabase: true);
        addTearDown(freshDb.close);
        final aiRepo = AiConfigRepository(freshDb);

        await aiRepo.saveConfig(
          AiConfig.inferenceProvider(
            id: 'p-gemini-mistral-choice',
            baseUrl: 'https://api.gemini.test',
            apiKey: 'k',
            name: 'Gemini',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            inferenceProviderType: InferenceProviderType.gemini,
          ),
          fromSync: true,
        );
        await aiRepo.saveConfig(
          AiConfig.model(
            id: 'm-gemini-mistral-choice',
            name: 'gemini-2.5-flash',
            providerModelId: 'gemini-2.5-flash',
            inferenceProviderId: 'p-gemini-mistral-choice',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            inputModalities: const [Modality.audio],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
          ),
          fromSync: true,
        );
        await aiRepo.saveConfig(
          AiConfig.inferenceProvider(
            id: 'p-mistral-offline-choice',
            baseUrl: 'https://api.mistral.ai/v1',
            apiKey: 'mistral-key',
            name: 'Mistral',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            inferenceProviderType: InferenceProviderType.mistral,
          ),
          fromSync: true,
        );
        await aiRepo.saveConfig(
          AiConfig.model(
            id: 'm-mistral-offline-choice',
            name: 'Voxtral Mini Transcribe',
            providerModelId: 'voxtral-mini-latest',
            inferenceProviderId: 'p-mistral-offline-choice',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            inputModalities: const [Modality.audio],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
          ),
          fromSync: true,
        );

        final dir = await Directory.systemTemp.createTemp('svc_mistral_bias_');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/mistral.m4a');
        await file.writeAsBytes([1, 2, 3]);

        final mockCloud = MockCloudInferenceRepository();
        when(
          () => mockCloud.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            overrideClient: any(named: 'overrideClient'),
            tools: any(named: 'tools'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            const AiStreamChunk(
              id: '1',
              created: 0,
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    content: 'mistral biased',
                  ),
                ),
              ],
            ),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
            cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
          ],
        );
        addTearDown(container.dispose);

        final svc = container.read(audioTranscriptionServiceProvider);
        final result = await svc.transcribe(
          file.path,
          speechDictionaryTerms: const ['Claude Code', 'macOS'],
        );

        expect(result, 'mistral biased');
        final captured = verify(
          () => mockCloud.generateWithAudio(
            any(),
            model: captureAny(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            overrideClient: any(named: 'overrideClient'),
            tools: any(named: 'tools'),
            speechDictionaryTerms: captureAny(named: 'speechDictionaryTerms'),
          ),
        ).captured;
        expect(captured[0], 'voxtral-mini-latest');
        expect(captured[1], ['Claude Code', 'macOS']);
      },
    );
  });
}
