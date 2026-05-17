import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_provider_selection_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  FormBuilderLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

MaterialApp _appWithModal({
  required void Function(InferenceProviderType) onProviderSelected,
  required VoidCallback onDismiss,
}) {
  return MaterialApp(
    localizationsDelegates: _localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AiProviderSelectionModal(
        onProviderSelected: onProviderSelected,
        onDismiss: onDismiss,
      ),
    ),
  );
}

MaterialApp _appWithOpenButton(WidgetBuilder buttonBuilder) {
  return MaterialApp(
    localizationsDelegates: _localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: buttonBuilder),
  );
}

String _geminiDescription(BuildContext context) =>
    AppLocalizations.of(context)!.aiProviderSetupOptionGeminiDescription;
String _mlxAudioDescription(BuildContext context) =>
    AppLocalizations.of(context)!.aiProviderMlxAudioDescription;
String _openAiDescription(BuildContext context) =>
    AppLocalizations.of(context)!.aiProviderSetupOptionOpenAiDescription;
String _mistralDescription(BuildContext context) =>
    AppLocalizations.of(context)!.aiProviderSetupOptionMistralDescription;

Future<void> _expectSelectionResult(
  WidgetTester tester, {
  required String providerLabel,
  required InferenceProviderType expectedType,
}) async {
  InferenceProviderType? selectedType;

  await tester.pumpWidget(
    _appWithOpenButton(
      (context) => ElevatedButton(
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
  );

  await tester.tap(find.text('Open Modal'));
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text(providerLabel));
  await tester.tap(find.text(providerLabel));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  expect(selectedType, equals(expectedType));
}

void main() {
  group('AiProviderSelectionModal', () {
    testWidgets('displays title and provider options', (tester) async {
      await tester.pumpWidget(
        _appWithModal(onProviderSelected: (_) {}, onDismiss: () {}),
      );

      expect(find.text('Set Up AI Features'), findsOneWidget);
      expect(
        find.text('Choose your AI provider to get started:'),
        findsOneWidget,
      );
      expect(find.text('Google Gemini'), findsOneWidget);
      expect(find.text('MLX Audio (local)'), findsOneWidget);
      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Mistral'), findsOneWidget);
    });

    testWidgets('displays provider descriptions', (tester) async {
      await tester.pumpWidget(
        _appWithModal(onProviderSelected: (_) {}, onDismiss: () {}),
      );

      final context = tester.element(find.byType(AiProviderSelectionModal));
      expect(find.text(_geminiDescription(context)), findsOneWidget);
      expect(find.text(_mlxAudioDescription(context)), findsOneWidget);
      expect(find.text(_openAiDescription(context)), findsOneWidget);
      expect(find.text(_mistralDescription(context)), findsOneWidget);
    });

    testWidgets('Continue button is disabled when no provider selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appWithModal(onProviderSelected: (_) {}, onDismiss: () {}),
      );

      // LottiPrimaryButton wraps an ElevatedButton
      final continueButton = tester.widget<LottiPrimaryButton>(
        find.byType(LottiPrimaryButton),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('Continue button is enabled after selecting a provider', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appWithModal(onProviderSelected: (_) {}, onDismiss: () {}),
      );

      // Tap on Gemini option
      await tester.tap(find.text('Google Gemini'));
      await tester.pumpAndSettle();

      final continueButton = tester.widget<LottiPrimaryButton>(
        find.byType(LottiPrimaryButton),
      );
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('calls onProviderSelected for each supported provider', (
      tester,
    ) async {
      final cases = <({String label, InferenceProviderType expectedType})>[
        (
          label: 'Google Gemini',
          expectedType: InferenceProviderType.gemini,
        ),
        (
          label: 'MLX Audio (local)',
          expectedType: InferenceProviderType.mlxAudio,
        ),
        (
          label: 'OpenAI',
          expectedType: InferenceProviderType.openAi,
        ),
        (
          label: 'Mistral',
          expectedType: InferenceProviderType.mistral,
        ),
      ];

      for (final testCase in cases) {
        await _expectSelectionResult(
          tester,
          providerLabel: testCase.label,
          expectedType: testCase.expectedType,
        );
      }
    });

    testWidgets("calls onDismiss when Don't Show Again tapped", (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        _appWithOpenButton(
          (context) => ElevatedButton(
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
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't Show Again"));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('shows additional info about configuring providers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appWithModal(onProviderSelected: (_) {}, onDismiss: () {}),
      );

      expect(
        find.text(
          'You can configure additional providers later in Settings > AI.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('selecting a provider updates radio button', (tester) async {
      await tester.pumpWidget(
        _appWithModal(onProviderSelected: (_) {}, onDismiss: () {}),
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
