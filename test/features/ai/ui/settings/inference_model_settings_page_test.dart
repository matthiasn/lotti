import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_settings_page.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockAiConfigRepository mockRepository;
  late MockNavigatorObserver mockNavigatorObserver;
  late List<AiConfig> testConfigs;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.model(
        id: 'fallback-id',
        name: 'Fallback Model',
        providerModelId: 'fallback-provider-model-id',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: true,
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

    // Create some test models
    testConfigs = [
      AiConfig.model(
        id: 'model-1',
        name: 'Test Model 1',
        providerModelId: 'provider-model-id-1',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: true,
      ),
      AiConfig.model(
        id: 'model-2',
        name: 'Test Model 2',
        providerModelId: 'provider-model-id-2',
        inferenceProviderId: 'provider-2',
        createdAt: DateTime.now(),
        inputModalities: const [Modality.text, Modality.image],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
    ];

    // Setup repository mock to return our test configs
    when(
      () => mockRepository.watchConfigsByType(AiConfigType.model),
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
        home: const InferenceModelSettingsPage(),
        navigatorObservers: [mockNavigatorObserver],
      ),
    );
  }

  group('InferenceModelSettingsPage Tests', () {
    testWidgets('should render with correct title and config type',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Assert - check that the title is correct
      expect(find.text('AI Models'), findsOneWidget);

      // Verify the correct config type was passed to AiConfigListPage
      final listPage = tester.widget<AiConfigListPage>(
        find.byType(AiConfigListPage),
      );
      expect(listPage.configType, equals(AiConfigType.model));
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
      expect(find.byType(InferenceModelEditPage), findsOneWidget);
      expect(find.text('Add Model'), findsOneWidget);
    });

    testWidgets('should navigate to edit page when item is tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Clear any previous calls to the navigator observer
      clearInteractions(mockNavigatorObserver);

      // Act - find and tap the first model in the list
      final listItem = find.text('Test Model 1');
      expect(listItem, findsOneWidget);
      await tester.tap(listItem);
      await tester.pumpAndSettle();

      // Assert - verify navigation was triggered
      verify(() => mockNavigatorObserver.didPush(any(), any())).called(1);

      // Verify we're on the edit page with the correct configId (edit mode)
      expect(find.byType(InferenceModelEditPage), findsOneWidget);
      expect(find.text('Edit Model'), findsOneWidget);
    });
  });
}
