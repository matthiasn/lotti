import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';
import 'package:lotti/features/knowledge_graph/ui/topology_minimap.dart';

void main() {
  test('topology transform fits world bounds inside the viewport', () {
    final transform = TopologyTransform.fit(
      positions: const {
        'a': Offset(-100, -50),
        'b': Offset(100, 50),
      },
      size: const Size(220, 140),
      inset: 12,
    );

    expect(
      transform.toLocal(const Offset(-100, -50)).dx,
      greaterThanOrEqualTo(12),
    );
    expect(transform.toLocal(const Offset(100, 50)).dx, lessThanOrEqualTo(208));
  });

  test('empty topology centers the transform and has no nearest node', () {
    final transform = TopologyTransform.fit(
      positions: const {},
      size: const Size(220, 140),
      inset: 12,
    );

    expect(transform.scale, 1);
    expect(transform.offset, const Offset(110, 70));
    expect(topologyBounds(const []), Rect.zero);
    expect(
      nearestTopologyNode(
        localPosition: Offset.zero,
        positions: const {},
        transform: transform,
      ),
      isNull,
    );
  });

  testWidgets('exposes one semantic control and jumps to the nearest node', (
    tester,
  ) async {
    final scenario = lightTaskScenario();
    final layout = computeWorldLayout(scenario, iterations: 1);
    String? jumpedTo;

    await tester.pumpWidget(
      MaterialApp(
        theme: DesignSystemTheme.dark(),
        home: Scaffold(
          body: Center(
            child: TopologyMiniMap(
              scenario: scenario,
              layout: layout,
              focusId: scenario.seedId,
              visibleNodeIds: {scenario.seedId},
              spec: GraphVisualSpec.fromTokens(dsTokensDark),
              semanticsLabel: 'Topology overview',
              onJump: (id) => jumpedTo = id,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Topology overview'), findsOneWidget);
    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Topology overview'),
    );
    expect(semantics.flagsCollection.isButton, isFalse);
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    final minimap = find.byKey(
      const ValueKey('knowledge-graph-topology-minimap'),
    );
    final renderBox = tester.renderObject<RenderBox>(minimap);
    final transform = TopologyTransform.fit(
      positions: layout.positions,
      size: renderBox.size,
      inset: dsTokensDark.spacing.step3,
    );
    final targetId = scenario.nodes.last.id;
    final target = transform.toLocal(layout.positions[targetId]!);
    await tester.tapAt(renderBox.localToGlobal(target));
    expect(jumpedTo, targetId);
  });

  testWidgets('empty minimap ignores taps without throwing', (tester) async {
    final scenario = GraphScenario(
      name: 'empty',
      seedId: 'missing',
      nodes: const [],
      edges: const [],
      now: DateTime(2026, 8, 5),
    );
    final jumps = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: DesignSystemTheme.dark(),
        home: Scaffold(
          body: TopologyMiniMap(
            scenario: scenario,
            layout: const GraphLayout({}),
            focusId: scenario.seedId,
            visibleNodeIds: const {},
            spec: GraphVisualSpec.fromTokens(dsTokensDark),
            semanticsLabel: 'Empty topology overview',
            onJump: jumps.add,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('knowledge-graph-topology-minimap')),
    );
    expect(jumps, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('repaints only when a visual input changes', () {
    final scenario = lightTaskScenario();
    final positions = computeWorldLayout(scenario, iterations: 1).positions;
    final visible = {scenario.seedId};
    const transform = TopologyTransform(scale: 1, offset: Offset.zero);
    final spec = GraphVisualSpec.fromTokens(dsTokensDark);
    final painter = TopologyMiniMapPainter(
      scenario: scenario,
      positions: positions,
      focusId: scenario.seedId,
      visibleNodeIds: visible,
      transform: transform,
      spec: spec,
    );

    TopologyMiniMapPainter copy({
      GraphScenario? nextScenario,
      Map<String, Offset>? nextPositions,
      String? nextFocusId,
      Set<String>? nextVisible,
      TopologyTransform? nextTransform,
      GraphVisualSpec? nextSpec,
    }) => TopologyMiniMapPainter(
      scenario: nextScenario ?? scenario,
      positions: nextPositions ?? positions,
      focusId: nextFocusId ?? scenario.seedId,
      visibleNodeIds: nextVisible ?? visible,
      transform: nextTransform ?? transform,
      spec: nextSpec ?? spec,
    );

    expect(copy().shouldRepaint(painter), isFalse);
    expect(
      copy(
        nextTransform: const TopologyTransform(
          scale: 1,
          offset: Offset.zero,
        ),
      ).shouldRepaint(painter),
      isFalse,
    );
    expect(
      copy(
        nextScenario: GraphScenario(
          name: scenario.name,
          seedId: scenario.seedId,
          nodes: scenario.nodes,
          edges: scenario.edges,
          now: scenario.now,
        ),
      ).shouldRepaint(painter),
      isTrue,
    );
    expect(copy(nextPositions: {...positions}).shouldRepaint(painter), isTrue);
    expect(copy(nextFocusId: 'other').shouldRepaint(painter), isTrue);
    expect(copy(nextVisible: {...visible}).shouldRepaint(painter), isTrue);
    expect(
      copy(
        nextTransform: const TopologyTransform(
          scale: 2,
          offset: Offset.zero,
        ),
      ).shouldRepaint(painter),
      isTrue,
    );
    expect(
      copy(
        nextSpec: GraphVisualSpec.fromTokens(dsTokensDark),
      ).shouldRepaint(painter),
      isTrue,
    );
  });
}
