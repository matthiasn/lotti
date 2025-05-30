import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/model_subtitle_widget.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;
  late AiConfigModel testModel;
  late AiConfig testProvider;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.inferenceProvider(
        id: 'fallback-id',
        name: 'Fallback Provider',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();

    testProvider = AiConfig.inferenceProvider(
      id: 'provider-123',
      name: 'Test Provider',
      baseUrl: 'https://api.example.com',
      apiKey: 'test-api-key',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.genericOpenAi,
      description: 'Test provider description',
    );

    testModel = AiConfig.model(
      id: 'model-123',
      name: 'Test Model',
      providerModelId: 'gpt-4',
      inferenceProviderId: 'provider-123',
      createdAt: DateTime(2024),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      description: 'Test model description',
    ) as AiConfigModel;
  });

  // Helper function to build the widget under test
  Widget buildTestWidget(Widget child) {
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
        home: Scaffold(body: child),
      ),
    );
  }

  group('ModelSubtitleWidget Tests', () {
    testWidgets('displays inference provider name when provider exists',
        (tester) async {
      // Arrange
      when(() => mockRepository.getConfigById('provider-123'))
          .thenAnswer((_) async => testProvider);

      await tester.pumpWidget(
        buildTestWidget(ModelSubtitleWidget(model: testModel)),
      );

      // Wait for the async provider to resolve
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test Provider'), findsOneWidget);
      verify(() => mockRepository.getConfigById('provider-123')).called(1);
    });

    testWidgets('displays fallback message when provider not found',
        (tester) async {
      // Arrange
      when(() => mockRepository.getConfigById('provider-123'))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildTestWidget(ModelSubtitleWidget(model: testModel)),
      );

      // Wait for the async provider to resolve
      await tester.pumpAndSettle();

      // Assert - should show fallback message
      expect(find.textContaining('Provider not found'), findsOneWidget);
      verify(() => mockRepository.getConfigById('provider-123')).called(1);
    });

    testWidgets('displays fallback message on error', (tester) async {
      // Arrange
      when(() => mockRepository.getConfigById('provider-123'))
          .thenThrow(Exception('Database error'));

      await tester.pumpWidget(
        buildTestWidget(ModelSubtitleWidget(model: testModel)),
      );

      // Wait for the async provider to resolve
      await tester.pumpAndSettle();

      // Assert - should show fallback message on error
      expect(find.textContaining('Provider not found'), findsOneWidget);
      verify(() => mockRepository.getConfigById('provider-123')).called(1);
    });

    testWidgets('shows empty text while loading', (tester) async {
      // Arrange - create a future that will be delayed but can be controlled
      final completer = Completer<AiConfig?>();
      when(() => mockRepository.getConfigById('provider-123'))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        buildTestWidget(ModelSubtitleWidget(model: testModel)),
      );

      // Pump once to start the future but don't wait for completion
      await tester.pump();

      // Assert - should show empty text while loading
      expect(find.text(''), findsOneWidget);
      verify(() => mockRepository.getConfigById('provider-123')).called(1);

      // Complete the future to avoid pending timer issues
      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('passes correct provider ID to InferenceProviderNameWidget',
        (tester) async {
      // Arrange
      final testModelWithDifferentProvider = AiConfig.model(
        id: 'model-456',
        name: 'Another Test Model',
        providerModelId: 'claude-3',
        inferenceProviderId: 'provider-456',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ) as AiConfigModel;

      final differentProvider = AiConfig.inferenceProvider(
        id: 'provider-456',
        name: 'Different Provider',
        baseUrl: 'https://api2.example.com',
        apiKey: 'test-api-key-2',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      when(() => mockRepository.getConfigById('provider-456'))
          .thenAnswer((_) async => differentProvider);

      await tester.pumpWidget(
        buildTestWidget(
          ModelSubtitleWidget(model: testModelWithDifferentProvider),
        ),
      );

      // Wait for the async provider to resolve
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Different Provider'), findsOneWidget);
      verify(() => mockRepository.getConfigById('provider-456')).called(1);
    });
  });
}
