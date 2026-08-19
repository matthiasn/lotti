import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
      final agentTarget = tester.getRect(
        find.ancestor(
          of: find.text('Task Laura'),
          matching: find.byType(InkWell),
        ),
      );
      expect(agentTarget.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(
        agentTarget.height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await tester.tap(find.text('Task Laura'));
      expect(agentTaps, 1);
    });

    testWidgets(
      'hovering the header block brightens its own ink instead of painting '
      'an overlay',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            TldrHeader(agentName: 'Task Laura', onAgentTap: () {}),
          ),
        );

        final ai = tester
            .element(find.text('Task Laura'))
            .designTokens
            .colors
            .aiCard;
        Color? nameInk() =>
            tester.widget<Text>(find.text('Task Laura')).style?.color;
        Color? badgeBorder() {
          final container = tester.widget<Container>(
            find
                .ancestor(
                  of: find.byIcon(LottiIcons.aiSpark),
                  matching: find.byType(Container),
                )
                .first,
          );
          return (container.decoration! as BoxDecoration).border?.top.color;
        }

        expect(nameInk(), ai.metaText);
        expect(badgeBorder(), ai.border);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.text('Task Laura')));
        await tester.pump();

        // The block answers hover itself: the badge border firms to the
        // accent and the agent name lifts a step.
        expect(nameInk(), ai.bodyText);
        expect(badgeBorder(), ai.accent);
      },
    );

    testWidgets('the tap target hugs the badge and title, not the whole row', (
      tester,
    ) async {
      const width = 900.0;
      tester.view
        ..physicalSize = const Size(width, 400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(
            agentName: 'Task Laura',
            onAgentTap: () {},
            playbackControl: const SizedBox(
              key: ValueKey('playback'),
              width: 48,
              height: 48,
            ),
          ),
        ),
      );

      final tokens = tester.element(find.byType(TldrHeader)).designTokens;
      final ink = tester.getRect(
        find.ancestor(
          of: find.text('Task Laura'),
          matching: find.byType(InkWell),
        ),
      );
      final playback = tester.getRect(find.byKey(const ValueKey('playback')));

      // The hover/press layer must stop after the title block instead of
      // running to the playback control at the far end of the header.
      expect(ink.right, lessThan(playback.left - tokens.spacing.step3));
      expect(ink.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      // Shrink-wrapping the button must not unpin the playback control from
      // the card's trailing edge.
      expect(
        playback.right,
        moreOrLessEquals(
          tester.getRect(find.byType(TldrHeader)).right -
              tokens.spacing.cardPadding,
          epsilon: 0.5,
        ),
      );
    });

    testWidgets('a long agent name truncates instead of wrapping', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longName = 'Task Laura the Extremely Thorough Release Coordinator';
      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(agentName: longName, onAgentTap: () {}),
        ),
      );

      // The agent's name is metadata and truncates; the card's own title is
      // allowed a second line rather than being cut to nonsense.
      expect(tester.widget<Text>(find.text(longName)).maxLines, 1);
      expect(
        tester.widget<Text>(find.text(longName)).overflow,
        TextOverflow.ellipsis,
      );
      expect(tester.widget<Text>(find.text('AI summary')).maxLines, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a compound title truncates rather than breaking mid-word', (
      tester,
    ) async {
      // German compounds the title into one unbreakable token,
      // "KI-Zusammenfassung". Given two lines and a slot narrower than that
      // token, Flutter breaks *inside* the word — "KI-Zusammenf / assung" —
      // which reads as a typo, not as shortening. One line and an ellipsis at
      // least tells the reader something was left out.
      Future<void> pumpAt(double width) {
        tester.view
          ..physicalSize = Size(width, 400)
          ..devicePixelRatio = 1;
        return tester.pumpWidget(
          makeTestableWidget(
            TldrHeader(agentName: 'Task Laura', onAgentTap: () {}),
            locale: const Locale('de'),
            mediaQueryData: phoneMediaQueryData.copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
          ),
        );
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpAt(320);
      final title = find.text('KI-Zusammenfassung');
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(title).maxLines, 1);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isTrue,
        reason: 'the ellipsis is what marks the title as shortened',
      );

      // The fallback is measured, not a narrow-width rule: give the same
      // string a slot its longest run fits in and the second line comes back.
      await pumpAt(730);
      expect(tester.widget<Text>(title).maxLines, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('TldrBody', () {
    testWidgets('uses editor-aligned bodySmall for all report prose', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(const _DisclosureHarness()),
      );

      final context = tester.element(find.byType(TldrBody));
      final styles = context.designTokens.typography.styles.body;
      final collapsedView = tester.widget<AgentMarkdownView>(
        find.byType(AgentMarkdownView),
      );

      expect(collapsedView.style?.fontSize, styles.bodySmall.fontSize);
      expect(collapsedView.style?.fontSize, isNot(styles.bodyMedium.fontSize));

      await tester.tap(find.text('Read more'));
      await tester.pump();

      final expandedViews = tester
          .widgetList<AgentMarkdownView>(find.byType(AgentMarkdownView))
          .toList();
      expect(expandedViews, hasLength(2));
      for (final view in expandedViews) {
        expect(view.style?.fontSize, styles.bodySmall.fontSize);
        expect(view.style?.fontWeight, styles.bodySmall.fontWeight);
        expect(view.style?.fontFamily, styles.bodySmall.fontFamily);
      }
    });

    testWidgets('disclosure has a compact step8 target and reports expansion', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        makeTestableWidget(const _DisclosureHarness()),
      );

      final disclosure = find.byKey(
        const ValueKey('taskAgentReportDisclosure'),
      );
      final context = tester.element(find.byType(TldrBody));
      expect(
        tester.getSize(disclosure).height,
        greaterThanOrEqualTo(context.designTokens.spacing.step8),
      );
      expect(
        tester.getSemantics(disclosure),
        matchesSemantics(
          label: 'Read more',
          isButton: true,
          isFocusable: true,
          hasExpandedState: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(disclosure);
      await tester.pump();

      expect(
        tester.getSemantics(disclosure),
        matchesSemantics(
          label: 'Show less',
          isButton: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

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
