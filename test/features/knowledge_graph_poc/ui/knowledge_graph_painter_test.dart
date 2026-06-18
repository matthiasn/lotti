import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_motion_controller.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_painter.dart';

import '../../../widget_test_utils.dart';

void main() {
  // `DsTokens` is a plain immutable value object exported by the design system,
  // so we can read the canonical dark-mode token set directly instead of
  // pumping a widget to fetch `context.designTokens`.
  const tokens = dsTokensDark;
  final style = GraphStyle.fromTokens(tokens);

  // Deterministic "now" so recency-as-luminance (and the age comparator in the
  // label sort) is reproducible across runs.
  final now = DateTime(2026, 6, 15, 12);
  const size = Size(800, 600);

  GraphNode node({
    required String id,
    required GraphNodeType type,
    String? label,
    String categoryId = 'cat-work',
    DateTime? createdAt,
  }) => GraphNode(
    id: id,
    type: type,
    label: label ?? 'Label $id',
    categoryId: categoryId,
    createdAt: createdAt ?? now,
  );

  // A rich scenario exercising every relation class so the painter walks all
  // `RelStyle` branches: containment (solid, directional), linkedTask (dashed,
  // directional), note (solid), checklist (solid), provenance (dashed,
  // directional, cyan), evaluation (dot-dash, directional, pink). The two
  // dashed kinds plus evaluation drive `_dashPoly`; the directional kinds drive
  // `_arrowhead`.
  GraphScenario richScenario() {
    final nodes = <GraphNode>[
      // The focus task and its project (containment).
      node(id: 'task', type: GraphNodeType.task, label: 'Focus task'),
      node(id: 'proj', type: GraphNodeType.project),
      // A linked sibling task (association → linkedTask, dashed + arrow).
      node(id: 'sibling', type: GraphNodeType.task),
      // A log note (association → note, solid). Old so recency fade engages.
      node(
        id: 'note',
        type: GraphNodeType.textEntry,
        createdAt: now.subtract(const Duration(days: 40)),
      ),
      // An audio entry (association → note).
      node(id: 'aud', type: GraphNodeType.audioEntry),
      // An image entry — gets a real thumbnail in the `images` map below.
      node(id: 'img', type: GraphNodeType.imageEntry),
      // An AI response (provenance, dashed cyan + arrow).
      node(id: 'ai', type: GraphNodeType.aiResponse),
      // A rating (evaluation, dot-dash pink + arrow).
      node(id: 'rate', type: GraphNodeType.rating),
      // A checklist and one item (checklist relation, depth-2 node).
      node(id: 'cl', type: GraphNodeType.checklist),
      node(id: 'cli', type: GraphNodeType.checklistItem),
      // A second category so a biome haze cluster (>=3 nodes) renders for it.
      node(id: 'far-a', type: GraphNodeType.textEntry, categoryId: 'cat-home'),
      node(id: 'far-b', type: GraphNodeType.textEntry, categoryId: 'cat-home'),
      node(id: 'far-c', type: GraphNodeType.textEntry, categoryId: 'cat-home'),
    ];
    final edges = <GraphEdge>[
      const GraphEdge(
        fromId: 'proj',
        toId: 'task',
        kind: GraphEdgeKind.containment,
      ),
      const GraphEdge(
        fromId: 'proj',
        toId: 'sibling',
        kind: GraphEdgeKind.containment,
      ),
      const GraphEdge(
        fromId: 'task',
        toId: 'sibling',
        kind: GraphEdgeKind.association,
      ),
      const GraphEdge(
        fromId: 'task',
        toId: 'note',
        kind: GraphEdgeKind.association,
      ),
      const GraphEdge(
        fromId: 'task',
        toId: 'aud',
        kind: GraphEdgeKind.association,
      ),
      const GraphEdge(
        fromId: 'task',
        toId: 'img',
        kind: GraphEdgeKind.association,
      ),
      const GraphEdge(
        fromId: 'task',
        toId: 'ai',
        kind: GraphEdgeKind.provenance,
      ),
      const GraphEdge(
        fromId: 'rate',
        toId: 'task',
        kind: GraphEdgeKind.evaluation,
      ),
      const GraphEdge(
        fromId: 'task',
        toId: 'cl',
        kind: GraphEdgeKind.association,
      ),
      const GraphEdge(
        fromId: 'cl',
        toId: 'cli',
        kind: GraphEdgeKind.checklist,
      ),
      // Connect the far cluster loosely so it has positions but low emphasis.
      const GraphEdge(
        fromId: 'note',
        toId: 'far-a',
        kind: GraphEdgeKind.association,
      ),
      const GraphEdge(
        fromId: 'far-a',
        toId: 'far-b',
        kind: GraphEdgeKind.association,
      ),
      const GraphEdge(
        fromId: 'far-b',
        toId: 'far-c',
        kind: GraphEdgeKind.association,
      ),
    ];
    return GraphScenario(
      name: 'rich',
      seedId: 'task',
      nodes: nodes,
      edges: edges,
      now: now,
    );
  }

  // BFS hop distances from the focus, mirroring what the production provider
  // feeds the painter. Covers every `emphasis` band (<=1, 2, 3, 4, >4 and the
  // absent-key default).
  Map<String, int> hopsFor(GraphScenario scenario, String focusId) {
    final adj = <String, List<String>>{
      for (final n in scenario.nodes) n.id: <String>[],
    };
    for (final e in scenario.edges) {
      adj[e.fromId]?.add(e.toId);
      adj[e.toId]?.add(e.fromId);
    }
    final hops = <String, int>{focusId: 0};
    final queue = <String>[focusId];
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      for (final nb in adj[cur] ?? const <String>[]) {
        if (!hops.containsKey(nb)) {
          hops[nb] = hops[cur]! + 1;
          queue.add(nb);
        }
      }
    }
    return hops;
  }

  // Build a tiny opaque RGBA image without touching the file system or the
  // platform codec: paint one filled rect into a PictureRecorder, end the
  // recording, and rasterize the resulting Picture. `toImage` is async, so
  // callers must run this inside `tester.runAsync`.
  Future<ui.Image> makeDummyImage({int w = 8, int h = 8}) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF3366CC),
    );
    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  KnowledgeGraphPainter painterFor(
    GraphScenario scenario, {
    Map<String, Offset>? positions,
    Map<String, int>? degrees,
    Map<String, int>? hops,
    double scale = 1,
    Offset pan = const Offset(400, 300),
    String focusId = 'task',
    String? selectedId,
    Map<String, ui.Image> images = const {},
    String? previousFocusId,
    List<String> walkPath = const [],
    double wake = 0,
    int labelMaxHop = 2,
    GraphMotionController? motion,
  }) {
    final pos =
        positions ?? computeGraphLayout(scenario, iterations: 12).positions;
    return KnowledgeGraphPainter(
      scenario: scenario,
      positions: pos,
      degrees: degrees ?? degreeMap(scenario.edges),
      scale: scale,
      pan: pan,
      focusId: focusId,
      hops: hops ?? hopsFor(scenario, focusId),
      selectedId: selectedId,
      style: style,
      images: images,
      previousFocusId: previousFocusId,
      walkPath: walkPath,
      wake: wake,
      labelMaxHop: labelMaxHop,
      motion: motion,
    );
  }

  // Drive paint() against a recording canvas — cheap, and every code path
  // (sort comparator, _dashPoly guard, bezier/arrow geometry, label collision
  // pass) executes. Returns the error if paint throws, for a precise message.
  void expectPaintsCleanly(KnowledgeGraphPainter painter) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    expect(() => painter.paint(canvas, size), returnsNormally);
    // Realize the recording so any deferred raster work is forced to run.
    expect(recorder.endRecording().toImageSync(1, 1), isNotNull);
  }

  group('paint()', () {
    test('renders a full multi-relation ego scenario without throwing', () {
      // Focus set, all relation classes, biome haze, glyphs and labels all run.
      expectPaintsCleanly(painterFor(richScenario()));
    });

    test('renders an empty scenario without throwing', () {
      final empty = GraphScenario(
        name: 'empty',
        seedId: 'ghost',
        nodes: const [],
        edges: const [],
        now: now,
      );
      // No nodes: _screen(focusId) would throw on a missing key, so the focus
      // must have a position. Provide one explicitly and an empty hops map.
      final painter = painterFor(
        empty,
        positions: const {'ghost': Offset.zero},
        degrees: const {},
        hops: const {},
        focusId: 'ghost',
      );
      expectPaintsCleanly(painter);
    });

    test('renders a single-node scenario without throwing', () {
      final single = GraphScenario(
        name: 'single',
        seedId: 'solo',
        nodes: [node(id: 'solo', type: GraphNodeType.task)],
        edges: const [],
        now: now,
      );
      expectPaintsCleanly(painterFor(single, focusId: 'solo'));
    });

    test('handles a focus with hops covering every emphasis band', () {
      // hopsFor produces depth 0..3 for the rich scenario; add an explicit far
      // node (hop 5) and an unreachable node (absent → 0.12 default) so the
      // full emphasis falloff ladder (<=1, 2, 3, 4, >4, absent) is exercised.
      final scenario = richScenario();
      final hops = hopsFor(scenario, 'task')
        ..['far-c'] =
            5 // pushes the >4 / 0.16 band
        ..remove('cli'); // unreachable → emphasis() default branch
      expectPaintsCleanly(painterFor(scenario, hops: hops));
    });

    test('renders with a previous focus, selection and a walk trail', () {
      final scenario = richScenario();
      // previousFocusId draws the ghost ring; walkPath length>=2 draws the wake
      // trail; selectedId (not the focus) draws the selection ring.
      expectPaintsCleanly(
        painterFor(
          scenario,
          selectedId: 'note',
          previousFocusId: 'sibling',
          walkPath: const ['sibling', 'task', 'cl'],
          wake: 0.6,
        ),
      );
    });

    test('drops a walk trail with a single point', () {
      final scenario = richScenario();
      // walkPath length < 2 short-circuits _paintWake — still must not throw.
      expectPaintsCleanly(
        painterFor(scenario, walkPath: const ['task']),
      );
    });

    test('renders across different pan / scale values', () {
      final scenario = richScenario();
      // Small scale (zoom clamp lower bound, far-horizon edge culling) and a
      // large scale (zoom clamp upper bound, biome radius clamp) both run.
      for (final scale in <double>[0.3, 1, 2.5]) {
        expectPaintsCleanly(
          painterFor(scenario, scale: scale, pan: const Offset(120, 80)),
        );
      }
    });

    test('renders with a very high labelMaxHop so distant labels place', () {
      final scenario = richScenario();
      // labelMaxHop 99 forces the label collision pass over every node, hitting
      // the placed/obstacle overlap rejection and the no-candidate skip.
      expectPaintsCleanly(painterFor(scenario, labelMaxHop: 99));
    });

    test('renders coincident nodes without dividing by a zero edge length', () {
      // Two nodes at the same world position make raw.distance < 1, exercising
      // the early-return guard in _paintEdge.
      final scenario = GraphScenario(
        name: 'coincident',
        seedId: 'a',
        nodes: [
          node(id: 'a', type: GraphNodeType.task),
          node(id: 'b', type: GraphNodeType.textEntry),
        ],
        edges: const [
          GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
        ],
        now: now,
      );
      expectPaintsCleanly(
        painterFor(
          scenario,
          positions: const {'a': Offset.zero, 'b': Offset.zero},
          focusId: 'a',
        ),
      );
    });
  });

  group('paint() with a real thumbnail (widget pump + recording canvas)', () {
    testWidgets('lit-sphere path is replaced by drawImageRect for image nodes', (
      tester,
    ) async {
      late ui.Image thumb;
      await tester.runAsync(() async {
        thumb = await makeDummyImage();
      });
      addTearDown(thumb.dispose);

      final scenario = richScenario();
      final painter = painterFor(scenario, images: {'img': thumb});

      // (a) Pump the painter inside a real CustomPaint so the framework drives
      // paint() against a live canvas — if it builds, paint() ran end-to-end.
      await tester.pumpWidget(
        makeTestableWidget(
          Center(
            child: CustomPaint(size: size, painter: painter),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);

      // (b) Also drive it against a recording canvas to assert the image branch
      // (clip + drawImageRect + _coverSrc) completes without throwing.
      expectPaintsCleanly(painter);
    });
  });

  group('shouldRepaint()', () {
    late GraphScenario scenario;
    late KnowledgeGraphPainter base;

    setUp(() {
      scenario = richScenario();
      base = painterFor(scenario);
    });

    test(
      'returns false for a painter built from identical field references',
      () {
        // Rebuild with the SAME references so every identity comparison holds.
        final same = KnowledgeGraphPainter(
          scenario: base.scenario,
          positions: base.positions,
          degrees: base.degrees,
          scale: base.scale,
          pan: base.pan,
          focusId: base.focusId,
          hops: base.hops,
          selectedId: base.selectedId,
          style: base.style,
          images: base.images,
          previousFocusId: base.previousFocusId,
          walkPath: base.walkPath,
          wake: base.wake,
          labelMaxHop: base.labelMaxHop,
          motion: base.motion,
        );
        expect(same.shouldRepaint(base), isFalse);
      },
    );

    test('returns true when the focus id changes', () {
      final next = painterFor(scenario, focusId: 'sibling');
      expect(next.shouldRepaint(base), isTrue);
    });

    test('returns true when the scale changes', () {
      // Reuse the same positions map so ONLY scale differs.
      final next = painterFor(scenario, positions: base.positions, scale: 1.5);
      expect(next.shouldRepaint(base), isTrue);
    });

    test('returns true when the pan changes', () {
      final next = painterFor(
        scenario,
        positions: base.positions,
        pan: const Offset(10, 20),
      );
      expect(next.shouldRepaint(base), isTrue);
    });

    test('returns true when a different images map instance is supplied', () {
      // A distinct (even if empty) map instance must trip the identity check —
      // this guards the documented stale-image bug class.
      final next = painterFor(
        scenario,
        positions: base.positions,
        images: <String, ui.Image>{},
      );
      expect(next.shouldRepaint(base), isTrue);
    });

    test('returns true when the scenario instance changes', () {
      final next = painterFor(richScenario(), positions: base.positions);
      expect(next.shouldRepaint(base), isTrue);
    });

    test('returns true when the selected id changes', () {
      final next = painterFor(
        scenario,
        positions: base.positions,
        selectedId: 'note',
      );
      expect(next.shouldRepaint(base), isTrue);
    });

    test('returns true when the wake / walk trail changes', () {
      final wakeChanged = painterFor(
        scenario,
        positions: base.positions,
        wake: 0.5,
      );
      final walkChanged = painterFor(
        scenario,
        positions: base.positions,
        walkPath: const ['task', 'note'],
      );
      expect(wakeChanged.shouldRepaint(base), isTrue);
      expect(walkChanged.shouldRepaint(base), isTrue);
    });

    test('returns true when previousFocusId or labelMaxHop changes', () {
      final prevChanged = painterFor(
        scenario,
        positions: base.positions,
        previousFocusId: 'note',
      );
      final hopChanged = painterFor(
        scenario,
        positions: base.positions,
        labelMaxHop: 5,
      );
      expect(prevChanged.shouldRepaint(base), isTrue);
      expect(hopChanged.shouldRepaint(base), isTrue);
    });

    test('returns true when the motion controller changes', () {
      final motion = GraphMotionController(vsync: const TestVSync());
      addTearDown(motion.dispose);

      final next = painterFor(
        scenario,
        positions: base.positions,
        motion: motion,
      );

      expect(next.shouldRepaint(base), isTrue);
    });
  });
}
