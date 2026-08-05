import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph_poc/state/graph_viewport_controller.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_visual_spec.dart';

void main() {
  test('walk, back and forward preserve a coherent navigation history', () {
    final controller = GraphViewportController(initialFocusId: 'a');
    addTearDown(controller.dispose);

    controller
      ..walkTo('b')
      ..walkTo('c');
    expect(controller.value.focusId, 'c');
    expect(controller.value.backHistory, ['a', 'b']);

    controller.goBack();
    expect(controller.value.focusId, 'b');
    expect(controller.value.forwardHistory, ['c']);

    controller.goForward();
    expect(controller.value.focusId, 'c');
    expect(controller.value.backHistory, ['a', 'b']);
  });

  test('jump re-seeds history while retaining workspace preferences', () {
    final controller = GraphViewportController(initialFocusId: 'a');
    addTearDown(controller.dispose);

    controller
      ..setDensity(GraphDensity.calm)
      ..setMode(GraphViewMode.connections)
      ..setFilters(const GraphProjectionFilters(maxHops: 1))
      ..walkTo('b')
      ..jumpTo('z');

    expect(controller.value.focusId, 'z');
    expect(controller.value.selectedId, 'z');
    expect(controller.value.backHistory, isEmpty);
    expect(controller.value.forwardHistory, isEmpty);
    expect(controller.value.density, GraphDensity.calm);
    expect(controller.value.mode, GraphViewMode.connections);
    expect(controller.value.filters.maxHops, 1);
  });

  test('aggregate expansion toggles independently from selection', () {
    final controller = GraphViewportController(initialFocusId: 'a');
    addTearDown(controller.dispose);

    controller
      ..selectNode('b')
      ..toggleAggregate('group');
    expect(controller.value.selectedId, 'b');
    expect(controller.value.expandedAggregateIds, {'group'});

    controller.toggleAggregate('group');
    expect(controller.value.expandedAggregateIds, isEmpty);
  });
}
