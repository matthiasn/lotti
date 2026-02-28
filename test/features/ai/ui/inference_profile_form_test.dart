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

  setUp(() {
    profileStreamController = StreamController<List<AiConfig>>();
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
          return _FakeInferenceProfileController()
            ..streamController = profileStreamController;
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
  });
}

class _FakeInferenceProfileController extends InferenceProfileController {
  StreamController<List<AiConfig>>? streamController;

  @override
  Stream<List<AiConfig>> build() {
    return streamController?.stream ?? const Stream.empty();
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
