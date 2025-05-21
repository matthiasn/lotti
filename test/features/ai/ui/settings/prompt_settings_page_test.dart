import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';
import 'package:lotti/features/ai/ui/settings/prompt_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/prompt_settings_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockAiConfigRepository mockRepository;
  late MockNavigatorObserver mockNavigatorObserver;
  late List<AiConfig> testConfigs;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.prompt(
        id: 'fallback-id',
        name: 'Fallback Prompt',
        systemMessage: 'Fallback system message',
        userMessage: 'Fallback template',
        defaultModelId: 'model-123',
        modelIds: [],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.taskSummary,
      ),
    );

    registerFallbackValue(
      MaterialPageRoute<void>(
        builder: (context) => const SizedBox(),
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();
    mockNavigatorObserver = MockNavigatorObserver();

    // Create some test prompts
    testConfigs = [
      AiConfig.prompt(
        id: 'prompt-1',
        name: 'Test Prompt 1',
        systemMessage: 'System message for prompt 1',
        userMessage: 'Template for prompt 1',
        defaultModelId: 'model-1',
        modelIds: [],
        createdAt: DateTime.now(),
        useReasoning: true,
        requiredInputData: const [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
      ),
      AiConfig.prompt(
        id: 'prompt-2',
        name: 'Test Prompt 2',
        systemMessage: 'System message for prompt 2',
        userMessage: 'Template for prompt 2',
        defaultModelId: 'model-2',
        modelIds: [],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [InputDataType.images],
        aiResponseType: AiResponseType.taskSummary,
      ),
    ];

    // Setup repository mock to return our test configs
    when(
      () => mockRepository.watchConfigsByType(AiConfigType.prompt),
    ).thenAnswer(
      (_) => Stream.value(testConfigs),
    );
  });

  // Helper to build the widget under test
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PromptSettingsPage(),
        navigatorObservers: [mockNavigatorObserver],
      ),
    );
  }

  group('PromptSettingsPage Tests', () {
    testWidgets('should render with correct title and config type',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Assert - check that the title is correct
      expect(find.text('AI Prompts'), findsOneWidget);

      // Verify the correct config type was passed to AiConfigListPage
      final listPage = tester.widget<AiConfigListPage>(
        find.byType(AiConfigListPage),
      );
      expect(listPage.configType, equals(AiConfigType.prompt));
    });

    testWidgets('should navigate to edit page when add button is pressed',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Clear any previous calls to the navigator observer
      clearInteractions(mockNavigatorObserver);

      // Act - tap the add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Assert - verify navigation was triggered
      verify(() => mockNavigatorObserver.didPush(any(), any())).called(1);

      // Verify we're on the edit page with null configId (create mode)
      expect(find.byType(PromptEditPage), findsOneWidget);
      expect(find.text('Add Prompt'), findsOneWidget);
    });

    testWidgets('should navigate to edit page when item is tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Clear any previous calls to the navigator observer
      clearInteractions(mockNavigatorObserver);

      // Act - find and tap the first prompt in the list
      final listItem = find.text('Test Prompt 1');
      expect(listItem, findsOneWidget);
      await tester.tap(listItem);
      await tester.pumpAndSettle();

      // Assert - verify navigation was triggered
      verify(() => mockNavigatorObserver.didPush(any(), any())).called(1);

      // Verify we're on the edit page with the correct configId (edit mode)
      expect(find.byType(PromptEditPage), findsOneWidget);
      expect(find.text('Edit Prompt'), findsOneWidget);
    });
  });
}
