import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_keyboard_navigation.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph/ui/entry_detail_sidebar.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_workspace_toolbar.dart';
import 'package:lotti/features/knowledge_graph/ui/knowledge_graph_painter.dart';
import 'package:lotti/features/knowledge_graph/ui/knowledge_graph_view.dart';
import 'package:lotti/features/knowledge_graph/ui/node_inspector_panel.dart';
import 'package:lotti/features/knowledge_graph/ui/topology_minimap.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';

import '../../../mocks/mocks.dart';
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
    GraphLayout? layout,
    bool showInspector = true,
    bool showTitle = true,
    bool showLegend = true,
    bool disableAnimations = false,
    void Function(String taskId, String previousFocusId)? onTaskFocusChanged,
    GraphImageLoader? imageLoader,
    GraphVisualSpec? visualSpec,
    Size size = desktopSize,
    List<Override> extraOverrides = const [],
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
          layout: layout,
          onTaskFocusChanged: onTaskFocusChanged,
          showInspector: showInspector,
          showTitle: showTitle,
          showLegend: showLegend,
          imageLoader: imageLoader,
          visualSpec: visualSpec,
        ),
        mediaQueryData: MediaQueryData(
          size: size,
          disableAnimations: disableAnimations,
        ),
        overrides: extraOverrides,
      ),
    );
    // Let the deferred image load (`_loadImages`) settle without animation.
    await tester.pump();
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

  /// On-screen position of a node given its [worldPos] (its layout position),
  /// using the painter's ACTUAL applied transform. Reading the live
  /// `scale`/`pan` (rather than replicating the view's private framing formula)
  /// makes tap targets correct regardless of how `_framedTransform` frames the
  /// focus — call it only after the relevant frame has settled. The result must
  /// land within the view's 30px tap-hit radius for a tap to walk to that node.
  Offset screenPosOf(WidgetTester tester, Offset worldPos) {
    final p = painterOf(tester);
    return worldPos * p.scale + p.pan;
  }

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

    testWidgets('uses a provided full layout for the topology minimap', (
      tester,
    ) async {
      // The provider relaxes the layout off the main thread and hands it in;
      // the view must paint from exactly those positions, not recompute its own.
      final scenario = GraphScenario(
        name: 'provided',
        seedId: 'a',
        nodes: [
          GraphNode(
            id: 'a',
            type: GraphNodeType.task,
            label: 'A',
            categoryId: catWork,
            createdAt: fixedNow,
          ),
          GraphNode(
            id: 'b',
            type: GraphNodeType.textEntry,
            label: 'B',
            categoryId: catWork,
            createdAt: fixedNow,
          ),
        ],
        edges: const [
          GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
        ],
        now: fixedNow,
      );
      const positions = {'a': Offset(12, 34), 'b': Offset(56, 78)};
      await pumpView(
        tester,
        scenario: scenario,
        layout: const GraphLayout(positions),
      );

      final minimapPaint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('knowledge-graph-topology-minimap')),
      );
      expect(
        (minimapPaint.painter! as TopologyMiniMapPainter).positions,
        positions,
      );
      // The main canvas owns a separate focus-centred local layout.
      expect(painterOf(tester).positions, isNot(equals(positions)));
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

    testWidgets('uses the visual spec node budget for local projection', (
      tester,
    ) async {
      final visualSpec = GraphVisualSpec(
        style: GraphStyle.fromTokens(dsTokensDark),
        balancedNodeLimit: 2,
      );
      await pumpView(
        tester,
        scenario: busyTaskScenario(),
        visualSpec: visualSpec,
      );

      expect(painterOf(tester).scenario.nodes.length, lessThanOrEqualTo(2));
    });

    testWidgets('reprojects when a host replaces the visual spec', (
      tester,
    ) async {
      final scenario = busyTaskScenario();
      final style = GraphStyle.fromTokens(dsTokensDark);
      var visualSpec = GraphVisualSpec(
        style: style,
        balancedNodeLimit: 2,
      );
      late StateSetter updateHost;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return KnowledgeGraphView(
                scenario: scenario,
                visualSpec: visualSpec,
                showInspector: false,
              );
            },
          ),
        ),
      );
      await tester.pump();
      final initialCount = painterOf(tester).scenario.nodes.length;
      expect(initialCount, lessThanOrEqualTo(2));

      updateHost(() {});
      await tester.pump();
      expect(painterOf(tester).scenario.nodes.length, initialCount);

      updateHost(() {
        visualSpec = GraphVisualSpec(
          style: style,
          balancedNodeLimit: 6,
        );
      });
      await tester.pump();
      expect(
        painterOf(tester).scenario.nodes.length,
        greaterThan(initialCount),
      );
      expect(painterOf(tester).scenario.nodes.length, lessThanOrEqualTo(6));
    });

    testWidgets('labels collapsed relationship aggregates with their count', (
      tester,
    ) async {
      await pumpView(tester, scenario: busyTaskScenario());

      final painter = painterOf(tester);
      final aggregate = painter.scenario.nodes.firstWhere(
        (node) => node.aggregateKind == GraphAggregateKind.relation,
      );
      expect(
        painter.nodeLabels[aggregate.id],
        'more links · ${aggregate.aggregateCount}',
      );
      expect(painter.hops[aggregate.id], 1);
      expect(
        painter.scenario.edges.any(
          (edge) => edge.fromId == painter.focusId && edge.toId == aggregate.id,
        ),
        isTrue,
      );
    });
  });

  group('representations and keyboard navigation', () {
    testWidgets('switches between graph and readable Connections list', (
      tester,
    ) async {
      await pumpView(tester, scenario: taskEgoNetworkScenario());

      expect(
        find.byKey(const ValueKey('knowledge-graph-connections-list')),
        findsNothing,
      );
      await tester.tap(find.text('Connections'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('knowledge-graph-connections-list')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is KnowledgeGraphPainter,
        ),
        findsNothing,
      );

      await tester.tap(find.text('Graph'));
      await tester.pump();
      expect(painterFocusId(tester), taskEgoNetworkScenario().seedId);
    });

    testWidgets('arrow selects a spatial neighbor and Enter walks to it', (
      tester,
    ) async {
      final scenario = lightTaskScenario();
      await pumpView(tester, scenario: scenario);
      final painter = painterOf(tester);
      final directions = <(LogicalKeyboardKey, Offset)>[
        (LogicalKeyboardKey.arrowRight, const Offset(1, 0)),
        (LogicalKeyboardKey.arrowLeft, const Offset(-1, 0)),
        (LogicalKeyboardKey.arrowDown, const Offset(0, 1)),
        (LogicalKeyboardKey.arrowUp, const Offset(0, -1)),
      ];
      final target = directions
          .map(
            (entry) => (
              entry.$1,
              nearestGraphNodeInDirection(
                positions: painter.positions,
                fromId: scenario.seedId,
                direction: entry.$2,
              ),
            ),
          )
          .firstWhere((entry) => entry.$2 != null);
      final graphFocus = tester.widget<Focus>(
        find.descendant(
          of: find.byType(KnowledgeGraphView),
          matching: find.byWidgetPredicate(
            (widget) => widget is Focus && widget.onKeyEvent != null,
          ),
        ),
      );
      graphFocus.focusNode!.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(target.$1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(painterFocusId(tester), target.$2);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(painterFocusId(tester), scenario.seedId);
    });

    testWidgets('explore density rebuilds a wider local projection', (
      tester,
    ) async {
      await pumpView(tester, scenario: busyTaskScenario());
      final before = painterOf(tester).scenario.nodes.length;

      tester
          .widget<GraphWorkspaceToolbar>(find.byType(GraphWorkspaceToolbar))
          .onDensityChanged(GraphDensity.explore);
      await tester.pump();

      final after = painterOf(tester).scenario.nodes.length;
      expect(after, greaterThanOrEqualTo(before));
      expect(after, lessThanOrEqualTo(GraphVisualSpec.defaultExploreNodeLimit));
    });

    testWidgets('minimap jump re-seeds focus without motion', (tester) async {
      final scenario = taskEgoNetworkScenario();
      final target = scenario.nodes.firstWhere(
        (node) => node.type == GraphNodeType.task && node.id != scenario.seedId,
      );
      final calls = <({String taskId, String previousFocusId})>[];
      await pumpView(
        tester,
        scenario: scenario,
        disableAnimations: true,
        onTaskFocusChanged: (taskId, previousFocusId) {
          calls.add((taskId: taskId, previousFocusId: previousFocusId));
        },
      );
      expect(find.bySemanticsLabel('Topology overview'), findsOneWidget);

      tester
          .widget<TopologyMiniMap>(find.byType(TopologyMiniMap))
          .onJump(
            target.id,
          );
      await tester.pump();

      expect(painterFocusId(tester), target.id);
      expect(painterOf(tester).wake, 0);
      expect(calls, [
        (taskId: target.id, previousFocusId: scenario.seedId),
      ]);
    });
  });

  group('deferred image loading', () {
    testWidgets('loads task cover art for the graph node background', (
      tester,
    ) async {
      late final ui.Image cover;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 8, 8),
          Paint()..color = const Color(0xFF3366CC),
        );
        cover = await recorder.endRecording().toImage(8, 8);
      });

      const coverPath = '/task-cover.png';
      final loadedPaths = <String>[];
      await pumpView(
        tester,
        scenario: GraphScenario(
          name: 'Cover art',
          seedId: 'task',
          nodes: [
            GraphNode(
              id: 'task',
              type: GraphNodeType.task,
              label: 'Task with cover art',
              categoryId: catWork,
              createdAt: fixedNow,
              coverImagePath: coverPath,
              coverImageCropX: 0.8,
            ),
          ],
          edges: const [],
          now: fixedNow,
        ),
        imageLoader: (path) async {
          loadedPaths.add(path);
          return cover;
        },
      );
      await tester.pump();

      expect(loadedPaths, [coverPath]);
      expect(painterOf(tester).images[coverPath], same(cover));
    });

    testWidgets(
      'decodes collapsed media paths and hands them to the painter',
      (tester) async {
        // Write a real (tiny) PNG and collapse the linked image into a media
        // collection. The raw image node is absent from the displayed scenario,
        // so this specifically guards aggregate thumbnail decoding.
        late final Directory tempDir;
        late final String pngPath;
        await tester.runAsync(() async {
          tempDir = Directory.systemTemp.createTempSync('lotti_kg_img_test');
          pngPath = '${tempDir.path}/seed_thumb.png';
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawRect(
            const Rect.fromLTWH(0, 0, 4, 4),
            Paint()..color = const Color(0xFF4285F4),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(4, 4);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          image.dispose();
          await File(pngPath).writeAsBytes(bytes!.buffer.asUint8List());
        });
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final scenario = GraphScenario(
          name: 'Image',
          seedId: 's',
          nodes: [
            GraphNode(
              id: 's',
              type: GraphNodeType.task,
              label: 'Task with photos',
              categoryId: catWork,
              createdAt: fixedNow,
              mediaPaths: [pngPath],
            ),
            GraphNode(
              id: 'photo',
              type: GraphNodeType.imageEntry,
              label: 'Photo entry',
              categoryId: catWork,
              createdAt: fixedNow,
              imagePath: pngPath,
            ),
          ],
          edges: const [
            GraphEdge(
              fromId: 's',
              toId: 'photo',
              kind: GraphEdgeKind.association,
            ),
          ],
          now: fixedNow,
        );

        late final ui.Image decoded;
        await tester.runAsync(() async {
          decoded = await decodeGraphImageFile(pngPath);
        });
        final loadedPaths = <String>[];
        await pumpView(
          tester,
          scenario: scenario,
          imageLoader: (path) async {
            loadedPaths.add(path);
            return decoded;
          },
        );
        await tester.pump();

        final painter = painterOf(tester);
        expect(loadedPaths, [pngPath]);
        expect(
          painter.scenario.nodes
              .singleWhere(
                (node) => node.type == GraphNodeType.mediaCollection,
              )
              .mediaPaths,
          [pngPath],
        );
        // The painter carries the decoded thumbnail under its media path even
        // though the raw image node was collapsed out of the local projection.
        final images = painterOf(tester).images;
        expect(images.keys, contains(pngPath));
        expect(images[pngPath], isA<ui.Image>());
        expect(images[pngPath]!.width, 4);
        expect(images[pngPath]!.height, 4);
        expect(images.keys, isNot(contains('photo')));
        // Disposal of the loaded image happens when the widget tears down at the
        // end of the test (covers the dispose loop with a real entry).
      },
    );
  });

  /// Matches text [t] that lives inside the [NodeInspectorPanel] (not the
  /// legend, title chip, or graph overlay) — the inspector cases assert here so
  /// a stray match elsewhere can't satisfy the expectation.
  Finder inspectorText(String t) => find.descendant(
    of: find.byType(NodeInspectorPanel),
    matching: find.text(t),
  );

  group('inspector preview content (desktop)', () {
    testWidgets('resolves the category NAME, the kicker and the linked timeline', (
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

      // LINKED timeline: a "LINKED · N" section header where N is the seed's
      // direct-neighbor count (the same set `_neighborsOf` builds — the other
      // endpoint of every edge touching the seed, deduped). The seed `t0`
      // touches p0, t1-t3, l1-l5, a1, a2, r1 and c1 -> 13 direct neighbors
      // (its checklist's items ci1-ci4 hang off c1, not the seed).
      final neighborIds = <String>{};
      for (final e in scenario.edges) {
        if (e.fromId == scenario.seedId) {
          neighborIds.add(e.toId);
        } else if (e.toId == scenario.seedId) {
          neighborIds.add(e.fromId);
        }
      }
      expect(neighborIds.length, 13);
      expect(inspectorText('LINKED · ${neighborIds.length}'), findsOneWidget);

      // Each direct neighbor appears as a timeline row: its snippet label plus a
      // "typeLabel · relativeAge" caption. Assert two distinct neighbors — a
      // linked task and a note — to prove the timeline is populated from the
      // focus node's real edges, with the right type label and age.
      // t1 "Fix sync race condition" is a task created 9 days ago.
      expect(inspectorText('Fix sync race condition'), findsOneWidget);
      expect(inspectorText('Task · 9 days ago'), findsOneWidget);
      // l1 "Standup notes" is a text entry (Note) created 2 days ago.
      expect(inspectorText('Standup notes'), findsOneWidget);
      expect(inspectorText('Note · 2 days ago'), findsOneWidget);
      // The seed's checklist items are NOT direct neighbors, so they are absent.
      expect(inspectorText('Tag build'), findsNothing);
    });

    testWidgets('falls back to the raw category id when no name is provided', (
      tester,
    ) async {
      await pumpView(tester, scenario: taskEgoNetworkScenario());

      // categoryNames is empty -> the kicker resolves to the raw id `work`,
      // uppercased.
      expect(inspectorText('TASK · WORK'), findsOneWidget);
    });

    testWidgets('omits the SUMMARY section when the node has no tldr', (
      tester,
    ) async {
      // The ego scenario's seed has no tldr, so the inspector renders no SUMMARY
      // section at all (there is no type-based fallback lede). The title and
      // kicker still render, and the LINKED timeline takes over the body.
      await pumpView(
        tester,
        scenario: taskEgoNetworkScenario(),
        categoryNames: const {catWork: 'Work'},
      );

      expect(inspectorText('SUMMARY'), findsNothing);
      // The identity (title + kicker) is unaffected by the missing summary.
      expect(inspectorText('Ship v2.3 release'), findsOneWidget);
      expect(inspectorText('TASK · WORK'), findsOneWidget);
      // The timeline still renders the linked entries below the (absent) summary.
      expect(inspectorText('LINKED · 13'), findsOneWidget);
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
      // (the remainder), with markdown punctuation flattened. The body stays
      // collapsed until requested so the inspector remains compact.
      expect(inspectorText('TL;DR'), findsOneWidget);
      expect(inspectorText('SUMMARY'), findsOneWidget);
      expect(
        inspectorText('• Ship the build\n• verify smoke tests'),
        findsNothing,
      );

      await tester.tap(inspectorText('SUMMARY'));
      await tester.pump(kThemeAnimationDuration);

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
          .map(
            (image) => switch (image.image) {
              final ResizeImage resized => resized.imageProvider,
              final provider => provider,
            },
          )
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
      expect(find.byTooltip('Forward'), findsOneWidget);
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

    testWidgets('reduced motion recenter jumps without a camera glide', (
      tester,
    ) async {
      await pumpView(
        tester,
        scenario: exploreWorldScenario(),
        size: phoneSize,
        disableAnimations: true,
      );

      final initial = painterOf(tester);
      await tester.drag(
        find.byType(KnowledgeGraphView),
        const Offset(84, 36),
      );
      await tester.pump();

      final panned = painterOf(tester);
      expect(panned.pan, isNot(initial.pan));

      await tester.tap(find.byIcon(Icons.center_focus_strong));
      await tester.pump();

      final jumped = painterOf(tester);
      expect(jumped.wake, 0);
      expect(jumped.pan, isNot(panned.pan));

      await tester.pump(const Duration(milliseconds: 200));

      final afterTime = painterOf(tester);
      expect(afterTime.scale, jumped.scale);
      expect(afterTime.pan, jumped.pan);
      expect(afterTime.wake, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'tapping back after a walk returns the focus to the previous node',
      (tester) async {
        // Explorable world so the back/recenter controls render. Walk to a real
        // neighbor first (so `_history` is non-empty), then tap the back control
        // to exercise the non-empty-history branch of `_back()`.
        final scenario = exploreWorldScenario();
        // The view uses `computeWorldLayout` for explorable (>40 node) worlds,
        // so the tap target must be computed from the same (deterministic)
        // layout, not the smaller-graph layout.
        await pumpView(tester, scenario: scenario, size: phoneSize);

        // Seed is P0T0; its project P0 is a direct (containment) neighbor, so it
        // sits inside the initial frame and is a clean tap target. Read the
        // painter's live transform (after the initial frame) to place the tap.
        expect(painterFocusId(tester), 'P0T0');
        const neighborId = 'P0';
        final neighborScreen = screenPosOf(
          tester,
          painterOf(tester).positions[neighborId]!,
        );
        await tester.tapAt(neighborScreen);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        // The walk landed on the neighbor, seeding `_history` with the seed.
        expect(painterFocusId(tester), neighborId);

        // Back is now enabled (history is non-empty).
        final backInk = tester.widget<InkWell>(
          find.ancestor(
            of: find.byIcon(Icons.arrow_back),
            matching: find.byType(InkWell),
          ),
        );
        expect(backInk.onTap, isNotNull);

        // Tap back → `_back()` pops the seed off history and walks to it.
        await tester.tap(find.byIcon(Icons.arrow_back));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        expect(painterFocusId(tester), 'P0T0');
        // History was emptied by the pop, so back is disabled again.
        final backInkAfter = tester.widget<InkWell>(
          find.ancestor(
            of: find.byIcon(Icons.arrow_back),
            matching: find.byType(InkWell),
          ),
        );
        expect(backInkAfter.onTap, isNull);

        final forwardInk = tester.widget<InkWell>(
          find.ancestor(
            of: find.byIcon(Icons.arrow_forward),
            matching: find.byType(InkWell),
          ),
        );
        expect(forwardInk.onTap, isNotNull);
        await tester.tap(find.byIcon(Icons.arrow_forward));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(painterFocusId(tester), neighborId);
        final forwardInkAfter = tester.widget<InkWell>(
          find.ancestor(
            of: find.byIcon(Icons.arrow_forward),
            matching: find.byType(InkWell),
          ),
        );
        expect(forwardInkAfter.onTap, isNull);
        expect(tester.takeException(), isNull);
      },
    );

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

  group('panel back navigation (desktop)', () {
    testWidgets(
      'panel renders nav buttons, back disabled until a walk, then back '
      'returns to the seed',
      (tester) async {
        // Desktop so the inspector (and its overlaid nav buttons) are visible.
        // The ego scenario's seed `t0` ("Ship v2.3 release") has direct
        // neighbors rendered as a tappable timeline; `t1`
        // ("Fix sync race condition") is one of them.
        final scenario = taskEgoNetworkScenario();
        await pumpView(tester, scenario: scenario);

        // The panel's recenter button is always present...
        expect(
          find.descendant(
            of: find.byType(NodeInspectorPanel),
            matching: find.byIcon(Icons.center_focus_strong_rounded),
          ),
          findsOneWidget,
        );
        // ...and the back button is present but DISABLED (no walk history yet,
        // so `canGoBack` is false → the _NavButton's InkWell has a null onTap).
        final backFinder = find.descendant(
          of: find.byType(NodeInspectorPanel),
          matching: find.byIcon(Icons.arrow_back_rounded),
        );
        expect(backFinder, findsOneWidget);
        final backInk = tester.widget<InkWell>(
          find.ancestor(of: backFinder, matching: find.byType(InkWell)),
        );
        expect(backInk.onTap, isNull);

        // Focus starts on the seed.
        expect(painterFocusId(tester), scenario.seedId);

        // Walk to the neighbor by tapping its timeline row inside the panel
        // (the snippet text is wrapped in the row's InkWell → `onNeighborTap`).
        // The timeline scrolls, and `t1` is an older neighbor that may sit below
        // the fold, so scroll it into view first.
        await tester.ensureVisible(inspectorText('Fix sync race condition'));
        await tester.pump();
        await tester.tap(inspectorText('Fix sync race condition'));
        await tester.pump();

        final motionAfterPanelWalk = painterOf(tester).motion!;
        expect(
          motionAfterPanelWalk.offsetFor('t1').distance,
          greaterThan(
            motionAfterPanelWalk.offsetFor(scenario.seedId).distance,
          ),
        );

        // Drive the bounded camera glide (760ms); never settle (the wake
        // controller ticks indefinitely).
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        // The walk landed on the neighbor, seeding `_history` with the seed.
        expect(painterFocusId(tester), 't1');
        // The inspector now describes the neighbor (its label as the heading).
        expect(inspectorText('Fix sync race condition'), findsOneWidget);

        // Back is now ENABLED (history is non-empty).
        final backInkAfter = tester.widget<InkWell>(
          find.ancestor(
            of: find.descendant(
              of: find.byType(NodeInspectorPanel),
              matching: find.byIcon(Icons.arrow_back_rounded),
            ),
            matching: find.byType(InkWell),
          ),
        );
        expect(backInkAfter.onTap, isNotNull);

        // Tap the panel back button → `_back()` pops the seed and walks to it.
        await tester.tap(
          find.descendant(
            of: find.byType(NodeInspectorPanel),
            matching: find.byIcon(Icons.arrow_back_rounded),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        // Focus returned to the seed.
        expect(painterFocusId(tester), scenario.seedId);
        expect(inspectorText('Ship v2.3 release'), findsOneWidget);
        // History was emptied by the pop, so back is disabled again.
        final backInkFinal = tester.widget<InkWell>(
          find.ancestor(
            of: find.descendant(
              of: find.byType(NodeInspectorPanel),
              matching: find.byIcon(Icons.arrow_back_rounded),
            ),
            matching: find.byType(InkWell),
          ),
        );
        expect(backInkFinal.onTap, isNull);
        expect(tester.takeException(), isNull);
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

  group('node motion', () {
    testWidgets('tapping the focused node kicks it without changing focus', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      final layout = computeGraphLayout(scenario);
      await pumpView(tester, scenario: scenario);

      final seedScreen = screenPosOf(
        tester,
        layout.positions[scenario.seedId]!,
      );
      await tester.tapAt(seedScreen);
      await tester.pump();

      final painter = painterOf(tester);
      expect(painter.focusId, scenario.seedId);
      expect(painter.motion, isNotNull);
      expect(
        painter.motion!.offsetFor(scenario.seedId).distance,
        greaterThan(0),
      );
      expect(
        scenario.nodes
            .where((node) => node.id != scenario.seedId)
            .any((node) => painter.motion!.offsetFor(node.id) != Offset.zero),
        isTrue,
      );

      painter.motion!.settle();
      await tester.pump();
    });

    testWidgets('system reduce motion suppresses node spring kicks', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      final layout = computeGraphLayout(scenario);
      await pumpView(
        tester,
        scenario: scenario,
        disableAnimations: true,
      );

      final seedScreen = screenPosOf(
        tester,
        layout.positions[scenario.seedId]!,
      );
      await tester.tapAt(seedScreen);
      await tester.pump();

      final motion = painterOf(tester).motion;
      expect(motion, isNotNull);
      expect(motion!.offsetFor(scenario.seedId), Offset.zero);
    });
  });

  group('tap-to-walk', () {
    testWidgets('tapping a projected media aggregate expands its photos', (
      tester,
    ) async {
      final scenario = GraphScenario(
        name: 'Media aggregate',
        seedId: 'task',
        nodes: [
          GraphNode(
            id: 'task',
            type: GraphNodeType.task,
            label: 'Task',
            categoryId: catWork,
            createdAt: fixedNow,
            mediaPaths: const ['/cover.jpg'],
          ),
          GraphNode(
            id: 'photo',
            type: GraphNodeType.imageEntry,
            label: 'Photo',
            categoryId: catWork,
            createdAt: fixedNow,
            imagePath: '/photo.jpg',
          ),
        ],
        edges: const [
          GraphEdge(
            fromId: 'task',
            toId: 'photo',
            kind: GraphEdgeKind.association,
          ),
        ],
        now: fixedNow,
      );
      await pumpView(tester, scenario: scenario);

      final before = painterOf(tester);
      final aggregate = before.scenario.nodes.singleWhere(
        (node) => node.type == GraphNodeType.mediaCollection,
      );
      expect(before.hops[aggregate.id], 1);
      await tester.tapAt(screenPosOf(tester, before.positions[aggregate.id]!));
      await tester.pump();

      final after = painterOf(tester);
      expect(
        after.scenario.nodes.map((node) => node.id),
        contains('photo'),
      );
      expect(
        after.scenario.nodes.where(
          (node) => node.type == GraphNodeType.mediaCollection,
        ),
        isEmpty,
      );
      expect(after.focusId, 'task');
    });

    testWidgets('keyboard expansion restores selection to the focus', (
      tester,
    ) async {
      final scenario = GraphScenario(
        name: 'Keyboard media aggregate',
        seedId: 'task',
        nodes: [
          GraphNode(
            id: 'task',
            type: GraphNodeType.task,
            label: 'Task',
            categoryId: catWork,
            createdAt: fixedNow,
            mediaPaths: const ['/cover.jpg'],
          ),
          GraphNode(
            id: 'photo',
            type: GraphNodeType.imageEntry,
            label: 'Photo',
            categoryId: catWork,
            createdAt: fixedNow,
            imagePath: '/photo.jpg',
          ),
        ],
        edges: const [
          GraphEdge(
            fromId: 'task',
            toId: 'photo',
            kind: GraphEdgeKind.association,
          ),
        ],
        now: fixedNow,
      );
      await pumpView(tester, scenario: scenario);
      final before = painterOf(tester);
      final aggregate = before.scenario.nodes.singleWhere(
        (node) => node.type == GraphNodeType.mediaCollection,
      );
      final direction =
          before.positions[aggregate.id]! - before.positions['task']!;
      final key = direction.dx.abs() >= direction.dy.abs()
          ? (direction.dx < 0
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight)
          : (direction.dy < 0
                ? LogicalKeyboardKey.arrowUp
                : LogicalKeyboardKey.arrowDown);
      final graphFocus = tester.widget<Focus>(
        find.descendant(
          of: find.byType(KnowledgeGraphView),
          matching: find.byWidgetPredicate(
            (widget) => widget is Focus && widget.onKeyEvent != null,
          ),
        ),
      );
      graphFocus.focusNode!.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(painterOf(tester).selectedId, aggregate.id);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      final after = painterOf(tester);
      expect(after.scenario.nodes.map((node) => node.id), contains('photo'));
      expect(after.selectedId, 'task');
    });

    testWidgets('filtering resets a hidden keyboard selection to the focus', (
      tester,
    ) async {
      final scenario = GraphScenario(
        name: 'Filtered selection',
        seedId: 'task',
        nodes: [
          GraphNode(
            id: 'task',
            type: GraphNodeType.task,
            label: 'Task',
            categoryId: catWork,
            createdAt: fixedNow,
          ),
          GraphNode(
            id: 'note',
            type: GraphNodeType.textEntry,
            label: 'Note',
            categoryId: catWork,
            createdAt: fixedNow,
          ),
        ],
        edges: const [
          GraphEdge(
            fromId: 'task',
            toId: 'note',
            kind: GraphEdgeKind.association,
          ),
        ],
        now: fixedNow,
      );
      await pumpView(tester, scenario: scenario);
      final painter = painterOf(tester);
      final direction = painter.positions['note']! - painter.positions['task']!;
      final key = direction.dx.abs() >= direction.dy.abs()
          ? (direction.dx < 0
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight)
          : (direction.dy < 0
                ? LogicalKeyboardKey.arrowUp
                : LogicalKeyboardKey.arrowDown);
      final graphFocus = tester.widget<Focus>(
        find.descendant(
          of: find.byType(KnowledgeGraphView),
          matching: find.byWidgetPredicate(
            (widget) => widget is Focus && widget.onKeyEvent != null,
          ),
        ),
      );
      graphFocus.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(painterOf(tester).selectedId, 'note');

      tester
          .widget<GraphWorkspaceToolbar>(find.byType(GraphWorkspaceToolbar))
          .onFiltersChanged(
            const GraphProjectionFilters(
              nodeTypes: {GraphNodeType.task},
            ),
          );
      await tester.pump();

      expect(painterOf(tester).selectedId, 'task');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(painterFocusId(tester), 'task');
    });

    testWidgets('tapping a neighbor node changes the focus', (tester) async {
      // Use the ego scenario (deterministic layout). Compute where a 1-hop
      // neighbor renders under the view's initial framing, then tap there.
      final scenario = taskEgoNetworkScenario();
      final layout = computeGraphLayout(scenario);
      await pumpView(tester, scenario: scenario);

      // Pick the project neighbor 'p0' (1 hop, distinct sector -> well
      // separated from siblings, so the 30px hit radius lands on it cleanly).
      // Place the tap from the painter's live transform (after the initial
      // frame settled), so it stays correct regardless of the framing formula.
      const targetId = 'p0';
      final screenPos = screenPosOf(tester, layout.positions[targetId]!);

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

    testWidgets('reduced motion walks without camera or wake animation', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      final layout = computeGraphLayout(scenario);
      await pumpView(
        tester,
        scenario: scenario,
        disableAnimations: true,
      );

      const targetId = 'p0';
      await tester.tapAt(screenPosOf(tester, layout.positions[targetId]!));
      await tester.pump();

      final jumped = painterOf(tester);
      expect(jumped.focusId, targetId);
      expect(jumped.wake, 0);
      expect(jumped.motion, isNotNull);
      expect(jumped.motion!.offsetFor(targetId), Offset.zero);

      await tester.pump(const Duration(milliseconds: 200));

      final afterTime = painterOf(tester);
      expect(afterTime.scale, jumped.scale);
      expect(afterTime.pan, jumped.pan);
      expect(afterTime.wake, 0);
    });

    testWidgets('walking to a task reports the task focus change', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      final calls = <({String taskId, String previousFocusId})>[];
      await pumpView(
        tester,
        scenario: scenario,
        onTaskFocusChanged: (taskId, previousFocusId) {
          calls.add((taskId: taskId, previousFocusId: previousFocusId));
        },
      );

      await tester.ensureVisible(inspectorText('Fix sync race condition'));
      await tester.pump();
      await tester.tap(inspectorText('Fix sync race condition'));
      await tester.pump();

      expect(calls, [
        (taskId: 't1', previousFocusId: scenario.seedId),
      ]);
      expect(painterFocusId(tester), 't1');
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
        // Explorable controls only render for `_world` scenarios, so the `back`
        // path is driven by tapping out then tapping the previous node, which
        // exercises `_walkTo` symmetrically (history is internal). Here we
        // verify the round-trip lands back on the seed by walking out and then
        // tapping the seed's screen position.
        await pumpView(tester, scenario: scenario);

        // Walk to project 'p0' — tap where it renders under the initial frame
        // (read from the painter's live transform).
        final p0Screen = screenPosOf(
          tester,
          painterOf(tester).positions['p0']!,
        );
        await tester.tapAt(p0Screen);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(painterFocusId(tester), 'p0');

        // From p0, the seed is its only 1-hop neighbor (containment edge), so
        // it must be visible in p0's frame. The camera has settled on p0, so
        // the painter's transform now frames p0 — read it to place the tap on
        // the seed.
        final seedScreen = screenPosOf(
          tester,
          painterOf(tester).positions[scenario.seedId]!,
        );
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

    testWidgets('a fast drag release kicks the focused node and neighbors', (
      tester,
    ) async {
      final scenario = taskEgoNetworkScenario();
      await pumpView(tester, scenario: scenario);

      await tester.fling(
        find.byType(KnowledgeGraphView),
        const Offset(260, 80),
        1800,
      );
      await tester.pump();

      final after = painterOf(tester);
      final motion = after.motion;
      expect(after.focusId, scenario.seedId);
      expect(motion, isNotNull);
      expect(motion!.offsetFor(scenario.seedId).distance, greaterThan(0));
      expect(
        scenario.nodes
            .where((node) => node.id != scenario.seedId)
            .any((node) => motion.offsetFor(node.id) != Offset.zero),
        isTrue,
      );
    });

    testWidgets('trackpad scroll zooms the graph', (tester) async {
      final scenario = taskEgoNetworkScenario();
      await pumpView(tester, scenario: scenario);

      final scaleBefore = painterOf(tester).scale;
      final pointer = TestPointer(1, ui.PointerDeviceKind.trackpad);
      final center = tester.getCenter(find.byType(KnowledgeGraphView));

      await tester.sendEventToBinding(pointer.panZoomStart(center));
      await tester.pump();
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(center, pan: const Offset(0, -80)),
      );
      await tester.pump();
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      final after = painterOf(tester);
      expect(after.scale, greaterThan(scaleBefore));
      expect(after.focusId, scenario.seedId);
    });
  });

  group('full-details overlay (desktop)', () {
    // The overlay's [EntryDetailSidebar] is a ConsumerWidget that watches
    // `entryControllerProvider(focusId)`. Building it for real would pull in
    // the app's full provider/getIt graph and the heavy TaskForm/details
    // widgets. Instead, the focus entry's controller is overridden with one
    // whose `build` resolves to `null` (no entry) — so the sidebar renders its
    // cheap "Entry not found" shell and never builds `_DetailBody`. The base
    // [EntryController]'s field initializers still touch getIt, so a minimal
    // get_it (setUpTestGetIt + a mock EditorStateService) is registered just for
    // these cases.
    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EditorStateService>(
            MockEditorStateService(),
          );
        },
      );
    });
    tearDown(tearDownTestGetIt);

    testWidgets(
      'tapping Open shows the EntryDetailSidebar; closing it hides it again',
      (tester) async {
        final scenario = taskEgoNetworkScenario();
        await pumpView(
          tester,
          scenario: scenario,
          extraOverrides: [
            // The focus at open time is the scenario seed (`t0`).
            entryControllerProvider(scenario.seedId).overrideWith(
              _NullEntryController.new,
            ),
          ],
        );

        // The inspector is docked (desktop), the overlay is not open yet.
        expect(find.byType(NodeInspectorPanel), findsOneWidget);
        expect(find.byType(EntryDetailSidebar), findsNothing);

        // Tap the inspector's Open button → `_detailsOpen = true`.
        await tester.tap(find.byIcon(Icons.open_in_full_rounded));
        // One frame mounts the overlay; a second lets the (async) controller
        // build resolve to its null value so the sidebar swaps its initial
        // spinner for the data shell.
        await tester.pump();
        await tester.pump();

        // The full-details overlay is now rendered above the inspector. With the
        // controller resolved to a null entry it shows the "Entry not found"
        // shell (proving the cheap path, not the heavy `_DetailBody`).
        expect(find.byType(EntryDetailSidebar), findsOneWidget);
        expect(find.text('Entry not found'), findsOneWidget);

        // Tap the overlay's close button → `_detailsOpen = false`.
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();

        // The overlay is gone; the inspector remains.
        expect(find.byType(EntryDetailSidebar), findsNothing);
        expect(find.byType(NodeInspectorPanel), findsOneWidget);
      },
    );
  });
}

/// Minimal [EntryController] whose `build` resolves to `null` (no entry), so the
/// [EntryDetailSidebar] renders its "Entry not found" shell without building the
/// heavy real detail widgets — and without the app's provider/getIt graph.
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build() async => null;
}
