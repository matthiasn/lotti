import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockAiConfigByTypeController extends AiConfigByTypeController {
  MockAiConfigByTypeController(this._configs);

  final List<AiConfig> _configs;

  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.value(_configs);
  }
}

// Test wrapper widget that provides all necessary dependencies
class TestOllamaDialogWrapper extends StatelessWidget {
  const TestOllamaDialogWrapper({
    required this.child,
    required this.mockRepository,
    required this.ollamaProvider,
    super.key,
  });

  final Widget child;
  final MockCloudInferenceRepository mockRepository;
  final AiConfigInferenceProvider ollamaProvider;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        cloudInferenceRepositoryProvider.overrideWithValue(mockRepository),
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.inferenceProvider,
        ).overrideWith(() => MockAiConfigByTypeController([ollamaProvider])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }
}

void main() {
  group('Ollama Model Installation UI', () {
    late MockCloudInferenceRepository mockRepository;
    late AiConfigInferenceProvider testOllamaProvider;

    const testModelName = 'gemma3:4b';

    setUp(() {
      mockRepository = MockCloudInferenceRepository();

      // Create a test Ollama provider
      testOllamaProvider = AiConfig.inferenceProvider(
        id: 'test-ollama-provider',
        name: 'Test Ollama',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      ) as AiConfigInferenceProvider;
    });

    group('OllamaModelInstallDialog', () {
      testWidgets('displays correct initial state', (tester) async {
        // Arrange
        await tester.pumpWidget(
          TestOllamaDialogWrapper(
            mockRepository: mockRepository,
            ollamaProvider: testOllamaProvider,
            child: const OllamaModelInstallDialog(modelName: testModelName),
          ),
        );

        // Assert
        expect(find.text('Model Not Installed'), findsOneWidget);
        expect(find.text('The model "$testModelName" is not installed.'),
            findsOneWidget);
        expect(find.text('To install it, run this command in your terminal:'),
            findsOneWidget);
        expect(find.text('ollama pull $testModelName'), findsOneWidget);
        expect(find.text('Would you like to install it now from Lotti?'),
            findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Install'), findsOneWidget);
      });

      testWidgets('displays command text as selectable', (tester) async {
        // Arrange
        await tester.pumpWidget(
          TestOllamaDialogWrapper(
            mockRepository: mockRepository,
            ollamaProvider: testOllamaProvider,
            child: const OllamaModelInstallDialog(modelName: testModelName),
          ),
        );

        // Assert - Command should be selectable text
        final commandFinder = find.text('ollama pull $testModelName');
        expect(commandFinder, findsOneWidget);

        // Verify it's a SelectableText widget
        expect(find.byType(SelectableText), findsOneWidget);
      });

      testWidgets('shows installation UI when install button is pressed',
          (tester) async {
        // Arrange
        final progressStream = Stream<OllamaPullProgress>.fromIterable([
          const OllamaPullProgress(status: 'pulling manifest', progress: 0),
        ]);

        when(() => mockRepository.installModel(testModelName, any()))
            .thenAnswer((_) => progressStream);

        await tester.pumpWidget(
          TestOllamaDialogWrapper(
            mockRepository: mockRepository,
            ollamaProvider: testOllamaProvider,
            child: const OllamaModelInstallDialog(modelName: testModelName),
          ),
        );

        // Act - Press install button
        await tester.tap(find.text('Install'));
        await tester.pump();

        // Assert - Should show installation UI
        expect(find.text('Installing model...'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('shows error state when installation fails', (tester) async {
        // Arrange
        when(() => mockRepository.installModel(testModelName, any()))
            .thenThrow(Exception('Installation failed'));

        await tester.pumpWidget(
          TestOllamaDialogWrapper(
            mockRepository: mockRepository,
            ollamaProvider: testOllamaProvider,
            child: const OllamaModelInstallDialog(modelName: testModelName),
          ),
        );

        // Act - Press install button
        await tester.tap(find.text('Install'));
        await tester.pumpAndSettle();

        // Assert - Should show error state (the dialog sets _isInstalling = false on error)
        expect(find.text('Model Not Installed'), findsOneWidget);
        expect(find.text('Install'),
            findsOneWidget); // Button should still be there
      });

      testWidgets('handles missing Ollama provider gracefully', (tester) async {
        // Arrange
        when(() =>
            mockRepository.installModel(
                testModelName, any())).thenThrow(Exception(
            'Ollama provider not found. Please configure Ollama in settings.'));

        // Create a test wrapper without Ollama provider
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cloudInferenceRepositoryProvider
                  .overrideWithValue(mockRepository),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                  () => MockAiConfigByTypeController([])), // No providers
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: OllamaModelInstallDialog(modelName: testModelName),
              ),
            ),
          ),
        );

        // Act - Press install button
        await tester.tap(find.text('Install'));
        await tester.pumpAndSettle();

        // Assert - Should show initial state again after error
        expect(find.text('Model Not Installed'), findsOneWidget);
        expect(find.text('Install'),
            findsOneWidget); // Button should still be there
      });

      testWidgets('has correct dialog structure', (tester) async {
        // Arrange
        await tester.pumpWidget(
          TestOllamaDialogWrapper(
            mockRepository: mockRepository,
            ollamaProvider: testOllamaProvider,
            child: const OllamaModelInstallDialog(modelName: testModelName),
          ),
        );

        // Assert - Dialog structure
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(Column), findsAtLeastNWidgets(1));
        expect(find.byType(ElevatedButton), findsOneWidget); // Install button
      });

      testWidgets('shows progress indicator during installation',
          (tester) async {
        // Arrange
        final progressStream = Stream<OllamaPullProgress>.fromIterable([
          const OllamaPullProgress(status: 'downloading', progress: 0.5),
        ]);

        when(() => mockRepository.installModel(testModelName, any()))
            .thenAnswer((_) => progressStream);

        await tester.pumpWidget(
          TestOllamaDialogWrapper(
            mockRepository: mockRepository,
            ollamaProvider: testOllamaProvider,
            child: const OllamaModelInstallDialog(modelName: testModelName),
          ),
        );

        // Act - Start installation
        await tester.tap(find.text('Install'));
        await tester.pump();

        // Assert - Progress indicator should be visible
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });
    });

    group('Model Installation Integration', () {
      testWidgets('integrates with unified AI progress view', (tester) async {
        // Arrange
        const entityId = 'test-entity';
        const promptId = 'test-prompt';

        await tester.pumpWidget(
          TestOllamaDialogWrapper(
            mockRepository: mockRepository,
            ollamaProvider: testOllamaProvider,
            child: const UnifiedAiProgressContent(
              entityId: entityId,
              promptId: promptId,
            ),
          ),
        );

        // This test would require more complex setup with the unified AI state
        // For now, we'll just verify the widget can be rendered
        expect(find.byType(UnifiedAiProgressContent), findsOneWidget);
      });
    });
  });
}
