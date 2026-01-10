import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/gemini_setup_prompt_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Mock What's New controller that returns no unseen releases
class _MockWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

void main() {
  late MockAiConfigRepository mockRepository;

  setUp(() {
    mockRepository = MockAiConfigRepository();

    // Reset shared preferences before each test
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        // Override What's New to return no unseen releases
        whatsNewControllerProvider.overrideWith(_MockWhatsNewController.new),
      ],
    );
  }

  group('GeminiSetupPromptService', () {
    test('returns true when no Gemini provider exists and not dismissed',
        () async {
      // No providers exist
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final container = createContainer();
      final result =
          await container.read(geminiSetupPromptServiceProvider.future);

      expect(result, isTrue);
    });

    test('returns false when Gemini provider exists', () async {
      // Gemini provider exists
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
      final result =
          await container.read(geminiSetupPromptServiceProvider.future);

      expect(result, isFalse);
    });

    test('returns false when non-Gemini provider exists but prompt dismissed',
        () async {
      // No Gemini provider, but another provider exists
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

      // Simulate prompt was dismissed
      SharedPreferences.setMockInitialValues(
          {'gemini_setup_prompt_dismissed': true});

      final container = createContainer();
      final result =
          await container.read(geminiSetupPromptServiceProvider.future);

      expect(result, isFalse);
    });

    test('dismissPrompt persists dismissal and updates state', () async {
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final container = createContainer();

      // Initially should show prompt
      final initialResult =
          await container.read(geminiSetupPromptServiceProvider.future);
      expect(initialResult, isTrue);

      // Dismiss the prompt
      await container
          .read(geminiSetupPromptServiceProvider.notifier)
          .dismissPrompt();

      // Now state should be false
      final afterDismiss =
          await container.read(geminiSetupPromptServiceProvider.future);
      expect(afterDismiss, isFalse);

      // Check that preference was persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('gemini_setup_prompt_dismissed'), isTrue);
    });

    test('resetDismissal clears persisted state', () async {
      // Start with dismissed state
      SharedPreferences.setMockInitialValues(
          {'gemini_setup_prompt_dismissed': true});

      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final container = createContainer();

      // Initially should not show (dismissed)
      final initialResult =
          await container.read(geminiSetupPromptServiceProvider.future);
      expect(initialResult, isFalse);

      // Reset the dismissal
      await container
          .read(geminiSetupPromptServiceProvider.notifier)
          .resetDismissal();

      // After reset, should show again (need to re-read as it invalidates self)
      final afterReset =
          await container.read(geminiSetupPromptServiceProvider.future);
      expect(afterReset, isTrue);

      // Check that preference was removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('gemini_setup_prompt_dismissed'), isNull);
    });
  });
}
