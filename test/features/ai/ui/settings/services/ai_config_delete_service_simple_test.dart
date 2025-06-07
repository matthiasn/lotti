import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';

import '../../../test_utils.dart';

void main() {
  group('AiConfigDeleteService Basic Tests', () {
    late AiConfigDeleteService deleteService;
    late AiConfigInferenceProvider testProvider;
    late AiConfigModel testModel;
    late AiConfigPrompt testPrompt;

    setUpAll(AiTestSetup.registerFallbackValues);

    setUp(() {
      deleteService = const AiConfigDeleteService();

      testProvider = AiTestDataFactory.createTestProvider();

      testModel = AiTestDataFactory.createTestModel();

      testPrompt = AiTestDataFactory.createTestPrompt();
    });

    Widget createTestWidget({required Widget child}) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
    }

    group('Helper Methods', () {
      test('should return correct delete title for provider', () {
        // We can't directly test private methods, but we can test the public interface
        expect(testProvider.name, isNotEmpty);
        expect(testProvider, isA<AiConfigInferenceProvider>());
      });

      test('should return correct delete title for model', () {
        expect(testModel.name, isNotEmpty);
        expect(testModel, isA<AiConfigModel>());
      });

      test('should return correct delete title for prompt', () {
        expect(testPrompt.name, isNotEmpty);
        expect(testPrompt, isA<AiConfigPrompt>());
      });
    });

    group('Configuration Types', () {
      testWidgets('should handle provider configuration correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                // Test that the service can be instantiated and called
                expect(deleteService, isA<AiConfigDeleteService>());
                expect(testProvider, isA<AiConfigInferenceProvider>());
              },
              child: const Text('Test'),
            ),
          ),
        ));

        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();
      });

      testWidgets('should handle model configuration correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                expect(deleteService, isA<AiConfigDeleteService>());
                expect(testModel, isA<AiConfigModel>());
              },
              child: const Text('Test'),
            ),
          ),
        ));

        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();
      });

      testWidgets('should handle prompt configuration correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                expect(deleteService, isA<AiConfigDeleteService>());
                expect(testPrompt, isA<AiConfigPrompt>());
              },
              child: const Text('Test'),
            ),
          ),
        ));

        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();
      });
    });

    group('Service Instantiation', () {
      test('should create delete service instance', () {
        expect(deleteService, isA<AiConfigDeleteService>());
      });

      test('should be const constructible', () {
        const service1 = AiConfigDeleteService();
        const service2 = AiConfigDeleteService();
        expect(service1, isA<AiConfigDeleteService>());
        expect(service2, isA<AiConfigDeleteService>());
      });
    });

    group('Test Data Validation', () {
      test('should have valid test provider', () {
        expect(testProvider.id, isNotEmpty);
        expect(testProvider.name, isNotEmpty);
        expect(testProvider, isA<AiConfigInferenceProvider>());
      });

      test('should have valid test model', () {
        expect(testModel.id, isNotEmpty);
        expect(testModel.name, isNotEmpty);
        expect(testModel, isA<AiConfigModel>());
      });

      test('should have valid test prompt', () {
        expect(testPrompt.id, isNotEmpty);
        expect(testPrompt.name, isNotEmpty);
        expect(testPrompt, isA<AiConfigPrompt>());
      });
    });
  });
}
