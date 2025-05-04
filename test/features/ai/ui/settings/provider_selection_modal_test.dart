import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/provider_selection_modal.dart';
import 'package:mocktail/mocktail.dart';

/// Mock repository implementation
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

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
      home: Scaffold(
        body: ProviderScope(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(repository),
          ],
          child: ProviderSelectionModal(configId: configId),
        ),
      ),
    );
  }

  /// Creates a mock provider list for testing
  List<AiConfig> createMockProviders({int count = 3}) {
    return List.generate(
      count,
      (index) => AiConfig.inferenceProvider(
        id: 'provider-$index',
        baseUrl: 'https://example.com/$index',
        apiKey: 'api-key-$index',
        name: 'Provider $index',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
        description: index.isEven ? 'Description for provider $index' : null,
      ),
    );
  }

  group('ProviderSelectionModal', () {
    testWidgets('displays list of providers when data is loaded',
        (WidgetTester tester) async {
      // Create mock providers
      final mockProviders = createMockProviders();

      // Set up mock repository to return providers
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.value(mockProviders));

      // Build the widget
      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify that all providers are displayed
      for (final provider in mockProviders) {
        expect(find.text(provider.name), findsOneWidget);

        // Verify that either description or baseUrl is shown
        if (provider.maybeMap(
          inferenceProvider: (p) => p.description != null,
          orElse: () => false,
        )) {
          expect(
            find.text(
              provider.maybeMap(
                inferenceProvider: (p) => p.description!,
                orElse: () => '',
              ),
            ),
            findsOneWidget,
          );
        } else {
          expect(
            find.text(
              provider.maybeMap(
                inferenceProvider: (p) => p.baseUrl,
                orElse: () => '',
              ),
            ),
            findsOneWidget,
          );
        }
      }
    });

    testWidgets('displays loading indicator when data is loading',
        (WidgetTester tester) async {
      // Create a completer that won't complete during the test
      final completer = Completer<List<AiConfig>>();

      // Set up mock repository to return a stream that doesn't emit yet
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.fromFuture(completer.future));

      // Build the widget
      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
        ),
      );

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the completer to avoid pending timers
      completer.complete([]);
      await tester.pump();
    });

    testWidgets('displays error message when loading fails',
        (WidgetTester tester) async {
      // Set up mock repository to return a stream with error
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.error(Exception('Test error')));

      // Build the widget
      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify error message is shown - find the text by partial content
      expect(
        find.textContaining('Error loading configurations'),
        findsOneWidget,
      );
      expect(find.textContaining('Test error'), findsOneWidget);
    });

    testWidgets('displays message when no providers are available',
        (WidgetTester tester) async {
      // Set up mock repository to return empty list
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.value([]));

      // Build the widget
      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify message is shown - use the exact text from the localization
      expect(
        find.text(
          'No API providers available. Please add an API provider first.',
        ),
        findsOneWidget,
      );
    });
  });
}
