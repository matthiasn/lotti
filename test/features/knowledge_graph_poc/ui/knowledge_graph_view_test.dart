import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_painter.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_view.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/node_inspector_panel.dart';

import '../../../widget_test_utils.dart';

void main() {
  // Deterministic clock for any ad-hoc scenarios (production scenarios already
  // pin their own `now`).
  final fixedNow = DateTime(2026, 6, 15);

  // Desktop layout: wide enough that `inspectorVisible` (width >= 720) is true.
  const desktopSize = Size(1280, 800);
  // Phone layout: narrow enough that the inspector is suppressed and the
  // floating title chip shows instead.
  const phoneSize = Size(390, 844);

  /// Pumps [KnowledgeGraphView] at a real render surface of [size] (set via
  /// `tester.view`, since `MediaQueryData` alone does not resize the viewport).
  /// The surface reset is registered so the global default is restored.
  Future<void> pumpView(
    WidgetTester tester, {
    GraphScenario? scenario,
    Map<String, Color>? categoryColors,
    Map<String, String> categoryNames = const {},
    String? initialFocusId,
    String? initialPreviousFocusId,
    bool showInspector = true,
    bool showTitle = true,
    bool showLegend = true,
    Size size = desktopSize,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        KnowledgeGraphView(
          scenario: scenario,
          categoryColors: categoryColors,
          categoryNames: categoryNames,
          initialFocusId: initialFocusId,
          initialPreviousFocusId: initialPreviousFocusId,
          showInspector: showInspector,
          showTitle: showTitle,
          showLegend: showLegend,
        ),
        mediaQueryData: MediaQueryData(size: size),
      ),
    );
    // Let the deferred image load (`_loadImages`) settle without animation.
    await tester.pump();
  }

  // ---------------------------------------------------------------------------
  // Pure replica of the view's `_framedTransform` so a neighbor's on-screen
  // position can be computed deterministically for tap-to-walk. This mirrors the
  // private method exactly (same constants, same reserves) — when it drifts the
  // tap-to-walk test fails loudly, which is the intended early-warning.
  // ---------------------------------------------------------------------------
  (double, Offset) framedTransform(
    GraphScenario scenario,
    GraphLayout layout,
    Size size,
    String focusId, {
    bool showTitle = true,
    bool showLegend = true,
  }) {
    final adjacency = {for (final n in scenario.nodes) n.id: <String>[]};
    for (final e in scenario.edges) {
      adjacency[e.fromId]?.add(e.toId);
      adjacency[e.toId]?.add(e.fromId);
    }
    final hops = <String, int>{focusId: 0};
    final queue = <String>[focusId];
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      for (final nb in adjacency[cur] ?? const <String>[]) {
        if (!hops.containsKey(nb)) {
          hops[nb] = hops[cur]! + 1;
          queue.add(nb);
        }
      }
    }
    final region = scenario.nodes
        .where((n) => (hops[n.id] ?? 99) <= 2)
        .map((n) => layout.positions[n.id])
        .whereType<Offset>()
        .toList();
    final focusPos = layout.positions[focusId] ?? Offset.zero;
    if (region.isEmpty) {
      return (1, Offset(size.width / 2, size.height / 2));
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in region) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    final bw = math.max(maxX - minX, 1);
    final bh = math.max(maxY - minY, 1);
    const margin = 60;
    final topReserve = showTitle ? 84 : margin;
    final bottomReserve = showLegend ? 104 : margin;
    final availW = math.max(size.width - margin * 2, 80);
    final availH = math.max(size.height - topReserve - bottomReserve, 80);
    final scale = math.min(availW / bw, availH / bh).clamp(0.45, 1.5);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2 * 0.4 + focusPos.dy * 0.6;
    final viewportCenter = Offset(size.width / 2, topReserve + availH / 2);
    final pan = viewportCenter - Offset(cx, cy) * scale;
    return (scale, pan);
  }

  /// The single [KnowledgeGraphPainter] the view paints with — the canonical
  /// readout for focus / pan / walk state, which are otherwise private.
  KnowledgeGraphPainter painterOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(KnowledgeGraphView),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is KnowledgeGraphPainter,
        ),
      ),
    );
    return paint.painter! as KnowledgeGraphPainter;
  }

  String painterFocusId(WidgetTester tester) => painterOf(tester).focusId;

  group('rendering', () {
    testWidgets('renders a CustomPaint with the seed as the focus node', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      await pumpView(tester, scenario: scenario);

      // The painter is the graph surface; its focus must start at the seed.
      expect(painterFocusId(tester), scenario.seedId);
      // The seed's label is surfaced (inspector on desktop).
      expect(find.text('Ship v2.3 release'), findsWidgets);
    });

    testWidgets('a single-node scenario still renders without throwing', (
      tester,
    ) async {
      final scenario = GraphScenario(
        name: 'Solo',
        seedId: 'only',
        nodes: [
          GraphNode(
            id: 'only',
            type: GraphNodeType.task,
            label: 'Lonely task',
            categoryId: catWork,
            createdAt: fixedNow,
          ),
        ],
        edges: const [],
        now: fixedNow,
      );

      await pumpView(tester, scenario: scenario);

      expect(painterFocusId(tester), 'only');
      // Inspector shows the lone node's label, proving the degenerate region
      // (region == single point) is laid out without an exception.
      expect(find.text('Lonely task'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  /// Matches text [t] that lives inside the [NodeInspectorPanel] (not the
  /// legend, title chip, or graph overlay) — the inspector cases assert here so
  /// a stray match elsewhere can't satisfy the expectation.
  Finder inspectorText(String t) => find.descendant(
    of: find.byType(NodeInspectorPanel),
    matching: find.text(t),
  );

  group('inspector preview content (desktop)', () {
    testWidgets('resolves the category NAME, type label and links breakdown', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      await pumpView(
        tester,
        scenario: scenario,
        // Map the synthetic category id to a real display name.
        categoryNames: const {catWork: 'Work projects'},
      );

      // The inspector panel is the right-rail dossier.
      expect(find.byType(NodeInspectorPanel), findsOneWidget);
      // Title (node label) as the heading inside the panel.
      expect(inspectorText('Ship v2.3 release'), findsOneWidget);
      // Kicker: "TYPE · CATEGORY" uppercased, with the RESOLVED category name
      // (not the raw id).
      expect(inspectorText('TASK · WORK PROJECTS'), findsOneWidget);
      // LINKED breakdown: a "LINKED" section plus a chip per neighbor type. The
      // seed's neighbors are 3 tasks, 2 notes, 2 audio notes, 1 photo, 1
      // project, 2 AI summaries, 1 rating and 1 checklist (13 links total).
      expect(inspectorText('LINKED'), findsOneWidget);
      expect(inspectorText('3  Task'), findsOneWidget);
      expect(inspectorText('2  Note'), findsOneWidget);
      expect(inspectorText('2  Audio note'), findsOneWidget);
      expect(inspectorText('1  Project'), findsOneWidget);
      expect(inspectorText('2  AI summary'), findsOneWidget);
    });

    testWidgets('falls back to the raw category id when no name is provided', (
      tester,
    ) async {
      await pumpView(tester, scenario: taskEgoNetworkScenario());

      // categoryNames is empty -> the kicker resolves to the raw id `work`,
      // uppercased.
      expect(inspectorText('TASK · WORK'), findsOneWidget);
    });

    testWidgets('shows the type-based lede fallback when tldr is absent', (
      tester,
    ) async {
      // The ego scenario's seed has no tldr, so the inspector renders the
      // task-type fallback lede (`tldrFallback`).
      await pumpView(
        tester,
        scenario: taskEgoNetworkScenario(),
        categoryNames: const {catWork: 'Work'},
      );

      expect(inspectorText('A Work task in your graph.'), findsOneWidget);
    });

    testWidgets('shows the node tldr (split into a lede) when present', (
      tester,
    ) async {
      // Build a tiny scenario whose seed carries a markdown tldr; the inspector
      // must strip heading/bullet/emphasis markers into a clean preview.
      final scenario = GraphScenario(
        name: 'Tldr',
        seedId: 's',
        nodes: [
          GraphNode(
            id: 's',
            type: GraphNodeType.task,
            label: 'Summarised task',
            categoryId: catWork,
            createdAt: fixedNow,
            tldr: '## TL;DR\n- **Ship** the build\n- _verify_ smoke tests',
          ),
          GraphNode(
            id: 'n',
            type: GraphNodeType.textEntry,
            label: 'Note',
            categoryId: catWork,
            createdAt: fixedNow,
          ),
        ],
        edges: const [
          GraphEdge(fromId: 's', toId: 'n', kind: GraphEdgeKind.association),
        ],
        now: fixedNow,
      );

      await pumpView(tester, scenario: scenario);

      // The tldr is split into a one-liner lede (first line) + a SUMMARY body
      // (the remainder), with markdown punctuation flattened.
      expect(inspectorText('TL;DR'), findsOneWidget);
      expect(inspectorText('SUMMARY'), findsOneWidget);
      expect(
        inspectorText('• Ship the build\n• verify smoke tests'),
        findsOneWidget,
      );
      // Since a real tldr is present, the type-based fallback lede must NOT show.
      expect(
        inspectorText('A Work task in your graph.'),
        findsNothing,
      );
    });

    testWidgets('builds an Image.file cover when the node has an image path', (
      tester,
    ) async {
      // Point at a path that does not exist on disk — the cover still builds an
      // Image.file (its errorBuilder handles the missing file at paint time).
      final scenario = GraphScenario(
        name: 'Cover',
        seedId: 's',
        nodes: [
          GraphNode(
            id: 's',
            type: GraphNodeType.imageEntry,
            label: 'Photo entry',
            categoryId: catWork,
            createdAt: fixedNow,
            imagePath: '/tmp/lotti_kg_view_test_missing.png',
          ),
          GraphNode(
            id: 'n',
            type: GraphNodeType.textEntry,
            label: 'Note',
            categoryId: catWork,
            createdAt: fixedNow,
          ),
        ],
        edges: const [
          GraphEdge(fromId: 's', toId: 'n', kind: GraphEdgeKind.association),
        ],
        now: fixedNow,
      );

      await pumpView(tester, scenario: scenario);

      final images = tester.widgetList<Image>(
        find.descendant(
          of: find.byType(KnowledgeGraphView),
          matching: find.byType(Image),
        ),
      );
      final fileImages = images
          .map((i) => i.image)
          .whereType<FileImage>()
          .where((p) => p.file.path == '/tmp/lotti_kg_view_test_missing.png');
      expect(
        fileImages,
        isNotEmpty,
        reason: 'inspector cover should build Image.file for the image path',
      );
    });
  });

  group('title chip vs inspector', () {
    testWidgets('desktop shows the inspector and hides the floating title', (
      tester,
    ) async {
      await pumpView(
        tester,
        scenario: taskEgoNetworkScenario(),
        categoryNames: const {catWork: 'Work'},
      );

      // The inspector panel (right rail) is shown, naming the focus node and
      // its relative age in the footer ('12 days ago' for the seed, created
      // _daysAgo(12)). These are inspector-only readouts.
      expect(find.byType(NodeInspectorPanel), findsOneWidget);
      expect(inspectorText('Ship v2.3 release'), findsOneWidget);
      expect(inspectorText('12 days ago'), findsOneWidget);
      // The floating title chip's caption ('Tap a node to walk · N nodes' or
      // 'N nodes') must be absent when the inspector is visible.
      expect(find.textContaining(' nodes'), findsNothing);
    });

    testWidgets('phone hides the inspector and shows the floating title chip', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      await pumpView(
        tester,
        scenario: scenario,
        size: phoneSize,
      );

      // The inspector panel is suppressed (width < 720).
      expect(find.byType(NodeInspectorPanel), findsNothing);
      // The title chip names the focus and the node count. The ego scenario is
      // not explorable (<= 40 nodes) -> caption is just 'N nodes'.
      expect(find.text('Ship v2.3 release'), findsWidgets);
      expect(find.text('${scenario.nodes.length} nodes'), findsOneWidget);
    });

    testWidgets(
      'showInspector: false on desktop falls back to the title chip',
      (tester) async {
        final scenario = taskEgoNetworkScenario();
        await pumpView(
          tester,
          scenario: scenario,
          showInspector: false,
        );

        // No inspector -> the chip is shown even on a wide viewport.
        expect(find.text('${scenario.nodes.length} nodes'), findsOneWidget);
        expect(find.byType(NodeInspectorPanel), findsNothing);
      },
    );

    testWidgets('explorable world shows the "Tap a node to walk" caption', (
      tester,
    ) async {
      // The explore-world scenario has > 40 nodes -> `_world` true -> explorable
      // caption + walk controls. Phone size so the title chip (with caption)
      // renders.
      final scenario = exploreWorldScenario();
      await pumpView(
        tester,
        scenario: scenario,
        size: phoneSize,
      );

      expect(
        find.text('Tap a node to walk · ${scenario.nodes.length} nodes'),
        findsOneWidget,
      );
    });
  });

  group('legend', () {
    testWidgets('shows resolved category names and a relation label', (
      tester,
    ) async {
      await pumpView(
        tester,
        scenario: taskEgoNetworkScenario(),
        categoryNames: const {catWork: 'Engineering', catWriting: 'Docs'},
      );

      // Categories present in the scenario, resolved to display names.
      expect(find.text('Engineering'), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
      // A relation-class legend entry (containment is always present here).
      expect(find.text('in project'), findsOneWidget);
      // The size/recency legend keys.
      expect(find.text('more links'), findsOneWidget);
      expect(find.text('recent → older'), findsOneWidget);
    });

    testWidgets('hides the legend when showLegend is false', (tester) async {
      await pumpView(
        tester,
        scenario: taskEgoNetworkScenario(),
        categoryNames: const {catWork: 'Engineering'},
        showLegend: false,
      );

      expect(find.text('more links'), findsNothing);
      expect(find.text('recent → older'), findsNothing);
    });
  });

  group('controls (explorable world)', () {
    testWidgets('renders back + recenter controls, with back disabled', (
      tester,
    ) async {
      // Phone size so the controls (rendered under the title chip) are present.
      await pumpView(tester, scenario: exploreWorldScenario(), size: phoneSize);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);

      // With no walk history the back button's InkWell has a null onTap.
      final backInk = tester.widget<InkWell>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(InkWell),
        ),
      );
      expect(backInk.onTap, isNull);

      // Recenter is always enabled.
      final recenterInk = tester.widget<InkWell>(
        find.ancestor(
          of: find.byIcon(Icons.center_focus_strong),
          matching: find.byType(InkWell),
        ),
      );
      expect(recenterInk.onTap, isNotNull);
    });

    testWidgets('tapping recenter restarts the camera glide without throwing', (
      tester,
    ) async {
      await pumpView(tester, scenario: exploreWorldScenario(), size: phoneSize);

      await tester.tap(find.byIcon(Icons.center_focus_strong));
      // Advance the bounded camera animation (760ms) in steps; never settle,
      // since the wake controller also ticks.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'controls are absent for a non-explorable (small) scenario',
      (tester) async {
        await pumpView(
          tester,
          scenario: taskEgoNetworkScenario(),
          size: phoneSize,
        );

        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(find.byIcon(Icons.center_focus_strong), findsNothing);
      },
    );
  });

  group('walk history via initial focus', () {
    testWidgets(
      'starting walked-to a node makes back available and frames that node',
      (tester) async {
        // The explore-world seed is P0T0; start the view already focused on a
        // neighbor reached from it, with the seed as the previous focus.
        final scenario = exploreWorldScenario();
        await pumpView(
          tester,
          scenario: scenario,
          initialFocusId: 'P0T1',
          initialPreviousFocusId: 'P0T0',
          size: phoneSize,
        );

        // Focus is the walked-to node, not the seed.
        expect(painterFocusId(tester), 'P0T1');
        // The painter is told where it came from (renders the trail/ghost).
        final painter = painterOf(tester);
        expect(painter.previousFocusId, 'P0T0');
        expect(painter.walkPath, isNotEmpty);
      },
    );

    testWidgets('an invalid initialFocusId falls back to the seed', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      await pumpView(
        tester,
        scenario: scenario,
        initialFocusId: 'does-not-exist',
      );

      expect(painterFocusId(tester), scenario.seedId);
    });
  });

  group('tap-to-walk', () {
    testWidgets('tapping a neighbor node changes the focus', (tester) async {
      // Use the ego scenario (deterministic layout). Compute where a 1-hop
      // neighbor renders under the view's initial framing, then tap there.
      final scenario = taskEgoNetworkScenario();
      final layout = computeGraphLayout(scenario);
      await pumpView(tester, scenario: scenario);

      // Pick the project neighbor 'p0' (1 hop, distinct sector -> well
      // separated from siblings, so the 30px hit radius lands on it cleanly).
      const targetId = 'p0';
      final (scale, pan) = framedTransform(
        scenario,
        layout,
        desktopSize,
        scenario.seedId,
      );
      final worldPos = layout.positions[targetId]!;
      final screenPos = worldPos * scale + pan;

      expect(painterFocusId(tester), scenario.seedId);

      await tester.tapAt(screenPos);
      // Drive the bounded camera glide (760ms) in steps without settling.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Focus walked to the tapped node.
      expect(painterFocusId(tester), targetId);
      // The inspector now describes the project node: its label as the heading
      // and the uppercased "PROJECT · WORK" kicker.
      expect(inspectorText('Lotti 2.x'), findsOneWidget);
      expect(inspectorText('PROJECT · WORK'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping empty space leaves the focus unchanged', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      await pumpView(tester, scenario: scenario);

      expect(painterFocusId(tester), scenario.seedId);

      // Top-left corner: far from any node (the graph is framed near center).
      await tester.tapAt(const Offset(4, 4));
      await tester.pump(const Duration(milliseconds: 200));

      expect(painterFocusId(tester), scenario.seedId);
    });

    testWidgets(
      'walking to a neighbor then back returns to the seed',
      (tester) async {
        final scenario = taskEgoNetworkScenario();
        final layout = computeGraphLayout(scenario);
        // Explorable controls only render for `_world` scenarios, so the `back`
        // path is driven by tapping out then tapping the previous node, which
        // exercises `_walkTo` symmetrically (history is internal). Here we
        // verify the round-trip lands back on the seed by walking out and then
        // tapping the seed's screen position.
        await pumpView(tester, scenario: scenario);

        final (scale, pan) = framedTransform(
          scenario,
          layout,
          desktopSize,
          scenario.seedId,
        );
        // Walk to project 'p0'.
        final p0Screen = layout.positions['p0']! * scale + pan;
        await tester.tapAt(p0Screen);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(painterFocusId(tester), 'p0');

        // From p0, the seed is its only 1-hop neighbor (containment edge), so
        // it must be visible in p0's frame. Recompute the frame for focus p0
        // and tap the seed.
        final (scale2, pan2) = framedTransform(
          scenario,
          layout,
          desktopSize,
          'p0',
        );
        final seedScreen = layout.positions[scenario.seedId]! * scale2 + pan2;
        await tester.tapAt(seedScreen);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        expect(painterFocusId(tester), scenario.seedId);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('pan / zoom gesture', () {
    testWidgets('a drag pans the graph without changing the focus', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      await pumpView(tester, scenario: scenario);

      final panBefore = painterOf(tester).pan;

      // Drag from center — a scale/pan gesture (onScaleUpdate) shifts the pan.
      await tester.drag(
        find.byType(KnowledgeGraphView),
        const Offset(120, 40),
      );
      await tester.pump();

      final after = painterOf(tester);

      // The pan moved; the focus did not.
      expect(after.pan, isNot(panBefore));
      expect(after.focusId, scenario.seedId);
    });
  });
}
