import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph_poc/state/graph_viewport_controller.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_visual_spec.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_workspace_toolbar.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 8, 5);
  late GraphScenario scenario;

  setUp(() {
    scenario = GraphScenario(
      name: 'filters',
      seedId: 'focus',
      nodes: [
        GraphNode(
          id: 'focus',
          type: GraphNodeType.task,
          label: 'Focus',
          categoryId: 'work',
          createdAt: now,
          taskStatus: GraphTaskStatus.inProgress,
        ),
        GraphNode(
          id: 'note',
          type: GraphNodeType.textEntry,
          label: 'Note',
          categoryId: 'notes',
          createdAt: now,
        ),
      ],
      edges: const [
        GraphEdge(
          fromId: 'focus',
          toId: 'note',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: now,
    );
  });

  Widget toolbar({
    GraphViewportState state = const GraphViewportState(
      focusId: 'focus',
      selectedId: 'focus',
    ),
    ValueChanged<GraphViewMode>? onMode,
    ValueChanged<GraphDensity>? onDensity,
    ValueChanged<GraphProjectionFilters>? onFilters,
  }) => makeTestableWidgetNoScroll(
    Material(
      child: GraphWorkspaceToolbar(
        state: state,
        scenario: scenario,
        categoryNames: const {'work': 'Work', 'notes': 'Notes'},
        onModeChanged: onMode ?? (_) {},
        onDensityChanged: onDensity ?? (_) {},
        onFiltersChanged: onFilters ?? (_) {},
      ),
    ),
  );

  testWidgets('switches to the list representation and toggles hop depth', (
    tester,
  ) async {
    final modes = <GraphViewMode>[];
    final filters = <GraphProjectionFilters>[];
    await tester.pumpWidget(toolbar(onMode: modes.add, onFilters: filters.add));

    await tester.tap(find.text('Connections'));
    await tester.tap(find.text('2 hops'));
    await tester.pump();

    expect(modes, [GraphViewMode.connections]);
    expect(filters.single.maxHops, 1);
  });

  testWidgets('selects a density from the menu', (tester) async {
    final densities = <GraphDensity>[];
    await tester.pumpWidget(toolbar(onDensity: densities.add));

    await tester.tap(
      find.byKey(const ValueKey('knowledge-graph-density-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calm').last);
    await tester.pumpAndSettle();

    expect(densities, [GraphDensity.calm]);
  });

  testWidgets('opens filters and emits a selected relationship', (
    tester,
  ) async {
    final filters = <GraphProjectionFilters>[];
    await tester.pumpWidget(toolbar(onFilters: filters.add));

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Relationships'), findsOneWidget);

    await tester.tap(find.text('linked task'));
    await tester.pump();

    expect(filters.last.edgeKinds, {GraphEdgeKind.association});
  });

  test('toggledFilterValue uses an empty set as the all-values state', () {
    expect(toggledFilterValue(<String>{}, 'a'), {'a'});
    expect(toggledFilterValue({'a'}, 'b'), {'a', 'b'});
    expect(toggledFilterValue({'a'}, 'a'), isEmpty);
  });

  test(
    'localized helper labels cover density, recency and status branches',
    () {
      final messages = AppLocalizationsEn();
      expect(
        GraphDensity.values.map((value) => graphDensityLabel(messages, value)),
        ['Calm', 'Balanced', 'Explore'],
      );
      expect(
        [null, 7, 30, 90].map((days) => graphRecencyLabel(messages, days)),
        [
          'All',
          'Last 7 days',
          'Last 30 days',
          'Last 90 days',
        ],
      );
      expect(
        GraphTaskStatus.values.map(
          (status) => graphTaskStatusLabel(messages, status),
        ),
        [
          'Open',
          'In Progress',
          'Groomed',
          'Blocked',
          'On Hold',
          'Done',
          'Rejected',
        ],
      );
    },
  );
}
