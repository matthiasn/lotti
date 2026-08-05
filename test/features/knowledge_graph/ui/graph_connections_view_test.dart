import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_connections_view.dart';

import '../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 8, 5);
  late GraphScenario scenario;

  setUp(() {
    GraphNode node(
      String id,
      GraphNodeType type, {
      String category = 'work',
      GraphTaskStatus? status,
    }) => GraphNode(
      id: id,
      type: type,
      label: '$id full readable title',
      categoryId: category,
      createdAt: now,
      taskStatus: status,
    );

    scenario = GraphScenario(
      name: 'connections',
      seedId: 'focus',
      nodes: [
        node('focus', GraphNodeType.task),
        node('blocked', GraphNodeType.task, status: GraphTaskStatus.blocked),
        node('source', GraphNodeType.task),
        node('note', GraphNodeType.textEntry, category: 'notes'),
      ],
      edges: const [
        GraphEdge(
          fromId: 'focus',
          toId: 'blocked',
          kind: GraphEdgeKind.blocks,
        ),
        GraphEdge(
          fromId: 'source',
          toId: 'focus',
          kind: GraphEdgeKind.followsUp,
        ),
        GraphEdge(
          fromId: 'focus',
          toId: 'note',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: now,
    );
  });

  test('groups direct links by typed relationship and direction', () {
    final groups = graphConnectionGroups(
      scenario: scenario,
      focusId: 'focus',
    );

    expect(
      groups.map(
        (group) => (group.kind, group.outgoing, group.nodes.single.id),
      ),
      [
        (GraphEdgeKind.association, true, 'note'),
        (GraphEdgeKind.blocks, true, 'blocked'),
        (GraphEdgeKind.followsUp, false, 'source'),
      ],
    );
  });

  test('applies the same relationship and node filters as the graph', () {
    final groups = graphConnectionGroups(
      scenario: scenario,
      focusId: 'focus',
      filters: const GraphProjectionFilters(
        edgeKinds: {GraphEdgeKind.blocks},
        taskStatuses: {GraphTaskStatus.blocked},
      ),
    );

    expect(groups, hasLength(1));
    expect(groups.single.nodes.single.id, 'blocked');
  });

  test('combines category and recency filters', () {
    final oldTask = GraphNode(
      id: 'old',
      type: GraphNodeType.task,
      label: 'old full readable title',
      categoryId: 'work',
      createdAt: now.subtract(const Duration(days: 40)),
    );
    final filteredScenario = GraphScenario(
      name: scenario.name,
      seedId: scenario.seedId,
      nodes: [...scenario.nodes, oldTask],
      edges: [
        ...scenario.edges,
        const GraphEdge(
          fromId: 'focus',
          toId: 'old',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: now,
    );

    final ids = graphConnectionGroups(
      scenario: filteredScenario,
      focusId: 'focus',
      filters: const GraphProjectionFilters(
        categoryIds: {'work'},
        maxAgeDays: 7,
      ),
    ).expand((group) => group.nodes).map((node) => node.id).toSet();

    expect(ids, containsAll({'blocked', 'source'}));
    expect(ids, isNot(contains('note')));
    expect(ids, isNot(contains('old')));
  });

  testWidgets('shows readable grouped rows and walks the selected connection', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Material(
          child: SizedBox(
            width: 700,
            height: 800,
            child: GraphConnectionsView(
              scenario: scenario,
              focusId: 'focus',
              filters: const GraphProjectionFilters(),
              categoryNames: const {'work': 'Work', 'notes': 'Notes'},
              onNodeTap: tapped.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Blocks · 1'), findsOneWidget);
    expect(find.text('Has follow-up · 1'), findsOneWidget);
    expect(find.text('note / log · 1'), findsOneWidget);
    expect(find.text('blocked full readable title'), findsOneWidget);

    await tester.tap(find.text('blocked full readable title'));
    await tester.pump();
    expect(tapped, ['blocked']);
  });

  testWidgets('uses a localized category fallback for an unmapped category', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GraphConnectionsView(
          scenario: scenario,
          focusId: 'focus',
          filters: const GraphProjectionFilters(),
          categoryNames: const {},
          onNodeTap: _ignore,
        ),
      ),
    );

    expect(find.text('Task · Uncategorized · today'), findsWidgets);
    expect(find.text('Note · Uncategorized · today'), findsOneWidget);
    expect(find.textContaining(' · work · '), findsNothing);
    expect(find.textContaining(' · notes · '), findsNothing);
  });

  testWidgets(
    'shows the localized empty state when filters remove every link',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          GraphConnectionsView(
            scenario: scenario,
            focusId: 'focus',
            filters: const GraphProjectionFilters(
              nodeTypes: {GraphNodeType.rating},
            ),
            categoryNames: const {},
            onNodeTap: _ignore,
          ),
        ),
      );

      expect(find.text('No links to explore yet'), findsOneWidget);
    },
  );
}

void _ignore(String _) {}
