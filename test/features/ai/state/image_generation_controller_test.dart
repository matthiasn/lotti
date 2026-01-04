import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/image_generation_controller.dart';

void main() {
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
}
