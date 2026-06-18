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
    String? tldr,
    String? coverImagePath,
    String? imagePath,
  }) => GraphNode(
    id: id,
    type: type,
    label: label,
    categoryId: categoryId,
    createdAt: created,
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

  group('tldrFallback', () {
    const categoryLabel = 'Work';

    test('returns a non-empty descriptor for every node type', () {
      for (final type in GraphNodeType.values) {
        final fallback = tldrFallback(node(type: type), categoryLabel);
        expect(fallback, isNotEmpty, reason: 'fallback for $type');
      }
    });

    test('includes the category label for task and project nodes', () {
      expect(
        // node() defaults to a task node.
        tldrFallback(node(), categoryLabel),
        contains(categoryLabel),
      );
      expect(
        tldrFallback(node(type: GraphNodeType.project), categoryLabel),
        contains(categoryLabel),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Widget
  // ---------------------------------------------------------------------------

  group('NodeInspectorPanel', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required GraphNode node,
      Map<GraphNodeType, int> neighborCounts = const {},
      String createdLabel = '2 days ago',
      Map<String, String> categoryNames = const {},
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
              child: NodeInspectorPanel(
                node: node,
                createdLabel: createdLabel,
                neighborCounts: neighborCounts,
                categoryNames: categoryNames,
                style: style,
                tokens: tokens,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the node label as the title', (tester) async {
      await pumpPanel(tester, node: node(label: 'My focus task'));
      expect(find.text('My focus task'), findsOneWidget);
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

    testWidgets('renders both lede and body and the SUMMARY label for a '
        'multi-line tldr', (tester) async {
      await pumpPanel(
        tester,
        node: node(tldr: 'A crisp lede line\nThe longer body explanation.'),
      );
      expect(find.text('A crisp lede line'), findsOneWidget);
      expect(find.text('The longer body explanation.'), findsOneWidget);
      expect(find.text('SUMMARY'), findsOneWidget);
    });

    testWidgets('shows the type-based fallback lede and no SUMMARY when tldr '
        'is null', (tester) async {
      // node() defaults to a task node in category 'work'.
      final taskNode = node();
      await pumpPanel(
        tester,
        node: taskNode,
        categoryNames: const {'work': 'Work'},
      );
      // The fallback lede for a task includes the category label.
      expect(find.text(tldrFallback(taskNode, 'Work')), findsOneWidget);
      expect(find.text('SUMMARY'), findsNothing);
    });

    testWidgets('shows the lede but no SUMMARY for a single-sentence tldr', (
      tester,
    ) async {
      await pumpPanel(tester, node: node(tldr: 'Just one sentence.'));
      expect(find.text('Just one sentence.'), findsOneWidget);
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
      // the Image widget is present in the tree is sufficient.
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows the gradient hero glyph and no Image when there is no '
        'cover', (tester) async {
      // node() defaults to a task node.
      await pumpPanel(tester, node: node());
      expect(find.byType(Image), findsNothing);
      // The gradient hero watermark uses the type glyph.
      expect(find.byIcon(glyphForType(GraphNodeType.task)), findsWidgets);
    });

    testWidgets('renders a LINKED section with a chip per type when there are '
        'neighbors', (tester) async {
      await pumpPanel(
        tester,
        node: node(),
        neighborCounts: const {
          GraphNodeType.textEntry: 3,
          GraphNodeType.aiResponse: 1,
        },
      );
      expect(find.text('LINKED'), findsOneWidget);
      // One chip per type, each showing "count  typeLabel".
      expect(
        find.text('3  ${typeLabel(GraphNodeType.textEntry)}'),
        findsOneWidget,
      );
      expect(
        find.text('1  ${typeLabel(GraphNodeType.aiResponse)}'),
        findsOneWidget,
      );
    });

    testWidgets('omits zero-count neighbors from the LINKED section', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        node: node(),
        neighborCounts: const {
          GraphNodeType.textEntry: 2,
          GraphNodeType.rating: 0,
        },
      );
      expect(find.text('LINKED'), findsOneWidget);
      expect(
        find.text('2  ${typeLabel(GraphNodeType.textEntry)}'),
        findsOneWidget,
      );
      // The zero-count rating chip must not render.
      expect(
        find.text('0  ${typeLabel(GraphNodeType.rating)}'),
        findsNothing,
      );
    });

    testWidgets('shows no LINKED section when there are no neighbors', (
      tester,
    ) async {
      await pumpPanel(tester, node: node());
      expect(find.text('LINKED'), findsNothing);
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
              createdLabel: 'today',
              neighborCounts: const {},
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
  });
}
