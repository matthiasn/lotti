import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/ui/query/query_audio_controls.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';
import '../../../tts/test_utils.dart';
import '../../query/query_audio_test_bench.dart';

void main() {
  late QueryAudioTestBench bench;
  setUpAll(registerAllFallbackValues);
  setUp(() async {
    await setUpTestGetIt();
    bench = QueryAudioTestBench();
  });
  tearDown(() async {
    await bench.close();
    await tearDownTestGetIt();
  });

  Future<void> pump(WidgetTester tester, {bool speech = false}) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Consumer(
          builder: (context, ref, _) {
            final data = ref
                .watch(queryChatDataProvider(QueryAudioTestBench.home))
                .value;
            return speech
                ? const QueryAnswerSpeechButton(
                    chatKey: QueryAudioTestBench.key,
                    answerId: 'answer',
                  )
                : QueryEvidenceAudioControls(
                    chatKey: QueryAudioTestBench.key,
                    actionId: 'answer:0',
                    evidence: bench.evidence,
                    audio:
                        (data?.access.entries['meeting'] as JournalAudio?) ??
                        bench.audio,
                  );
          },
        ),
        overrides: bench.overrides,
      ),
    );
    await tester.pump();
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('timestamped Listen plays the excerpt and Stop releases it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Listen · 01:35–02:35'), findsOneWidget);
    expect(find.textContaining('sends this recording'), findsNothing);
    await tester.tap(find.text('Listen · 01:35–02:35'));
    await tester.pump();
    verify(bench.player.play).called(1);
    expect(find.text('Stop audio'), findsOneWidget);
    await tester.tap(find.text('Stop audio'));
    await tester.pump();
    verify(bench.player.dispose).called(1);
    expect(find.text('Listen · 01:35–02:35'), findsOneWidget);
  });

  testWidgets(
    'preparing is explicit, discloses the upload and updates the timestamp label',
    (tester) async {
      bench.audio = bench.audio.copyWith(
        data: bench.audio.data.copyWith(transcriptTimings: {}),
      );
      await pump(tester);
      expect(find.textContaining('sends this recording'), findsOneWidget);
      expect(bench.requests, 0);
      // The buffered transport needs the real event loop. Await the persistence
      // boundary instead of advancing frames while its request is suspended.
      await tester.runAsync(() async {
        await tester.tap(find.text('Prepare audio excerpt'));
        await bench.timingWritten.future;
      });
      await tester.pump();
      expect(bench.requests, 1);
      expect(bench.writes, 1);
      expect(find.text('Stop audio'), findsOneWidget);
      await tester.tap(find.text('Stop audio'));
      await tester.pump();
      expect(find.text('Listen · 01:35–02:35'), findsOneWidget);
    },
  );

  testWidgets(
    'preparation can be cancelled before late provider output arrives',
    (tester) async {
      final pending = Completer<void>();
      bench.beforeResponse = () => pending.future;
      bench.audio = bench.audio.copyWith(
        data: bench.audio.data.copyWith(transcriptTimings: {}),
      );
      await pump(tester);
      await tester.tap(find.text('Prepare audio excerpt'));
      await tester.pump();
      expect(find.text('Preparing audio…'), findsOneWidget);
      await tester.tap(find.text('Stop audio'));
      pending.complete();
      await tester.pump();
      expect(bench.writes, 0);
      verifyNever(bench.player.play);
      expect(find.text('Prepare audio excerpt'), findsOneWidget);
    },
  );

  for (final failure in ['missing', 'unmatched', 'unsupported', 'native']) {
    testWidgets('$failure has a specific recovery message', (tester) async {
      var label = 'Listen · 01:35–02:35';
      late String expected;
      switch (failure) {
        case 'missing':
          when(bench.file.existsSync).thenReturn(false);
          expected = 'The recording isn’t available on this device yet.';
        case 'unmatched':
          final timing =
              bench.audio.data.transcriptTimings[bench.evidence.fingerprint]!;
          bench.audio = bench.audio.copyWith(
            data: bench.audio.data.copyWith(
              transcriptTimings: {
                timing.sourceFingerprint: timing.copyWith(
                  segments: [
                    timing.segments.single.copyWith(text: 'Other words.'),
                  ],
                ),
              },
            ),
          );
          label = 'Prepare audio excerpt';
          expected =
              'This quote could not be matched unambiguously to the recording. You can still open the full entry.';
        case 'unsupported':
          bench.profile = null;
          bench.audio = bench.audio.copyWith(
            data: bench.audio.data.copyWith(transcriptTimings: {}),
          );
          label = 'Prepare audio excerpt';
          expected =
              'To prepare excerpts, select Melious Whisper or a supported Mistral Voxtral transcription model in this agent’s inference profile. The provider URL must use HTTPS.';
        case 'native':
          when(bench.player.play).thenThrow(StateError('failed'));
          expected = 'Audio could not be prepared or played. Try again.';
      }
      await pump(tester);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(find.text(expected), findsOneWidget);
      expect(find.text('Stop audio'), findsNothing);
    });
  }

  testWidgets('the speech action uses local TTS and offers Stop', (
    tester,
  ) async {
    await pump(tester, speech: true);
    await tester.tap(find.text('Read answer aloud'));
    await tester.pump();
    expect(bench.engine.calls.single.text, 'Keep the feeder latch.');
    expect(find.text('Stop audio'), findsOneWidget);
    await tester.tap(find.text('Stop audio'));
    await tester.pump();
    expect(bench.speechPlayer.stopCount, greaterThan(0));
    expect(find.text('Read answer aloud'), findsOneWidget);
    bench.ttsEnabled.add(false);
    await tester.pump();
    expect(find.text('Read answer aloud'), findsNothing);
  });

  testWidgets('leaving during speech preparation prevents late playback', (
    tester,
  ) async {
    final pending = Completer<File>();
    bench.engine = FakeTtsEngine(pendingSynthesis: pending.future);
    await pump(tester, speech: true);
    await tester.tap(find.text('Read answer aloud'));
    await tester.pump();
    expect(find.text('Preparing audio…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(File('/tmp/nonexistent-query-controls.wav'));
    await tester.pump();
    expect(bench.speechPlayer.playCount, 0);
  });
}
