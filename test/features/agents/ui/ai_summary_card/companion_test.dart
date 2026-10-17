import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_report_layout.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';

import '../../../tts/test_utils.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

const _tldr = 'Two items left: the review and the release notes.';
const _report = '## Goal\nShip the card.\n';

/// A phone's card: below [CompanionReportLayout.besideMinWidth] once the
/// card padding is taken off.
const _narrowCard = 360.0;

/// Her ticker runs for as long as she is on screen, so these tests pump a
/// fixed number of frames instead of settling.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpCard(
  WidgetTester tester, {
  bool enableCompanion = true,
  bool enableSummaryTts = true,
  bool engineSupported = true,
  String? content,
  double? width,
  List<({String clip, String text})>? loads,
  Future<File>? pendingSynthesis,
}) async {
  final bench = AgentTestBench(
    enableCompanion: enableCompanion,
    enableSummaryTts: enableSummaryTts,
    ttsEngine: FakeTtsEngine(
      supported: engineSupported,
      pendingSynthesis: pendingSynthesis,
    ),
    report: content == null
        ? makeTestReport(tldr: _tldr)
        : makeTestReport(tldr: _tldr, content: content),
    width: width,
    extraOverrides: [
      spokenTrackLoaderProvider.overrideWithValue((clip, text) {
        loads?.add((clip: clip, text: text));
        return Completer<MouthTrack>().future;
      }),
    ],
  );
  await tester.pumpWidget(bench.build());
  await _pumpFrames(tester);
}

CompanionSpeaker _speaker(WidgetTester tester) =>
    tester.widget<CompanionSpeaker>(find.byType(CompanionSpeaker));

void main() {
  group('the companion on the AI summary card', () {
    testWidgets('is not shown while her flag is off', (tester) async {
      await _pumpCard(tester, enableCompanion: false);

      expect(find.byType(TtsPlayButton), findsOneWidget);
      expect(find.byType(CompanionSpeaker), findsNothing);
    });

    testWidgets('is not shown while summary playback is off', (tester) async {
      await _pumpCard(tester, enableSummaryTts: false);

      expect(find.byType(TtsPlayButton), findsNothing);
      expect(find.byType(CompanionSpeaker), findsNothing);
    });

    testWidgets('is not shown where the device has no voice', (tester) async {
      await _pumpCard(tester, engineSupported: false);

      expect(find.byType(TtsPlayButton), findsNothing);
      expect(find.byType(CompanionSpeaker), findsNothing);
    });

    testWidgets("speaks this task's utterance, framed head to toe", (
      tester,
    ) async {
      await _pumpCard(tester);

      final speaker = _speaker(tester);
      expect(speaker.sourceId, AgentTestBench.taskId);
      expect(speaker.framing, CompanionFraming.full);
    });

    testWidgets('mouths the full report when it is read expanded', (
      tester,
    ) async {
      final loads = <({String clip, String text})>[];
      await _pumpCard(
        tester,
        content: '## Goal\nShip the card.\n',
        loads: loads,
      );

      await tester.tap(find.text('Read more'));
      await _pumpFrames(tester);
      await tester.tap(find.byType(TtsPlayButton));
      await _pumpFrames(tester);

      expect(loads, [
        (
          clip: '/tmp/fake_tts_output.wav',
          text: '$_tldr\n\n## Goal\nShip the card.',
        ),
      ]);
    });

    testWidgets('mouths the words tapped, though the card expands meanwhile', (
      tester,
    ) async {
      final loads = <({String clip, String text})>[];
      final synthesis = Completer<File>();
      await _pumpCard(
        tester,
        content: '## Goal\nShip the card.\n',
        loads: loads,
        pendingSynthesis: synthesis.future,
      );

      await tester.tap(find.byType(TtsPlayButton));
      await _pumpFrames(tester);
      await tester.tap(find.text('Read more'));
      await _pumpFrames(tester);
      synthesis.complete(File('/tmp/fake_tts_output.wav'));
      await _pumpFrames(tester);

      expect(loads, [(clip: '/tmp/fake_tts_output.wav', text: _tldr)]);
    });

    testWidgets('stands beside the summary on a wide card, at the wide '
        'size', (tester) async {
      await _pumpCard(tester);

      final her = tester.getRect(find.byType(CompanionView));
      expect(her.height, ControlSizes.companionCardWide);
      expect(
        her.width,
        closeTo(
          ControlSizes.companionCardWide * CompanionFraming.full.aspectRatio,
          0.01,
        ),
      );
      final summary = tester.getRect(find.text(_tldr));
      final overhang = CompanionSlot.overhang(ControlSizes.companionCardWide);
      expect(her.right - overhang, lessThan(summary.left));
      expect(her.top, summary.top);
    });

    testWidgets('stands under the full-width summary on a narrow card, beside '
        'its links', (tester) async {
      await _pumpCard(tester, width: _narrowCard, content: _report);

      final her = tester.getRect(find.byType(CompanionView));
      expect(her.height, ControlSizes.companionCardCompact);
      final summary = tester.getRect(find.text(_tldr));
      expect(her.top, greaterThan(summary.bottom));
      final readMore = tester.getRect(find.text('Read more'));
      expect(readMore.left, greaterThan(her.right));
      expect(readMore.top, greaterThan(her.top));
      expect(readMore.bottom, lessThan(her.bottom));

      // Expanded, she follows the links down under the full report.
      await tester.tap(find.text('Read more'));
      await _pumpFrames(tester);
      final expanded = tester.getRect(find.byType(CompanionView));
      final report = tester.getRect(
        find.byType(AgentMarkdownView).last,
      );
      expect(expanded.top, greaterThan(report.bottom));
      expect(
        tester.getRect(find.text('Show less')).left,
        greaterThan(expanded.right),
      );
    });

    testWidgets('mouths the clip the read-aloud control plays', (
      tester,
    ) async {
      final loads = <({String clip, String text})>[];
      await _pumpCard(tester, loads: loads);

      await tester.tap(find.byType(TtsPlayButton));
      await _pumpFrames(tester);

      expect(loads, [(clip: '/tmp/fake_tts_output.wav', text: _tldr)]);
    });
  });

  testWidgets('on a wide card the summary gives way to her slot and one gap', (
    tester,
  ) async {
    await _pumpCard(tester, enableCompanion: false);
    final alone = tester.getRect(find.text(_tldr)).left;

    // A fresh scope, so the flag is read again.
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpCard(tester);
    final beside = tester.getRect(find.text(_tldr)).left;

    final context = tester.element(find.byType(CompanionSpeaker));
    final gap = context.designTokens.spacing.step5;
    final slot = tester.getSize(find.byType(CompanionSlot)).width;
    expect(beside - alone, closeTo(slot + gap, 0.01));
  });

  testWidgets('on a narrow card the summary keeps the full width', (
    tester,
  ) async {
    await _pumpCard(tester, enableCompanion: false, width: _narrowCard);
    final alone = tester.getRect(find.text(_tldr));

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpCard(tester, width: _narrowCard);

    expect(find.byType(CompanionView), findsOneWidget);
    expect(tester.getRect(find.text(_tldr)), alone);
  });
}
