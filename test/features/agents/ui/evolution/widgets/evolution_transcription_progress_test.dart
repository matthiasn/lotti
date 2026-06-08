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

  testWidgets('shows partial transcript text alongside icon and progress', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(partialTranscript: 'Transcribing...'));
    // Use pump() — CircularProgressIndicator never settles
    await tester.pump();

    expect(find.text('Transcribing...'), findsOneWidget);
    expect(find.byIcon(Icons.transcribe), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders gracefully with an empty partial transcript', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(partialTranscript: ''));
    await tester.pump();

    // Empty string still renders a Text widget (no overflow/crash) and the
    // progress affordances remain visible while transcription is pending.
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(EvolutionTranscriptionProgress),
        matching: find.byType(Text),
      ),
    );
    expect(text.data, '');
    expect(find.byIcon(Icons.transcribe), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
