import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';

void main() {
  test('resolves palette from tokens and owns density budgets', () {
    final spec = GraphVisualSpec.fromTokens(dsTokensDark);

    expect(spec.style.background, dsTokensDark.colors.background.level01);
    expect(spec.style.focusRing, dsTokensDark.colors.interactive.enabled);
    expect(spec.nodeLimit(GraphDensity.calm), 24);
    expect(spec.nodeLimit(GraphDensity.balanced), 48);
    expect(spec.nodeLimit(GraphDensity.explore), 72);
    expect(GraphVisualSpec.defaultNodeLimit(GraphDensity.calm), 24);
    expect(GraphVisualSpec.defaultNodeLimit(GraphDensity.balanced), 48);
    expect(GraphVisualSpec.defaultNodeLimit(GraphDensity.explore), 72);
    expect(spec.clusterPreviewLimit, lessThan(spec.clusterCollapseThreshold));
  });
}
