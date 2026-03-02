import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_transcription_progress.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({required String partialTranscript}) {
    return makeTestableWidgetWithScaffold(
      EvolutionTranscriptionProgress(partialTranscript: partialTranscript),
    );
  }

  testWidgets('shows partial transcript text', (tester) async {
    await tester.pumpWidget(buildSubject(partialTranscript: 'Transcribing...'));
    // Use pump() — CircularProgressIndicator never settles
    await tester.pump();

    expect(find.text('Transcribing...'), findsOneWidget);
  });

  testWidgets('shows transcribe icon and progress indicator', (tester) async {
    await tester.pumpWidget(buildSubject(partialTranscript: 'Text'));
    await tester.pump();

    expect(find.byIcon(Icons.transcribe), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
