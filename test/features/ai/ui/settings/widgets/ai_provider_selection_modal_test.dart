import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_provider_selection_modal.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

void main() {
  group('AiProviderSelectionModal', () {
    testWidgets('displays title and provider options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiProviderSelectionModal(
              onProviderSelected: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('Set Up AI Features'), findsOneWidget);
      expect(
          find.text('Choose your AI provider to get started:'), findsOneWidget);
      expect(find.text('Google Gemini'), findsOneWidget);
      expect(find.text('OpenAI'), findsOneWidget);
    });

    testWidgets('displays provider descriptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiProviderSelectionModal(
              onProviderSelected: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Uses descriptions from AiProviderOption extension
      expect(
        find.text(AiProviderOption.gemini.description),
        findsOneWidget,
      );
      expect(
        find.text(AiProviderOption.openAi.description),
        findsOneWidget,
      );
    });

    testWidgets('Continue button is disabled when no provider selected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiProviderSelectionModal(
              onProviderSelected: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // LottiPrimaryButton wraps an ElevatedButton
      final continueButton = tester.widget<LottiPrimaryButton>(
        find.byType(LottiPrimaryButton),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('Continue button is enabled after selecting a provider',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiProviderSelectionModal(
              onProviderSelected: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Tap on Gemini option
      await tester.tap(find.text('Google Gemini'));
      await tester.pumpAndSettle();

      final continueButton = tester.widget<LottiPrimaryButton>(
        find.byType(LottiPrimaryButton),
      );
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('calls onProviderSelected with gemini when Gemini selected',
        (tester) async {
      InferenceProviderType? selectedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await AiProviderSelectionModal.show(
                  context,
                  onProviderSelected: (type) => selectedType = type,
                  onDismiss: () {},
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Select Gemini
      await tester.tap(find.text('Google Gemini'));
      await tester.pumpAndSettle();

      // Tap Continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(selectedType, equals(InferenceProviderType.gemini));
    });

    testWidgets('calls onProviderSelected with openAi when OpenAI selected',
        (tester) async {
      InferenceProviderType? selectedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await AiProviderSelectionModal.show(
                  context,
                  onProviderSelected: (type) => selectedType = type,
                  onDismiss: () {},
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Select OpenAI
      await tester.tap(find.text('OpenAI'));
      await tester.pumpAndSettle();

      // Tap Continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(selectedType, equals(InferenceProviderType.openAi));
    });

    testWidgets("calls onDismiss when Don't Show Again tapped", (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await AiProviderSelectionModal.show(
                  context,
                  onProviderSelected: (_) {},
                  onDismiss: () => dismissed = true,
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't Show Again"));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('shows additional info about configuring providers',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiProviderSelectionModal(
              onProviderSelected: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(
        find.text(
            'You can configure additional providers later in Settings > AI.'),
        findsOneWidget,
      );
    });

    testWidgets('selecting a provider updates radio button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiProviderSelectionModal(
              onProviderSelected: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Initially no radio is selected - check RadioGroup's groupValue
      final initialRadioGroup = tester.widget<RadioGroup<AiProviderOption>>(
        find.byType(RadioGroup<AiProviderOption>),
      );
      expect(initialRadioGroup.groupValue, isNull);

      // Tap on OpenAI option
      await tester.tap(find.text('OpenAI'));
      await tester.pumpAndSettle();

      // RadioGroup should now have OpenAI selected
      final updatedRadioGroup = tester.widget<RadioGroup<AiProviderOption>>(
        find.byType(RadioGroup<AiProviderOption>),
      );
      expect(updatedRadioGroup.groupValue, equals(AiProviderOption.openAi));
    });
  });
}
