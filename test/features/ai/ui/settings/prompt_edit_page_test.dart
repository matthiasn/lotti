import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/prompt_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Mock repository implementation
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Mock controller for saving/updating
class MockPromptFormController extends Mock {
  void addConfig(AiConfig config) {}
  void updateConfig(AiConfig config) {}
}

void main() {
  late MockAiConfigRepository mockRepository;

  setUp(() {
    mockRepository = MockAiConfigRepository();
  });

  /// Helper function to build a testable widget with the correct localizations
  /// and provider overrides
  Widget buildTestWidget({
    required String? configId,
    required MockAiConfigRepository repository,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProviderScope(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(repository),
        ],
        child: PromptEditPage(configId: configId),
      ),
    );
  }

  /// Creates a mock prompt config for testing
  AiConfig createMockPromptConfig({
    required String id,
    required String name,
    required String systemMessage,
    required String userMessage,
    required String defaultModelId,
    List<String> modelIds = const [],
    String? description,
    String? comment,
    String? category,
    bool useReasoning = false,
    List<InputDataType> requiredInputData = const [],
    AiResponseType aiResponseType = AiResponseType.taskSummary,
  }) {
    return AiConfig.prompt(
      id: id,
      name: name,
      systemMessage: systemMessage,
      userMessage: userMessage,
      defaultModelId: defaultModelId,
      modelIds: modelIds,
      createdAt: DateTime.now(),
      useReasoning: useReasoning,
      requiredInputData: requiredInputData,
      description: description,
      comment: comment,
      category: category,
      aiResponseType: aiResponseType,
    );
  }

  group('PromptEditPage', () {
    testWidgets('displays create form when configId is null',
        (WidgetTester tester) async {
      // Build the widget in create mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify the title shows "Add Prompt" or equivalent
      expect(find.textContaining('Add Prompt'), findsOneWidget);

      // Verify the form is displayed
      expect(find.byType(PromptForm), findsOneWidget);
    });

    testWidgets(
        'displays edit form when configId is provided and config exists',
        (WidgetTester tester) async {
      // Create a mock config
      final mockConfig = createMockPromptConfig(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System message for Test Prompt',
        userMessage: 'This is a test template with {{variable}}',
        defaultModelId: 'model-123',
        description: 'Test Description',
      );

      // Set up mock repository to return the config
      when(() => mockRepository.getConfigById('prompt-1'))
          .thenAnswer((_) async => mockConfig);

      // Build the widget in edit mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: 'prompt-1',
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify the title shows "Edit Prompt" or equivalent
      expect(find.textContaining('Edit Prompt'), findsOneWidget);
    });

    testWidgets('displays loading indicator when config is loading',
        (WidgetTester tester) async {
      // Use a Completer that we can complete at the end of the test
      final completer = Completer<AiConfig?>();

      // Set up mock repository to return the completer's future
      when(() => mockRepository.getConfigById('prompt-1'))
          .thenAnswer((_) => completer.future);

      // Build the widget in edit mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: 'prompt-1',
          repository: mockRepository,
        ),
      );

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(null);
      await tester.pump();
    });

    testWidgets('displays error when config fails to load',
        (WidgetTester tester) async {
      // Set up mock repository to throw error
      when(() => mockRepository.getConfigById('prompt-1'))
          .thenThrow(Exception('Test error'));

      // Build the widget in edit mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: 'prompt-1',
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.textContaining('Failed to load'), findsOneWidget);
    });
  });
}
