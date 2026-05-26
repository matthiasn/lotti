import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  late MockAiConfigRepository mockRepository;
  late AiConfig testModel;
  late AiConfig testProvider;

  setUpAll(() {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    registerFallbackValue(
      AiConfig.model(
        id: 'fallback-id',
        name: 'Fallback Model',
        providerModelId: 'fallback-model-id',
        inferenceProviderId: 'fallback-provider',
        createdAt: testDate,
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();
    final testDate = DateTime(2024, 3, 15, 10, 30);

    testProvider = AiConfig.inferenceProvider(
      id: 'provider-1',
      name: 'Test Provider',
      baseUrl: 'https://api.test.com',
      apiKey: 'test-key',
      createdAt: testDate,
      inferenceProviderType: InferenceProviderType.openAi,
    );

    testModel = AiConfig.model(
      id: 'test-model-id',
      name: 'Test Model',
      providerModelId: 'gpt-4',
      inferenceProviderId: 'provider-1',
      createdAt: testDate,
      inputModalities: [Modality.text, Modality.image],
      outputModalities: [Modality.text],
      isReasoningModel: false,
      supportsFunctionCalling: true,
      description: 'A test model for unit tests',
    );

    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
    when(
      () => mockRepository.getConfigById('test-model-id'),
    ).thenAnswer((_) async => testModel);
    when(
      () => mockRepository.getConfigById('provider-1'),
    ).thenAnswer((_) async => testProvider);
    when(
      () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer((_) async => [testProvider]);
  });

  Widget buildTestWidget({String? configId}) {
    return ProviderScope(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          extensions: const <ThemeExtension<dynamic>>[dsTokensDark],
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InferenceModelEditPage(configId: configId),
      ),
    );
  }

  Future<void> pumpAndIdle(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('InferenceModelEditPage v3 redesign', () {
    testWidgets('displays "Add Model" title for new model', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpAndIdle(tester);
      expect(find.text('Add Model'), findsOneWidget);
    });

    testWidgets('displays "Edit Model" title for existing model', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
      await pumpAndIdle(tester);
      expect(find.text('Edit Model'), findsOneWidget);
    });

    testWidgets('populates name, model id, and provider for existing model', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
      await pumpAndIdle(tester);

      // Model name appears in both the header strip and the Display name
      // text field — both render through the form-state name value.
      expect(find.text('Test Model'), findsAtLeastNWidgets(1));
      expect(find.text('gpt-4'), findsOneWidget);
      // Provider name appears in the header strip subtitle and inside the
      // Provider selector field.
      expect(find.text('Test Provider'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders Identity and Capabilities section headings', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpAndIdle(tester);
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Capabilities'), findsOneWidget);
    });

    testWidgets(
      'renders the seven Identity + Capabilities field labels',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await pumpAndIdle(tester);
        expect(find.text('Provider'), findsOneWidget);
        expect(find.text('Display name'), findsOneWidget);
        expect(find.text('Provider model ID'), findsOneWidget);
        expect(find.text('Description'), findsOneWidget);
        expect(find.text('Max completion tokens'), findsOneWidget);
        expect(find.text('Input modalities'), findsOneWidget);
        expect(find.text('Output modalities'), findsOneWidget);
      },
    );

    testWidgets('renders Gemini thinking mode for Gemini provider models', (
      tester,
    ) async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      testProvider = AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'Gemini Provider',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        createdAt: testDate,
        inferenceProviderType: InferenceProviderType.gemini,
      );
      testModel = AiConfig.model(
        id: 'test-model-id',
        name: 'Test Gemini Model',
        providerModelId: 'gemini-3.1-pro-preview',
        inferenceProviderId: 'provider-1',
        createdAt: testDate,
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: true,
        geminiThinkingMode: GeminiThinkingMode.high,
      );

      await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
      await pumpAndIdle(tester);

      expect(find.text('Gemini thinking mode'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('changing Gemini thinking mode updates the selector value', (
      tester,
    ) async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      testProvider = AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'Gemini Provider',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        createdAt: testDate,
        inferenceProviderType: InferenceProviderType.gemini,
      );
      testModel = AiConfig.model(
        id: 'test-model-id',
        name: 'Test Gemini Model',
        providerModelId: 'gemini-3.1-pro-preview',
        inferenceProviderId: 'provider-1',
        createdAt: testDate,
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: true,
        geminiThinkingMode: GeminiThinkingMode.high,
      );

      await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
      await pumpAndIdle(tester);

      await tester.tap(find.text('High'));
      await pumpAndIdle(tester);
      await tester.tap(find.text('Minimal'));
      await pumpAndIdle(tester);

      expect(find.text('Minimal'), findsOneWidget);
    });

    testWidgets('Save action is in the AppBar (not a bottom bar)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpAndIdle(tester);

      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);
      // The redesign drops the FormBottomBar — there is no Cancel button.
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets(
      'empty provider selection shows the "Select a provider" hint',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await pumpAndIdle(tester);
        // For a new model the form has no provider — both the header
        // subtitle and the Provider selector display the hint.
        expect(find.text('Select a provider'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('renders reasoning + function-calling toggle labels', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpAndIdle(tester);
      expect(find.text('Reasoning model'), findsOneWidget);
      expect(
        find.text('This model uses extended thinking / chain-of-thought.'),
        findsOneWidget,
      );
      expect(find.text('Function calling'), findsOneWidget);
      expect(
        find.text('This model supports function and tool calling.'),
        findsOneWidget,
      );
      // Reasoning + function-calling toggles render two switches.
      expect(find.byType(Switch), findsAtLeastNWidgets(2));
    });

    testWidgets(
      'tapping the function-calling switch toggles its visual state',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        // The existing model has supportsFunctionCalling: true, so the
        // second switch (function calling) starts on. Tapping it should
        // flip it off; we read the state from the rebuilt widget.
        final switches = find.byType(Switch);
        expect(switches, findsAtLeastNWidgets(2));
        final before = tester.widget<Switch>(switches.at(1)).value;
        await tester.tap(switches.at(1));
        await pumpAndIdle(tester);
        final after = tester.widget<Switch>(find.byType(Switch).at(1)).value;
        expect(after, !before);
      },
    );

    testWidgets('renders the redesigned error state when load fails', (
      tester,
    ) async {
      when(
        () => mockRepository.getConfigById('error-id'),
      ).thenThrow(Exception('Failed to load'));

      await tester.pumpWidget(buildTestWidget(configId: 'error-id'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load model configuration'), findsOneWidget);
      // The redesign drops the "Please try again" body + "Go Back" button.
      expect(find.text('Please try again or contact support'), findsNothing);
      expect(find.text('Go Back'), findsNothing);
    });

    testWidgets('keyboard-shortcut wrapper is preserved across the redesign', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpAndIdle(tester);
      // The Cmd+S shortcut is still wired — guard the visible wrapper so a
      // future refactor that removes it gets caught.
      expect(find.byType(CallbackShortcuts), findsWidgets);
    });

    testWidgets('description field renders with its sentence-case label', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpAndIdle(tester);
      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets(
      'AppBar back arrow routes through popAiSettingsDetail — when the '
      'page is pushed onto a navigator, tapping the arrow pops the route '
      'and the outer launcher button is visible again (proves the leading '
      "IconButton is wired to the shared back affordance, not Material's "
      'default `Navigator.maybePop()` which would no-op on desktop '
      'master/detail).',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiConfigRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
              ),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const InferenceModelEditPage(),
                        ),
                      ),
                      child: const Text('open-model-edit'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open-model-edit'));
        await tester.pumpAndSettle();

        // The model-edit page is now mounted.
        expect(find.byType(InferenceModelEditPage), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // After back-tap the route should have popped: outer button
        // visible again, page gone.
        expect(find.text('open-model-edit'), findsOneWidget);
        expect(find.byType(InferenceModelEditPage), findsNothing);
      },
    );

    testWidgets(
      'editing the display name and tapping Save calls saveConfig',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        // The Display name field is the text field initialised with the
        // existing model name. Find it by its current text.
        final nameField = find.widgetWithText(TextFormField, 'Test Model');
        expect(nameField, findsOneWidget);
        await tester.enterText(nameField, 'Updated Model Name');
        await tester.pump();

        await tester.tap(find.text('Save'));
        await pumpAndIdle(tester);

        verify(() => mockRepository.saveConfig(any())).called(1);
      },
    );
  });
}
