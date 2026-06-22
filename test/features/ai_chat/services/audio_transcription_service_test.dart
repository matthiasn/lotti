import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

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

final _createdAt = DateTime(2024, 3, 15, 10, 30);

AiConfig _provider({
  required String id,
  InferenceProviderType type = InferenceProviderType.gemini,
  String name = 'Gemini',
  String baseUrl = 'http://localhost:1234',
  String apiKey = 'k',
}) {
  return AiConfig.inferenceProvider(
    id: id,
    baseUrl: baseUrl,
    apiKey: apiKey,
    name: name,
    createdAt: _createdAt,
    inferenceProviderType: type,
  );
}

AiConfig _audioModel({
  required String id,
  required String providerId,
  String name = 'gemini-2.5-flash',
  String providerModelId = 'gemini-2.5-flash',
  bool isReasoningModel = false,
  GeminiThinkingMode? geminiThinkingMode,
}) {
  return AiConfig.model(
    id: id,
    name: name,
    providerModelId: providerModelId,
    inferenceProviderId: providerId,
    createdAt: _createdAt,
    inputModalities: const [Modality.audio],
    outputModalities: const [Modality.text],
    isReasoningModel: isReasoningModel,
    geminiThinkingMode: geminiThinkingMode ?? GeminiThinkingMode.low,
  );
}

// ---------------------------------------------------------------------------
// Batch model-selection property test scaffolding
// ---------------------------------------------------------------------------

/// The distinct audio-model categories the batch selector ranks. Each maps to
/// a provider type + a `providerModelId` shape that the predicates in
/// `debugSelectBatchAudioModel` discriminate on.
enum _ModelKind {
  /// Mistral provider + a `voxtral-` model → Mistral offline transcription
  /// (highest priority).
  mistralVoxtral,

  /// Mistral provider + a non-voxtral model → generic Mistral batch.
  mistralOther,

  /// Melious provider + a Whisper-class model → Melious transcription.
  meliousWhisper,

  /// MLX Audio provider + a Qwen3-ASR model id.
  mlxQwen,

  /// Gemini provider + the default flash model id.
  geminiFlash,

  /// Gemini provider + an unrelated model id (only ever the last-resort pick).
  geminiOther,
}

InferenceProviderType _providerTypeFor(_ModelKind kind) => switch (kind) {
  _ModelKind.mistralVoxtral ||
  _ModelKind.mistralOther => InferenceProviderType.mistral,
  _ModelKind.meliousWhisper => InferenceProviderType.melious,
  _ModelKind.mlxQwen => InferenceProviderType.mlxAudio,
  _ModelKind.geminiFlash ||
  _ModelKind.geminiOther => InferenceProviderType.gemini,
};

String _providerModelIdFor(_ModelKind kind, int index) => switch (kind) {
  _ModelKind.mistralVoxtral => 'voxtral-mini-latest-$index',
  _ModelKind.mistralOther => 'mistral-large-audio-$index',
  _ModelKind.meliousWhisper => 'openai/whisper-large-v3',
  _ModelKind.mlxQwen => mlxAudioQwenAsrModelId,
  _ModelKind.geminiFlash => 'gemini-2.5-flash',
  _ModelKind.geminiOther => 'gemini-pro-audio-$index',
};

/// Builds the `(models, providers)` inputs for `debugSelectBatchAudioModel`
/// from a list of kinds, one provider per element so each model resolves.
({List<AiConfigModel> models, List<AiConfigInferenceProvider> providers})
_buildSelectionInputs(List<_ModelKind> kinds) {
  final models = <AiConfigModel>[];
  final providers = <AiConfigInferenceProvider>[];
  for (var i = 0; i < kinds.length; i++) {
    final kind = kinds[i];
    final providerId = 'p$i';
    providers.add(
      _provider(id: providerId, type: _providerTypeFor(kind))
          as AiConfigInferenceProvider,
    );
    models.add(
      _audioModel(
            id: 'm$i',
            providerId: providerId,
            providerModelId: _providerModelIdFor(kind, i),
          )
          as AiConfigModel,
    );
  }
  return (models: models, providers: providers);
}

