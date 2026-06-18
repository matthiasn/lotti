import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/node_inspector_panel.dart';

import '../../../widget_test_utils.dart';

void main() {
  // `DsTokens` is a plain immutable value object exported by the design system,
  // so the style/tokens the panel needs can be built directly without pumping a
  // widget to fetch `context.designTokens` (mirrors the sibling style tests).
  const tokens = dsTokensDark;
  final style = GraphStyle.fromTokens(tokens);

  // Deterministic "now" / created times — no `DateTime.now()` in tests.
  final created = DateTime(2026, 6, 15, 12);

  GraphNode node({
    String id = 'n1',
    GraphNodeType type = GraphNodeType.task,
    String label = 'Focus task',
    String categoryId = 'work',
    DateTime? createdAt,
    String? oneLiner,
    String? tldr,
    String? coverImagePath,
    String? imagePath,
  }) => GraphNode(
    id: id,
    type: type,
    label: label,
    categoryId: categoryId,
    createdAt: createdAt ?? created,
    oneLiner: oneLiner,
    tldr: tldr,
    coverImagePath: coverImagePath,
    imagePath: imagePath,
  );

  // ---------------------------------------------------------------------------
  // Pure functions
  // ---------------------------------------------------------------------------

  group('relativeAge', () {
    test('covers every branch boundary', () {
      // Duration overrides `==`, so the map itself can't be const.
      final cases = <Duration, String>{
        // < 24h → 'today'
        const Duration(hours: 1): 'today',
        const Duration(hours: 23, minutes: 59): 'today',
        // exactly 24h is 1 day → 'yesterday'
        const Duration(hours: 24): 'yesterday',
        const Duration(days: 1, hours: 12): 'yesterday',
        // 2..13 days → 'N days ago'
        const Duration(days: 2): '2 days ago',
        const Duration(days: 13): '13 days ago',
        // 14..59 days → 'N weeks ago' (round(days / 7))
        const Duration(days: 14): '2 weeks ago',
        const Duration(days: 59): '8 weeks ago',
        // >= 60 days → 'N months ago' (round(days / 30))
        const Duration(days: 60): '2 months ago',
        const Duration(days: 200): '7 months ago',
      };
      for (final entry in cases.entries) {
        expect(
          relativeAge(entry.key),
          entry.value,
          reason: 'age for ${entry.key}',
        );
      }
    });
  });

  group('previewFromMarkdown', () {
    test('strips leading heading markers', () {
      expect(previewFromMarkdown('## Heading text'), 'Heading text');
      expect(previewFromMarkdown('###### Deep'), 'Deep');
    });

    test('normalizes -, * and + list bullets to "• "', () {
      for (final marker in ['-', '*', '+']) {
        expect(
          previewFromMarkdown('$marker item'),
          '• item',
          reason: 'bullet for "$marker"',
        );
      }
    });

    test('turns underscores into spaces so identifiers stay readable', () {
      expect(
        previewFromMarkdown('enable_knowledge_graph'),
        'enable knowledge graph',
      );
    });

    test('removes emphasis, backtick and quote punctuation', () {
      expect(previewFromMarkdown('*bold* and `code`'), 'bold and code');
      // The leading '>' is removed and the trailing .trim() drops the gap it
      // left, so the quote marker disappears cleanly.
      expect(previewFromMarkdown('> quoted line'), 'quoted line');
      // A '>' mid-string is removed, and the doubled space it leaves collapses.
      expect(previewFromMarkdown('a > b'), 'a b');
    });

    test('collapses runs of spaces/tabs and blank lines', () {
      expect(previewFromMarkdown('a    b'), 'a b');
      expect(previewFromMarkdown('a\t\tb'), 'a b');
      expect(
        previewFromMarkdown('line one\n\n\nline two'),
        'line one\nline two',
      );
    });

    test('falls back to the trimmed original when fully stripped to empty', () {
      // '###' is all heading marker → cleaned is empty → original is returned.
      expect(previewFromMarkdown('  ###  '), '###');
    });
  });

  group('splitTldr', () {
    test('splits on the first newline when the first line is short', () {
      final result = splitTldr('First line\nSecond line\nThird line');
      expect(result.lede, 'First line');
      expect(result.body, 'Second line\nThird line');
    });

    test('splits on the first sentence when there is no newline', () {
      final result = splitTldr('Hello world. The rest follows here.');
      expect(result.lede, 'Hello world.');
      expect(result.body, 'The rest follows here.');
    });

    test('splits on the first sentence when the first line is too long', () {
      // First line is 170 chars (> 160) so the newline branch is skipped and
      // the first sentence becomes the lede instead.
      final longFirst = '${'x' * 170}. tail.\nignored newline';
      final result = splitTldr(longFirst);
      expect(result.lede, '${'x' * 170}.');
      expect(result.body, 'tail.\nignored newline');
    });

    test('returns lede only with empty body for a single sentence', () {
      final result = splitTldr('Only one sentence here.');
      expect(result.lede, 'Only one sentence here.');
      expect(result.body, isEmpty);
    });

    test('strips a leading bullet marker from the lede', () {
      // The bullet line is normalized to "• ..." by previewFromMarkdown, then
      // splitTldr removes the leading "• " from the lede.
      final result = splitTldr('- First bullet\nSecond line');
      expect(result.lede, 'First bullet');
      expect(result.body, 'Second line');
    });

    test('returns empty lede and body for empty / whitespace input', () {
      expect(splitTldr('').lede, isEmpty);
      expect(splitTldr('').body, isEmpty);
      expect(splitTldr('   \n  ').lede, isEmpty);
      expect(splitTldr('   \n  ').body, isEmpty);
    });
  });

  group('resolveInspectorSummary', () {
    // Deterministic created time — no `DateTime.now()` in tests.
    final summaryCreated = DateTime(2026, 6, 15, 12);

    GraphNode summaryNode({String? oneLiner, String? tldr}) => GraphNode(
      id: 'n1',
      type: GraphNodeType.task,
      label: 'Focus task',
      categoryId: 'work',
      createdAt: summaryCreated,
      oneLiner: oneLiner,
      tldr: tldr,
    );

    test('oneLiner + tldr → deck is the oneLiner, body is the preview of '
        'tldr', () {
      const oneLiner = 'Ship the inspector panel';
      const tldr = '## Heading\nThe longer body explanation.';
      final result = resolveInspectorSummary(
        summaryNode(oneLiner: oneLiner, tldr: tldr),
      );
      expect(result.deck, oneLiner);
      // The body is the markdown preview of the whole tldr — not split.
      expect(result.body, previewFromMarkdown(tldr));
    });

    test('oneLiner only → deck is the oneLiner, body is null', () {
      const oneLiner = 'Just a tagline';
      final result = resolveInspectorSummary(summaryNode(oneLiner: oneLiner));
      expect(result.deck, oneLiner);
      expect(result.body, isNull);
    });

    test('tldr only (multi-line) → deck/body come from splitTldr', () {
      const tldr = 'A crisp lede line\nThe longer body explanation.';
      final result = resolveInspectorSummary(summaryNode(tldr: tldr));
      final split = splitTldr(tldr);
      expect(result.deck, split.lede);
      expect(result.body, split.body);
      // Sanity: the multi-line tldr really does produce both a lede and a body.
      expect(result.deck, 'A crisp lede line');
      expect(result.body, 'The longer body explanation.');
    });

    test('tldr only (single sentence) → deck is the lede, body is null', () {
      // splitTldr returns an empty body for a single sentence, which
      // resolveInspectorSummary maps to null.
      final result = resolveInspectorSummary(
        summaryNode(tldr: 'Only one sentence here.'),
      );
      expect(result.deck, 'Only one sentence here.');
      expect(result.body, isNull);
    });

    test('neither oneLiner nor tldr → both deck and body are null', () {
      final result = resolveInspectorSummary(summaryNode());
      expect(result.deck, isNull);
      expect(result.body, isNull);
    });

    test('blank-string oneLiner and tldr are treated as null', () {
      // Whitespace-only fields trim to empty → treated as absent.
      final result = resolveInspectorSummary(
        summaryNode(oneLiner: '   ', tldr: '  \n  '),
      );
      expect(result.deck, isNull);
      expect(result.body, isNull);
    });

    test('non-blank oneLiner with blank tldr → deck only, body null', () {
      final result = resolveInspectorSummary(
        summaryNode(oneLiner: 'Tagline', tldr: '   '),
      );
      expect(result.deck, 'Tagline');
      expect(result.body, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget
  // ---------------------------------------------------------------------------

  group('NodeInspectorPanel', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required GraphNode node,
      List<GraphNode> neighbors = const [],
      DateTime? now,
      String createdLabel = '2 days ago',
      Map<String, String> categoryNames = const {},
      void Function(String id)? onNeighborTap,
      bool canGoBack = false,
      VoidCallback? onBack,
      VoidCallback? onRecenter,
      VoidCallback? onOpen,
    }) async {
      tester.view
        ..physicalSize = const Size(420, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: 360,
              height: 860,
              // The timeline rows use InkWell, which needs a Material ancestor;
              // the panel itself is a frosted DecoratedBox with no Material.
              child: Material(
                type: MaterialType.transparency,
                child: NodeInspectorPanel(
                  node: node,
                  neighbors: neighbors,
                  now: now ?? created,
                  createdLabel: createdLabel,
                  categoryNames: categoryNames,
                  style: style,
                  tokens: tokens,
                  onNeighborTap: onNeighborTap,
                  canGoBack: canGoBack,
                  onBack: onBack,
                  onRecenter: onRecenter,
                  onOpen: onOpen,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the full node label as the title, untruncated', (
      tester,
    ) async {
      // A 60+ char title proves the heading has no maxLines / truncation.
      const longTitle =
          'Refactor the knowledge graph explorer and ship the inspector panel';
      expect(longTitle.length, greaterThan(60));
      await pumpPanel(tester, node: node(label: longTitle));
      // The complete string is found → nothing was clipped or ellipsized.
      expect(find.text(longTitle), findsOneWidget);
    });

    testWidgets('kicker shows TYPE · resolved category name, uppercased', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        // node() defaults to a task node in category 'work'.
        node: node(),
        categoryNames: const {'work': 'Deep Work'},
      );
      expect(find.text('TASK · DEEP WORK'), findsOneWidget);
    });

    testWidgets('kicker falls back to the raw category id when unmapped', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        node: node(type: GraphNodeType.project, categoryId: 'health'),
      );
      // No categoryNames entry → the raw id is used as the label.
      expect(find.text('PROJECT · HEALTH'), findsOneWidget);
    });

    testWidgets('renders both the deck and the SUMMARY body for a '
        'multi-line tldr', (tester) async {
      // tldr-only node → resolveInspectorSummary routes through splitTldr, so
      // the first line is the deck and the remainder is the SUMMARY body.
      await pumpPanel(
        tester,
        node: node(tldr: 'A crisp lede line\nThe longer body explanation.'),
      );
      expect(find.text('SUMMARY'), findsOneWidget);
      expect(find.text('A crisp lede line'), findsOneWidget);
      expect(find.text('The longer body explanation.'), findsOneWidget);
    });

    testWidgets('shows the deck but no SUMMARY body for a single-sentence '
        'tldr', (tester) async {
      await pumpPanel(tester, node: node(tldr: 'Just one sentence.'));
      // A single-sentence tldr yields a deck (the lede) but an empty body, so
      // the SUMMARY section is omitted while the deck still renders.
      expect(find.text('Just one sentence.'), findsOneWidget);
      expect(find.text('SUMMARY'), findsNothing);
    });

    testWidgets('renders the oneLiner as the deck under the title', (
      tester,
    ) async {
      // A oneLiner with no tldr → the deck (one-liner) renders and there is no
      // SUMMARY body.
      await pumpPanel(tester, node: node(oneLiner: 'Ship the inspector panel'));
      expect(find.text('Ship the inspector panel'), findsOneWidget);
      expect(find.text('SUMMARY'), findsNothing);
    });

    testWidgets('renders both the oneLiner deck and the SUMMARY body when a '
        'oneLiner and a multi-line tldr are present', (tester) async {
      const oneLiner = 'Ship the inspector panel';
      const tldr = 'A crisp lede line\nThe longer body explanation.';
      await pumpPanel(
        tester,
        node: node(oneLiner: oneLiner, tldr: tldr),
      );
      // The deck is the one-liner verbatim (the tldr is NOT split out for the
      // deck here); the body is the full markdown preview of the tldr.
      expect(find.text(oneLiner), findsOneWidget);
      expect(find.text('SUMMARY'), findsOneWidget);
      expect(find.text(previewFromMarkdown(tldr)), findsOneWidget);
    });

    testWidgets('shows no deck and no SUMMARY when there is neither a '
        'oneLiner nor a tldr', (tester) async {
      // node() defaults to a task node in category 'work' with no oneLiner and
      // no tldr.
      await pumpPanel(
        tester,
        node: node(),
        categoryNames: const {'work': 'Work'},
      );
      // No summary fields → the SUMMARY section is omitted entirely. The old
      // generic type-based fallback line no longer exists.
      expect(find.text('SUMMARY'), findsNothing);
    });

    testWidgets('builds an Image in the hero when a cover image is set', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        node: node(coverImagePath: '/tmp/does-not-exist-cover.png'),
      );
      // Image.file may not decode under test (the file is absent); asserting
      // the Image widget is present in the tree is sufficient here.
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('falls back to the gradient hero when the cover fails to load', (
      tester,
    ) async {
      // A cover path that does not exist on disk: Image.file builds, the decode
      // fails, and its errorBuilder swaps in `_gradientHero()` — which paints
      // the type glyph. Pumping inside runAsync lets the (failing) FileImage
      // resolve so the errorBuilder actually fires.
      final coverNode = node(
        type: GraphNodeType.imageEntry,
        coverImagePath: '/nonexistent/cover_xyz.png',
      );
      // The hero glyph rendered *inside* the Image is the errorBuilder's
      // `_gradientHero()` output (the kicker glyph lives elsewhere in the tree).
      final heroGlyph = find.descendant(
        of: find.byType(Image),
        matching: find.byIcon(glyphForType(GraphNodeType.imageEntry)),
      );

      await tester.runAsync(() async {
        tester.view
          ..physicalSize = const Size(420, 900)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Center(
              child: SizedBox(
                width: 360,
                height: 860,
                child: NodeInspectorPanel(
                  node: coverNode,
                  neighbors: const [],
                  now: created,
                  createdLabel: 'today',
                  categoryNames: const {},
                  style: style,
                  tokens: tokens,
                ),
              ),
            ),
          ),
        );
        // The FileImage load fails asynchronously against the real event loop;
        // pump (bounded) until the errorBuilder swaps in the gradient hero. Real
        // file I/O justifies the real-time yield (test/README.md fake-time
        // exception).
        for (var i = 0; i < 50; i++) {
          await tester.pump();
          if (heroGlyph.evaluate().isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();

      expect(
        heroGlyph,
        findsOneWidget,
        reason: 'errorBuilder should render the gradient hero glyph',
      );
    });

    testWidgets('shows the gradient hero glyph and no Image when there is no '
        'cover', (tester) async {
      // node() defaults to a task node.
      await pumpPanel(tester, node: node());
      expect(find.byType(Image), findsNothing);
      // The gradient hero watermark uses the type glyph (also reused by the
      // kicker), so it is present at least once.
      expect(find.byIcon(glyphForType(GraphNodeType.task)), findsWidgets);
    });

    testWidgets('renders a LINKED · N section with a timeline row per '
        'neighbor', (tester) async {
      // Two neighbors of distinct types, each 2 days before `now`, so the age
      // string is deterministically 'today' for one and computed for both.
      // createdAt = created - 2 days → relativeAge == '2 days ago'.
      final twoDaysBefore = created.subtract(const Duration(days: 2));
      final neighbors = [
        node(
          id: 'nb-note',
          type: GraphNodeType.textEntry,
          label: 'A linked note snippet',
          createdAt: twoDaysBefore,
        ),
        node(
          id: 'nb-ai',
          type: GraphNodeType.aiResponse,
          label: 'An AI summary snippet',
          createdAt: twoDaysBefore,
        ),
      ];
      await pumpPanel(tester, node: node(), neighbors: neighbors);

      // Header counts the neighbors.
      expect(find.text('LINKED · 2'), findsOneWidget);

      // Each row shows the neighbor snippet label …
      expect(find.text('A linked note snippet'), findsOneWidget);
      expect(find.text('An AI summary snippet'), findsOneWidget);

      // … and its "typeLabel · age" caption (age is deterministic).
      expect(
        find.text('${typeLabel(GraphNodeType.textEntry)} · 2 days ago'),
        findsOneWidget,
      );
      expect(
        find.text('${typeLabel(GraphNodeType.aiResponse)} · 2 days ago'),
        findsOneWidget,
      );
    });

    testWidgets('shows no LINKED section when there are no neighbors', (
      tester,
    ) async {
      await pumpPanel(tester, node: node());
      // No 'LINKED · ...' header is rendered for an empty timeline.
      expect(find.textContaining('LINKED'), findsNothing);
    });

    testWidgets('tapping a timeline row invokes onNeighborTap with the '
        'neighbor id', (tester) async {
      final tapped = <String>[];
      final neighbor = node(
        id: 'nb-tap',
        label: 'Tap target row',
        createdAt: created.subtract(const Duration(days: 2)),
      );
      await pumpPanel(
        tester,
        node: node(),
        neighbors: [neighbor],
        onNeighborTap: tapped.add,
      );

      // Tap the row by its snippet text; the InkWell wrapping the row fires the
      // callback with the neighbor's id.
      await tester.tap(find.text('Tap target row'));
      await tester.pump();

      expect(tapped, ['nb-tap']);
    });

    testWidgets('timeline rows render and do not crash on tap when '
        'onNeighborTap is null', (tester) async {
      final neighbor = node(
        id: 'nb-null',
        type: GraphNodeType.textEntry,
        label: 'Non-tappable row',
        createdAt: created.subtract(const Duration(days: 2)),
      );
      // No onNeighborTap passed → rows still render; tapping is a no-op.
      await pumpPanel(tester, node: node(), neighbors: [neighbor]);

      expect(find.text('Non-tappable row'), findsOneWidget);
      // Tapping must not throw even though the InkWell's onTap is null.
      await tester.tap(find.text('Non-tappable row'));
      await tester.pump();
      expect(find.text('Non-tappable row'), findsOneWidget);
    });

    testWidgets('renders the pre-formatted created label in the footer', (
      tester,
    ) async {
      await pumpPanel(tester, node: node(), createdLabel: '5 weeks ago');
      expect(find.text('5 weeks ago'), findsOneWidget);
    });

    testWidgets('cross-fades content via the keyed AnimatedSwitcher when the '
        'focus node changes', (tester) async {
      tester.view
        ..physicalSize = const Size(420, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget panelFor(GraphNode n) => makeTestableWidgetNoScroll(
        Center(
          child: SizedBox(
            width: 360,
            height: 860,
            child: NodeInspectorPanel(
              node: n,
              neighbors: const [],
              now: created,
              createdLabel: 'today',
              categoryNames: const {},
              style: style,
              tokens: tokens,
            ),
          ),
        ),
      );

      await tester.pumpWidget(panelFor(node(id: 'a', label: 'First node')));
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.text('First node'), findsOneWidget);

      // Different id → AnimatedSwitcher swaps the keyed content.
      await tester.pumpWidget(panelFor(node(id: 'b', label: 'Second node')));
      // Advance past the 220ms cross-fade without risking a pumpAndSettle hang.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Second node'), findsOneWidget);
    });

    testWidgets('renders both nav buttons and fires their callbacks when '
        'enabled (canGoBack)', (tester) async {
      var backTaps = 0;
      var recenterTaps = 0;
      await pumpPanel(
        tester,
        node: node(),
        canGoBack: true,
        onBack: () => backTaps++,
        onRecenter: () => recenterTaps++,
      );

      final backIcon = find.byIcon(Icons.arrow_back_rounded);
      final recenterIcon = find.byIcon(Icons.center_focus_strong_rounded);
      expect(backIcon, findsOneWidget);
      expect(recenterIcon, findsOneWidget);

      // canGoBack → the back button is enabled and invokes onBack.
      await tester.tap(backIcon);
      await tester.pump();
      expect(backTaps, 1);
      expect(recenterTaps, 0);

      // The recenter button is always wired when onRecenter is provided.
      await tester.tap(recenterIcon);
      await tester.pump();
      expect(recenterTaps, 1);
      expect(backTaps, 1);
    });

    testWidgets('renders the back button but does not fire onBack when '
        'canGoBack is false', (tester) async {
      var backTaps = 0;
      await pumpPanel(
        tester,
        node: node(),
        onBack: () => backTaps++,
        onRecenter: () {},
      );

      final backIcon = find.byIcon(Icons.arrow_back_rounded);
      // The disabled back button still renders (so the control doesn't pop in
      // and out as history changes).
      expect(backIcon, findsOneWidget);

      // canGoBack is false → the InkWell's onTap is null, so tapping is a no-op.
      await tester.tap(backIcon);
      await tester.pump();
      expect(backTaps, 0);
    });

    testWidgets('renders no nav buttons when both onBack and onRecenter are '
        'null', (tester) async {
      // node() with the default pumpPanel nav params (all null/false).
      await pumpPanel(tester, node: node());
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsNothing);
    });

    testWidgets('renders the open-details button and fires onOpen on tap when '
        'onOpen is provided', (tester) async {
      var openTaps = 0;
      await pumpPanel(tester, node: node(), onOpen: () => openTaps++);

      final openIcon = find.byIcon(Icons.open_in_full_rounded);
      expect(openIcon, findsOneWidget);

      await tester.tap(openIcon);
      await tester.pump();
      expect(openTaps, 1);
    });

    testWidgets('renders no open-details button when onOpen is null', (
      tester,
    ) async {
      // node() with the default pumpPanel nav params (onOpen null).
      await pumpPanel(tester, node: node());
      expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
    });
  });

  group('relStyleForNeighborType', () {
    test('maps every node type to its graph relation class (exhaustive)', () {
      const expected = <GraphNodeType, RelStyle>{
        GraphNodeType.project: RelStyle.containment,
        GraphNodeType.aiResponse: RelStyle.provenance,
        GraphNodeType.rating: RelStyle.evaluation,
        GraphNodeType.checklist: RelStyle.checklist,
        GraphNodeType.checklistItem: RelStyle.checklist,
        GraphNodeType.task: RelStyle.linkedTask,
        GraphNodeType.textEntry: RelStyle.note,
        GraphNodeType.audioEntry: RelStyle.note,
        GraphNodeType.imageEntry: RelStyle.note,
      };
      for (final type in GraphNodeType.values) {
        expect(relStyleForNeighborType(type), expected[type], reason: '$type');
      }
    });
  });
}
