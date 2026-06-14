import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/ui/widgets/tts_model_selector.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String modelId,
    required ValueChanged<String> onChanged,
    List<TtsModelOption>? models,
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        TtsModelSelector(
          modelId: modelId,
          onChanged: onChanged,
          models: models ?? kTtsModels,
        ),
      ),
    );
  }

  testWidgets('shows the model name and download hint', (tester) async {
    await pump(tester, modelId: 'supertonic-3', onChanged: (_) {});

    expect(find.text('Supertonic 3'), findsOneWidget);
    expect(find.text('Downloads once'), findsOneWidget);
  });

  testWidgets('hides the recommended badge when there is only one model', (
    tester,
  ) async {
    // The shipped catalog has a single model, so recommending it is noise.
    expect(kTtsModels.length, 1);
    await pump(tester, modelId: 'supertonic-3', onChanged: (_) {});

    expect(find.text('Recommended'), findsNothing);
  });

  testWidgets('shows the recommended badge only when there is a real choice', (
    tester,
  ) async {
    await pump(
      tester,
      modelId: 'fast',
      onChanged: (_) {},
      models: const [
        TtsModelOption(
          id: 'fast',
          displayName: 'Fast model',
          huggingFaceRepoId: 'repo/fast',
          recommended: true,
        ),
        TtsModelOption(
          id: 'hifi',
          displayName: 'Hi-fi model',
          huggingFaceRepoId: 'repo/hifi',
        ),
      ],
    );

    // Exactly one badge, attached to the recommended (Fast) model.
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Fast model'), findsOneWidget);
    expect(find.text('Hi-fi model'), findsOneWidget);
  });

  testWidgets('marks the active model selected', (tester) async {
    await pump(tester, modelId: 'supertonic-3', onChanged: (_) {});
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('reports the tapped model id', (tester) async {
    String? picked;
    await pump(tester, modelId: 'supertonic-3', onChanged: (id) => picked = id);

    await tester.tap(find.text('Supertonic 3'));
    expect(picked, 'supertonic-3');
  });
}
