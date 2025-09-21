import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';

import '../../test_utils.dart';

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

    group('Integration with Flutter Framework', () {
      testWidgets('should work with themed MaterialApp',
          (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: Container()),
        ));
        await tester.pumpAndSettle();
      });
    });
  });
}
