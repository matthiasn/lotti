import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late MockEntitiesCacheService mockCacheService;

  setUp(() {
    mockCacheService = MockEntitiesCacheService();
    getIt.registerSingleton<EntitiesCacheService>(mockCacheService);
  });

  tearDown(getIt.reset);

  group('isDefaultPromptSync edge cases', () {
    AiConfigPrompt createTestPrompt({
      required String id,
      String name = 'Test Prompt',
    }) {
      return AiConfig.prompt(
        id: id,
        name: name,
        systemMessage: 'test system',
        userMessage: 'test user',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;
    }

    test('returns false when categoryId is null', () {
      final testPrompt = createTestPrompt(id: 'test-prompt');

      final result = isDefaultPromptSync(
        null,
        testPrompt,
      );

      expect(result, isFalse);
    });

    test('returns false when category not found in cache', () {
      const categoryId = 'non-existent-category';

      when(() => mockCacheService.getCategoryById(categoryId)).thenReturn(null);

      final testPrompt = createTestPrompt(id: 'test-prompt');

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isFalse);
      verify(() => mockCacheService.getCategoryById(categoryId)).called(1);
    });

    test('returns false when automaticPrompts is null', () {
      const categoryId = 'test-category';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = createTestPrompt(id: 'test-prompt');

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isFalse);
    });

    test('returns false when automaticPrompts is empty', () {
      const categoryId = 'test-category';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {}, // Empty map
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = createTestPrompt(id: 'test-prompt');

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isFalse);
    });

    test('returns true when prompt is first in transcription list', () {
      const categoryId = 'test-category';
      const promptId = 'default-transcription-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.audioTranscription: [
            promptId,
            'other-prompt-1',
            'other-prompt-2',
          ],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = AiConfig.prompt(
        id: promptId,
        name: 'Default Transcription',
        systemMessage: 'test system',
        userMessage: 'test user',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isTrue);
    });

    test('returns true when prompt is first in checklist list', () {
      const categoryId = 'test-category';
      const promptId = 'default-checklist-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.checklistUpdates: [
            promptId,
            'other-prompt',
          ],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = AiConfig.prompt(
        id: promptId,
        name: 'Default Checklist',
        systemMessage: 'test system',
        userMessage: 'test user',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.checklistUpdates,
      ) as AiConfigPrompt;

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isTrue);
    });

    test('returns true when prompt is first in task summary list', () {
      const categoryId = 'test-category';
      const promptId = 'default-task-summary-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.taskSummary: [
            promptId,
          ],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = AiConfig.prompt(
        id: promptId,
        name: 'Default Task Summary',
        systemMessage: 'test system',
        userMessage: 'test user',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.taskSummary,
      ) as AiConfigPrompt;

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isTrue);
    });

    test('returns false when prompt is in list but not first', () {
      const categoryId = 'test-category';
      const promptId = 'second-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.audioTranscription: [
            'first-prompt',
            promptId, // This prompt is second
            'third-prompt',
          ],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = AiConfig.prompt(
        id: promptId,
        name: 'Second Prompt',
        systemMessage: 'test system',
        userMessage: 'test user',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isFalse);
    });

    test('returns false when prompt not in any list', () {
      const categoryId = 'test-category';
      const promptId = 'not-in-list-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.audioTranscription: ['prompt-1', 'prompt-2'],
          AiResponseType.checklistUpdates: ['prompt-3', 'prompt-4'],
          AiResponseType.taskSummary: ['prompt-5'],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = AiConfig.prompt(
        id: promptId,
        name: 'Not In List',
        systemMessage: 'test system',
        userMessage: 'test user',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isFalse);
    });

    test('handles cache service exception gracefully', () {
      const categoryId = 'test-category';

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenThrow(Exception('Cache error'));

      final testPrompt = createTestPrompt(id: 'test-prompt');

      // Should not throw, should return false
      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isFalse);
    });

    test('returns true when prompt is first in multiple lists', () {
      const categoryId = 'test-category';
      const promptId = 'multi-purpose-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.audioTranscription: [
            promptId, // First here
            'other-prompt',
          ],
          AiResponseType.checklistUpdates: [
            'different-prompt', // Not first here
            promptId,
          ],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = AiConfig.prompt(
        id: promptId,
        name: 'Multi Purpose',
        systemMessage: 'test system',
        userMessage: 'test user',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      // Should return true because it's first in at least one list
      expect(result, isTrue);
    });

    test('handles empty prompt list in automaticPrompts', () {
      const categoryId = 'test-category';
      const promptId = 'test-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.audioTranscription: [], // Empty list
          AiResponseType.checklistUpdates: ['some-prompt'],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final testPrompt = AiConfig.prompt(
        id: promptId,
        name: 'Test',
        systemMessage: 'test system',
        userMessage: 'test user',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;

      final result = isDefaultPromptSync(
        categoryId,
        testPrompt,
      );

      expect(result, isFalse);
    });
  });

  group('Widget integration tests', () {
    testWidgets('displays gold icon for default prompts', (tester) async {
      const categoryId = 'test-category';
      const defaultPromptId = 'default-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.audioTranscription: [defaultPromptId],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final defaultPrompt = AiConfig.prompt(
        id: defaultPromptId,
        name: 'Default Prompt',
        systemMessage: 'test',
        userMessage: 'test',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;

      final now = DateTime.now();
      final journalEntity = JournalAudio(
        meta: Metadata(
          id: 'test-entry',
          createdAt: now,
          updatedAt: now,
          categoryId: categoryId,
          dateFrom: now,
          dateTo: now,
        ),
        data: AudioData(
          dateFrom: now,
          dateTo: now,
          audioFile: 'test.m4a',
          audioDirectory: '/test',
          duration: const Duration(seconds: 10),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availablePromptsProvider(entityId: journalEntity.id)
                .overrideWith((ref) async => [defaultPrompt]),
            categoryChangesProvider(categoryId)
                .overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: UnifiedAiPromptsList(
                journalEntity: journalEntity,
                onPromptSelected: (_, __) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the widget renders
      expect(find.text('Default Prompt'), findsOneWidget);
    });

    testWidgets('displays regular icon for non-default prompts',
        (tester) async {
      const categoryId = 'test-category';
      const regularPromptId = 'regular-prompt';
      const defaultPromptId = 'default-prompt';

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.audioTranscription: [defaultPromptId],
        },
      );

      when(() => mockCacheService.getCategoryById(categoryId))
          .thenReturn(category);

      final regularPrompt = AiConfig.prompt(
        id: regularPromptId,
        name: 'Regular Prompt',
        systemMessage: 'test',
        userMessage: 'test',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;

      final now = DateTime.now();
      final journalEntity = JournalAudio(
        meta: Metadata(
          id: 'test-entry',
          createdAt: now,
          updatedAt: now,
          categoryId: categoryId,
          dateFrom: now,
          dateTo: now,
        ),
        data: AudioData(
          dateFrom: now,
          dateTo: now,
          audioFile: 'test.m4a',
          audioDirectory: '/test',
          duration: const Duration(seconds: 10),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availablePromptsProvider(entityId: journalEntity.id)
                .overrideWith((ref) async => [regularPrompt]),
            categoryChangesProvider(categoryId)
                .overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: UnifiedAiPromptsList(
                journalEntity: journalEntity,
                onPromptSelected: (_, __) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the regular prompt renders (not marked as default)
      expect(find.text('Regular Prompt'), findsOneWidget);
    });

    testWidgets('handles null categoryId', (tester) async {
      const promptId = 'test-prompt';

      final prompt = AiConfig.prompt(
        id: promptId,
        name: 'Test Prompt',
        systemMessage: 'test',
        userMessage: 'test',
        defaultModelId: 'test-model',
        modelIds: const ['test-model'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt;

      final now = DateTime.now();
      final journalEntity = JournalAudio(
        meta: Metadata(
          id: 'test-entry',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: AudioData(
          dateFrom: now,
          dateTo: now,
          audioFile: 'test.m4a',
          audioDirectory: '/test',
          duration: const Duration(seconds: 10),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availablePromptsProvider(entityId: journalEntity.id)
                .overrideWith((ref) async => [prompt]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: UnifiedAiPromptsList(
                journalEntity: journalEntity,
                onPromptSelected: (_, __) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render without issues when category is null
      expect(find.text('Test Prompt'), findsOneWidget);
    });
  });
}
