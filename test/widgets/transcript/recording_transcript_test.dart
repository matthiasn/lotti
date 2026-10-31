import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

void main() {
  const long =
      'Walked the long way round the colony after lunch and the cold finally '
      'cleared my head. Decided to stop answering messages before nine and to '
      'take the first hour for the sled plans instead. Felt lighter by the '
      'evening than I have all week, and slept through the night.';

  Future<void> pump(WidgetTester tester, RecordingTranscript transcript) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: 320, child: transcript),
        ),
      ),
    );
    // The spinner never settles; one frame is all a status line needs.
    await tester.pump();
  }

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(RecordingTranscript)).designTokens;

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  group('heard', () {
    testWidgets('folds the words in a history list, leading with a summary', (
      tester,
    ) async {
      await pump(
        tester,
        const RecordingTranscript(
          id: 'a1',
          status: TranscriptStatus.heard,
          transcript: long,
          summary: 'A long walk cleared the head.',
        ),
      );

      final folded = tester.widget<FoldedWords>(find.byType(FoldedWords));
      expect(folded.words, long);
      expect(folded.summary, 'A long walk cleared the head.');
      expect(find.text('A long walk cleared the head.'), findsOneWidget);
      expect(find.byKey(const ValueKey('transcript-status-a1')), findsNothing);
    });

    testWidgets('shows every word, unfolded, where the user reviews what they '
        'just said — in the words tier, announced as it lands', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const RecordingTranscript(
          id: 'a1',
          status: TranscriptStatus.heard,
          transcript: '  $long  ',
          folded: false,
        ),
      );

      expect(find.byType(FoldedWords), findsNothing);
      final words = tester.widget<Text>(
        find.byKey(const ValueKey('transcript-words-a1')),
      );
      expect(words.data, long, reason: 'trimmed, never clipped');
      expect(words.maxLines, isNull);
      expect(
        words.style,
        FoldedWords.wordsStyle(tester.element(find.byType(Text))),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('transcript-words-a1'))),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('heard with no words draws nothing rather than an empty line', (
      tester,
    ) async {
      await pump(
        tester,
        const RecordingTranscript(
          id: 'a1',
          status: TranscriptStatus.heard,
          transcript: '   ',
        ),
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(FoldedWords), findsNothing);
    });
  });

  group('status line', () {
    testWidgets('transcribing: the spinner, the quiet label, the host detail, '
        'and no Retry — something is already on its way', (tester) async {
      var retried = 0;
      await pump(
        tester,
        RecordingTranscript(
          id: 'a1',
          status: TranscriptStatus.transcribing,
          detail: 'You can save now — the words follow.',
          onRetry: () => retried++,
        ),
      );

      final tokens = tokensOf(tester);
      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      expect(find.byIcon(LottiIcons.warning), findsNothing);
      expect(
        colorOf(tester, 'Transcribing…'),
        tokens.colors.text.mediumEmphasis,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('transcript-detail-a1')))
            .data,
        'You can save now — the words follow.',
      );
      expect(find.byKey(const ValueKey('transcript-retry-a1')), findsNothing);
      expect(retried, 0);
    });

    for (final (status, label) in [
      (TranscriptStatus.notTranscribed, 'Not transcribed'),
      (TranscriptStatus.failed, 'Transcription failed'),
    ]) {
      testWidgets('${status.name}: the warning glyph, the label at full ink '
          'because it is the news, and Retry asks again', (tester) async {
        var retried = 0;
        await pump(
          tester,
          RecordingTranscript(
            id: 'a1',
            status: status,
            onRetry: () => retried++,
          ),
        );

        final tokens = tokensOf(tester);
        final glyph = tester.widget<Icon>(find.byIcon(LottiIcons.warning));
        expect(glyph.color, tokens.colors.alert.warning.defaultColor);
        expect(find.byType(DesignSystemSpinner), findsNothing);
        expect(colorOf(tester, label), tokens.colors.text.highEmphasis);

        final retry = tester.widget<DesignSystemButton>(
          find.byKey(const ValueKey('transcript-retry-a1')),
        );
        expect(retry.label, 'Retry');
        expect(retry.variant, DesignSystemButtonVariant.tertiary);
        expect(retry.size, DesignSystemButtonSize.dense);
        await tester.tap(find.byKey(const ValueKey('transcript-retry-a1')));
        expect(retried, 1);
      });
    }

    testWidgets('no Retry when the host cannot honour one, and a blank detail '
        'draws no empty line', (tester) async {
      await pump(
        tester,
        const RecordingTranscript(
          id: 'a1',
          status: TranscriptStatus.failed,
          detail: '  ',
        ),
      );

      expect(find.text('Transcription failed'), findsOneWidget);
      expect(find.byType(DesignSystemButton), findsNothing);
      expect(find.byKey(const ValueKey('transcript-detail-a1')), findsNothing);
    });

    testWidgets("the detail sits under the label, clear of the glyph's "
        'column', (tester) async {
      await pump(
        tester,
        const RecordingTranscript(
          id: 'a1',
          status: TranscriptStatus.failed,
          detail: 'HTTP 503 · Transcription service unavailable',
        ),
      );

      final labelLeft = tester.getTopLeft(find.text('Transcription failed')).dx;
      final detailLeft = tester
          .getTopLeft(find.byKey(const ValueKey('transcript-detail-a1')))
          .dx;
      expect(detailLeft, labelLeft);
      expect(
        tester.getTopLeft(find.byIcon(LottiIcons.warning)).dx,
        lessThan(detailLeft),
      );
    });

    testWidgets('the status is announced as it changes', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const RecordingTranscript(
          id: 'a1',
          status: TranscriptStatus.notTranscribed,
        ),
      );

      expect(
        tester.getSemantics(find.text('Not transcribed')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });
  });
}
