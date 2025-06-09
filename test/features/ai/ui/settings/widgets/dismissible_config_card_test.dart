import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/features/ai/ui/settings/widgets/dismiss_background.dart';
import 'package:lotti/features/ai/ui/settings/widgets/dismissible_config_card.dart';

void main() {
  group('DismissibleConfigCard', () {
    late AiConfigInferenceProvider testProvider;
    late AiConfigModel testModel;
    late bool tapCalled;

    setUp(() {
      tapCalled = false;

      testProvider = AiConfig.inferenceProvider(
        id: 'test-provider',
        name: 'Test Provider',
        description: 'Test description',
        inferenceProviderType: InferenceProviderType.anthropic,
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        createdAt: DateTime.now(),
      ) as AiConfigInferenceProvider;

      testModel = AiConfig.model(
        id: 'test-model',
        name: 'Test Model',
        description: 'Model description',
        providerModelId: 'model-id',
        inferenceProviderId: 'provider-id',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text, Modality.image],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      ) as AiConfigModel;
    });

    Widget createWidget<T extends AiConfig>({
      required T config,
      bool showCapabilities = false,
      bool isCompact = false,
    }) {
      return ProviderScope(
        overrides: [
          // Mock provider lookups for models that reference providers
          aiConfigByIdProvider('provider-id').overrideWith((ref) async {
            return testProvider;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                DismissibleConfigCard<T>(
                  config: config,
                  onTap: () => tapCalled = true,
                  showCapabilities: showCapabilities,
                  isCompact: isCompact,
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('displays AiConfigCard', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      expect(find.byType(AiConfigCard), findsOneWidget);
      expect(find.text('Test Provider'), findsOneWidget);
    });

    testWidgets('is wrapped in Dismissible', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('has correct dismiss direction', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible),
      );
      expect(dismissible.direction, DismissDirection.endToStart);
    });

    testWidgets('uses config id as key', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible),
      );
      expect(dismissible.key, ValueKey(testProvider.id));
    });

    testWidgets('shows dismiss background when swiping',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      // Start swipe gesture - use specific type parameter
      await tester.drag(
        find.byType(DismissibleConfigCard<AiConfigInferenceProvider>),
        const Offset(-100, 0),
      );
      await tester.pump();

      expect(find.byType(DismissBackground), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      await tester.tap(find.byType(AiConfigCard));
      await tester.pump();

      expect(tapCalled, isTrue);
    });

    testWidgets('passes showCapabilities to AiConfigCard',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        config: testModel,
        showCapabilities: true,
      ));

      final card = tester.widget<AiConfigCard>(
        find.byType(AiConfigCard),
      );
      expect(card.showCapabilities, isTrue);
    });

    testWidgets('passes isCompact to AiConfigCard',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        config: testProvider,
        isCompact: true,
      ));

      final card = tester.widget<AiConfigCard>(
        find.byType(AiConfigCard),
      );
      expect(card.isCompact, isTrue);
    });

    testWidgets('works with different config types - provider',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      expect(find.text('Test Provider'), findsOneWidget);
      expect(find.text('Test description'), findsOneWidget);
    });

    testWidgets('works with different config types - model',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        config: testModel,
        showCapabilities: true,
      ));

      expect(find.text('Test Model'), findsOneWidget);
      expect(find.text('Model description'), findsOneWidget);

      // Should show capability indicators
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('maintains dismiss functionality across rebuilds',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      // Start swipe - use specific type parameter
      await tester.drag(
        find.byType(DismissibleConfigCard<AiConfigInferenceProvider>),
        const Offset(-50, 0),
      );
      await tester.pump();

      // Trigger rebuild by updating widget
      await tester.pumpWidget(createWidget(
        config: testProvider,
        isCompact: true,
      ));

      // Card should still be visible
      expect(find.byType(AiConfigCard), findsOneWidget);
    });

    testWidgets('dismissible has confirm dismiss callback',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(config: testProvider));

      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible),
      );

      expect(dismissible.confirmDismiss, isNotNull);
    });
  });
}
