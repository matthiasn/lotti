import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_layout_engine.dart';
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
    await tester.tap(
      find.byKey(const ValueKey('knowledge-graph-topology-minimap')),
    );
    expect(jumpedTo, isNotNull);
  });
}
