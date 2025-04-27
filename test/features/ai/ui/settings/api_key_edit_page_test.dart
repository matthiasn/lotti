import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/api_key_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/api_key_form.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockAiConfigRepository mockRepository;
  late AiConfig testConfig;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.apiKey(
        id: 'fallback-id',
        name: 'Fallback API',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();

    // Create a test config
    testConfig = AiConfig.apiKey(
      id: 'test-id',
      name: 'Test API',
      baseUrl: 'https://api.example.com',
      apiKey: 'test-api-key',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    // Set up the repository responses
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
    when(() => mockRepository.getConfigById('test-id'))
        .thenAnswer((_) async => testConfig);
  });

  // Helper function to build the widget under test
  Widget buildTestWidget({String? configId}) {
    return ProviderScope(
      overrides: [
        // Mock the repository instead of the controller
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
        home: ApiKeyEditPage(configId: configId),
        navigatorObservers: [MockNavigatorObserver()],
      ),
    );
  }

  group('ApiKeyEditPage Tests', () {
    testWidgets('should display "Add API Key" title when configId is null',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Add API Key'), findsOneWidget);
      expect(find.byType(ApiKeyForm), findsOneWidget);
    });

    testWidgets('should display "Edit API Key" title when configId is provided',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Edit API Key'), findsOneWidget);
      expect(find.byType(ApiKeyForm), findsOneWidget);
    });

    testWidgets('should call repository saveConfig when adding a new API key',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Fill in the form fields
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'New API');
      await tester.enterText(
        find.widgetWithText(TextField, 'Base URL'),
        'https://new.example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'API Key'),
        'new-api-key',
      );
      await tester.pumpAndSettle();

      // Act - press the save button
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets(
        'should call repository saveConfig when updating an existing API key',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));
      await tester.pumpAndSettle();

      // Fill in the form fields
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Updated API',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Base URL'),
        'https://updated.example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'API Key'),
        'updated-api-key',
      );
      await tester.pumpAndSettle();

      // Act - press the save button
      await tester.tap(find.widgetWithText(FilledButton, 'Update'));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets('should show loading indicator when loading a config',
        (WidgetTester tester) async {
      // Arrange - use a Completer that we can control
      final completer = Completer<AiConfig?>();
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));

      // Assert - should see loading indicator while future is pending
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(testConfig);
      await tester.pumpAndSettle();
    });

    testWidgets('should show error message when config loading fails',
        (WidgetTester tester) async {
      // Arrange - repository that throws an error
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) => Future<AiConfig?>.error('Failed to load'));

      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Failed to load API key configuration'), findsOneWidget);
    });
  });
}
