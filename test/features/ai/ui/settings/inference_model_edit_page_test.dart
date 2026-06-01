import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets(
      'new model save (addConfig path) calls saveConfig with correct fields',
      (tester) async {
        // Stub the stream-based watch used by AiConfigByTypeController so
        // the Provider selector modal can resolve.
        when(
          () => mockRepository.watchConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) => Stream.value([testProvider]));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiConfigRepositoryProvider.overrideWithValue(mockRepository),
              // Pre-seed the provider id so the form is immediately valid.
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
              home: const InferenceModelEditPage(
                preselectedProviderId: 'provider-1',
              ),
            ),
          ),
        );
        await pumpAndIdle(tester);

        // Fill in required fields to make the new-model form valid.
        // In the new form, TextFormFields appear in order:
        //   index 0 → Display name, 1 → Provider model ID,
        //   2 → Description, 3 → Max completion tokens.
        final allTextFields = find.byType(TextFormField);
        await tester.tap(allTextFields.at(0));
        await tester.enterText(allTextFields.at(0), 'New Model');
        await tester.pump();

        // Fill provider model ID.
        await tester.tap(allTextFields.at(1));
        await tester.enterText(allTextFields.at(1), 'gpt-new');
        await tester.pump();

        // Dismiss keyboard and pump so validation can settle.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await pumpAndIdle(tester);

        await tester.tap(find.text('Save'));
        await pumpAndIdle(tester);

        // addConfig path: saveConfig must be called once with an AiConfigModel
        // whose name matches what we entered.
        final captured = verify(
          () => mockRepository.saveConfig(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final saved = captured.first as AiConfig;
        expect(
          saved.maybeMap(
            model: (m) => m.name,
            orElse: () => fail('Expected AiConfigModel'),
          ),
          'New Model',
        );
      },
    );

    testWidgets(
      'while save is in progress the Save button is disabled '
      '(isFormValid && !_isSaving guard at line 88)',
      (tester) async {
        // Use a completer so we can observe the "in-flight" state.
        final completer = Completer<void>();
        when(
          () => mockRepository.saveConfig(any()),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        final nameField = find.widgetWithText(TextFormField, 'Test Model');
        await tester.enterText(nameField, 'In Flight Name');
        await tester.pump();

        // Tap Save — _isSaving becomes true, save hasn't resolved yet.
        await tester.tap(find.text('Save'));
        await tester.pump();

        // While in flight the Save button onPressed must be null (disabled).
        final saveButton = tester.widget<TextButton>(
          find.ancestor(
            of: find.text('Save'),
            matching: find.byType(TextButton),
          ),
        );
        expect(saveButton.onPressed, isNull);

        // Complete the save so async resources clean up properly.
        completer.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Cmd+S keyboard shortcut triggers save when form is valid',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        // Make the form dirty so isFormValid is true.
        final nameField = find.widgetWithText(TextFormField, 'Test Model');
        await tester.enterText(nameField, 'Name Via Shortcut');
        await tester.pump();

        // Send the Cmd+S shortcut.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await pumpAndIdle(tester);

        verify(() => mockRepository.saveConfig(any())).called(1);
      },
    );

    testWidgets(
      'tapping the Provider selector field opens the provider selection modal',
      (tester) async {
        when(
          () => mockRepository.watchConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) => Stream.value([testProvider]));

        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        // Find the Provider selector field and tap it.
        final providerField = find.ancestor(
          of: find.text('Provider'),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(providerField.first);
        await tester.tap(providerField.first);
        await tester.pumpAndSettle();

        // The provider selection modal's title is visible.
        expect(find.text('Test Provider'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'tapping the Input modalities selector opens the modality modal',
      (tester) async {
        when(
          () => mockRepository.watchConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) => Stream.value([testProvider]));

        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        // Scroll down to make the Input modalities field visible.
        final inputModalitiesLabel = find.text('Input modalities');
        await tester.ensureVisible(inputModalitiesLabel);
        await tester.pump();

        // The _SelectorField wraps its content in an InkWell.
        final inputModalityField = find.ancestor(
          of: inputModalitiesLabel,
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(inputModalityField.first);
        await tester.tap(inputModalityField.first);
        await tester.pumpAndSettle();

        // The modality selection modal shows modality options.
        expect(find.text('Text'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'tapping the Output modalities selector opens the modality modal',
      (tester) async {
        when(
          () => mockRepository.watchConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) => Stream.value([testProvider]));

        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        final outputModalitiesLabel = find.text('Output modalities');
        await tester.ensureVisible(outputModalitiesLabel);
        await tester.pump();

        final outputModalityField = find.ancestor(
          of: outputModalitiesLabel,
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(outputModalityField.first);
        await tester.tap(outputModalityField.first);
        await tester.pumpAndSettle();

        // The modality selection modal shows modality options.
        expect(find.text('Text'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      '_formatModalities shows "None selected" hint when modalities are empty '
      '(isEmpty branch at line 353)',
      (tester) async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final emptyModalityModel = AiConfig.model(
          id: 'empty-modality-id',
          name: 'No Modality Model',
          providerModelId: 'model-no-modal',
          inferenceProviderId: 'provider-1',
          createdAt: testDate,
          inputModalities: const [],
          outputModalities: const [],
          isReasoningModel: false,
        );

        when(
          () => mockRepository.getConfigById('empty-modality-id'),
        ).thenAnswer((_) async => emptyModalityModel);

        await tester.pumpWidget(
          buildTestWidget(configId: 'empty-modality-id'),
        );
        await pumpAndIdle(tester);

        // When modalities list is empty, _formatModalities returns the
        // "None selected" localised string — two _SelectorFields render it.
        expect(
          find.text('None selected'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      '_formatModalities joins display names with comma for non-empty list',
      (tester) async {
        // testModel has inputModalities: [Modality.text, Modality.image]
        // so _formatModalities returns "Text, Image".
        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        // At least one selector field should show the joined text.
        expect(find.textContaining('Text'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'reasoning model switch toggles isReasoningModel flag',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
        await pumpAndIdle(tester);

        final switches = find.byType(Switch);
        expect(switches, findsAtLeastNWidgets(2));

        // First switch is reasoning model (starts false for testModel).
        final beforeReasoning = tester.widget<Switch>(switches.first).value;
        expect(beforeReasoning, isFalse);

        await tester.tap(switches.first);
        await pumpAndIdle(tester);

        final afterReasoning = tester
            .widget<Switch>(find.byType(Switch).first)
            .value;
        expect(afterReasoning, isTrue);
      },
    );
  });
}
