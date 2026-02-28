import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';

import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart';

void main() {
  late StreamController<List<AiConfig>> profileStreamController;
  late _FakeInferenceProfileController fakeProfileController;

  setUp(() {
    profileStreamController = StreamController<List<AiConfig>>();
    fakeProfileController = _FakeInferenceProfileController()
      ..streamController = profileStreamController;
  });

  tearDown(() {
    profileStreamController.close();
  });

  Widget buildSubject({
    AiConfigInferenceProfile? existingProfile,
    List<AiConfig> models = const [],
    List<AiConfig> providers = const [],
  }) {
    return makeTestableWidgetNoScroll(
      InferenceProfileForm(existingProfile: existingProfile),
      overrides: [
        inferenceProfileControllerProvider.overrideWith(() {
          return fakeProfileController;
        }),
        aiConfigByTypeControllerProvider(configType: AiConfigType.model)
            .overrideWith(() {
          return _FakeAiConfigByTypeController(models);
        }),
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.inferenceProvider,
        ).overrideWith(() {
          return _FakeAiConfigByTypeController(providers);
        }),
      ],
    );
  }

  group('InferenceProfileForm', () {
    testWidgets('shows create title when no existing profile', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Create Profile'), findsOneWidget);
    });

    testWidgets('shows edit title when editing existing profile',
        (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'Existing Profile',
      );

      await tester.pumpWidget(buildSubject(existingProfile: profile));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('populates form fields when editing', (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'My Profile',
        desktopOnly: true,
      );

      await tester.pumpWidget(buildSubject(existingProfile: profile));
      await tester.pumpAndSettle();

      // Name should be pre-filled.
      final nameField = find.widgetWithText(TextFormField, 'My Profile');
      expect(nameField, findsOneWidget);

      // Desktop toggle should be on.
      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('shows all four model slot fields', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Thinking *'), findsOneWidget);
      expect(find.text('Image Recognition'), findsOneWidget);
      expect(find.text('Transcription'), findsOneWidget);
      expect(find.text('Image Generation'), findsOneWidget);
    });

    testWidgets('shows save button in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('validates name is required', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap save without entering a name.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('A profile name is required'), findsOneWidget);
    });

    testWidgets('shows desktop-only toggle with description', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Desktop Only'), findsOneWidget);
      expect(
        find.text(
          'Only available on desktop platforms (e.g. for local models)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows select model placeholder for empty slots',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // All four model slots should show the placeholder.
      expect(find.text('Select a model…'), findsNWidgets(4));
    });

    testWidgets('shows snackbar when saving without thinking model',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Enter a name to pass validation.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile Name'),
        'Test Profile',
      );

      // Tap save — no thinking model selected.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('A thinking model is required'),
        findsOneWidget,
      );
    });

    testWidgets('saves profile and pops when thinking model is selected',
        (tester) async {
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
      ) as AiConfigModel;

      final provider = AiConfig.inferenceProvider(
        id: 'prov-1',
        name: 'Provider',
        baseUrl: 'https://example.com',
        apiKey: 'key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      ) as AiConfigInferenceProvider;

      await tester.pumpWidget(
        buildSubject(
          models: [thinkingModel],
          providers: [provider],
        ),
      );
      await tester.pumpAndSettle();

      // Enter name.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile Name'),
        'My New Profile',
      );

      // Tap the thinking model slot InkWell to open picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Select the model.
      await tester.tap(find.text('Flash'));
      await tester.pumpAndSettle();

      // Tap save.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify the profile was saved.
      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(fakeProfileController.savedProfiles.first.name, 'My New Profile');
      expect(
        fakeProfileController.savedProfiles.first.thinkingModelId,
        'models/flash',
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
      await tester.pumpAndSettle();

      // Tap save — has name and thinking model from existing profile.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Error snackbar should appear.
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('model slot shows selected model name', (tester) async {
      final thinkingModel = AiConfig.model(
        id: 'tm-1',
        name: 'Gemini Pro',
        providerModelId: 'models/gemini-pro',
        inferenceProviderId: 'prov-1',
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      ) as AiConfigModel;

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
      await tester.pumpAndSettle();

      // The model name should be shown in the thinking slot.
      expect(find.text('Gemini Pro'), findsOneWidget);
    });

    testWidgets('model slot shows raw ID when model not found in list',
        (tester) async {
      // Edit profile with a model ID that doesn't match any loaded model.
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'My Profile',
        thinkingModelId: 'models/unknown-model',
      );

      await tester.pumpWidget(
        buildSubject(existingProfile: profile),
      );
      await tester.pumpAndSettle();

      // The raw model ID should be displayed as fallback.
      expect(find.text('models/unknown-model'), findsOneWidget);
    });

    testWidgets('clear button removes selected model', (tester) async {
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
      ) as AiConfigModel;

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
      await tester.pumpAndSettle();

      // Initially the model name is shown.
      expect(find.text('Flash'), findsOneWidget);

      // Tap the clear button.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Model name should be gone, placeholder shown.
      expect(find.text('Flash'), findsNothing);
      // Should now show placeholder or raw ID gone.
      expect(find.text('Select a model…'), findsAtLeastNWidgets(1));
    });

    testWidgets('desktop-only toggle changes value', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Scroll down to make the toggle visible.
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Initially off.
      var switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isFalse);

      // Toggle on.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('description field is shown and editable', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Description'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'A helpful profile',
      );
      await tester.pumpAndSettle();

      expect(find.text('A helpful profile'), findsOneWidget);
    });

    testWidgets('only shows models matching slot filter in picker',
        (tester) async {
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
      await tester.pumpAndSettle();

      // Open the thinking model picker by tapping the InkWell wrapping the slot.
      // The first InputDecorator is the thinking slot.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Open the thinking model picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Provider name should appear as part of the subtitle.
      expect(find.textContaining('Google AI'), findsOneWidget);
      expect(find.textContaining('models/flash'), findsOneWidget);
    });

    testWidgets('model picker shows checkmark for selected model',
        (tester) async {
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
      await tester.pumpAndSettle();

      // Open the thinking model picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Selected model should show a check icon.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('saves profile with description', (tester) async {
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
      ) as AiConfigModel;

      await tester.pumpWidget(
        buildSubject(models: [thinkingModel]),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flash'));
      await tester.pumpAndSettle();

      // Save.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(
        fakeProfileController.savedProfiles.first.description,
        'A test description',
      );
    });

    testWidgets('saves profile with desktop-only enabled', (tester) async {
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
      ) as AiConfigModel;

      await tester.pumpWidget(
        buildSubject(models: [thinkingModel]),
      );
      await tester.pumpAndSettle();

      // Enter name.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile Name'),
        'Desktop Profile',
      );

      // Select thinking model.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flash'));
      await tester.pumpAndSettle();

      // Scroll down and enable desktop-only toggle.
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // Scroll back up to Save button.
      await tester.scrollUntilVisible(
        find.text('Save'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Save.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(fakeProfileController.savedProfiles.first.desktopOnly, isTrue);
    });

    testWidgets('preserves existing profile ID when editing', (tester) async {
      final existingProfile = testInferenceProfile(
        id: 'existing-uuid',
        name: 'Original',
      );

      await tester.pumpWidget(
        buildSubject(existingProfile: existingProfile),
      );
      await tester.pumpAndSettle();

      // Tap save — has name and thinking model from existing profile.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify the saved profile kept the original ID.
      expect(fakeProfileController.savedProfiles, hasLength(1));
      expect(fakeProfileController.savedProfiles.first.id, 'existing-uuid');
    });
  });
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
