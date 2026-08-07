import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph/ui/node_inspector_panel.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_cs.dart';
import 'package:lotti/l10n/app_localizations_de.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/l10n/app_localizations_es.dart';
import 'package:lotti/l10n/app_localizations_fr.dart';
import 'package:lotti/l10n/app_localizations_ro.dart';

import '../../../widget_test_utils.dart';

void main() {
  // `DsTokens` is a plain immutable value object exported by the design system,
  // so the style/tokens the panel needs can be built directly without pumping a
  // widget to fetch `context.designTokens` (mirrors the sibling style tests).
  const tokens = dsTokensDark;
  final style = GraphStyle.fromTokens(tokens);
  final messages = AppLocalizationsEn();

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
    double coverImageCropX = 0.5,
    String? imagePath,
    List<String> mediaPaths = const [],
  }) => GraphNode(
    id: id,
    type: type,
    label: label,
    categoryId: categoryId,
    createdAt: createdAt ?? created,
    oneLiner: oneLiner,
    tldr: tldr,
    coverImagePath: coverImagePath,
    coverImageCropX: coverImageCropX,
    imagePath: imagePath,
    mediaPaths: mediaPaths,
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
          relativeAge(messages, entry.key),
          entry.value,
          reason: 'age for ${entry.key}',
        );
      }
    });

    test('localizes singular age units in every supported locale', () {
      final cases =
          <
            ({
              String locale,
              AppLocalizations messages,
              String day,
              String week,
              String month,
            })
          >[
            (
              locale: 'en',
              messages: AppLocalizationsEn(),
              day: '1 day ago',
              week: '1 week ago',
              month: '1 month ago',
            ),
            (
              locale: 'cs',
              messages: AppLocalizationsCs(),
              day: 'před 1 dnem',
              week: 'před 1 týdnem',
              month: 'před 1 měsícem',
            ),
            (
              locale: 'de',
              messages: AppLocalizationsDe(),
              day: 'vor 1 Tag',
              week: 'vor 1 Woche',
              month: 'vor 1 Monat',
            ),
            (
              locale: 'es',
              messages: AppLocalizationsEs(),
              day: 'hace 1 día',
              week: 'hace 1 semana',
              month: 'hace 1 mes',
            ),
            (
              locale: 'fr',
              messages: AppLocalizationsFr(),
              day: 'il y a 1 jour',
              week: 'il y a 1 semaine',
              month: 'il y a 1 mois',
            ),
            (
              locale: 'ro',
              messages: AppLocalizationsRo(),
              day: 'acum 1 zi',
              week: 'acum 1 săptămână',
              month: 'acum 1 lună',
            ),
          ];

      for (final entry in cases) {
        expect(
          entry.messages.knowledgeGraphAgeDaysAgo(1),
          entry.day,
          reason: '${entry.locale} day',
        );
        expect(
          entry.messages.knowledgeGraphAgeWeeksAgo(1),
          entry.week,
          reason: '${entry.locale} week',
        );
        expect(
          entry.messages.knowledgeGraphAgeMonthsAgo(1),
          entry.month,
          reason: '${entry.locale} month',
        );
      }
    });

    test('uses Czech and Romanian plural categories for graph counts', () {
      final cs = AppLocalizationsCs();
      expect(cs.knowledgeGraphAgeDaysAgo(2), 'před 2 dny');
      expect(cs.knowledgeGraphAgeDaysAgo(5), 'před 5 dny');
      expect(cs.knowledgeGraphNodeCount(1), '1 uzel');
      expect(cs.knowledgeGraphNodeCount(2), '2 uzly');
      expect(cs.knowledgeGraphNodeCount(5), '5 uzlů');

      final ro = AppLocalizationsRo();
      expect(ro.knowledgeGraphAgeDaysAgo(2), 'acum 2 zile');
      expect(ro.knowledgeGraphAgeDaysAgo(20), 'acum 20 de zile');
      expect(ro.knowledgeGraphNodeCount(1), '1 nod');
      expect(ro.knowledgeGraphNodeCount(2), '2 noduri');
      expect(ro.knowledgeGraphNodeCount(20), '20 de noduri');
    });

    test('uses reviewed French and Spanish graph terminology', () {
      final fr = AppLocalizationsFr();
      expect(fr.knowledgeGraphBack, 'Revenir');
      expect(fr.knowledgeGraphNodeCount(1), '1 nœud');
      expect(fr.knowledgeGraphNodeCount(2), '2 nœuds');

      expect(
        AppLocalizationsEs().knowledgeGraphNodeTypeChecklist,
        'Lista de verificación',
      );
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
        previewFromMarkdown('graph_preview'),
        'graph preview',
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

  group('inspectorMediaPaths', () {
    test('orders cover art first and removes duplicate image paths', () {
      expect(
        inspectorMediaPaths(
          node(
            coverImagePath: '/cover.png',
            mediaPaths: const [
              '/cover.png',
              '/photo-one.png',
              '/photo-two.png',
            ],
            imagePath: '/photo-one.png',
          ),
        ),
        ['/cover.png', '/photo-one.png', '/photo-two.png'],
      );
    });

    test('falls back to the image entry path when no media list exists', () {
      expect(
        inspectorMediaPaths(node(imagePath: '/single.png')),
        ['/single.png'],
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
      List<GraphNode> neighbors = const [],
      DateTime? now,
      String createdLabel = '2 days ago',
      Map<String, String> categoryNames = const {},
      void Function(String id)? onNeighborTap,
      bool canGoBack = false,
      VoidCallback? onBack,
      VoidCallback? onRecenter,
      VoidCallback? onOpen,
      double panelWidth = 360,
      double panelHeight = 860,
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
              width: panelWidth,
              height: panelHeight,
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

    testWidgets('kicker uses a localized category fallback when unmapped', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        node: node(type: GraphNodeType.project, categoryId: 'health'),
      );
      expect(find.text('PROJECT · UNCATEGORIZED'), findsOneWidget);
    });

    testWidgets('kicker stays within a narrow inspector', (tester) async {
      const label = 'TASK · AN EXTREMELY LONG CATEGORY NAME';
      await pumpPanel(
        tester,
        node: node(categoryId: 'long-category'),
        categoryNames: const {
          'long-category': 'An extremely long category name',
        },
        panelWidth: 300,
      );

      final kicker = tester.widget<Text>(find.text(label));
      expect(kicker.maxLines, 1);
      expect(kicker.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the AI summary collapsed until requested', (
      tester,
    ) async {
      // tldr-only node → resolveInspectorSummary routes through splitTldr, so
      // the first line is the deck and the remainder is the SUMMARY body.
      await pumpPanel(
        tester,
        node: node(tldr: 'A crisp lede line\nThe longer body explanation.'),
      );
      expect(find.text('SUMMARY'), findsOneWidget);
      expect(find.text('A crisp lede line'), findsOneWidget);
      expect(find.text('The longer body explanation.'), findsNothing);

      await tester.tap(find.text('SUMMARY'));
      await tester.pump(kThemeAnimationDuration);

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

    testWidgets('uses the oneLiner as the deck and expands the full tldr', (
      tester,
    ) async {
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
      expect(find.text(previewFromMarkdown(tldr)), findsNothing);

      await tester.tap(find.text('SUMMARY'));
      await tester.pump(kThemeAnimationDuration);

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

    testWidgets('surfaces cover art in the compact media carousel', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        node: node(coverImagePath: '/tmp/does-not-exist-cover.png'),
      );
      expect(
        find.byKey(const ValueKey('knowledge-graph-media-carousel')),
        findsOneWidget,
      );
      expect(find.text('PHOTO · 1'), findsOneWidget);
      final imageFinder = find.byType(Image);
      final image = tester.widget<Image>(imageFinder);
      final fallback = image.errorBuilder!(
        tester.element(imageFinder),
        StateError('decode failed'),
        StackTrace.empty,
      );
      await tester.pumpWidget(makeTestableWidgetNoScroll(fallback));
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('does not reserve media space when the task has no photos', (
      tester,
    ) async {
      // node() defaults to a task node.
      await pumpPanel(tester, node: node());
      expect(find.byType(Image), findsNothing);
      expect(
        find.byKey(const ValueKey('knowledge-graph-media-carousel')),
        findsNothing,
      );
    });

    testWidgets(
      'keeps cover first, applies its crop, and includes task photos',
      (
        tester,
      ) async {
        await pumpPanel(
          tester,
          node: node(
            coverImagePath: '/cover.png',
            coverImageCropX: 0.75,
            mediaPaths: const [
              '/cover.png',
              '/photo-one.png',
              '/photo-two.png',
            ],
          ),
        );

        final list = tester.widget<ListView>(
          find.byKey(const ValueKey('knowledge-graph-media-carousel')),
        );
        expect(list.semanticChildCount, 3);
        expect(find.text('PHOTOS · 3'), findsOneWidget);

        final cover = tester.widget<Image>(
          find.byKey(
            const ValueKey('knowledge-graph-media-/cover.png'),
          ),
        );
        expect(cover.alignment, const Alignment(0.5, 0));
        // Provider changes (e.g. a DPR change altering cacheWidth) must keep
        // the previous frame instead of flashing the tile blank.
        expect(cover.gaplessPlayback, isTrue);
        final resized = cover.image as ResizeImage;
        expect(
          resized.width,
          ((tokens.spacing.step13 + tokens.spacing.step10) *
                  tester.view.devicePixelRatio)
              .round(),
        );
      },
    );

    testWidgets(
      'tapping a carousel tile opens the fullscreen gallery at that image',
      (tester) async {
        // Real files: the pushed viewer resolves them via FileImage, and a
        // missing file would surface as an async load exception.
        final tempDir = Directory.systemTemp.createTempSync('lotti_kg_panel_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final paths = [
          for (var i = 0; i < 3; i++) '${tempDir.path}/photo_$i.png',
        ];
        const transparentPng = [
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x00,
          0x00,
          0x0D,
          0x49,
          0x48,
          0x44,
          0x52,
          0x00,
          0x00,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x01,
          0x08,
          0x06,
          0x00,
          0x00,
          0x00,
          0x1F,
          0x15,
          0xC4,
          0x89,
          0x00,
          0x00,
          0x00,
          0x0A,
          0x49,
          0x44,
          0x41,
          0x54,
          0x78,
          0x9C,
          0x63,
          0x00,
          0x01,
          0x00,
          0x00,
          0x05,
          0x00,
          0x01,
          0x0D,
          0x0A,
          0x2D,
          0xB4,
          0x00,
          0x00,
          0x00,
          0x00,
          0x49,
          0x45,
          0x4E,
          0x44,
          0xAE,
          0x42,
          0x60,
          0x82,
        ];
        for (final path in paths) {
          File(path).writeAsBytesSync(transparentPng);
        }

        await pumpPanel(
          tester,
          node: node(coverImagePath: paths.first, mediaPaths: paths),
        );

        // The second tile only peeks into the carousel viewport, so a
        // hit-tested tap can miss; invoke its InkWell directly — the tap
        // affordance itself, not hit testing, is under test here.
        final tile = tester.widget<InkWell>(
          find.ancestor(
            of: find.byKey(ValueKey('knowledge-graph-media-${paths[1]}')),
            matching: find.byType(InkWell),
          ),
        );
        tile.onTap!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final viewer = tester.widget<HeroPhotoViewRouteWrapper>(
          find.byType(HeroPhotoViewRouteWrapper),
        );
        expect(viewer.file.path, paths[1]);
        expect(viewer.initialIndex, 1);
        expect(
          viewer.gallery!.map((file) => file.path).toList(),
          paths,
          reason: 'the whole carousel is navigable from the viewer',
        );
        expect(viewer.heroTag, 'knowledge-graph-media-hero-${paths[1]}');
      },
    );

    group('overflow affordance', () {
      List<GraphNode> manyNeighbors() => [
        for (var i = 0; i < 12; i++)
          node(
            id: 'nb-$i',
            type: GraphNodeType.textEntry,
            label: 'Linked entry number $i',
            createdAt: created.subtract(Duration(days: i)),
          ),
      ];

      testWidgets(
        'a list that continues below the fold offers a way to reach the rest',
        (tester) async {
          // Regression: the LINKED eyebrow counted entries the panel appeared
          // not to have — the list scrolled, but the only hint was a fade that
          // read as a dimmed/disabled section.
          await pumpPanel(
            tester,
            node: node(),
            neighbors: manyNeighbors(),
            panelHeight: 320,
          );
          await tester.pump();

          expect(find.text('More below'), findsOneWidget);

          // The affordance takes the user to the end of the list, where it
          // then has nothing left to announce.
          await tester.tap(find.text('More below'));
          await tester.pumpAndSettle();

          expect(find.text('More below'), findsNothing);
          expect(find.text('Linked entry number 11'), findsOneWidget);
        },
      );

      testWidgets(
        'the reserved bottom strip alone never triggers the affordance',
        (tester) async {
          // Regression: the panel reserves a bottom strip for the fade and
          // the pill. That padding inflates the scroll extent by itself, so a
          // panel whose real content fits was still reporting overflow and
          // offering to scroll the user to blank space.
          //
          // These heights sit in the band where the scrollable reports a
          // POSITIVE maxScrollExtent that is entirely the reserved strip —
          // exactly the case the old `maxScrollExtent > 0` check got wrong.
          for (final height in <double>[412, 404, 396]) {
            await pumpPanel(
              tester,
              node: node(),
              neighbors: [
                for (var i = 0; i < 3; i++)
                  node(
                    id: 'nb-$i',
                    type: GraphNodeType.textEntry,
                    label: 'Linked entry $i',
                  ),
              ],
              panelHeight: height,
            );
            await tester.pump();

            final scrollable = tester
                .widgetList<SingleChildScrollView>(
                  find.descendant(
                    of: find.byType(NodeInspectorPanel),
                    matching: find.byType(SingleChildScrollView),
                  ),
                )
                .first;
            final extent = scrollable.controller!.position.maxScrollExtent;
            final reserved = tokens.spacing.sectionGap;

            // Guard the guard: if this stops being the interesting band the
            // test would silently stop proving anything.
            expect(
              extent,
              inExclusiveRange(0, reserved + 0.01),
              reason:
                  'height $height no longer isolates padding-only overflow '
                  '(extent $extent vs reserved $reserved)',
            );
            expect(
              find.text('More below'),
              findsNothing,
              reason:
                  'height $height: offered to scroll to blank reserved space',
            );
          }
        },
      );

      testWidgets(
        'a list that fits shows no overflow affordance at all',
        (tester) async {
          await pumpPanel(
            tester,
            node: node(),
            neighbors: [
              node(
                id: 'only',
                type: GraphNodeType.textEntry,
                label: 'The one linked entry',
              ),
            ],
          );
          await tester.pump();

          expect(find.text('More below'), findsNothing);
        },
      );
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
        find.text(
          '${typeLabel(messages, GraphNodeType.textEntry)} · 2 days ago',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '${typeLabel(messages, GraphNodeType.aiResponse)} · 2 days ago',
        ),
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
        GraphNodeType.mediaCollection: RelStyle.note,
        GraphNodeType.aggregate: RelStyle.linkedTask,
      };
      for (final type in GraphNodeType.values) {
        expect(relStyleForNeighborType(type), expected[type], reason: '$type');
      }
    });
  });
}
