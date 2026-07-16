import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';

import '../../../../widget_test_utils.dart';
import '../../../tts/test_utils.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

class _DisclosureHarness extends StatefulWidget {
  const _DisclosureHarness({this.onOpenInternals});

  final VoidCallback? onOpenInternals;

  @override
  State<_DisclosureHarness> createState() => _DisclosureHarnessState();
}

class _DisclosureHarnessState extends State<_DisclosureHarness> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return TldrBody(
      tldr: 'Summary first.',
      expanded: expanded,
      additionalReport: 'Full report details.',
      onToggle: () => setState(() => expanded = !expanded),
      onOpenInternals: widget.onOpenInternals ?? () {},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TldrHeader', () {
    testWidgets('keeps identity primary and exposes optional playback', (
      tester,
    ) async {
      var agentTaps = 0;
      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(
            agentName: 'Task Laura',
            onAgentTap: () => agentTaps++,
            playbackControl: const SizedBox(
              key: ValueKey('playback'),
              width: 48,
              height: 48,
            ),
          ),
        ),
      );

      expect(find.text('AI summary'), findsOneWidget);
      expect(find.text('Task Laura'), findsOneWidget);
      expect(find.byKey(const ValueKey('playback')), findsOneWidget);
      await tester.tap(find.text('Task Laura'));
      expect(agentTaps, 1);
    });
  });

  group('TldrBody', () {
    testWidgets('places disclosure below its summary and expands in place', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(const _DisclosureHarness()),
      );

      final summaryBottom = tester
          .getBottomLeft(find.text('Summary first.'))
          .dy;
      final disclosureTop = tester.getTopLeft(find.text('Read more')).dy;
      expect(disclosureTop, greaterThan(summaryBottom));
      expect(find.text('Full report details.'), findsNothing);

      await tester.tap(find.text('Read more'));
      await tester.pump();

      expect(find.text('Full report details.'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Show less')).dy,
        greaterThan(
          tester.getBottomLeft(find.text('Full report details.')).dy,
        ),
      );
    });

    testWidgets('expanded internals action invokes its callback', (
      tester,
    ) async {
      var internalsTaps = 0;
      await tester.pumpWidget(
        makeTestableWidget(
          _DisclosureHarness(onOpenInternals: () => internalsTaps++),
        ),
      );
      expect(find.text('Open agent internals'), findsNothing);

      await tester.tap(find.text('Read more'));
      await tester.pump();
      await tester.tap(find.text('Open agent internals'));

      expect(internalsTaps, 1);
    });
  });

  group('AiSummaryCard playback integration', () {
    testWidgets('hides playback while the feature flag is off', (tester) async {
      final bench = AgentTestBench(
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.byType(TtsPlayButton), findsNothing);
    });

    testWidgets('plays the visible summary through the TTS engine', (
      tester,
    ) async {
      final engine = FakeTtsEngine();
      final bench = AgentTestBench(
        enableSummaryTts: true,
        ttsEngine: engine,
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtsPlayButton));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(engine.calls.single.text, 'Tldr line.');
      expect(engine.calls.single.voiceId, 'F1');
    });

    testWidgets('expanded playback includes the full report', (tester) async {
      final engine = FakeTtsEngine();
      final bench = AgentTestBench(
        enableSummaryTts: true,
        ttsEngine: engine,
        report: makeTestReport(
          tldr: 'Tldr line.',
          content: '## Goal\nShip the card.\n',
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtsPlayButton));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        engine.calls.single.text,
        'Tldr line.\n\n## Goal\nShip the card.',
      );
    });

    testWidgets('shows an error toast when synthesis fails', (tester) async {
      final engine = FakeTtsEngine(throwOnSynthesize: true);
      final bench = AgentTestBench(
        enableSummaryTts: true,
        ttsEngine: engine,
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtsPlayButton));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(engine.calls, isEmpty);
      expect(find.text('Error'), findsOneWidget);
    });
  });
}
