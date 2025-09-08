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

class _InMemoryAiConfigRepo extends AiConfigRepository {
  _InMemoryAiConfigRepo(super.db);
}

class _MockCloudRepo extends Mock implements CloudInferenceRepository {}

void main() {
  late AiConfigDb sharedDb;

  setUpAll(() {
    // Create a single shared database instance for all tests
    // ignore: invalid_use_of_visible_for_testing_member
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
    final aiRepo = _InMemoryAiConfigRepo(sharedDb);
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
    final aiRepo = _InMemoryAiConfigRepo(sharedDb);
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
    final aiRepo = _InMemoryAiConfigRepo(sharedDb);
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
}
