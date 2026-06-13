import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/ui/widgets/tts_model_selector.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String modelId,
    required ValueChanged<String> onChanged,
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        TtsModelSelector(modelId: modelId, onChanged: onChanged),
      ),
    );
  }

  testWidgets('shows the model name, recommended badge, and download hint', (
    tester,
  ) async {
    await pump(tester, modelId: 'supertonic-3', onChanged: (_) {});

    expect(find.text('Supertonic 3'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Downloads once'), findsOneWidget);
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
