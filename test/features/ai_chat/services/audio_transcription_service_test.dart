import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class _MockCloudRepo extends Mock implements CloudInferenceRepository {}

// Provider IDs used across batch guard tests
const _pMistral = 'p-mistral-guard';
const _pGemini = 'p-gemini-guard';

// ignore: unused_element
const _pOther = 'p-other-guard';

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
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      ) as AiConfigInferenceProvider,
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
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
    final mockCloud = _MockCloudRepo();
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
      ),
    ).thenAnswer(
      (_) => Stream<CreateChatCompletionStreamResponse>.fromIterable([
        const CreateChatCompletionStreamResponse(
          id: '1',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'foo'),
            ),
          ],
        ),
        const CreateChatCompletionStreamResponse(
          id: '2',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'bar'),
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

  test('fallbacks to first audio-capable model when flash not found', () async {
    final aiRepo = AiConfigRepository(sharedDb);
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_test_');
    final file = File('${dir.path}/b.m4a');
    await file.writeAsBytes([5, 6]);

    final mockCloud = _MockCloudRepo();
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
      ),
    ).thenAnswer(
      (_) => Stream.value(
        const CreateChatCompletionStreamResponse(
          id: '1',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'ok'),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_more_');
    final file = File('${dir.path}/c.m4a');
    await file.writeAsBytes([7, 8, 9]);

    final mockCloud = _MockCloudRepo();
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
      ),
    ).thenAnswer(
      (_) => Stream<CreateChatCompletionStreamResponse>.fromIterable([
        const CreateChatCompletionStreamResponse(
          id: '1',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: ''),
            ),
          ],
        ),
        const CreateChatCompletionStreamResponse(
          id: '2',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'ok'),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_stream_');
    final file = File('${dir.path}/d.m4a');
    await file.writeAsBytes([10, 11, 12]);

    final mockCloud = _MockCloudRepo();
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
      ),
    ).thenAnswer(
      (_) => Stream<CreateChatCompletionStreamResponse>.fromIterable([
        const CreateChatCompletionStreamResponse(
          id: '1',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'First '),
            ),
          ],
        ),
        const CreateChatCompletionStreamResponse(
          id: '2',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'Second '),
            ),
          ],
        ),
        const CreateChatCompletionStreamResponse(
          id: '3',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'Third'),
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
          createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final dir = await Directory.systemTemp.createTemp('guard_test_');
      final file = File('${dir.path}/test.m4a');
      await file.writeAsBytes([1, 2, 3]);

      final mockCloud = _MockCloudRepo();
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
        ),
      ).thenAnswer(
        (_) => Stream.value(
          const CreateChatCompletionStreamResponse(
            id: '1',
            object: 'chat.completion.chunk',
            created: 0,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'batch ok'),
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
        ),
      ).captured;
      expect(captured.first, 'gemini-2.5-flash');

      await dir.delete(recursive: true);
    });

    test('throws when only realtime models exist (all excluded)', () async {
      final aiRepo = AiConfigRepository(sharedDb);

      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: _pMistral,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'k',
          name: 'Mistral',
          createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final dir = await Directory.systemTemp.createTemp('guard_keep_');
      final file = File('${dir.path}/test.m4a');
      await file.writeAsBytes([1, 2, 3]);

      final mockCloud = _MockCloudRepo();
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
        ),
      ).thenAnswer(
        (_) => Stream.value(
          const CreateChatCompletionStreamResponse(
            id: '1',
            object: 'chat.completion.chunk',
            created: 0,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta:
                    ChatCompletionStreamResponseDelta(content: 'mistral batch'),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_null_');
    final file = File('${dir.path}/null_choices.m4a');
    await file.writeAsBytes([1, 2, 3]);

    final mockCloud = _MockCloudRepo();
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
      ),
    ).thenAnswer(
      (_) => Stream<CreateChatCompletionStreamResponse>.fromIterable([
        // Chunk with null choices
        const CreateChatCompletionStreamResponse(
          id: '1',
          object: 'chat.completion.chunk',
          created: 0,
        ),
        // Chunk with empty choices list
        const CreateChatCompletionStreamResponse(
          id: '2',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [],
        ),
        // Chunk with null delta content
        const CreateChatCompletionStreamResponse(
          id: '3',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(),
            ),
          ],
        ),
        // Normal chunk with content
        const CreateChatCompletionStreamResponse(
          id: '4',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'hello'),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final dir = await Directory.systemTemp.createTemp('svc_empty_');
    final file = File('${dir.path}/e.m4a');
    await file.writeAsBytes([13, 14, 15]);

    final mockCloud = _MockCloudRepo();
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
      ),
    ).thenAnswer(
      (_) => Stream<CreateChatCompletionStreamResponse>.fromIterable([
        const CreateChatCompletionStreamResponse(
          id: '1',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: ''),
            ),
          ],
        ),
        const CreateChatCompletionStreamResponse(
          id: '2',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: 'content'),
            ),
          ],
        ),
        const CreateChatCompletionStreamResponse(
          id: '3',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: ''),
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
}
