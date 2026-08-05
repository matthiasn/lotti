import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph/state/graph_viewport_controller.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_workspace_toolbar.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/l10n/app_localizations_it.dart';
import 'package:lotti/l10n/app_localizations_ro.dart';

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

  test('preserves Italian and Romanian density and recency meanings', () {
    final italian = AppLocalizationsIt();
    final romanian = AppLocalizationsRo();

    expect(graphDensityLabel(italian, GraphDensity.calm), 'Calma');
    expect(graphDensityLabel(italian, GraphDensity.explore), 'Esplorativa');
    expect(italian.knowledgeGraphFilterRecency, 'Periodo');
    expect(graphDensityLabel(romanian, GraphDensity.calm), 'Calmă');
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
    await tester.tap(find.text('Graph'));
    await tester.tap(find.text('2 hops'));
    await tester.pump();

    expect(modes, [GraphViewMode.connections, GraphViewMode.graph]);
    expect(filters.single.maxHops, 1);
  });

  testWidgets('toggles one hop back to two hops', (tester) async {
    final filters = <GraphProjectionFilters>[];
    await tester.pumpWidget(
      toolbar(
        state: const GraphViewportState(
          focusId: 'focus',
          selectedId: 'focus',
          filters: GraphProjectionFilters(maxHops: 1),
        ),
        onFilters: filters.add,
      ),
    );

    expect(find.text('1 hop'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('knowledge-graph-hop-filter')),
    );

    expect(filters.single.maxHops, 2);
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

    await tester.tap(find.text('linked entry'));
    await tester.pump();

    expect(filters.last.edgeKinds, {GraphEdgeKind.association});
  });

  testWidgets('combines category, recency and task-status filters', (
    tester,
  ) async {
    final filters = <GraphProjectionFilters>[];
    await tester.pumpWidget(toolbar(onFilters: filters.add));

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task'));
    await tester.pump();
    expect(filters.last.nodeTypes, {GraphNodeType.task});

    await tester.tap(find.text('Work'));
    await tester.pump();
    expect(filters.last.categoryIds, {'work'});

    await tester.tap(find.text('Last 7 days'));
    await tester.pump();
    expect(filters.last.categoryIds, {'work'});
    expect(filters.last.maxAgeDays, 7);

    await tester.scrollUntilVisible(
      find.text('In Progress'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('In Progress'));
    await tester.pump();
    expect(filters.last.categoryIds, {'work'});
    expect(filters.last.maxAgeDays, 7);
    expect(filters.last.taskStatuses, {GraphTaskStatus.inProgress});

    await tester.scrollUntilVisible(
      find.text('All'),
      -160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(filters.last.categoryIds, {'work'});
    expect(filters.last.maxAgeDays, isNull);
    expect(filters.last.taskStatuses, {GraphTaskStatus.inProgress});

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Relationships'), findsNothing);
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

  test('uses primary and inverse labels for every typed relationship', () {
    final messages = AppLocalizationsEn();
    const expected = {
      GraphEdgeKind.blocks: ('Blocks', 'Is blocked by'),
      GraphEdgeKind.followsUp: ('Follows up on', 'Has follow-up'),
      GraphEdgeKind.duplicates: ('Duplicates', 'Is duplicated by'),
      GraphEdgeKind.fixes: ('Fixes', 'Is fixed by'),
      GraphEdgeKind.supersedes: ('Supersedes', 'Is superseded by'),
    };

    for (final entry in expected.entries) {
      expect(
        graphDirectionalEdgeLabel(
          messages,
          entry.key,
          outgoing: true,
        ),
        entry.value.$1,
      );
      expect(
        graphDirectionalEdgeLabel(
          messages,
          entry.key,
          outgoing: false,
        ),
        entry.value.$2,
      );
    }

    expect(
      {
        for (final kind in const [
          GraphEdgeKind.containment,
          GraphEdgeKind.association,
          GraphEdgeKind.provenance,
          GraphEdgeKind.evaluation,
          GraphEdgeKind.checklist,
        ])
          kind: graphDirectionalEdgeLabel(messages, kind, outgoing: false),
      },
      {
        GraphEdgeKind.containment: 'in project',
        GraphEdgeKind.association: 'linked entry',
        GraphEdgeKind.provenance: 'AI source',
        GraphEdgeKind.evaluation: 'rating',
        GraphEdgeKind.checklist: 'checklist',
      },
    );
  });
}
