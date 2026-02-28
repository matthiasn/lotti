import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';

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

  Widget buildSubject({List<AiConfig>? initialData}) {
    return makeTestableWidgetNoScroll(
      const InferenceProfilePage(),
      overrides: [
        inferenceProfileControllerProvider.overrideWith(() {
          return _FakeInferenceProfileController()
            ..streamController = profileStreamController
            ..initialData = initialData;
        }),
      ],
    );
  }

  group('InferenceProfilePage', () {
    testWidgets('shows empty state when there are no profiles', (tester) async {
      await tester.pumpWidget(buildSubject(initialData: []));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.text('No inference profiles yet'), findsOneWidget);
    });

    testWidgets('shows profile cards when profiles exist', (tester) async {
      final profiles = <AiConfig>[
        testInferenceProfile(
          id: 'p1',
          name: 'Gemini Flash',
        ),
        testInferenceProfile(
          id: 'p2',
          name: 'Local Ollama',
          thinkingModelId: 'qwen3:8b',
          desktopOnly: true,
        ),
      ];

      await tester.pumpWidget(buildSubject(initialData: profiles));
      await tester.pumpAndSettle();

      expect(find.text('Gemini Flash'), findsOneWidget);
      expect(find.text('Local Ollama'), findsOneWidget);
    });

    testWidgets('shows desktop-only chip for desktop profiles', (tester) async {
      final profiles = <AiConfig>[
        testInferenceProfile(
          id: 'p1',
          name: 'Local Profile',
          desktopOnly: true,
        ),
      ];

      await tester.pumpWidget(buildSubject(initialData: profiles));
      await tester.pumpAndSettle();

      // The Chip widget should show desktop only text
      expect(find.text('Desktop Only'), findsOneWidget);
    });

    testWidgets('shows slot rows for configured model slots', (tester) async {
      final profiles = <AiConfig>[
        testInferenceProfile(
          id: 'p1',
          name: 'Full Profile',
          thinkingModelId: 'thinking-model',
          imageRecognitionModelId: 'vision-model',
          transcriptionModelId: 'audio-model',
          imageGenerationModelId: 'image-gen-model',
        ),
      ];

      await tester.pumpWidget(buildSubject(initialData: profiles));
      await tester.pumpAndSettle();

      // Thinking slot is always shown
      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('thinking-model'), findsOneWidget);
      // Optional slots are shown when configured
      expect(find.text('Image Recognition'), findsOneWidget);
      expect(find.text('vision-model'), findsOneWidget);
      expect(find.text('Transcription'), findsOneWidget);
      expect(find.text('audio-model'), findsOneWidget);
      expect(find.text('Image Generation'), findsOneWidget);
      expect(find.text('image-gen-model'), findsOneWidget);
    });

    testWidgets('shows lock icon for default profiles', (tester) async {
      final profiles = <AiConfig>[
        testInferenceProfile(
          id: 'p1',
          name: 'Default Profile',
          isDefault: true,
        ),
      ];

      await tester.pumpWidget(buildSubject(initialData: profiles));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows FAB for creating new profiles', (tester) async {
      await tester.pumpWidget(buildSubject(initialData: []));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows loading state while profiles are loading',
        (tester) async {
      // Don't provide initial data — the stream hasn't emitted yet.
      await tester.pumpWidget(buildSubject());
      // Use pump with a short duration to avoid pending timer issues from
      // SettingsPageHeader animations.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Emit data to let the stream complete and settle timers.
      profileStreamController.add([]);
      await tester.pumpAndSettle();
    });
  });
}

class _FakeInferenceProfileController extends InferenceProfileController {
  StreamController<List<AiConfig>>? streamController;
  List<AiConfig>? initialData;

  @override
  Stream<List<AiConfig>> build() {
    if (initialData != null) {
      return Stream.value(initialData!);
    }
    return streamController!.stream;
  }
}
