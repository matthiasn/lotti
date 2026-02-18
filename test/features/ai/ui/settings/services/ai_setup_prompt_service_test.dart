import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';

/// Mock What's New controller that returns no unseen releases
class _MockWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

/// Mock What's New controller that returns unseen releases
class _MockWhatsNewControllerWithUnseen extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => WhatsNewState(
        // hasUnseenRelease is computed from unseenContent.isNotEmpty
        unseenContent: [
          WhatsNewContent(
            release: WhatsNewRelease(
              version: '1.0.0',
              date: DateTime(2024),
              title: 'Test Release',
              folder: 'v1.0.0',
            ),
            headerMarkdown: '# Test',
            sections: ['Feature 1'],
          ),
        ],
      );
}

void main() {
  late MockAiConfigRepository mockRepository;
  late SettingsDb settingsDb;

  setUp(() async {
    mockRepository = MockAiConfigRepository();

    // Use in-memory database for tests
    settingsDb = SettingsDb(inMemoryDatabase: true);

    if (getIt.isRegistered<SettingsDb>()) {
      getIt.unregister<SettingsDb>();
    }
    getIt.registerSingleton<SettingsDb>(settingsDb);
  });

  tearDown(() async {
    await settingsDb.close();
    await getIt.reset();
  });

  ProviderContainer createContainer({bool hasUnseenWhatsNew = false}) {
    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        whatsNewControllerProvider.overrideWith(
          hasUnseenWhatsNew
              ? _MockWhatsNewControllerWithUnseen.new
              : _MockWhatsNewController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AiSetupPromptService', () {
    test('returns true when no AI provider exists and not dismissed', () async {
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final container = createContainer();
      final result = await container.read(aiSetupPromptServiceProvider.future);

      expect(result, isTrue);
    });

    test('returns false when Gemini provider exists', () async {
      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [geminiProvider]);

      final container = createContainer();
      final result = await container.read(aiSetupPromptServiceProvider.future);

      expect(result, isFalse);
    });

    test('returns false when OpenAI provider exists', () async {
      final openAiProvider = AiConfig.inferenceProvider(
        id: 'openai-provider',
        name: 'My OpenAI',
        baseUrl: 'https://api.openai.com',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [openAiProvider]);

      final container = createContainer();
      final result = await container.read(aiSetupPromptServiceProvider.future);

      expect(result, isFalse);
    });

    test('returns true when only non-supported provider exists', () async {
      // Ollama provider exists but not Gemini or OpenAI
      final ollamaProvider = AiConfig.inferenceProvider(
        id: 'ollama-provider',
        name: 'My Ollama',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [ollamaProvider]);

      final container = createContainer();
      final result = await container.read(aiSetupPromptServiceProvider.future);

      expect(result, isTrue);
    });

    test("returns false when What's New has unseen content", () async {
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final container = createContainer(hasUnseenWhatsNew: true);
      final result = await container.read(aiSetupPromptServiceProvider.future);

      expect(result, isFalse);
    });

    test('returns false when prompt was previously dismissed', () async {
      await settingsDb.saveSettingsItem('ai_setup_prompt_dismissed', 'true');

      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final container = createContainer();
      final result = await container.read(aiSetupPromptServiceProvider.future);

      expect(result, isFalse);
    });

    test('dismissPrompt persists dismissal and updates state', () async {
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final container = createContainer();

      // Initially should show prompt
      final initialResult =
          await container.read(aiSetupPromptServiceProvider.future);
      expect(initialResult, isTrue);

      // Dismiss the prompt
      await container
          .read(aiSetupPromptServiceProvider.notifier)
          .dismissPrompt();

      // Now state should be false
      final afterDismiss =
          await container.read(aiSetupPromptServiceProvider.future);
      expect(afterDismiss, isFalse);

      // Check that setting was persisted
      final storedValue =
          await settingsDb.itemByKey('ai_setup_prompt_dismissed');
      expect(storedValue, 'true');
    });

    test('resetDismissal clears persisted state', () async {
      // Start with dismissed state
      await settingsDb.saveSettingsItem('ai_setup_prompt_dismissed', 'true');

      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final container = createContainer();

      // Initially should not show (dismissed)
      final initialResult =
          await container.read(aiSetupPromptServiceProvider.future);
      expect(initialResult, isFalse);

      // Reset the dismissal
      await container
          .read(aiSetupPromptServiceProvider.notifier)
          .resetDismissal();

      // After reset, should show again (need to re-read as it invalidates self)
      final afterReset =
          await container.read(aiSetupPromptServiceProvider.future);
      expect(afterReset, isTrue);

      // Check that setting was removed
      final storedValue =
          await settingsDb.itemByKey('ai_setup_prompt_dismissed');
      expect(storedValue, isNull);
    });
  });

  group('AiProviderOption', () {
    test('displayName returns correct names', () {
      expect(AiProviderOption.gemini.displayName, equals('Google Gemini'));
      expect(AiProviderOption.openAi.displayName, equals('OpenAI'));
    });

    test('description returns non-empty strings', () {
      expect(AiProviderOption.gemini.description, isNotEmpty);
      expect(AiProviderOption.openAi.description, isNotEmpty);
    });

    test('inferenceProviderType returns correct types', () {
      expect(
        AiProviderOption.gemini.inferenceProviderType,
        equals(InferenceProviderType.gemini),
      );
      expect(
        AiProviderOption.openAi.inferenceProviderType,
        equals(InferenceProviderType.openAi),
      );
    });
  });

  // Note: isFirstProviderOfType and getProviderCountByType are now in
  // FtueTriggerService and tested in ftue_trigger_service_test.dart
}
