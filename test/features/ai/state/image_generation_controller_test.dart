import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart'
    show GeneratedImage;
import 'package:lotti/features/ai/state/image_generation_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockLoggingService extends Mock implements LoggingService {}

// Fallback value for AiConfigInferenceProvider
class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(AiConfigType.inferenceProvider);
  });
  group('ImageGenerationState', () {
    test('initial state has correct type', () {
      const state = ImageGenerationState.initial();

      expect(state, isA<ImageGenerationInitial>());
    });

    test('generating state contains prompt', () {
      const prompt = 'A beautiful sunset';
      const state = ImageGenerationState.generating(prompt: prompt);

      expect(state, isA<ImageGenerationGenerating>());
      state.map(
        initial: (_) => fail('Should be generating'),
        generating: (s) => expect(s.prompt, equals(prompt)),
        success: (_) => fail('Should be generating'),
        error: (_) => fail('Should be generating'),
      );
    });

    test('success state contains image data', () {
      const prompt = 'A beautiful sunset';
      final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      const mimeType = 'image/png';

      final state = ImageGenerationState.success(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );

      expect(state, isA<ImageGenerationSuccess>());
      state.map(
        initial: (_) => fail('Should be success'),
        generating: (_) => fail('Should be success'),
        success: (s) {
          expect(s.prompt, equals(prompt));
          expect(s.imageBytes, equals(imageBytes));
          expect(s.mimeType, equals(mimeType));
        },
        error: (_) => fail('Should be success'),
      );
    });

    test('error state contains error message', () {
      const prompt = 'A beautiful sunset';
      const errorMessage = 'Failed to generate image';

      const state = ImageGenerationState.error(
        prompt: prompt,
        errorMessage: errorMessage,
      );

      expect(state, isA<ImageGenerationError>());
      state.map(
        initial: (_) => fail('Should be error'),
        generating: (_) => fail('Should be error'),
        success: (_) => fail('Should be error'),
        error: (s) {
          expect(s.prompt, equals(prompt));
          expect(s.errorMessage, equals(errorMessage));
        },
      );
    });
  });

  group('ImageGenerationController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is initial', () {
      const entityId = 'test-entity-id';

      final state = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );

      expect(state, isA<ImageGenerationInitial>());
    });

    test('reset returns to initial state', () {
      const entityId = 'test-entity-id';

      container
          .read(imageGenerationControllerProvider(entityId: entityId).notifier)
          // Manually set state via controller (simulating a previous operation)
          .reset();

      final state = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );

      expect(state, isA<ImageGenerationInitial>());
    });

    test('different entityIds have independent state', () {
      const entityId1 = 'entity-1';
      const entityId2 = 'entity-2';

      final state1 = container.read(
        imageGenerationControllerProvider(entityId: entityId1),
      );
      final state2 = container.read(
        imageGenerationControllerProvider(entityId: entityId2),
      );

      // Both should be initial
      expect(state1, isA<ImageGenerationInitial>());
      expect(state2, isA<ImageGenerationInitial>());
    });

    test('retryGeneration throws when no prompt available in initial state',
        () async {
      const entityId = 'test-entity-id';

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      expect(
        notifier.retryGeneration,
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No prompt available for retry'),
          ),
        ),
      );
    });
  });

  group('ImageGenerationController.retryGeneration prompt extraction', () {
    test('extracts prompt from generating state', () {
      const prompt = 'Test prompt from generating';
      const state = ImageGenerationState.generating(prompt: prompt);

      final extractedPrompt = state.map(
        initial: (_) => null,
        generating: (s) => s.prompt,
        success: (s) => s.prompt,
        error: (s) => s.prompt,
      );

      expect(extractedPrompt, prompt);
    });

    test('extracts prompt from success state', () {
      const prompt = 'Test prompt from success';
      final state = ImageGenerationState.success(
        prompt: prompt,
        imageBytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      );

      final extractedPrompt = state.map(
        initial: (_) => null,
        generating: (s) => s.prompt,
        success: (s) => s.prompt,
        error: (s) => s.prompt,
      );

      expect(extractedPrompt, prompt);
    });

    test('extracts prompt from error state', () {
      const prompt = 'Test prompt from error';
      const state = ImageGenerationState.error(
        prompt: prompt,
        errorMessage: 'Some error',
      );

      final extractedPrompt = state.map(
        initial: (_) => null,
        generating: (s) => s.prompt,
        success: (s) => s.prompt,
        error: (s) => s.prompt,
      );

      expect(extractedPrompt, prompt);
    });

    test('returns null for initial state', () {
      const state = ImageGenerationState.initial();

      final extractedPrompt = state.map(
        initial: (_) => null,
        generating: (s) => s.prompt,
        success: (s) => s.prompt,
        error: (s) => s.prompt,
      );

      expect(extractedPrompt, isNull);
    });
  });

  group('ImageGenerationState equality and hashCode', () {
    test('initial states are equal', () {
      const state1 = ImageGenerationState.initial();
      const state2 = ImageGenerationState.initial();

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('generating states with same prompt are equal', () {
      const prompt = 'Test prompt';
      const state1 = ImageGenerationState.generating(prompt: prompt);
      const state2 = ImageGenerationState.generating(prompt: prompt);

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('generating states with different prompts are not equal', () {
      const state1 = ImageGenerationState.generating(prompt: 'Prompt 1');
      const state2 = ImageGenerationState.generating(prompt: 'Prompt 2');

      expect(state1, isNot(equals(state2)));
    });

    test('success states with same data are equal', () {
      const prompt = 'Test prompt';
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      const mimeType = 'image/png';

      final state1 = ImageGenerationState.success(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
      final state2 = ImageGenerationState.success(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );

      expect(state1, equals(state2));
    });

    test('error states with same data are equal', () {
      const state1 = ImageGenerationState.error(
        prompt: 'Prompt',
        errorMessage: 'Error',
      );
      const state2 = ImageGenerationState.error(
        prompt: 'Prompt',
        errorMessage: 'Error',
      );

      expect(state1, equals(state2));
    });
  });

  group('ImageGenerationState map function', () {
    test('map correctly routes to initial handler', () {
      const state = ImageGenerationState.initial();

      final result = state.map(
        initial: (_) => 'initial',
        generating: (_) => 'generating',
        success: (_) => 'success',
        error: (_) => 'error',
      );

      expect(result, equals('initial'));
    });

    test('map correctly routes to generating handler', () {
      const state = ImageGenerationState.generating(prompt: 'test');

      final result = state.map(
        initial: (_) => 'initial',
        generating: (_) => 'generating',
        success: (_) => 'success',
        error: (_) => 'error',
      );

      expect(result, equals('generating'));
    });

    test('map correctly routes to success handler', () {
      final state = ImageGenerationState.success(
        prompt: 'test',
        imageBytes: Uint8List.fromList([1]),
        mimeType: 'image/png',
      );

      final result = state.map(
        initial: (_) => 'initial',
        generating: (_) => 'generating',
        success: (_) => 'success',
        error: (_) => 'error',
      );

      expect(result, equals('success'));
    });

    test('map correctly routes to error handler', () {
      const state = ImageGenerationState.error(
        prompt: 'test',
        errorMessage: 'Failed',
      );

      final result = state.map(
        initial: (_) => 'initial',
        generating: (_) => 'generating',
        success: (_) => 'success',
        error: (_) => 'error',
      );

      expect(result, equals('error'));
    });
  });

  group('ImageGenerationController with mocked dependencies', () {
    late MockJournalRepository mockJournalRepo;
    late MockCloudInferenceRepository mockCloudRepo;
    late MockAiConfigRepository mockAiConfigRepo;
    late MockLoggingService mockLoggingService;
    late ProviderContainer container;

    final testGeminiProvider = AiConfigInferenceProvider(
      id: 'gemini-provider',
      name: 'Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com',
      apiKey: 'test-key',
      createdAt: DateTime(2025),
      inferenceProviderType: InferenceProviderType.gemini,
    );

    setUp(() {
      mockJournalRepo = MockJournalRepository();
      mockCloudRepo = MockCloudInferenceRepository();
      mockAiConfigRepo = MockAiConfigRepository();
      mockLoggingService = MockLoggingService();

      // Register LoggingService in GetIt
      if (getIt.isRegistered<LoggingService>()) {
        getIt.unregister<LoggingService>();
      }
      getIt.registerSingleton<LoggingService>(mockLoggingService);

      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepo),
          cloudInferenceRepositoryProvider.overrideWithValue(mockCloudRepo),
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      if (getIt.isRegistered<LoggingService>()) {
        getIt.unregister<LoggingService>();
      }
    });

    test('generateImage transitions to generating then success state',
        () async {
      const entityId = 'test-entity';
      const prompt = 'Generate a beautiful sunset';
      final imageBytes = [1, 2, 3, 4, 5];

      when(() => mockAiConfigRepo.getConfigsByType(any<AiConfigType>()))
          .thenAnswer((_) async => [testGeminiProvider]);

      when(
        () => mockCloudRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any<AiConfigInferenceProvider>(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenAnswer(
        (_) async => GeneratedImage(bytes: imageBytes, mimeType: 'image/png'),
      );

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      // Verify initial state
      expect(
        container.read(imageGenerationControllerProvider(entityId: entityId)),
        isA<ImageGenerationInitial>(),
      );

      // Generate image
      await notifier.generateImage(prompt: prompt);

      // Verify final state is success
      final finalState = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );
      expect(finalState, isA<ImageGenerationSuccess>());

      finalState.map(
        initial: (_) => fail('Should be success'),
        generating: (_) => fail('Should be success'),
        success: (s) {
          expect(s.prompt, prompt);
          expect(s.imageBytes, Uint8List.fromList(imageBytes));
          expect(s.mimeType, 'image/png');
        },
        error: (_) => fail('Should be success'),
      );
    });

    test('generateImage transitions to error state on failure', () async {
      const entityId = 'test-entity';
      const prompt = 'Generate a beautiful sunset';

      when(() => mockAiConfigRepo.getConfigsByType(any<AiConfigType>()))
          .thenAnswer((_) async => [testGeminiProvider]);

      when(
        () => mockCloudRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any<AiConfigInferenceProvider>(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenThrow(Exception('API error'));

      when(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenReturn(null);

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      await notifier.generateImage(prompt: prompt);

      final finalState = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );
      expect(finalState, isA<ImageGenerationError>());

      finalState.map(
        initial: (_) => fail('Should be error'),
        generating: (_) => fail('Should be error'),
        success: (_) => fail('Should be error'),
        error: (s) {
          expect(s.prompt, prompt);
          expect(s.errorMessage, contains('API error'));
        },
      );
    });

    test('generateImage errors when no Gemini provider is configured',
        () async {
      const entityId = 'test-entity';
      const prompt = 'Generate a beautiful sunset';

      // Return empty list - no providers
      when(() => mockAiConfigRepo.getConfigsByType(any<AiConfigType>()))
          .thenAnswer((_) async => []);

      when(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenReturn(null);

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      await notifier.generateImage(prompt: prompt);

      final finalState = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );
      expect(finalState, isA<ImageGenerationError>());

      finalState.map(
        initial: (_) => fail('Should be error'),
        generating: (_) => fail('Should be error'),
        success: (_) => fail('Should be error'),
        error: (s) {
          expect(s.errorMessage, contains('No Gemini provider'));
        },
      );
    });

    test('generateImageFromEntity fails with non-existent entity', () async {
      const entityId = 'non-existent';

      when(() => mockJournalRepo.getJournalEntityById(entityId))
          .thenAnswer((_) async => null);

      when(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenReturn(null);

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      await notifier.generateImageFromEntity(audioEntityId: entityId);

      final finalState = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );
      expect(finalState, isA<ImageGenerationError>());

      finalState.map(
        initial: (_) => fail('Should be error'),
        generating: (_) => fail('Should be error'),
        success: (_) => fail('Should be error'),
        error: (s) {
          expect(s.errorMessage, contains('not found'));
        },
      );
    });

    test('generateImageFromEntity fails with non-audio entity', () async {
      const entityId = 'image-entity';

      final imageEntity = JournalImage(
        meta: Metadata(
          id: entityId,
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: ImageData(
          imageId: 'img-1',
          imageFile: 'test.jpg',
          imageDirectory: '/tmp',
          capturedAt: DateTime(2025),
        ),
      );

      when(() => mockJournalRepo.getJournalEntityById(entityId))
          .thenAnswer((_) async => imageEntity);

      when(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenReturn(null);

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      await notifier.generateImageFromEntity(audioEntityId: entityId);

      final finalState = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );
      expect(finalState, isA<ImageGenerationError>());

      finalState.map(
        initial: (_) => fail('Should be error'),
        generating: (_) => fail('Should be error'),
        success: (_) => fail('Should be error'),
        error: (s) {
          expect(s.errorMessage, contains('Expected JournalAudio'));
        },
      );
    });

    test('retryGeneration with modified prompt uses new prompt', () async {
      const entityId = 'test-entity';
      const originalPrompt = 'Original prompt';
      const modifiedPrompt = 'Modified prompt';
      final imageBytes = [1, 2, 3];

      when(() => mockAiConfigRepo.getConfigsByType(any<AiConfigType>()))
          .thenAnswer((_) async => [testGeminiProvider]);

      when(
        () => mockCloudRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any<AiConfigInferenceProvider>(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenAnswer(
        (_) async => GeneratedImage(bytes: imageBytes, mimeType: 'image/png'),
      );

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      // First generate with original prompt
      await notifier.generateImage(prompt: originalPrompt);

      // Now retry with modified prompt
      await notifier.retryGeneration(modifiedPrompt: modifiedPrompt);

      final finalState = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );
      expect(finalState, isA<ImageGenerationSuccess>());

      finalState.map(
        initial: (_) => fail('Should be success'),
        generating: (_) => fail('Should be success'),
        success: (s) {
          expect(s.prompt, modifiedPrompt);
        },
        error: (_) => fail('Should be success'),
      );
    });

    test('retryGeneration without modified prompt uses current prompt',
        () async {
      const entityId = 'test-entity';
      const prompt = 'Test prompt';
      final imageBytes = [1, 2, 3];

      when(() => mockAiConfigRepo.getConfigsByType(any<AiConfigType>()))
          .thenAnswer((_) async => [testGeminiProvider]);

      when(
        () => mockCloudRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any<AiConfigInferenceProvider>(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenAnswer(
        (_) async => GeneratedImage(bytes: imageBytes, mimeType: 'image/png'),
      );

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      // First generate
      await notifier.generateImage(prompt: prompt);

      // Retry without modifying
      await notifier.retryGeneration();

      final finalState = container.read(
        imageGenerationControllerProvider(entityId: entityId),
      );
      expect(finalState, isA<ImageGenerationSuccess>());

      finalState.map(
        initial: (_) => fail('Should be success'),
        generating: (_) => fail('Should be success'),
        success: (s) {
          expect(s.prompt, prompt);
        },
        error: (_) => fail('Should be success'),
      );
    });

    test('generateImage uses system message from preconfigured prompt',
        () async {
      const entityId = 'test-entity';
      const prompt = 'Test prompt';
      final imageBytes = [1, 2, 3];

      when(() => mockAiConfigRepo.getConfigsByType(any<AiConfigType>()))
          .thenAnswer((_) async => [testGeminiProvider]);

      when(
        () => mockCloudRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any<AiConfigInferenceProvider>(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenAnswer(
        (_) async => GeneratedImage(bytes: imageBytes, mimeType: 'image/png'),
      );

      final notifier = container.read(
        imageGenerationControllerProvider(entityId: entityId).notifier,
      );

      await notifier.generateImage(prompt: prompt);

      // Verify generateImage was called with systemMessage
      verify(
        () => mockCloudRepo.generateImage(
          prompt: prompt,
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).called(1);
    });
  });
}
