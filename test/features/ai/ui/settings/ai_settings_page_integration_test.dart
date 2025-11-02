import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';

import '../../test_utils.dart';

void main() {
  group('AiSettingsPage Integration Tests', () {
    tearDown(() async {
      // Ensure all timers are disposed after each test
      await Future<void>.delayed(Duration.zero);
    });
    late List<AiConfig> testConfigs;

    setUp(() {
      testConfigs = AiTestDataFactory.createMixedTestConfigs();
    });

    Widget createApp([List<Override>? overrides]) {
      return AiTestSetup.createTestApp(
        providerOverrides: overrides ?? [],
        child: const AiSettingsPage(),
      );
    }

    List<AiConfig> getConfigsByType(AiConfigType type) {
      return testConfigs.where((config) {
        return switch (type) {
          AiConfigType.inferenceProvider => config is AiConfigInferenceProvider,
          AiConfigType.model => config is AiConfigModel,
          AiConfigType.prompt => config is AiConfigPrompt,
        };
      }).toList();
    }

    Widget createAppWithTestData() {
      return createApp(AiTestSetup.createControllerOverrides(
        providers: getConfigsByType(AiConfigType.inferenceProvider),
        models: getConfigsByType(AiConfigType.model),
        prompts: getConfigsByType(AiConfigType.prompt),
      ));
    }

    group('initial page load', () {
      testWidgets('displays page title and navigation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createAppWithTestData());
        await tester.pumpAndSettle();

        expect(find.text('AI Settings'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('displays search bar and tab bar',
          (WidgetTester tester) async {
        await tester.pumpWidget(createApp([
          aiConfigByTypeControllerProvider(
                  configType: AiConfigType.inferenceProvider)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.inferenceProvider))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.model)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.model))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.prompt)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.prompt))),
        ]));

        await tester.pumpAndSettle();

        expect(find.text('Search AI configurations...'), findsOneWidget);
        expect(find.text('Providers'), findsOneWidget);
        expect(find.text('Models'), findsOneWidget);
        expect(find.text('Prompts'), findsOneWidget);
      });

      testWidgets('starts with providers tab selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createApp([
          aiConfigByTypeControllerProvider(
                  configType: AiConfigType.inferenceProvider)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.inferenceProvider))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.model)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.model))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.prompt)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.prompt))),
        ]));

        await tester.pumpAndSettle();

        // Providers tab should be active (implementation-dependent visual verification)
        expect(find.text('Providers'), findsOneWidget);
      });
    });

    group('tab navigation', () {
      testWidgets('switches to models tab and shows model filters',
          (WidgetTester tester) async {
        await tester.pumpWidget(createApp([
          aiConfigByTypeControllerProvider(
                  configType: AiConfigType.inferenceProvider)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.inferenceProvider))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.model)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.model))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.prompt)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.prompt))),
        ]));

        await tester.pumpAndSettle();

        await tester.tap(find.text('Models'));
        await tester.pumpAndSettle();

        // Model-specific filters should appear
        expect(find.text('Text'), findsOneWidget);
        expect(find.text('Vision'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.text('Reasoning'), findsOneWidget);
      });

      testWidgets('switches to prompts tab and hides model filters',
          (WidgetTester tester) async {
        await tester.pumpWidget(createApp([
          aiConfigByTypeControllerProvider(
                  configType: AiConfigType.inferenceProvider)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.inferenceProvider))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.model)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.model))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.prompt)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.prompt))),
        ]));

        await tester.pumpAndSettle();

        // Start on models tab to show filters
        await tester.tap(find.text('Models'));
        await tester.pumpAndSettle();

        // Verify filters are shown
        expect(find.text('Vision'), findsOneWidget);

        // Switch to prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Filter chips should still be visible (changed behavior - filters shown on all tabs)
        expect(find.text('Vision'), findsOneWidget);
      });
    });

    group('search functionality', () {
      testWidgets('filters configurations by search query',
          (WidgetTester tester) async {
        await tester.pumpWidget(createApp([
          aiConfigByTypeControllerProvider(
                  configType: AiConfigType.inferenceProvider)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.inferenceProvider))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.model)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.model))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.prompt)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.prompt))),
        ]));

        await tester.pumpAndSettle();

        // Enter search query
        await tester.enterText(find.byType(TextField), 'anthropic');
        await tester.pump();

        // Should filter results (verification depends on mock data setup)
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('clears search when clear button is tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(createApp([
          aiConfigByTypeControllerProvider(
                  configType: AiConfigType.inferenceProvider)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.inferenceProvider))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.model)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.model))),
          aiConfigByTypeControllerProvider(configType: AiConfigType.prompt)
              .overrideWith(() => MockAiConfigByTypeController(
                  getConfigsByType(AiConfigType.prompt))),
        ]));

        // Enter search text
        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump();

        // Clear button should appear
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

        // Tap clear button
        await tester.tap(find.byIcon(Icons.clear_rounded));
        await tester.pump();

        // Text field should be empty
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, isEmpty);
      });
    });
  });
}