CreateChatCompletionStreamResponse _contentChunk(String content) {
  return CreateChatCompletionStreamResponse(
    id: '0',
    object: 'chat.completion.chunk',
    created: 0,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(content: content),
      ),
    ],
  );
}

/// Stubs `generateWithAudio` with a freshly built stream per invocation.
void _stubGenerateWithAudioStream(
  MockCloudInferenceRepository mock,
  Stream<CreateChatCompletionStreamResponse> Function() stream,
) {
  when(
    () => mock.generateWithAudio(
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
  ).thenAnswer((_) => stream());
}

/// Stubs `generateWithAudio` to emit one content chunk per string.
void _stubGenerateWithAudio(
  MockCloudInferenceRepository mock,
  List<String> contents,
) {
  _stubGenerateWithAudioStream(
    mock,
    () => Stream.fromIterable(contents.map(_contentChunk)),
  );
}

/// Verifies a single `generateWithAudio` call and returns the captured
/// `model` and `speechDictionaryTerms` arguments.
({Object? model, Object? speechDictionaryTerms}) _verifyGenerateWithAudio(
  MockCloudInferenceRepository mock,
) {
  final captured = verify(
    () => mock.generateWithAudio(
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
      geminiThinkingMode: any(named: 'geminiThinkingMode'),
    ),
  ).captured;
  return (model: captured[0], speechDictionaryTerms: captured[1]);
}

void main() {
  late AiConfigDb sharedDb;
  late AiConfigRepository sharedRepo;
  late Directory sharedTempDir;
  var audioFileIndex = 0;

  /// Writes a small audio fixture into the shared temp dir.
  Future<File> audioFile() async {
    final file = File('${sharedTempDir.path}/audio_${audioFileIndex++}.m4a');
    await file.writeAsBytes([1, 2, 3, 4]);
    return file;
  }

  /// A fresh in-memory config repository for tests whose model selection
  /// depends on the *absence* of other rows (the shared DB accumulates).
  AiConfigRepository isolatedRepo() {
    final db = AiConfigDb(inMemoryDatabase: true);
    addTearDown(db.close);
    return AiConfigRepository(db);
  }

  /// Builds the service with the standard repo/cloud/MLX overrides.
  AudioTranscriptionService buildService({
    required AiConfigRepository repo,
    MockCloudInferenceRepository? cloud,
    MlxAudioChannel? mlxChannel,
  }) {
    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWith((_) => repo),
        if (cloud != null)
          cloudInferenceRepositoryProvider.overrideWith((_) => cloud),
        if (mlxChannel != null)
          mlxAudioChannelProvider.overrideWithValue(mlxChannel),
      ],
    );
    addTearDown(container.dispose);
    return container.read(audioTranscriptionServiceProvider);
  }

  setUpAll(() async {
    // One shared in-memory DB pre-populated with the standard Gemini
    // provider + flash model pair, and one shared temp dir for fixtures.
    sharedDb = AiConfigDb(inMemoryDatabase: true);
    sharedRepo = AiConfigRepository(sharedDb);
    await sharedRepo.saveConfig(_provider(id: 'p1'), fromSync: true);
    await sharedRepo.saveConfig(
      _audioModel(id: 'm1', providerId: 'p1'),
      fromSync: true,
    );
    sharedTempDir = await Directory.systemTemp.createTemp('svc_test_');

    registerFallbackValue(
      _provider(id: 'p-fallback', baseUrl: 'http://localhost')
          as AiConfigInferenceProvider,
    );
  });

  tearDownAll(() async {
    await sharedDb.close();
    await sharedTempDir.delete(recursive: true);
  });

  test('aggregates stream chunks into a single transcript', () async {
    final file = await audioFile();
    final mockCloud = MockCloudInferenceRepository();
    _stubGenerateWithAudio(mockCloud, ['foo', 'bar']);

    final svc = buildService(repo: sharedRepo, cloud: mockCloud);

    expect(await svc.transcribe(file.path), 'foobar');
  });

  test(
    'forwards the model row thinking mode for Gemini 3 audio models',
    () async {
      // Isolated DB: the shared instance carries a 'gemini-2.5-flash' row,
      // which would win the batch-model selection over the Gemini 3 row
      // under test.
      final aiRepo = isolatedRepo();
      await aiRepo.saveConfig(_provider(id: 'p-g3'), fromSync: true);
      await aiRepo.saveConfig(
        _audioModel(
          id: 'm-g3',
          providerId: 'p-g3',
          name: 'gemini-3-flash',
          providerModelId: 'gemini-3-flash-preview',
          isReasoningModel: true,
          geminiThinkingMode: GeminiThinkingMode.medium,
        ),
        fromSync: true,
      );

      final file = await audioFile();
      final mockCloud = MockCloudInferenceRepository();
      _stubGenerateWithAudio(mockCloud, ['hi']);

      final svc = buildService(repo: aiRepo, cloud: mockCloud);
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
    },
  );

  test('fallbacks to first audio-capable model when flash not found', () async {
    // Isolated DB: the fallback only triggers when no flash row exists.
    final aiRepo = isolatedRepo();
    await aiRepo.saveConfig(_provider(id: 'p1'), fromSync: true);
    await aiRepo.saveConfig(
      _audioModel(
        id: 'm2',
        providerId: 'p1',
        name: 'gemini-other',
        providerModelId: 'gemini-audio',
      ),
      fromSync: true,
    );

    final file = await audioFile();
    final mockCloud = MockCloudInferenceRepository();
    _stubGenerateWithAudio(mockCloud, ['ok']);

    final svc = buildService(repo: aiRepo, cloud: mockCloud);

    expect(await svc.transcribe(file.path), 'ok');
    // The fallback model — not a flash model — was actually used.
    expect(_verifyGenerateWithAudio(mockCloud).model, 'gemini-audio');
  });

  test('throws when no audio-capable model is configured', () async {
    // Isolated DB: must contain no audio-capable model at all.
    final aiRepo = isolatedRepo();
    await aiRepo.saveConfig(_provider(id: 'p1'), fromSync: true);

    final svc = buildService(repo: aiRepo);

    expect(
      () => svc.transcribe('/tmp/does-not-matter.m4a'),
      throwsA(isA<Exception>()),
    );
  });

  test('throws when provider for selected audio model is missing', () async {
    // Isolated DB: only a model whose provider row does not exist.
    final aiRepo = isolatedRepo();
    await aiRepo.saveConfig(
      _audioModel(id: 'm1', providerId: 'prov-missing'),
      fromSync: true,
    );

    final svc = buildService(repo: aiRepo);

    await expectLater(
      () => svc.transcribe('/tmp/file.m4a'),
      throwsA(predicate((e) => e.toString().contains('Provider not found'))),
    );
  });

  test('ignores empty content chunks from cloud stream', () async {
    final file = await audioFile();
    final mockCloud = MockCloudInferenceRepository();
    _stubGenerateWithAudio(mockCloud, ['', 'ok']);

    final svc = buildService(repo: sharedRepo, cloud: mockCloud);

    expect(await svc.transcribe(file.path), 'ok');
  });

  test('transcribeStream yields chunks progressively', () async {
    final file = await audioFile();
    final mockCloud = MockCloudInferenceRepository();
    _stubGenerateWithAudio(mockCloud, ['First ', 'Second ', 'Third']);

    final svc = buildService(repo: sharedRepo, cloud: mockCloud);

    final chunks = <String>[];
    await svc.transcribeStream(file.path).forEach(chunks.add);

    // Chunks arrive progressively and concatenate to the full transcript.
    expect(chunks, ['First ', 'Second ', 'Third']);
    expect(chunks.join(), 'First Second Third');
  });

  test(
    'transcribeStream propagates a mid-stream cloud error after partial '
    'chunks',
    () async {
      final file = await audioFile();
      final mockCloud = MockCloudInferenceRepository();
      _stubGenerateWithAudioStream(mockCloud, () async* {
        yield _contentChunk('partial ');
        throw StateError('stream interrupted');
      });

      final svc = buildService(repo: sharedRepo, cloud: mockCloud);

      final chunks = <String>[];
      await expectLater(
        svc.transcribeStream(file.path).forEach(chunks.add),
        throwsStateError,
      );
      // The chunks yielded before the failure made it out.
      expect(chunks, ['partial ']);
    },
  );

  group('batch guard: excludes realtime models', () {
    /// Saves a Mistral provider plus the listed audio models on an isolated
    /// repo, transcribes, and returns the model id the service actually
    /// selected for the cloud call. Isolated so the shared flash row never
    /// shadows the model under test.
    Future<String?> selectedBatchModel({
      required List<AiConfig> models,
      bool addGeminiProvider = false,
    }) async {
      final aiRepo = isolatedRepo();
      await aiRepo.saveConfig(
        _provider(
          id: _pMistral,
          type: InferenceProviderType.mistral,
          name: 'Mistral',
          baseUrl: 'https://api.mistral.ai/v1',
        ),
        fromSync: true,
      );
      if (addGeminiProvider) {
        await aiRepo.saveConfig(
          _provider(id: _pGemini, baseUrl: 'https://api.gemini.test'),
          fromSync: true,
        );
      }
      for (final model in models) {
        await aiRepo.saveConfig(model, fromSync: true);
      }

      final file = await audioFile();
      final mockCloud = MockCloudInferenceRepository();
      _stubGenerateWithAudio(mockCloud, ['ok']);

      final svc = buildService(repo: aiRepo, cloud: mockCloud);
      expect(await svc.transcribe(file.path), 'ok');
      return _verifyGenerateWithAudio(mockCloud).model as String?;
    }

    final realtimeModel = _audioModel(
      id: 'm-realtime',
      providerId: _pMistral,
      name: 'Voxtral Realtime',
      providerModelId: 'voxtral-mini-transcribe-realtime-2602',
    );

    test(
      'excludes Mistral realtime model, selects the Gemini batch model',
      () async {
        // Realtime Mistral + batch Gemini: the realtime model is filtered out and
        // the Gemini batch model wins.
        final selected = await selectedBatchModel(
          addGeminiProvider: true,
          models: [
            realtimeModel,
            _audioModel(id: 'm-batch', providerId: _pGemini),
          ],
        );
        expect(selected, 'gemini-2.5-flash');
      },
    );

    test('keeps a non-realtime Mistral model for batch', () async {
      // Only a non-realtime Mistral model exists, so it must be the selection.
      final selected = await selectedBatchModel(
        models: [
          _audioModel(
            id: 'm-mistral-batch',
            providerId: _pMistral,
            name: 'Mistral Batch Audio',
            providerModelId: 'mistral-large-audio',
          ),
        ],
      );
      expect(selected, 'mistral-large-audio');
    });

    test('throws when only realtime models exist (all excluded)', () async {
      final aiRepo = isolatedRepo();
      await aiRepo.saveConfig(
        _provider(
          id: _pMistral,
          type: InferenceProviderType.mistral,
          name: 'Mistral',
          baseUrl: 'https://api.mistral.ai/v1',
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(realtimeModel, fromSync: true);

      final svc = buildService(repo: aiRepo);

      expect(
        () => svc.transcribe('/tmp/test.m4a'),
        throwsA(isA<Exception>()),
      );
    });
  });

  test('transcribeStream handles null choices in response chunk', () async {
    final file = await audioFile();
    final mockCloud = MockCloudInferenceRepository();
    _stubGenerateWithAudioStream(
      mockCloud,
      () => Stream.fromIterable([
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
        _contentChunk('hello'),
      ]),
    );

    final svc = buildService(repo: sharedRepo, cloud: mockCloud);

    final chunks = <String>[];
    await svc.transcribeStream(file.path).forEach(chunks.add);

    // Only the valid chunk should be yielded
    expect(chunks, ['hello']);
  });

  test('transcribeStream skips empty chunks', () async {
    final file = await audioFile();
    final mockCloud = MockCloudInferenceRepository();
    _stubGenerateWithAudio(mockCloud, ['', 'content', '']);

    final svc = buildService(repo: sharedRepo, cloud: mockCloud);

    final chunks = <String>[];
    await svc.transcribeStream(file.path).forEach(chunks.add);

    // Should only yield non-empty chunks
    expect(chunks, ['content']);
  });

  group('offline bias-capable model selection', () {
    test('prefers Mistral offline over MLX Qwen when both exist', () async {
      final aiRepo = isolatedRepo();
      await aiRepo.saveConfig(
        _provider(
          id: 'p-mistral-default-choice',
          type: InferenceProviderType.mistral,
          name: 'Mistral',
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'mistral-key',
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        _audioModel(
          id: 'm-mistral-default-choice',
          providerId: 'p-mistral-default-choice',
          name: 'Voxtral Mini Transcribe',
          providerModelId: 'voxtral-mini-latest',
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        _provider(
          id: 'p-mlx-default-choice',
          type: InferenceProviderType.mlxAudio,
          name: 'MLX Audio',
          baseUrl: '',
          apiKey: '',
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        _audioModel(
          id: 'm-mlx-default-choice',
          providerId: 'p-mlx-default-choice',
          name: 'Qwen3 ASR',
          providerModelId: mlxAudioQwenAsrModelId,
        ),
        fromSync: true,
      );

      final file = await audioFile();
      final mlxAudioChannel = _FakeMlxAudioChannel();
      final mockCloud = MockCloudInferenceRepository();
      _stubGenerateWithAudio(mockCloud, ['mistral default']);

      final svc = buildService(
        repo: aiRepo,
        cloud: mockCloud,
        mlxChannel: mlxAudioChannel,
      );
      final result = await svc.transcribe(file.path);

      expect(result, 'mistral default');
      expect(mlxAudioChannel.transcribedFilePath, isNull);
      expect(_verifyGenerateWithAudio(mockCloud).model, 'voxtral-mini-latest');
    });

    test('prefers MLX Qwen and forwards speech dictionary terms', () async {
      final aiRepo = isolatedRepo();
      await aiRepo.saveConfig(
        _provider(
          id: 'p-gemini-qwen-choice',
          baseUrl: 'https://api.gemini.test',
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        _audioModel(
          id: 'm-gemini-qwen-choice',
          providerId: 'p-gemini-qwen-choice',
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        _provider(
          id: 'p-mlx-qwen-choice',
          type: InferenceProviderType.mlxAudio,
          name: 'MLX Audio',
          baseUrl: '',
          apiKey: '',
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        _audioModel(
          id: 'm-mlx-qwen-choice',
          providerId: 'p-mlx-qwen-choice',
          name: 'Qwen3 ASR',
          providerModelId: mlxAudioQwenAsrModelId,
        ),
        fromSync: true,
      );

      final file = await audioFile();
      final mlxAudioChannel = _FakeMlxAudioChannel();

      final svc = buildService(repo: aiRepo, mlxChannel: mlxAudioChannel);
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
        final aiRepo = isolatedRepo();
        await aiRepo.saveConfig(
          _provider(
            id: 'p-mlx-qwen17-choice',
            type: InferenceProviderType.mlxAudio,
            name: 'MLX Audio',
            baseUrl: '',
            apiKey: '',
          ),
          fromSync: true,
        );
        await aiRepo.saveConfig(
          _audioModel(
            id: 'm-mlx-qwen17-choice',
            providerId: 'p-mlx-qwen17-choice',
            name: 'Qwen3 ASR 1.7B',
            providerModelId: mlxAudioQwenAsr17B8BitModelId,
          ),
          fromSync: true,
        );

        final file = await audioFile();
        final mlxAudioChannel = _FakeMlxAudioChannel();

        final svc = buildService(repo: aiRepo, mlxChannel: mlxAudioChannel);
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
        final aiRepo = isolatedRepo();
        await aiRepo.saveConfig(
          _provider(
            id: 'p-gemini-mistral-choice',
            baseUrl: 'https://api.gemini.test',
          ),
          fromSync: true,
        );
        await aiRepo.saveConfig(
          _audioModel(
            id: 'm-gemini-mistral-choice',
            providerId: 'p-gemini-mistral-choice',
          ),
          fromSync: true,
        );
        await aiRepo.saveConfig(
          _provider(
            id: 'p-mistral-offline-choice',
            type: InferenceProviderType.mistral,
            name: 'Mistral',
            baseUrl: 'https://api.mistral.ai/v1',
            apiKey: 'mistral-key',
          ),
          fromSync: true,
        );
        await aiRepo.saveConfig(
          _audioModel(
            id: 'm-mistral-offline-choice',
            providerId: 'p-mistral-offline-choice',
            name: 'Voxtral Mini Transcribe',
            providerModelId: 'voxtral-mini-latest',
          ),
          fromSync: true,
        );

        final file = await audioFile();
        final mockCloud = MockCloudInferenceRepository();
        _stubGenerateWithAudio(mockCloud, ['mistral biased']);

        final svc = buildService(repo: aiRepo, cloud: mockCloud);
        final result = await svc.transcribe(
          file.path,
          speechDictionaryTerms: const ['Claude Code', 'macOS'],
        );

        expect(result, 'mistral biased');
        final args = _verifyGenerateWithAudio(mockCloud);
        expect(args.model, 'voxtral-mini-latest');
        expect(args.speechDictionaryTerms, ['Claude Code', 'macOS']);
      },
    );
  });

  group('batch model-selection priority (property)', () {
    glados.Glados<List<_ModelKind>>(
      glados.any.nonEmptyList(glados.any.choose(_ModelKind.values)),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'selected model always honours the documented priority order',
      (
        kinds,
      ) {
        final inputs = _buildSelectionInputs(kinds);
        final selected = debugSelectBatchAudioModel(
          inputs.models,
          inputs.providers,
        );
        final providerType = {
          for (final p in inputs.providers) p.id: p.inferenceProviderType,
        };
        bool isMistral(AiConfigModel m) =>
            providerType[m.inferenceProviderId] ==
            InferenceProviderType.mistral;
        bool isVoxtral(AiConfigModel m) =>
            m.providerModelId.startsWith('voxtral-');
        bool isMlxQwen(AiConfigModel m) =>
            providerType[m.inferenceProviderId] ==
                InferenceProviderType.mlxAudio &&
            isMlxAudioQwenAsrModelId(m.providerModelId);
        bool isMeliousWhisper(AiConfigModel m) =>
            providerType[m.inferenceProviderId] ==
                InferenceProviderType.melious &&
            m.providerModelId.contains('whisper');
        bool isFlash(AiConfigModel m) =>
            m.providerModelId.contains('gemini-2.5-flash');

        // Closure: the pick is always one of the supplied models.
        expect(inputs.models, contains(selected), reason: 'kinds=$kinds');

        // Priority: each higher tier, when present, forces the pick into it.
        if (inputs.models.any(isVoxtral)) {
          expect(
            isVoxtral(selected),
            isTrue,
            reason: 'voxtral wins; kinds=$kinds',
          );
        } else if (inputs.models.any(isMistral)) {
          expect(
            isMistral(selected),
            isTrue,
            reason: 'mistral batch wins; kinds=$kinds',
          );
        } else if (inputs.models.any(isMeliousWhisper)) {
          expect(
            isMeliousWhisper(selected),
            isTrue,
            reason: 'melious transcription wins; kinds=$kinds',
          );
        } else if (inputs.models.any(isMlxQwen)) {
          expect(
            isMlxQwen(selected),
            isTrue,
            reason: 'mlx qwen wins; kinds=$kinds',
          );
        } else if (inputs.models.any(isFlash)) {
          expect(isFlash(selected), isTrue, reason: 'flash wins; kinds=$kinds');
        }
      },
      tags: 'glados',
    );
  });
}
