import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';

import '../../../../widget_test_utils.dart';
import '../../../tts/test_utils.dart';
import '../../test_data/constants.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

class _DisclosureHarness extends StatefulWidget {
  const _DisclosureHarness({this.onOpenInternals, this.disclosureKey});

  final VoidCallback? onOpenInternals;
  final Key? disclosureKey;

  @override
  State<_DisclosureHarness> createState() => _DisclosureHarnessState();
}

class _DisclosureHarnessState extends State<_DisclosureHarness> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final key = widget.disclosureKey;
    return TldrBody(
      tldr: 'Summary first.',
      expanded: expanded,
      additionalReport: 'Full report details.',
      onToggle: () => setState(() => expanded = !expanded),
      onOpenInternals: widget.onOpenInternals ?? () {},
      disclosureKey: key ?? const ValueKey('taskAgentReportDisclosure'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AgentReportEntity report({String? tldr, String content = 'Full report.'}) =>
      AgentDomainEntity.agentReport(
            id: 'report-1',
            agentId: 'agent-1',
            scope: AgentReportScopes.current,
            createdAt: kAgentTestDate,
            vectorClock: null,
            content: content,
            tldr: tldr,
          )
          as AgentReportEntity;

  group('report text resolution', () {
    test('the summary is the report tldr when it has one', () {
      expect(resolveReportTldr(report(tldr: 'Short.')), 'Short.');
    });

    test('a blank tldr falls back to the full content', () {
      expect(resolveReportTldr(report(tldr: '   ')), 'Full report.');
      expect(resolveReportTldr(report()), 'Full report.');
    });

    test('no report at all resolves to the empty string, not null', () {
      expect(resolveReportTldr(null), '');
    });

    test('the full text sits behind Read more when it differs', () {
      expect(
        resolveReportAdditional(report(tldr: 'Short.')),
        'Full report.',
      );
    });

    test('a full text equal to the tldr is not disclosed again — the same '
        'paragraph twice is what a no-op Read more looks like', () {
      expect(
        resolveReportAdditional(report(tldr: 'Same.', content: 'Same.')),
        isNull,
      );
    });

    test('nothing is disclosed without a separate tldr, without content, or '
        'without a report', () {
      expect(resolveReportAdditional(report()), isNull);
      expect(
        resolveReportAdditional(report(tldr: 'Short.', content: ' ')),
        isNull,
      );
      expect(resolveReportAdditional(null), isNull);
    });
  });

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
            trailing: const SizedBox(
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

    testWidgets('a nameless agent gets the card title alone, in both the '
        'header and its semantics', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(agentName: '   ', onAgentTap: () {}),
        ),
      );

      // A blank name is no name: the caption row is omitted rather than
      // rendered empty, and the tap target announces only what it opens.
      expect(find.text('AI summary'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TldrHeader),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('AI summary'),
        findsOneWidget,
        reason: 'the nameless header announces the card, nothing more',
      );
    });

    testWidgets('the agent name rests in the meta ink and lifts to body ink '
        'under the pointer', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(agentName: 'Task Laura', onAgentTap: () {}),
        ),
      );

      final ai = tester
          .element(find.byType(TldrHeader))
          .designTokens
          .colors
          .aiCard;
      Color nameColor() => tester
          .renderObject<RenderParagraph>(find.text('Task Laura'))
          .text
          .style!
          .color!;
      expect(nameColor(), ai.metaText);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Task Laura')));
      await tester.pump();
      // The block answers on its own ink — there is no hover fill to answer
      // with, by design.
      expect(nameColor(), ai.bodyText);
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
    });

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
            trailing: const SizedBox(
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

    testWidgets('a text-bearing trailing slot is bounded to half the header '
        'instead of overflowing it', (tester) async {
      // Regression: the slot was an unbounded, non-flex child of the header
      // Row. A fixed-size playback button never noticed, but the goal read
      // card puts TEXT there — an impact pill plus an "as of …" caption —
      // which grows with the locale and the text scale, and an unbounded
      // trailing child of a Row clips rather than shrinks.
      tester.view
        ..physicalSize = const Size(320, 400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(
            agentName: 'Task Laura',
            onAgentTap: () {},
            // The PRODUCTION shape, not a single ellipsizing Text: the goal
            // read card hands this slot a min-size Row of two facts. Capping
            // the slot bounds the rail, not the children inside it — a Row
            // still lays its non-flex children out at their intrinsic
            // widths — so the fact that yields has to be flexible.
            // The PRODUCTION shape, not a single ellipsizing Text: the goal
            // read card hands this slot TWO facts. Each fits the cap alone;
            // together they do not. A Row would lay both out at their
            // intrinsic widths and clip past the cap — a Wrap drops the
            // second onto its own line instead.
            trailing: const Wrap(
              key: ValueKey('rail'),
              alignment: WrapAlignment.end,
              children: [
                SizedBox(key: ValueKey('rail-pill'), width: 90, height: 16),
                SizedBox(key: ValueKey('rail-age'), width: 90, height: 16),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.byType(TldrHeader));
      final rail = tester.getRect(find.byKey(const ValueKey('rail')));
      expect(rail.right, lessThanOrEqualTo(header.right));
      expect(
        rail.width,
        lessThanOrEqualTo(header.width / 2 + 1),
        reason: 'the identity block keeps at least half the header',
      );
      // 90 + 90 cannot fit a 160px cap, so the second fact took its own
      // line rather than the pair clipping past the header's edge.
      final pill = tester.getRect(find.byKey(const ValueKey('rail-pill')));
      final age = tester.getRect(find.byKey(const ValueKey('rail-age')));
      expect(age.top, greaterThanOrEqualTo(pill.bottom));
      expect(age.right, lessThanOrEqualTo(header.right));
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

  group('TldrHeader title', () {
    testWidgets('defaults to the shared AI card title', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(agentName: 'Task Laura', onAgentTap: () {}),
        ),
      );

      expect(find.text('AI summary'), findsOneWidget);
    });

    testWidgets('a host that is not an AI summary names itself instead, and '
        'the semantics label follows the visible title', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(
            title: 'Briefing',
            agentName: "Anna's companion",
            onAgentTap: () {},
          ),
        ),
      );

      expect(find.text('Briefing'), findsOneWidget);
      expect(find.text('AI summary'), findsNothing);
      expect(
        find.bySemanticsLabel("Briefing. Anna's companion"),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('with no agent name the semantics label is the title alone', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        makeTestableWidget(
          TldrHeader(title: 'Briefing', agentName: null, onAgentTap: () {}),
        ),
      );

      expect(find.bySemanticsLabel('Briefing'), findsOneWidget);
      semantics.dispose();
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

    testWidgets('the disclosure carries the host-supplied key, so a failure '
        'names the surface it happened on', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const _DisclosureHarness(
            disclosureKey: ValueKey('relationship-briefing-expand'),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('relationship-briefing-expand')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('taskAgentReportDisclosure')),
        findsNothing,
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
