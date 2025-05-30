import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_name_widget.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Mock implementation of the AI Config Repository
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;

  setUp(() {
    mockRepository = MockAiConfigRepository();
  });

  /// Helper function to build a testable widget with the correct localizations
  /// and provider overrides
  Widget buildTestWidget({
    required String providerId,
    required List<Override> overrides,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProviderScope(
          overrides: overrides,
          child: InferenceProviderNameWidget(
            providerId: providerId,
          ),
        ),
      ),
    );
  }

  /// Returns a mock AI config for testing
  AiConfig createMockConfig({
    required String id,
    required String name,
  }) {
    return AiConfig.inferenceProvider(
      id: id,
      baseUrl: 'https://example.com',
      apiKey: 'fake-key',
      name: name,
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.openAi,
    );
  }

  group('InferenceProviderNameWidget', () {
    testWidgets('displays provider name when config is loaded',
        (WidgetTester tester) async {
      // Create a mock config
      const expectedName = 'Test Provider';
      final mockConfig = createMockConfig(
        id: 'test-id',
        name: expectedName,
      );

      // Set up the repository mock to return our config
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) async => mockConfig);

      // Build the widget with a ProviderScope override
      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'test-id',
          overrides: [
            // Override the repository provider
            aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );

      // Initial pump for widget initialization
      await tester.pump();

      // Allow async provider to complete
      await tester.pump(const Duration(milliseconds: 50));

      // Verify the widget displays the expected name
      expect(find.text(expectedName), findsOneWidget);
    });

    testWidgets('displays empty string when config is null',
        (WidgetTester tester) async {
      // Set up the repository mock to return null
      when(() => mockRepository.getConfigById('non-existent-id'))
          .thenAnswer((_) async => null);

      // Build the widget with a ProviderScope override
      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'non-existent-id',
          overrides: [
            // Override the repository provider
            aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );

      // Initial pump for widget initialization
      await tester.pump();

      // Allow async provider to complete
      await tester.pump(const Duration(milliseconds: 50));

      // Verify the widget displays an empty string
      expect(find.text('Inference Provider not found'), findsOneWidget);
    });

    testWidgets('displays empty string while loading',
        (WidgetTester tester) async {
      // Use a Completer that we won't complete during the test
      final completer = Completer<AiConfig?>();

      // Set up the repository mock to return the uncompleted completer's future
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) => completer.future);

      // Build the widget with a ProviderScope override
      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'test-id',
          overrides: [
            // Override the repository provider
            aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );

      // Initial pump for widget initialization - the future is still pending
      await tester.pump();

      // Verify the widget displays an empty string during loading
      expect(find.text(''), findsOneWidget);

      // We need to complete the completer before the test ends
      // to avoid a "pending timer" error
      completer.complete(null);

      // Pump one more time to process the completed future
      await tester.pump();
    });

    testWidgets('displays not found when error occurs',
        (WidgetTester tester) async {
      // Set up the repository mock to throw an error
      when(() => mockRepository.getConfigById('test-id'))
          .thenThrow(Exception('Test error'));

      // Build the widget with a ProviderScope override
      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'test-id',
          overrides: [
            // Override the repository provider
            aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );

      // Initial pump for widget initialization
      await tester.pump();

      // Allow async provider to complete with error
      await tester.pump(const Duration(milliseconds: 50));

      // Verify the widget displays an empty string when there's an error
      expect(
        find.text('Inference Provider not found'),
        findsOneWidget,
      );
    });
  });
}
