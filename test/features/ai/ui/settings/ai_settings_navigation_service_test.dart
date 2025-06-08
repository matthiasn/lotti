import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../test_utils.dart';

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  group('AiSettingsNavigationService Comprehensive Tests', () {
    late AiSettingsNavigationService service;
    late AiConfig testProvider;
    late AiConfig testModel;
    late AiConfig testPrompt;

    setUpAll(AiTestSetup.registerFallbackValues);

    setUp(() {
      service = const AiSettingsNavigationService();

      testProvider = AiTestDataFactory.createTestProvider(
        id: 'test-provider-id',
        description: 'A test provider for navigation testing',
      );

      testModel = AiTestDataFactory.createTestModel(
        id: 'test-model-id',
        description: 'A test model for navigation testing',
      );

      testPrompt = AiTestDataFactory.createTestPrompt(
        id: 'test-prompt-id',
        description: 'A test prompt for navigation testing',
      );
    });

    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        home: Scaffold(
          body: child ?? const Center(child: Text('Test Widget')),
        ),
      );
    }

    group('Service Instantiation and Constants', () {
      test('should create service instance consistently', () {
        const service1 = AiSettingsNavigationService();
        const service2 = AiSettingsNavigationService();

        expect(service1.runtimeType, service2.runtimeType);
        expect(service1.getCreatePageTitle(AiConfigInferenceProvider),
            service2.getCreatePageTitle(AiConfigInferenceProvider));
      });

      test('should be immutable and const constructible', () {
        const service1 = AiSettingsNavigationService();
        const service2 = AiSettingsNavigationService();

        // Services should have identical behavior
        expect(service1.canEditConfig(testProvider),
            service2.canEditConfig(testProvider));
        expect(service1.canDeleteConfig(testModel),
            service2.canDeleteConfig(testModel));
      });

      test('should maintain deterministic behavior', () {
        const service1 = AiSettingsNavigationService();
        const service2 = AiSettingsNavigationService();

        // Same inputs should produce same outputs
        expect(service1.getEditPageTitle(AiConfigPrompt),
            service2.getEditPageTitle(AiConfigPrompt));
        expect(service1.getCreatePageTitle(AiConfigModel),
            service2.getCreatePageTitle(AiConfigModel));
      });
    });

    group('Title Helper Methods - Extended Coverage', () {
      test('should return correct create titles for all config types', () {
        expect(service.getCreatePageTitle(AiConfigInferenceProvider),
            'Add AI Inference Provider');
        expect(service.getCreatePageTitle(AiConfigModel), 'Add AI Model');
        expect(service.getCreatePageTitle(AiConfigPrompt), 'Add AI Prompt');
      });

      test('should return fallback title for unknown types', () {
        expect(service.getCreatePageTitle(String), 'Add AI Configuration');
        expect(service.getCreatePageTitle(int), 'Add AI Configuration');
        expect(service.getCreatePageTitle(Object), 'Add AI Configuration');
      });

      test('should return correct edit titles for all config types', () {
        expect(service.getEditPageTitle(AiConfigInferenceProvider),
            'Edit AI Inference Provider');
        expect(service.getEditPageTitle(AiConfigModel), 'Edit AI Model');
        expect(service.getEditPageTitle(AiConfigPrompt), 'Edit AI Prompt');
      });

      test('should return fallback title for unknown edit types', () {
        expect(service.getEditPageTitle(String), 'Edit AI Configuration');
        expect(service.getEditPageTitle(List), 'Edit AI Configuration');
        expect(service.getEditPageTitle(Map), 'Edit AI Configuration');
      });

      test('should handle null type gracefully', () {
        expect(() => service.getCreatePageTitle(Null), returnsNormally);
        expect(() => service.getEditPageTitle(Null), returnsNormally);
      });
    });

    group('Permission Checking Methods', () {
      test('should return true for all configs by default for edit permission',
          () {
        expect(service.canEditConfig(testProvider), isTrue);
        expect(service.canEditConfig(testModel), isTrue);
        expect(service.canEditConfig(testPrompt), isTrue);
      });

      test(
          'should return true for all configs by default for delete permission',
          () {
        expect(service.canDeleteConfig(testProvider), isTrue);
        expect(service.canDeleteConfig(testModel), isTrue);
        expect(service.canDeleteConfig(testPrompt), isTrue);
      });

      test('should handle multiple permission checks consistently', () {
        // Test that multiple calls return consistent results
        for (var i = 0; i < 5; i++) {
          expect(service.canEditConfig(testProvider), isTrue);
          expect(service.canDeleteConfig(testProvider), isTrue);
        }
      });

      test('should work with different config variations', () {
        final variations = [
          AiTestDataFactory.createTestProvider(
              id: 'provider-a',
              name: 'Provider A',
              type: InferenceProviderType.openAi),
          AiTestDataFactory.createTestProvider(
              id: 'provider-b', name: 'Provider B'),
          AiTestDataFactory.createTestModel(id: 'model-a', name: 'Model A'),
          AiTestDataFactory.createTestModel(id: 'model-b', name: 'Model B'),
          AiTestDataFactory.createTestPrompt(id: 'prompt-a', name: 'Prompt A'),
          AiTestDataFactory.createTestPrompt(id: 'prompt-b', name: 'Prompt B'),
        ];

        for (final config in variations) {
          expect(service.canEditConfig(config), isTrue);
          expect(service.canDeleteConfig(config), isTrue);
        }
      });
    });

    group('Config Type Recognition', () {
      test('should correctly identify provider configs', () {
        expect(testProvider, isA<AiConfigInferenceProvider>());
        expect(testProvider.runtimeType.toString(),
            contains('AiConfigInferenceProvider'));
      });

      test('should correctly identify model configs', () {
        expect(testModel, isA<AiConfigModel>());
        expect(testModel.runtimeType.toString(), contains('AiConfigModel'));
      });

      test('should correctly identify prompt configs', () {
        expect(testPrompt, isA<AiConfigPrompt>());
        expect(testPrompt.runtimeType.toString(), contains('AiConfigPrompt'));
      });

      test('should work with different inference provider types', () {
        final anthropicProvider = AiTestDataFactory.createTestProvider();
        final openAiProvider = AiTestDataFactory.createTestProvider(
            type: InferenceProviderType.openAi);
        final genericProvider = AiTestDataFactory.createTestProvider(
            type: InferenceProviderType.genericOpenAi);

        expect(anthropicProvider, isA<AiConfigInferenceProvider>());
        expect(openAiProvider, isA<AiConfigInferenceProvider>());
        expect(genericProvider, isA<AiConfigInferenceProvider>());
      });

      test('should work with different modality combinations', () {
        final textModel = AiTestDataFactory.createTestModel(
            inputModalities: [Modality.text],
            outputModalities: [Modality.text]);
        final multiModalModel = AiTestDataFactory.createTestModel(
            inputModalities: [Modality.text, Modality.image],
            outputModalities: [Modality.text, Modality.image]);

        expect(textModel, isA<AiConfigModel>());
        expect(multiModalModel, isA<AiConfigModel>());
      });
    });

    group('Navigation Method Contracts', () {
      testWidgets(
          'navigateToConfigEdit should accept valid contexts and configs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold));

        // Test that the method signature accepts the expected parameters
        expect(() => service.navigateToConfigEdit(context, testProvider),
            returnsNormally);
        expect(() => service.navigateToConfigEdit(context, testModel),
            returnsNormally);
        expect(() => service.navigateToConfigEdit(context, testPrompt),
            returnsNormally);
      });

      testWidgets('create navigation methods should accept valid contexts',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold));

        // Test that create methods don't throw on invocation
        expect(
            () => service.navigateToCreateProvider(context), returnsNormally);
        expect(() => service.navigateToCreateModel(context), returnsNormally);
        expect(() => service.navigateToCreatePrompt(context), returnsNormally);
      });
    });

    group('Route Creation Logic', () {
      testWidgets('should handle route creation for different config types',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Test that route creation methods can be called without throwing
        expect(
            () => service.navigateToConfigEdit(
                tester.element(find.byType(Scaffold)), testProvider),
            returnsNormally);
        expect(
            () => service.navigateToConfigEdit(
                tester.element(find.byType(Scaffold)), testModel),
            returnsNormally);
        expect(
            () => service.navigateToConfigEdit(
                tester.element(find.byType(Scaffold)), testPrompt),
            returnsNormally);
      });

      testWidgets('should handle page builder functions correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold));

        // These should not throw when called
        expect(
            () => service.navigateToCreateProvider(context), returnsNormally);
        expect(() => service.navigateToCreateModel(context), returnsNormally);
        expect(() => service.navigateToCreatePrompt(context), returnsNormally);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should maintain consistent behavior with various config states',
          () {
        // Test with configs that have different properties
        final emptyProvider =
            AiTestDataFactory.createTestProvider(name: '', description: '');
        final longNameModel = AiTestDataFactory.createTestModel(
            name: 'Very Long Model Name That Exceeds Normal Limits');
        final multiLinePrompt =
            AiTestDataFactory.createTestPrompt(name: 'Multi\nLine\nPrompt');

        expect(service.canEditConfig(emptyProvider), isTrue);
        expect(service.canEditConfig(longNameModel), isTrue);
        expect(service.canEditConfig(multiLinePrompt), isTrue);
      });

      test('should handle configs with special characters', () {
        final specialProvider =
            AiTestDataFactory.createTestProvider(name: r'Provider@#$%^&*()');
        final unicodeModel =
            AiTestDataFactory.createTestModel(name: 'Model 🤖 with 👍 emojis');
        final accentPrompt =
            AiTestDataFactory.createTestPrompt(name: 'Café résumé naïve');

        expect(service.canEditConfig(specialProvider), isTrue);
        expect(service.canDeleteConfig(unicodeModel), isTrue);
        expect(service.canEditConfig(accentPrompt), isTrue);
      });

      test('should work with extreme date values', () {
        final oldProvider = AiConfig.inferenceProvider(
          id: 'old-provider',
          name: 'Old Provider',
          inferenceProviderType: InferenceProviderType.anthropic,
          apiKey: 'key',
          baseUrl: 'url',
          createdAt: DateTime(1970),
        );

        final futureModel = AiConfig.model(
          id: 'future-model',
          name: 'Future Model',
          providerModelId: 'model-id',
          inferenceProviderId: 'provider-id',
          createdAt: DateTime(2030, 12, 31),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        );

        expect(service.canEditConfig(oldProvider), isTrue);
        expect(service.canDeleteConfig(futureModel), isTrue);
      });
    });

    group('Service Behavior Consistency', () {
      test('should produce same results for equivalent configs', () {
        final provider1 = AiTestDataFactory.createTestProvider(
            id: 'provider-1', name: 'Same Provider');
        final provider2 = AiTestDataFactory.createTestProvider(
            id: 'provider-2', name: 'Same Provider');

        expect(
            service.canEditConfig(provider1), service.canEditConfig(provider2));
        expect(service.canDeleteConfig(provider1),
            service.canDeleteConfig(provider2));
      });

      test('should handle rapid sequential calls', () {
        // Test that multiple rapid calls don't cause issues
        for (var i = 0; i < 100; i++) {
          expect(service.getCreatePageTitle(AiConfigInferenceProvider),
              'Add AI Inference Provider');
          expect(service.canEditConfig(testProvider), isTrue);
        }
      });

      test('should be thread-safe for immutable operations', () {
        // Test concurrent access to title methods
        final futures = <Future<String>>[];
        for (var i = 0; i < 10; i++) {
          futures.add(Future(() => service.getEditPageTitle(AiConfigModel)));
        }

        expect(Future.wait(futures), completion(everyElement('Edit AI Model')));
      });
    });

    group('Integration with Flutter Framework', () {
      testWidgets('should work with different MaterialApp configurations',
          (WidgetTester tester) async {
        // Test with basic MaterialApp
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Container()),
        ));
        await tester.pumpAndSettle();

        expect(() => service.canEditConfig(testProvider), returnsNormally);
      });

      testWidgets('should work with themed MaterialApp',
          (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: Container()),
        ));
        await tester.pumpAndSettle();

        expect(
            () => service.getCreatePageTitle(AiConfigModel), returnsNormally);
      });

      testWidgets('should handle widget disposal gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Remove widget
        await tester.pumpWidget(const SizedBox.shrink());

        // Service methods should still work (they don't depend on widget state)
        expect(service.canEditConfig(testProvider), isTrue);
        expect(service.getCreatePageTitle(AiConfigPrompt), 'Add AI Prompt');
      });
    });

    group('Performance and Memory Characteristics', () {
      test('should be lightweight and stateless', () {
        // Service should not hold any mutable state
        const service1 = AiSettingsNavigationService();
        const service2 = AiSettingsNavigationService();

        // Multiple instances should behave identically
        expect(service1.getCreatePageTitle(AiConfigInferenceProvider),
            service2.getCreatePageTitle(AiConfigInferenceProvider));
      });

      test('should handle large numbers of config objects efficiently', () {
        final configs = <AiConfig>[];

        // Create many test configs
        for (var i = 0; i < 1000; i++) {
          configs
            ..add(AiTestDataFactory.createTestProvider(
                id: 'provider-$i', name: 'Provider $i'))
            ..add(AiTestDataFactory.createTestModel(
                id: 'model-$i', name: 'Model $i'))
            ..add(AiTestDataFactory.createTestPrompt(
                id: 'prompt-$i', name: 'Prompt $i'));
        }

        // Service should handle all configs efficiently
        for (final config in configs) {
          expect(service.canEditConfig(config), isTrue);
          expect(service.canDeleteConfig(config), isTrue);
        }
      });

      test('should have consistent performance for title generation', () {
        final stopwatch = Stopwatch()..start();

        // Generate many titles
        for (var i = 0; i < 10000; i++) {
          service
            ..getCreatePageTitle(AiConfigInferenceProvider)
            ..getEditPageTitle(AiConfigModel)
            ..getCreatePageTitle(AiConfigPrompt);
        }

        stopwatch.stop();

        // Should complete quickly (generous timeout for test environment)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}
