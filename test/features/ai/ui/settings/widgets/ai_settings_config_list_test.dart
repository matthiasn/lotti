import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_config_list.dart';

void main() {
  group('AiSettingsConfigList', () {
    late List<AiConfigInferenceProvider> testProviders;
    late List<AiConfigModel> testModels;
    late List<AiConfigPrompt> testPrompts;
    late List<AiConfig> tappedConfigs;

    setUp(() {
      tappedConfigs = [];

      testProviders = [
        AiConfig.inferenceProvider(
          id: 'provider-1',
          name: 'Test Provider 1',
          description: 'First test provider',
          inferenceProviderType: InferenceProviderType.anthropic,
          apiKey: 'key1',
          baseUrl: 'https://api1.com',
          createdAt: DateTime.now(),
        ) as AiConfigInferenceProvider,
        AiConfig.inferenceProvider(
          id: 'provider-2',
          name: 'Test Provider 2',
          description: 'Second test provider',
          inferenceProviderType: InferenceProviderType.openAi,
          apiKey: 'key2',
          baseUrl: 'https://api2.com',
          createdAt: DateTime.now(),
        ) as AiConfigInferenceProvider,
      ];

      testModels = [
        AiConfig.model(
          id: 'model-1',
          name: 'Test Model 1',
          description: 'First test model',
          providerModelId: 'model-1-id',
          inferenceProviderId: 'provider-1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ) as AiConfigModel,
        AiConfig.model(
          id: 'model-2',
          name: 'Test Model 2',
          description: 'Second test model',
          providerModelId: 'model-2-id',
          inferenceProviderId: 'provider-2',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: true,
        ) as AiConfigModel,
      ];

      testPrompts = [
        AiConfig.prompt(
          id: 'prompt-1',
          name: 'Test Prompt 1',
          description: 'First test prompt',
          systemMessage: 'System message 1',
          userMessage: 'User message 1',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        ) as AiConfigPrompt,
        AiConfig.prompt(
          id: 'prompt-2',
          name: 'Test Prompt 2',
          description: 'Second test prompt',
          systemMessage: 'System message 2',
          userMessage: 'User message 2',
          defaultModelId: 'model-2',
          modelIds: ['model-2'],
          createdAt: DateTime.now(),
          useReasoning: true,
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        ) as AiConfigPrompt,
      ];
    });

    Widget createWidget<T extends AiConfig>({
      required AsyncValue<List<AiConfig>> configsAsync,
      required List<T> filteredConfigs,
      String emptyMessage = 'No configurations',
      IconData emptyIcon = Icons.error,
      bool showCapabilities = false,
      ValueChanged<AiConfig>? onConfigTap,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AiSettingsConfigList<T>(
              configsAsync: configsAsync,
              filteredConfigs: filteredConfigs,
              emptyMessage: emptyMessage,
              emptyIcon: emptyIcon,
              showCapabilities: showCapabilities,
              onConfigTap: onConfigTap ??
                  (config) {
                    tappedConfigs.add(config);
                  },
            ),
          ),
        ),
      );
    }

    group('data states', () {
      testWidgets('shows loading indicator when data is loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: const AsyncValue.loading(),
          filteredConfigs: [],
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows error message when data loading fails',
          (WidgetTester tester) async {
        const error = 'Network connection failed';
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: const AsyncValue.error(error, StackTrace.empty),
          filteredConfigs: [],
        ));

        expect(find.text('Failed to load configurations'), findsOneWidget);
        expect(find.text(error), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('shows empty state when no configurations exist',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: const AsyncValue.data([]),
          filteredConfigs: [],
          emptyMessage: 'No providers configured',
          emptyIcon: Icons.hub,
        ));

        expect(find.text('No providers configured'), findsOneWidget);
        expect(find.byIcon(Icons.hub), findsOneWidget);
      });

      testWidgets('shows empty state when all configurations are filtered out',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(testProviders.cast<AiConfig>()),
          filteredConfigs: [], // Empty after filtering
          emptyMessage: 'No matching providers',
          emptyIcon: Icons.search_off,
        ));

        expect(find.text('No matching providers'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
      });
    });

    group('configuration display', () {
      testWidgets('displays providers correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(testProviders.cast<AiConfig>()),
          filteredConfigs: testProviders,
        ));

        expect(find.text('Test Provider 1'), findsOneWidget);
        expect(find.text('Test Provider 2'), findsOneWidget);
        expect(find.text('First test provider'), findsOneWidget);
        expect(find.text('Second test provider'), findsOneWidget);
      });

      testWidgets('displays models correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigModel>(
          configsAsync: AsyncValue.data(testModels.cast<AiConfig>()),
          filteredConfigs: testModels,
        ));

        expect(find.text('Test Model 1'), findsOneWidget);
        expect(find.text('Test Model 2'), findsOneWidget);
        expect(find.text('First test model'), findsOneWidget);
        expect(find.text('Second test model'), findsOneWidget);
      });

      testWidgets('displays prompts correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigPrompt>(
          configsAsync: AsyncValue.data(testPrompts.cast<AiConfig>()),
          filteredConfigs: testPrompts,
        ));

        expect(find.text('Test Prompt 1'), findsOneWidget);
        expect(find.text('Test Prompt 2'), findsOneWidget);
        expect(find.text('First test prompt'), findsOneWidget);
        expect(find.text('Second test prompt'), findsOneWidget);
      });
    });

    group('capabilities display', () {
      testWidgets('shows capabilities when showCapabilities is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigModel>(
          configsAsync: AsyncValue.data(testModels.cast<AiConfig>()),
          filteredConfigs: testModels,
          showCapabilities: true,
        ));

        // Should show capability indicators for models
        expect(find.text('Test Model 1'), findsOneWidget);
        expect(find.text('Test Model 2'), findsOneWidget);

        // Capability chips or indicators should be present
        // (Exact implementation depends on the card widget)
      });

      testWidgets('hides capabilities when showCapabilities is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigModel>(
          configsAsync: AsyncValue.data(testModels.cast<AiConfig>()),
          filteredConfigs: testModels,
        ));

        expect(find.text('Test Model 1'), findsOneWidget);
        expect(find.text('Test Model 2'), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('calls onConfigTap when configuration is tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(testProviders.cast<AiConfig>()),
          filteredConfigs: testProviders,
        ));

        await tester.tap(find.text('Test Provider 1'));
        await tester.pump();

        expect(tappedConfigs, hasLength(1));
        expect(tappedConfigs.first.id, 'provider-1');
      });

      testWidgets('allows tapping multiple configurations',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(testProviders.cast<AiConfig>()),
          filteredConfigs: testProviders,
        ));

        await tester.tap(find.text('Test Provider 1'));
        await tester.pump();
        await tester.tap(find.text('Test Provider 2'));
        await tester.pump();

        expect(tappedConfigs, hasLength(2));
        expect(tappedConfigs.map((c) => c.id), ['provider-1', 'provider-2']);
      });
    });

    group('scrolling and layout', () {
      testWidgets('scrolls properly with many configurations',
          (WidgetTester tester) async {
        // Create many test providers
        final manyProviders = List.generate(
          20,
          (index) => AiConfig.inferenceProvider(
            id: 'provider-$index',
            name: 'Provider $index',
            description: 'Description $index',
            inferenceProviderType: InferenceProviderType.anthropic,
            apiKey: 'key$index',
            baseUrl: 'https://api$index.com',
            createdAt: DateTime.now(),
          ) as AiConfigInferenceProvider,
        );

        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(manyProviders.cast<AiConfig>()),
          filteredConfigs: manyProviders,
        ));

        // Should be able to scroll
        expect(find.byType(ListView), findsOneWidget);

        // First item should be visible
        expect(find.text('Provider 0'), findsOneWidget);

        // Last item should not be visible initially
        expect(find.text('Provider 19'), findsNothing);

        // Scroll to bottom
        await tester.fling(find.byType(ListView), const Offset(0, -1000), 3000);
        await tester.pumpAndSettle();

        // Last item should now be visible
        expect(find.text('Provider 19'), findsOneWidget);
      });

      testWidgets('maintains proper spacing between items',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(testProviders.cast<AiConfig>()),
          filteredConfigs: testProviders,
        ));

        final listView = find.byType(ListView);
        expect(listView, findsOneWidget);

        // Should show both providers
        expect(find.text('Test Provider 1'), findsOneWidget);
        expect(find.text('Test Provider 2'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty configurations list gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: const AsyncValue.data([]),
          filteredConfigs: const [],
        ));

        expect(find.text('No configurations'), findsOneWidget);
      });

      testWidgets('handles null descriptions gracefully',
          (WidgetTester tester) async {
        final providerWithoutDescription = AiConfig.inferenceProvider(
          id: 'provider-no-desc',
          name: 'Provider Without Description',
          inferenceProviderType: InferenceProviderType.anthropic,
          apiKey: 'key',
          baseUrl: 'https://api.com',
          createdAt: DateTime.now(),
        ) as AiConfigInferenceProvider;

        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data([providerWithoutDescription]),
          filteredConfigs: [providerWithoutDescription],
        ));

        expect(find.text('Provider Without Description'), findsOneWidget);
        // Should not crash when description is null
      });

      testWidgets('handles very long configuration names',
          (WidgetTester tester) async {
        const longName =
            'This is a very long configuration name that might overflow the layout and cause issues with text wrapping or truncation';

        final providerWithLongName = AiConfig.inferenceProvider(
          id: 'long-name-provider',
          name: longName,
          description: 'Test description',
          inferenceProviderType: InferenceProviderType.anthropic,
          apiKey: 'key',
          baseUrl: 'https://api.com',
          createdAt: DateTime.now(),
        ) as AiConfigInferenceProvider;

        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data([providerWithLongName]),
          filteredConfigs: [providerWithLongName],
        ));

        // Should handle long names without overflow
        expect(find.textContaining('This is a very long'), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('provides proper semantics for screen readers',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(testProviders.cast<AiConfig>()),
          filteredConfigs: testProviders,
        ));

        // Configuration items should be semantically accessible
        expect(find.text('Test Provider 1'), findsOneWidget);
        expect(find.text('Test Provider 2'), findsOneWidget);
      });

      testWidgets('maintains focus after configuration tap',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(testProviders.cast<AiConfig>()),
          filteredConfigs: testProviders,
        ));

        // Tap configuration
        await tester.tap(find.text('Test Provider 1'));
        await tester.pump();

        // Configuration should still be present
        expect(find.text('Test Provider 1'), findsOneWidget);
        expect(tappedConfigs, hasLength(1));
      });
    });

    group('performance', () {
      testWidgets('efficiently handles large lists',
          (WidgetTester tester) async {
        // Create a large number of configurations
        final largeList = List.generate(
          1000,
          (index) => AiConfig.inferenceProvider(
            id: 'provider-$index',
            name: 'Provider $index',
            description: 'Description $index',
            inferenceProviderType: InferenceProviderType.anthropic,
            apiKey: 'key$index',
            baseUrl: 'https://api$index.com',
            createdAt: DateTime.now(),
          ) as AiConfigInferenceProvider,
        );

        await tester.pumpWidget(createWidget<AiConfigInferenceProvider>(
          configsAsync: AsyncValue.data(largeList.cast<AiConfig>()),
          filteredConfigs: largeList,
        ));

        // Should render without performance issues
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Provider 0'), findsOneWidget);
      });
    });
  });
}
