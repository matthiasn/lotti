import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_settings_page.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockAiConfigRepository mockRepository;
  late MockNavigatorObserver mockNavigatorObserver;
  late List<AiConfig> testConfigs;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.inferenceProvider(
        id: 'fallback-id',
        name: 'Fallback API',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
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

    // Create some test configs
    testConfigs = [
      AiConfig.inferenceProvider(
        id: 'test-id-1',
        name: 'Test API 1',
        baseUrl: 'https://api1.example.com',
        apiKey: 'test-api-key-1',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
      AiConfig.inferenceProvider(
        id: 'test-id-2',
        name: 'Test API 2',
        baseUrl: 'https://api2.example.com',
        apiKey: 'test-api-key-2',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
    ];

    // Set up the repository to return our test configs
    when(
      () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer(
      (_) => Stream.value(testConfigs),
    );
  });

  // Helper function to build the widget under test
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
        home: const InferenceProviderSettingsPage(),
        navigatorObservers: [mockNavigatorObserver],
      ),
    );
  }

  group('ApiKeysSettingsPage Tests', () {
    testWidgets('should render with correct title and config type',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('API Keys'), findsOneWidget);

      // Verify the correct config type was passed to AiConfigListPage
      final listPage = tester.widget<AiConfigListPage>(
        find.byType(AiConfigListPage),
      );
      expect(listPage.configType, equals(AiConfigType.inferenceProvider));
    });

    testWidgets('should navigate to edit page when add button is pressed',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Clear any previous calls to the navigator observer
      clearInteractions(mockNavigatorObserver);

      // Act - simulate pressing the add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Assert - verify navigation was triggered
      verify(() => mockNavigatorObserver.didPush(any(), any())).called(1);

      // Verify we're on the edit page with null configId
      expect(find.byType(InferenceProviderEditPage), findsOneWidget);
      expect(find.text('Add API Key'), findsOneWidget);
    });

    testWidgets('should navigate to edit page when item is tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Clear any previous calls to the navigator observer
      clearInteractions(mockNavigatorObserver);

      // Act - find and tap the first list item
      final listItem = find.text('Test API 1');
      expect(listItem, findsOneWidget);
      await tester.tap(listItem);
      await tester.pumpAndSettle();

      // Assert - verify navigation was triggered
      verify(() => mockNavigatorObserver.didPush(any(), any())).called(1);

      // Verify we're on the edit page with the correct configId
      expect(find.byType(InferenceProviderEditPage), findsOneWidget);
      expect(find.text('Edit API Key'), findsOneWidget);
    });
  });
}
