import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/widgets/profile_pinning_selector.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart';

void main() {
  late StreamController<List<AiConfig>> profileStreamController;
  late _FakeInferenceProfileController fakeProfileController;
  late MockAiConfigRepository mockAiConfigRepository;

  setUp(() {
    profileStreamController = StreamController<List<AiConfig>>();
    fakeProfileController = _FakeInferenceProfileController()
      ..streamController = profileStreamController;
    mockAiConfigRepository = MockAiConfigRepository();
  });

  tearDown(() {
    profileStreamController.close();
  });

  Widget buildSubject({
    AiConfigInferenceProfile? existingProfile,
    List<AiConfig> models = const [],
    List<AiConfig> providers = const [],
    List<SyncNodeProfile> knownNodes = const [],
  }) {
    when(
      () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => models);

    return makeTestableWidgetNoScroll(
      InferenceProfileForm(existingProfile: existingProfile),
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        inferenceProfileControllerProvider.overrideWith(() {
          return fakeProfileController;
        }),
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.model,
        ).overrideWith(() {
          return _FakeAiConfigByTypeController(models);
        }),
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.inferenceProvider,
        ).overrideWith(() {
          return _FakeAiConfigByTypeController(providers);
        }),
        // Stub the pinning selector's data sources so the form's existing
        // tests don't need to register a real sync stack.
        knownSyncNodesProvider.overrideWith((_) => Stream.value(knownNodes)),
        localVectorClockHostIdProvider.overrideWith((_) async => null),
      ],
    );
  }

  group('InferenceProfileForm', () {
    testWidgets('shows create title when no existing profile', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Create Profile'), findsOneWidget);
    });

    testWidgets('shows edit title when editing existing profile', (
      tester,
    ) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'Existing Profile',
      );

      await tester.pumpWidget(buildSubject(existingProfile: profile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('populates form fields when editing', (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'My Profile',
        desktopOnly: true,
      );

      await tester.pumpWidget(buildSubject(existingProfile: profile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Name should be pre-filled.
      final nameField = find.widgetWithText(TextFormField, 'My Profile');
      expect(nameField, findsOneWidget);

      // Scroll down to the desktop toggle.
      final desktopToggle = find.widgetWithText(
        SwitchListTile,
        'Desktop Only',
      );
      await tester.scrollUntilVisible(
        desktopToggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Desktop toggle should be on.
      final switchTile = tester.widget<SwitchListTile>(desktopToggle);
      expect(switchTile.value, isTrue);
    });

    testWidgets('shows all five model slot fields', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Thinking *'), findsOneWidget);
      expect(find.text('Thinking (High-End)'), findsOneWidget);
      expect(find.text('Image Recognition'), findsOneWidget);
      expect(find.text('Transcription'), findsOneWidget);
      expect(find.text('Image Generation'), findsOneWidget);
    });

    testWidgets('shows save button in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets(
      'AppBar back arrow routes through popAiSettingsDetail — when the '
      'form is pushed onto a navigator, tapping the arrow pops the route '
      'and the outer launcher button is visible again (proves the leading '
      "IconButton is wired to the shared back affordance, not Material's "
      'default `Navigator.maybePop()` which would no-op on desktop '
      'master/detail).',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const InferenceProfileForm(),
                      ),
                    ),
                    child: const Text('open-form'),
                  ),
                ),
              ),
            ),
            overrides: [
              inferenceProfileControllerProvider.overrideWith(
                () => fakeProfileController,
              ),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.model,
              ).overrideWith(() => _FakeAiConfigByTypeController(const [])),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(() => _FakeAiConfigByTypeController(const [])),
            ],
          ),
        );

        await tester.tap(find.text('open-form'));
        await tester.pumpAndSettle();

        // The form is now mounted; confirm by finding its create title.
        expect(find.text('Create Profile'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // After back-tap the route should have popped: outer button
        // visible again, form gone.
        expect(find.text('open-form'), findsOneWidget);
        expect(find.text('Create Profile'), findsNothing);
      },
    );

    testWidgets('validates name is required', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap save without entering a name.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('A profile name is required'), findsOneWidget);
    });

    testWidgets('shows desktop-only toggle with description', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll down to the desktop toggle (may be off-screen with 5 slots).
      await tester.scrollUntilVisible(
        find.text('Desktop Only'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Desktop Only'), findsOneWidget);
      expect(
        find.text(
          'Only available on desktop platforms (e.g. for local models)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows select model placeholder for empty slots', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify each model slot label and its placeholder are present.
      // Use scrollUntilVisible since the ListView may not render all at once.
      for (final label in [
        'Thinking *',
        'Thinking (High-End)',
        'Image Recognition',
        'Transcription',
        'Image Generation',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(label), findsOneWidget);
      }
      // At least the visible slots should show placeholders.
      expect(find.text('Select a model…'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows snackbar when saving without thinking model', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter a name to pass validation.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile Name'),
        'Test Profile',
      );

      // Tap save — no thinking model selected.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('A thinking model is required'),
        findsOneWidget,
      );
    });

    testWidgets('saves profile and pops when thinking model is selected', (
      tester,
    ) async {
      final thinkingModel =
          AiConfig.model(
                id: 'tm-1',
                name: 'Flash',
                providerModelId: 'models/flash',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;

      final provider =
          AiConfig.inferenceProvider(
                id: 'prov-1',
                name: 'Provider',
                baseUrl: 'https://example.com',
                apiKey: 'key',
                createdAt: DateTime(2024),
                inferenceProviderType: InferenceProviderType.gemini,
              )
              as AiConfigInferenceProvider;

      await tester.pumpWidget(
        buildSubject(
          models: [thinkingModel],
          providers: [provider],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter name.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile Name'),
        'My New Profile',
      );

      // Tap the thinking model slot InkWell to open picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select the model.
      await tester.tap(find.text('Flash'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap save.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the profile was saved.
      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(fakeProfileController.savedProfiles.first.name, 'My New Profile');
      expect(
        fakeProfileController.savedProfiles.first.thinkingModelId,
        'tm-1',
      );
    });

    testWidgets('shows error snackbar when save fails', (tester) async {
      fakeProfileController.shouldThrowOnSave = true;

      final existingProfile = testInferenceProfile(
        id: 'p1',
        name: 'Existing',
      );

      await tester.pumpWidget(
        buildSubject(existingProfile: existingProfile),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap save — has name and thinking model from existing profile.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Error snackbar should appear.
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('model slot shows selected model name', (tester) async {
      final thinkingModel =
          AiConfig.model(
                id: 'tm-1',
                name: 'Gemini Pro',
                providerModelId: 'models/gemini-pro',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;

      // Editing a profile that already has this model selected.
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'My Profile',
        thinkingModelId: 'models/gemini-pro',
      );

      await tester.pumpWidget(
        buildSubject(
          existingProfile: profile,
          models: [thinkingModel],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The model name should be shown in the thinking slot.
      expect(find.text('Gemini Pro'), findsOneWidget);
    });

    testWidgets(
      'model slot shows unavailable message (not the raw id) when the '
      'model no longer resolves — e.g. its provider was deleted and its '
      'models were cascade-removed',
      (tester) async {
        // Edit a profile whose slot points at a model id that no longer
        // matches any loaded model row, as happens after the model's
        // inference provider is deleted.
        final profile = testInferenceProfile(
          id: 'p1',
          name: 'My Profile',
          thinkingModelId: 'models/unknown-model',
        );

        await tester.pumpWidget(
          buildSubject(existingProfile: profile),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The dangling slot shows a clear "unavailable" message instead of
        // leaking the raw composite id.
        expect(
          find.text('Model unavailable — its provider may have been removed'),
          findsOneWidget,
        );
        expect(find.text('models/unknown-model'), findsNothing);
      },
    );

    testWidgets(
      'unavailable slot keeps its clear (×) action so the dangling '
      'reference can be reset',
      (tester) async {
        final profile = testInferenceProfile(
          id: 'p1',
          name: 'My Profile',
          thinkingModelId: 'models/unknown-model',
        );

        await tester.pumpWidget(
          buildSubject(existingProfile: profile),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The unavailable message is shown and a clear button is present.
        expect(
          find.text('Model unavailable — its provider may have been removed'),
          findsOneWidget,
        );

        // Clearing the slot drops the dangling id and reveals the
        // placeholder again.
        await tester.tap(find.byIcon(Icons.clear).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Model unavailable — its provider may have been removed'),
          findsNothing,
        );
        expect(find.text('Select a model…'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('clear button removes selected model', (tester) async {
      final thinkingModel =
          AiConfig.model(
                id: 'tm-1',
                name: 'Flash',
                providerModelId: 'models/flash',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;

      final profile = testInferenceProfile(
        id: 'p1',
        name: 'My Profile',
        thinkingModelId: 'models/flash',
      );

      await tester.pumpWidget(
        buildSubject(
          existingProfile: profile,
          models: [thinkingModel],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially the model name is shown.
      expect(find.text('Flash'), findsOneWidget);

      // Tap the clear button.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Model name should be gone, placeholder shown.
      expect(find.text('Flash'), findsNothing);
      // Should now show placeholder or raw ID gone.
      expect(find.text('Select a model…'), findsAtLeastNWidgets(1));
    });

    testWidgets('desktop-only toggle changes value', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final desktopToggle = find.widgetWithText(
        SwitchListTile,
        'Desktop Only',
      );

      // Scroll down to make the toggle visible.
      await tester.scrollUntilVisible(
        desktopToggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially off.
      var switchTile = tester.widget<SwitchListTile>(desktopToggle);
      expect(switchTile.value, isFalse);

      // Toggle on.
      await tester.tap(desktopToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      switchTile = tester.widget<SwitchListTile>(desktopToggle);
      expect(switchTile.value, isTrue);
    });

    testWidgets('description field is shown and editable', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Description'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'A helpful profile',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('A helpful profile'), findsOneWidget);
    });

    testWidgets('only shows models matching slot filter in picker', (
      tester,
    ) async {
      // Create a model that supports function calling (thinking slot).
      final thinkingModel = AiConfig.model(
        id: 'tm-1',
        name: 'Thinking Model',
        providerModelId: 'models/thinking',
        inferenceProviderId: 'prov-1',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );
      // Create a model that does NOT support function calling.
      final otherModel = AiConfig.model(
        id: 'tm-2',
        name: 'Other Model',
        providerModelId: 'models/other',
        inferenceProviderId: 'prov-1',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      );

      await tester.pumpWidget(
        buildSubject(models: [thinkingModel, otherModel]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open the thinking model picker by tapping the InkWell wrapping the slot.
      // The first InputDecorator is the thinking slot.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Only the thinking model should appear (filtered by supportsFunctionCalling).
      expect(find.text('Thinking Model'), findsOneWidget);
      expect(find.text('Other Model'), findsNothing);
    });

    testWidgets('model picker shows provider name in subtitle', (tester) async {
      final thinkingModel = AiConfig.model(
        id: 'tm-1',
        name: 'Flash',
        providerModelId: 'models/flash',
        inferenceProviderId: 'prov-1',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      final provider = AiConfig.inferenceProvider(
        id: 'prov-1',
        name: 'Google AI',
        baseUrl: 'https://example.com',
        apiKey: 'key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await tester.pumpWidget(
        buildSubject(
          models: [thinkingModel],
          providers: [provider],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open the thinking model picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Provider name should appear as part of the subtitle.
      expect(find.textContaining('Google AI'), findsOneWidget);
      expect(find.textContaining('models/flash'), findsOneWidget);
    });

    testWidgets('model picker shows checkmark for selected model', (
      tester,
    ) async {
      final thinkingModel = AiConfig.model(
        id: 'tm-1',
        name: 'Flash',
        providerModelId: 'models/flash',
        inferenceProviderId: 'prov-1',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      // Editing a profile that already has this model selected.
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'My Profile',
        thinkingModelId: 'models/flash',
      );

      await tester.pumpWidget(
        buildSubject(
          existingProfile: profile,
          models: [thinkingModel],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open the thinking model picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Selected model should show a check icon.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    group('model picker search field', () {
      // Three thinking-eligible models across two providers — the
      // shared fixture lets the search tests assert filter narrowing
      // (one match), filter widening via clear, provider-name match
      // (cross-row scoping), and the no-match empty state without
      // re-declaring rows in every test.
      final flashModel = AiConfig.model(
        id: 'm-1',
        name: 'Gemini Flash',
        providerModelId: 'models/gemini-flash',
        inferenceProviderId: 'prov-google',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );
      final proModel = AiConfig.model(
        id: 'm-2',
        name: 'Gemini Pro',
        providerModelId: 'models/gemini-pro',
        inferenceProviderId: 'prov-google',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );
      final sonnetModel = AiConfig.model(
        id: 'm-3',
        name: 'Claude Sonnet',
        providerModelId: 'models/claude-sonnet',
        inferenceProviderId: 'prov-anthropic',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      final googleProvider = AiConfig.inferenceProvider(
        id: 'prov-google',
        name: 'Google AI',
        baseUrl: 'https://example.com',
        apiKey: 'key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );
      final anthropicProvider = AiConfig.inferenceProvider(
        id: 'prov-anthropic',
        name: 'Anthropic',
        baseUrl: 'https://example.com',
        apiKey: 'key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      Future<void> openThinkingPicker(WidgetTester tester) async {
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Scope the TextField finder to the search field inside the
      // picker — the underlying profile form also renders TextFields
      // (name, description, …) which would otherwise satisfy a bare
      // `find.byType(TextField)` and trip "Too many elements".
      Finder searchTextField() => find.descendant(
        of: find.byType(DesignSystemSearch),
        matching: find.byType(TextField),
      );

      testWidgets(
        'typing a query that matches one model by display name '
        'narrows the list to that row — proves the substring filter '
        'runs against AiConfigModel.name',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              models: [flashModel, proModel, sonnetModel],
              providers: [googleProvider, anthropicProvider],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await openThinkingPicker(tester);

          // All three rows visible before any input.
          expect(find.text('Gemini Flash'), findsOneWidget);
          expect(find.text('Gemini Pro'), findsOneWidget);
          expect(find.text('Claude Sonnet'), findsOneWidget);

          await tester.enterText(searchTextField(), 'sonnet');
          await tester.pump();

          // Only the Sonnet row remains; the Gemini rows are filtered out.
          expect(find.text('Claude Sonnet'), findsOneWidget);
          expect(find.text('Gemini Flash'), findsNothing);
          expect(find.text('Gemini Pro'), findsNothing);
        },
      );

      testWidgets(
        'typing a provider name surfaces every model owned by that '
        'provider — proves the filter widens to the resolved provider '
        'label, not just the model row text, so users can pivot by '
        'provider without remembering each model name',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              models: [flashModel, proModel, sonnetModel],
              providers: [googleProvider, anthropicProvider],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await openThinkingPicker(tester);

          await tester.enterText(searchTextField(), 'Google');
          await tester.pump();

          // Both Gemini rows match via the Google AI provider label.
          // Claude Sonnet (Anthropic) is filtered out.
          expect(find.text('Gemini Flash'), findsOneWidget);
          expect(find.text('Gemini Pro'), findsOneWidget);
          expect(find.text('Claude Sonnet'), findsNothing);
        },
      );

      testWidgets(
        'a query that matches no model surfaces the localised '
        '"No matches" empty state instead of leaving the list region '
        'blank — the user gets explicit feedback that the filter, not '
        'the data, is responsible for the empty surface',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              models: [flashModel, proModel, sonnetModel],
              providers: [googleProvider, anthropicProvider],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await openThinkingPicker(tester);

          await tester.enterText(searchTextField(), 'zzz-nope');
          await tester.pump();

          expect(find.text('No matches'), findsOneWidget);
          expect(find.text('Gemini Flash'), findsNothing);
          expect(find.text('Gemini Pro'), findsNothing);
          expect(find.text('Claude Sonnet'), findsNothing);
        },
      );

      testWidgets(
        'clearing the query via the search field clear affordance '
        'restores every model — proves the filter state resets to the '
        'unfiltered list rather than leaving stale matches on screen',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              models: [flashModel, proModel, sonnetModel],
              providers: [googleProvider, anthropicProvider],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await openThinkingPicker(tester);

          await tester.enterText(searchTextField(), 'sonnet');
          await tester.pump();
          expect(find.text('Gemini Flash'), findsNothing);

          // DesignSystemSearch renders the clear affordance as
          // Icons.cancel_rounded inside its decoration.
          await tester.tap(find.byIcon(Icons.cancel_rounded));
          await tester.pump();

          expect(find.text('Gemini Flash'), findsOneWidget);
          expect(find.text('Gemini Pro'), findsOneWidget);
          expect(find.text('Claude Sonnet'), findsOneWidget);
        },
      );
    });

    testWidgets('saves profile with description', (tester) async {
      final thinkingModel =
          AiConfig.model(
                id: 'tm-1',
                name: 'Flash',
                providerModelId: 'models/flash',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;

      await tester.pumpWidget(
        buildSubject(models: [thinkingModel]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter name.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile Name'),
        'Described Profile',
      );

      // Enter description.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'A test description',
      );

      // Select thinking model.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Flash'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Save.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(
        fakeProfileController.savedProfiles.first.description,
        'A test description',
      );
    });

    testWidgets('saves profile with desktop-only enabled', (tester) async {
      final thinkingModel =
          AiConfig.model(
                id: 'tm-1',
                name: 'Flash',
                providerModelId: 'models/flash',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;

      await tester.pumpWidget(
        buildSubject(models: [thinkingModel]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter name.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile Name'),
        'Desktop Profile',
      );

      // Select thinking model.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Flash'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll down and enable desktop-only toggle.
      final desktopToggle = find.widgetWithText(
        SwitchListTile,
        'Desktop Only',
      );
      await tester.scrollUntilVisible(
        desktopToggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(desktopToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll back up to Save button.
      await tester.scrollUntilVisible(
        find.text('Save'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Save.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(fakeProfileController.savedProfiles.first.desktopOnly, isTrue);
    });

    testWidgets(
      'preserves pinnedHostId on save when the form has no pin selector yet',
      (tester) async {
        // Regression guard: PR4 will add an explicit pinning selector, but
        // until then every form save must carry through whatever pin the
        // user (or sync) stored on the profile — otherwise an unrelated edit
        // (rename, description tweak, slot change) silently disables the
        // synced-audio auto-trigger for this profile.
        final profile = testInferenceProfile(
          id: 'pinned-profile',
          name: 'Pinned Studio',
          pinnedHostId: 'host-uuid-abc',
        );

        await tester.pumpWidget(buildSubject(existingProfile: profile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Save without changes.
        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        expect(
          fakeProfileController.savedProfiles.first.pinnedHostId,
          'host-uuid-abc',
        );
      },
    );

    group('skill assignments', () {
      testWidgets('shows skill assignment section with skill names', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll down to find the skills section.
        await tester.scrollUntilVisible(
          find.text('Automated Skills'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Automated Skills'), findsOneWidget);

        // All transcription and imageAnalysis skills should be listed.
        final relevantSkills = builtInSkills.where(
          (s) =>
              s.skillType == SkillType.transcription ||
              s.skillType == SkillType.imageAnalysis,
        );
        for (final skill in relevantSkills) {
          expect(find.text(skill.name), findsOneWidget);
        }
      });

      testWidgets('skill toggle disabled when required model slot is empty', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to skill assignments.
        await tester.scrollUntilVisible(
          find.text('Automated Skills'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // All SwitchListTiles for skills should be disabled (no model set).
        // Find skill tiles (not the desktop-only toggle).
        final skillTiles = tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .where((t) => t.onChanged == null)
            .toList();

        // All skill tiles should be disabled since no model slots are set.
        final relevantSkillCount = builtInSkills
            .where(
              (s) =>
                  s.skillType == SkillType.transcription ||
                  s.skillType == SkillType.imageAnalysis,
            )
            .length;
        expect(skillTiles.length, relevantSkillCount);
      });

      testWidgets(
        'skill toggle enabled when required model slot is populated',
        (tester) async {
          // Profile with transcription model set.
          final profile = testInferenceProfile(
            id: 'p1',
            name: 'With Transcription',
            transcriptionModelId: 'models/whisper',
          );

          await tester.pumpWidget(buildSubject(existingProfile: profile));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Scroll to skill assignments.
          await tester.scrollUntilVisible(
            find.text('Automated Skills'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Transcription skill tiles should be enabled.
          final transcriptionSkills = builtInSkills.where(
            (s) => s.skillType == SkillType.transcription,
          );
          for (final skill in transcriptionSkills) {
            final tileFinder = find.widgetWithText(SwitchListTile, skill.name);
            expect(tileFinder, findsOneWidget);
            final tile = tester.widget<SwitchListTile>(tileFinder);
            expect(tile.onChanged, isNotNull);
          }
        },
      );

      testWidgets(
        'toggling skill on and saving includes it in skillAssignments',
        (
          tester,
        ) async {
          // Need a thinking model for save to work, plus a transcription model.
          final thinkingModel =
              AiConfig.model(
                    id: 'tm-1',
                    name: 'Flash',
                    providerModelId: 'models/flash',
                    inferenceProviderId: 'prov-1',
                    createdAt: DateTime(2024),
                    inputModalities: const [Modality.text],
                    outputModalities: const [Modality.text],
                    isReasoningModel: false,
                    supportsFunctionCalling: true,
                  )
                  as AiConfigModel;

          final profile = testInferenceProfile(
            id: 'p1',
            name: 'Skill Test',
            transcriptionModelId: 'models/whisper',
          );

          await tester.pumpWidget(
            buildSubject(
              existingProfile: profile,
              models: [thinkingModel],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Scroll to the first transcription skill.
          final firstTranscriptionSkill = builtInSkills.firstWhere(
            (s) => s.skillType == SkillType.transcription,
          );
          await tester.scrollUntilVisible(
            find.text(firstTranscriptionSkill.name),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Toggle the skill on.
          await tester.tap(
            find.widgetWithText(SwitchListTile, firstTranscriptionSkill.name),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Scroll back to Save.
          await tester.scrollUntilVisible(
            find.text('Save'),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Save.
          await tester.tap(find.text('Save'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(fakeProfileController.savedProfiles, hasLength(1));
          final saved = fakeProfileController.savedProfiles.first;
          expect(
            saved.skillAssignments.any(
              (a) => a.skillId == firstTranscriptionSkill.id && a.automate,
            ),
            isTrue,
          );
        },
      );

      testWidgets('preserves existing skill assignments when editing', (
        tester,
      ) async {
        const existingAssignment = SkillAssignment(
          skillId: skillTranscribeId,
          automate: true,
        );

        final profile = testInferenceProfile(
          id: 'p1',
          name: 'With Skills',
          transcriptionModelId: 'models/whisper',
          skillAssignments: [existingAssignment],
        );

        await tester.pumpWidget(buildSubject(existingProfile: profile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to skill assignments.
        await tester.scrollUntilVisible(
          find.text('Automated Skills'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The toggle for the transcribe skill should be on.
        final tileFinder = find.widgetWithText(
          SwitchListTile,
          'Transcribe Audio',
        );
        expect(tileFinder, findsOneWidget);
        final tile = tester.widget<SwitchListTile>(tileFinder);
        expect(tile.value, isTrue);

        // Scroll back to Save.
        await tester.scrollUntilVisible(
          find.text('Save'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Save without changes.
        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        final saved = fakeProfileController.savedProfiles.first;
        expect(
          saved.skillAssignments.any(
            (a) => a.skillId == skillTranscribeId && a.automate,
          ),
          isTrue,
        );
      });

      testWidgets('shows "Requires" subtitle when model slot is empty', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to skill assignments.
        await tester.scrollUntilVisible(
          find.text('Automated Skills'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should show "Requires Transcription model to be set".
        expect(
          find.text('Requires Transcription model to be set'),
          findsAtLeastNWidgets(1),
        );
      });

      testWidgets('shows "Uses" subtitle when model slot is populated', (
        tester,
      ) async {
        final profile = testInferenceProfile(
          id: 'p1',
          name: 'With Transcription',
          transcriptionModelId: 'models/whisper',
        );

        await tester.pumpWidget(buildSubject(existingProfile: profile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to skill assignments.
        await tester.scrollUntilVisible(
          find.text('Automated Skills'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should show "Uses Transcription model".
        expect(
          find.text('Uses Transcription model'),
          findsAtLeastNWidgets(1),
        );
      });
    });

    testWidgets('shows high-end thinking model when editing profile', (
      tester,
    ) async {
      final thinkingModel =
          AiConfig.model(
                id: 'tm-1',
                name: 'Flash',
                providerModelId: 'models/flash',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;

      final proModel =
          AiConfig.model(
                id: 'tm-2',
                name: 'Gemini Pro',
                providerModelId: 'models/gemini-pro',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: true,
              )
              as AiConfigModel;

      final profile = testInferenceProfile(
        id: 'p1',
        name: 'My Profile',
        thinkingModelId: 'models/flash',
        thinkingHighEndModelId: 'models/gemini-pro',
      );

      await tester.pumpWidget(
        buildSubject(
          existingProfile: profile,
          models: [thinkingModel, proModel],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The regular thinking model should be shown.
      expect(find.text('Flash'), findsOneWidget);

      // Scroll to the high-end slot and verify the model name is shown.
      await tester.scrollUntilVisible(
        find.text('Gemini Pro'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Gemini Pro'), findsOneWidget);
    });

    testWidgets('saves profile with high-end thinking model', (tester) async {
      final thinkingModel =
          AiConfig.model(
                id: 'tm-1',
                name: 'Flash',
                providerModelId: 'models/flash',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;

      final proModel =
          AiConfig.model(
                id: 'tm-2',
                name: 'Gemini Pro',
                providerModelId: 'models/gemini-pro',
                inferenceProviderId: 'prov-1',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: true,
              )
              as AiConfigModel;

      // Editing a profile that already has thinking model set.
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'Pro Profile',
      );

      await tester.pumpWidget(
        buildSubject(
          existingProfile: profile,
          models: [thinkingModel, proModel],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to the high-end slot and select a model.
      await tester.scrollUntilVisible(
        find.text('Thinking (High-End)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the high-end thinking slot (second InkWell).
      final highEndSlot = find.ancestor(
        of: find.text('Thinking (High-End)'),
        matching: find.byType(InkWell),
      );
      await tester.tap(highEndSlot.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select Gemini Pro.
      await tester.tap(find.text('Gemini Pro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll back to Save.
      await tester.scrollUntilVisible(
        find.text('Save'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Save.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeProfileController.savedProfiles, hasLength(1));
      final saved = fakeProfileController.savedProfiles.first;
      expect(saved.thinkingHighEndModelId, 'tm-2');
    });

    testWidgets('preserves existing profile ID when editing', (tester) async {
      final existingProfile = testInferenceProfile(
        id: 'existing-uuid',
        name: 'Original',
      );

      await tester.pumpWidget(
        buildSubject(existingProfile: existingProfile),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap save — has name and thinking model from existing profile.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the saved profile kept the original ID.
      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(fakeProfileController.savedProfiles.first.id, 'existing-uuid');
    });
  });

  group('model slot onModelSelected callbacks', () {
    // Shared models for each slot type.
    final imageRecognitionModel =
        AiConfig.model(
              id: 'ir-1',
              name: 'Vision Model',
              providerModelId: 'models/vision',
              inferenceProviderId: 'prov-1',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.text, Modality.image],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
            )
            as AiConfigModel;

    final transcriptionModel =
        AiConfig.model(
              id: 'tr-1',
              name: 'Whisper',
              providerModelId: 'models/whisper',
              inferenceProviderId: 'prov-1',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.audio],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
            )
            as AiConfigModel;

    final imageGenerationModel =
        AiConfig.model(
              id: 'ig-1',
              name: 'Imagen',
              providerModelId: 'models/imagen',
              inferenceProviderId: 'prov-1',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.image],
              isReasoningModel: false,
            )
            as AiConfigModel;

    final thinkingModel =
        AiConfig.model(
              id: 'tm-1',
              name: 'Flash',
              providerModelId: 'models/flash',
              inferenceProviderId: 'prov-1',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
              supportsFunctionCalling: true,
            )
            as AiConfigModel;

    testWidgets(
      'selecting image recognition model sets imageRecognitionModelId on save',
      (tester) async {
        final profile = testInferenceProfile(
          id: 'p1',
          name: 'IR Profile',
        );

        await tester.pumpWidget(
          buildSubject(
            existingProfile: profile,
            models: [thinkingModel, imageRecognitionModel],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to the Image Recognition slot.
        await tester.scrollUntilVisible(
          find.text('Image Recognition'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Open the image recognition picker.
        final irSlot = find.ancestor(
          of: find.text('Image Recognition'),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(irSlot.first);
        await tester.tap(irSlot.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Select the vision model.
        await tester.tap(find.text('Vision Model'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll back to save.
        await tester.scrollUntilVisible(
          find.text('Save'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        // Slots persist the canonical AiConfigModel.id, not the wire-level
        // providerModelId.
        expect(
          fakeProfileController.savedProfiles.first.imageRecognitionModelId,
          'ir-1',
        );
      },
    );

    testWidgets(
      'selecting transcription model sets transcriptionModelId on save',
      (tester) async {
        final profile = testInferenceProfile(
          id: 'p2',
          name: 'Transcription Profile',
        );

        await tester.pumpWidget(
          buildSubject(
            existingProfile: profile,
            models: [thinkingModel, transcriptionModel],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to the Transcription slot.
        await tester.scrollUntilVisible(
          find.text('Transcription'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Open the transcription picker.
        final trSlot = find.ancestor(
          of: find.text('Transcription'),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(trSlot.first);
        await tester.tap(trSlot.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Select the whisper model.
        await tester.tap(find.text('Whisper'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll back to save.
        await tester.scrollUntilVisible(
          find.text('Save'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        // Slots persist the canonical AiConfigModel.id, not the wire-level
        // providerModelId.
        expect(
          fakeProfileController.savedProfiles.first.transcriptionModelId,
          'tr-1',
        );
      },
    );

    testWidgets(
      'selecting image generation model sets imageGenerationModelId on save',
      (tester) async {
        final profile = testInferenceProfile(
          id: 'p3',
          name: 'Image Gen Profile',
        );

        await tester.pumpWidget(
          buildSubject(
            existingProfile: profile,
            models: [thinkingModel, imageGenerationModel],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to the Image Generation slot.
        await tester.scrollUntilVisible(
          find.text('Image Generation'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Open the image generation picker.
        final igSlot = find.ancestor(
          of: find.text('Image Generation'),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(igSlot.first);
        await tester.tap(igSlot.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Select the imagen model.
        await tester.tap(find.text('Imagen'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll back to save.
        await tester.scrollUntilVisible(
          find.text('Save'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        // Slots persist the canonical AiConfigModel.id, not the wire-level
        // providerModelId.
        expect(
          fakeProfileController.savedProfiles.first.imageGenerationModelId,
          'ig-1',
        );
      },
    );
  });

  group('save-time slot normalization', () {
    final visionModel =
        AiConfig.model(
              id: 'vision-row',
              name: 'Vision Model',
              providerModelId: 'models/vision',
              inferenceProviderId: 'prov-1',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.text, Modality.image],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
              supportsFunctionCalling: true,
            )
            as AiConfigModel;

    AiConfigModel duplicateThinkingModel(String id) =>
        AiConfig.model(
              id: id,
              name: 'Dup $id',
              providerModelId: 'models/dup-thinking',
              inferenceProviderId: 'prov-1',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
              supportsFunctionCalling: true,
            )
            as AiConfigModel;

    testWidgets(
      'keeps image-analysis automation enabled when the slot resolves',
      (tester) async {
        final imageSkill = builtInSkills.firstWhere(
          (s) => s.skillType == SkillType.imageAnalysis,
        );
        final profile = testInferenceProfile(
          id: 'p-img-skill',
          name: 'Image Skill Profile',
          thinkingModelId: 'vision-row',
          imageRecognitionModelId: 'vision-row',
          skillAssignments: [
            SkillAssignment(skillId: imageSkill.id, automate: true),
          ],
        );

        await tester.pumpWidget(
          buildSubject(existingProfile: profile, models: [visionModel]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        final saved = fakeProfileController.savedProfiles.first;
        // The slot resolves to a real model row, so the automated
        // image-analysis assignment survives the save-time sanitizer.
        final assignment = saved.skillAssignments.singleWhere(
          (a) => a.skillId == imageSkill.id,
        );
        expect(assignment.automate, isTrue);
      },
    );

    testWidgets(
      'aborts the save with a toast when the thinking slot value is an '
      'ambiguous legacy id',
      (tester) async {
        // Two model rows share the legacy providerModelId the profile's
        // thinking slot still stores — persisting either would pick an
        // arbitrary row, so the save must force a re-selection instead.
        final profile = testInferenceProfile(
          id: 'p-ambiguous',
          name: 'Ambiguous Profile',
          thinkingModelId: 'models/dup-thinking',
        );

        await tester.pumpWidget(
          buildSubject(
            existingProfile: profile,
            models: [
              duplicateThinkingModel('dup-a'),
              duplicateThinkingModel('dup-b'),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, isEmpty);
        expect(find.text('A thinking model is required'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'ProfilePinningSelector onChanged updates pinnedHostId on save',
    (tester) async {
      // Provide a sync node so the pinning dropdown has an eligible option.
      final knownNode = SyncNodeProfile(
        hostId: 'host-device-x',
        displayName: 'Device X',
        platform: 'macos',
        // No capabilities → eligible when profile has no local-only models.
        capabilities: const [],
        updatedAt: DateTime(2024),
      );

      final profile = testInferenceProfile(
        id: 'pinning-profile',
        name: 'Pinning Test',
      );

      await tester.pumpWidget(
        buildSubject(
          existingProfile: profile,
          knownNodes: [knownNode],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to the pinning dropdown.
      await tester.scrollUntilVisible(
        find.text('Not pinned (no auto-trigger)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open the dropdown and pick Device X.
      await tester.tap(find.text('Not pinned (no auto-trigger)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Device X').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to save button.
      await tester.scrollUntilVisible(
        find.text('Save'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(
        fakeProfileController.savedProfiles.first.pinnedHostId,
        'host-device-x',
      );
    },
  );

  group('_sanitizedSkillAssignments edge cases', () {
    // A thinking model used for save to succeed.
    final thinkingModel =
        AiConfig.model(
              id: 'tm-1',
              name: 'Flash',
              providerModelId: 'models/flash',
              inferenceProviderId: 'prov-1',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
              supportsFunctionCalling: true,
            )
            as AiConfigModel;

    testWidgets(
      'unknown skillId is preserved as-is in saved skillAssignments',
      (tester) async {
        // An assignment with a skill ID that is NOT in builtInSkills —
        // exercises the `unknown.add(a)` path (line 342).
        const unknownAssignment = SkillAssignment(
          skillId: 'skill-unknown-999',
          automate: true,
        );

        final profile = testInferenceProfile(
          id: 'unk-p',
          name: 'Unknown Skill',
          skillAssignments: [unknownAssignment],
        );

        await tester.pumpWidget(
          buildSubject(
            existingProfile: profile,
            models: [thinkingModel],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Save without changes.
        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        final saved = fakeProfileController.savedProfiles.first;
        // The unknown assignment must survive sanitization unchanged.
        expect(
          saved.skillAssignments.any(
            (a) => a.skillId == 'skill-unknown-999' && a.automate,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'automated skill with model present is kept automated after save',
      (tester) async {
        // automate: true + model slot populated → `if (hasModel) return a`
        // path (line 357) — assignment is preserved as automated.
        const transcribeAssignment = SkillAssignment(
          skillId: skillTranscribeId,
          automate: true,
        );

        final profile = testInferenceProfile(
          id: 'has-model-p',
          name: 'Has Model',
          transcriptionModelId: 'models/whisper',
          skillAssignments: [transcribeAssignment],
        );

        await tester.pumpWidget(
          buildSubject(
            existingProfile: profile,
            models: [thinkingModel],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        final saved = fakeProfileController.savedProfiles.first;
        // The assignment must remain automate: true because the model slot
        // is populated.
        expect(
          saved.skillAssignments.any(
            (a) => a.skillId == skillTranscribeId && a.automate,
          ),
          isTrue,
        );
      },
    );
  });

  group('_toggleSkillAssignment', () {
    final thinkingModel =
        AiConfig.model(
              id: 'tm-1',
              name: 'Flash',
              providerModelId: 'models/flash',
              inferenceProviderId: 'prov-1',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
              supportsFunctionCalling: true,
            )
            as AiConfigModel;

    testWidgets(
      'toggling a skill OFF removes its automate flag — exercises else '
      'branch (line 379) and saves assignment with automate: false',
      (tester) async {
        // Start with the transcription skill enabled.
        const transcribeAssignment = SkillAssignment(
          skillId: skillTranscribeId,
          automate: true,
        );

        final profile = testInferenceProfile(
          id: 'toggle-off-p',
          name: 'Toggle Off',
          transcriptionModelId: 'models/whisper',
          skillAssignments: [transcribeAssignment],
        );

        await tester.pumpWidget(
          buildSubject(
            existingProfile: profile,
            models: [thinkingModel],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to skill assignments.
        await tester.scrollUntilVisible(
          find.text('Automated Skills'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify the toggle is currently ON.
        final tileFinder = find.widgetWithText(
          SwitchListTile,
          'Transcribe Audio',
        );
        var tile = tester.widget<SwitchListTile>(tileFinder);
        expect(tile.value, isTrue);

        // Toggle it OFF.
        await tester.tap(tileFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        tile = tester.widget<SwitchListTile>(tileFinder);
        expect(tile.value, isFalse);

        // Scroll to save.
        await tester.scrollUntilVisible(
          find.text('Save'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        final saved = fakeProfileController.savedProfiles.first;
        // The assignment must exist but with automate: false.
        expect(
          saved.skillAssignments.any(
            (a) => a.skillId == skillTranscribeId && !a.automate,
          ),
          isTrue,
        );
        expect(
          saved.skillAssignments.any(
            (a) => a.skillId == skillTranscribeId && a.automate,
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'toggling a second same-type skill ON removes the first — exercises '
      'the removeWhere same-type path (line 376) ensuring mutual exclusion',
      (tester) async {
        // Both transcription skills exist; start with skillTranscribeId ON.
        const transcribeAssignment = SkillAssignment(
          skillId: skillTranscribeId,
          automate: true,
        );

        final profile = testInferenceProfile(
          id: 'mutual-excl-p',
          name: 'Mutual Exclusion',
          transcriptionModelId: 'models/whisper',
          skillAssignments: [transcribeAssignment],
        );

        await tester.pumpWidget(
          buildSubject(
            existingProfile: profile,
            models: [thinkingModel],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to the skills section.
        await tester.scrollUntilVisible(
          find.text('Automated Skills'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Find the "Transcribe (Task Context)" tile and toggle it ON.
        // That skill is the same SkillType.transcription, so the first
        // skill must be removed (line 376).
        final contextTileFinder = find.widgetWithText(
          SwitchListTile,
          'Transcribe (Task Context)',
        );
        await tester.ensureVisible(contextTileFinder);
        await tester.tap(contextTileFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to save.
        await tester.scrollUntilVisible(
          find.text('Save'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeProfileController.savedProfiles, hasLength(1));
        final saved = fakeProfileController.savedProfiles.first;

        // Only skillTranscribeContextId should be automated now.
        expect(
          saved.skillAssignments.any(
            (a) => a.skillId == skillTranscribeContextId && a.automate,
          ),
          isTrue,
        );
        // The original skill must NOT be automated.
        expect(
          saved.skillAssignments.any(
            (a) => a.skillId == skillTranscribeId && a.automate,
          ),
          isFalse,
        );
      },
    );
  });

  /// Modular coverage for the URL-driven entry point. Each test
  /// exercises ONE branch of the `aiConfigByIdProvider.when(...)` switch
  /// (loading / error / not-a-profile data / matching profile data) by
  /// driving the upstream Riverpod future via an override.
}

class _FakeInferenceProfileController extends InferenceProfileController {
  StreamController<List<AiConfig>>? streamController;
  final savedProfiles = <AiConfigInferenceProfile>[];
  bool shouldThrowOnSave = false;

  @override
  Stream<List<AiConfig>> build() {
    return streamController?.stream ?? const Stream.empty();
  }

  @override
  Future<void> saveProfile(AiConfigInferenceProfile profile) async {
    if (shouldThrowOnSave) {
      throw Exception('Save failed');
    }
    savedProfiles.add(profile);
  }
}

class _FakeAiConfigByTypeController extends AiConfigByTypeController {
  _FakeAiConfigByTypeController(this._data);

  final List<AiConfig> _data;

  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.value(_data);
  }
}
