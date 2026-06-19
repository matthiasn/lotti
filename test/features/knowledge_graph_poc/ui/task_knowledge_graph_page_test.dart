import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/state/task_graph_provider.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/entry_detail_sidebar.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_painter.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_view.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/task_knowledge_graph_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Minimal [EntryController] resolving to `null` so the opened
/// [EntryDetailSidebar] renders its cheap "Entry not found" shell instead of
/// building the heavy real detail page.
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) async => null;
}

class _BoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  bool get value => state;

  set value(bool value) => state = value;
}

void main() {
  const taskId = 'task-1';
  // Deterministic clock for every node/scenario timestamp (never DateTime.now).
  final fixedNow = DateTime(2026, 6, 15);

  late MockLoggingService mockLoggingService;

  // The localized strings the page renders, resolved from the generated ARB
  // bundle so the test asserts against the real source of truth.
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    mockLoggingService = MockLoggingService();
    stubLoggingService(mockLoggingService);
    await setUpTestGetIt(
      additionalSetup: () {
        // The page's ref.listen error path logs through getIt<LoggingService>;
        // swap the real one registered by setUpTestGetIt for a verifiable mock.
        getIt
          ..unregister<LoggingService>()
          ..registerSingleton<LoggingService>(mockLoggingService)
          // EntryController's field initializers touch getIt<EditorStateService>
          // when the detail overlay opens; a mock is enough for the null path.
          ..registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  /// A graph node with deterministic timestamp; only the parts the page cares
  /// about (node count) really matter here.
  GraphNode node(String id, {GraphNodeType type = GraphNodeType.task}) =>
      GraphNode(
        id: id,
        type: type,
        label: 'Node $id',
        categoryId: kUncategorized,
        createdAt: fixedNow,
      );

  /// A real multi-node scenario so the data branch renders the actual view
  /// (nodes.length > 1).
  TaskGraphData multiNodeData() => TaskGraphData(
    scenario: GraphScenario(
      name: 'Seed task',
      seedId: taskId,
      nodes: [
        node(taskId),
        node('linked-1', type: GraphNodeType.textEntry),
        node('linked-2', type: GraphNodeType.project),
      ],
      edges: const [
        GraphEdge(
          fromId: taskId,
          toId: 'linked-1',
          kind: GraphEdgeKind.association,
        ),
        GraphEdge(
          fromId: 'linked-2',
          toId: taskId,
          kind: GraphEdgeKind.containment,
        ),
      ],
      now: fixedNow,
    ),
    categoryColors: const {},
  );

  TaskGraphData projectHubData({
    bool includeSeedNote = false,
    bool includeThirdTask = false,
  }) => TaskGraphData(
    scenario: GraphScenario(
      name: 'Seed task',
      seedId: taskId,
      nodes: [
        node(taskId),
        node('project', type: GraphNodeType.project),
        node('task-2'),
        if (includeThirdTask) node('task-3'),
        if (includeSeedNote) node('seed-note', type: GraphNodeType.textEntry),
      ],
      edges: [
        const GraphEdge(
          fromId: 'project',
          toId: taskId,
          kind: GraphEdgeKind.containment,
        ),
        const GraphEdge(
          fromId: 'project',
          toId: 'task-2',
          kind: GraphEdgeKind.containment,
        ),
        if (includeThirdTask)
          const GraphEdge(
            fromId: 'project',
            toId: 'task-3',
            kind: GraphEdgeKind.containment,
          ),
        if (includeSeedNote)
          const GraphEdge(
            fromId: taskId,
            toId: 'seed-note',
            kind: GraphEdgeKind.association,
          ),
      ],
      now: fixedNow,
    ),
    categoryColors: const {},
  );

  TaskGraphData taskTwoExpansionData({bool includeExtraNote = false}) =>
      TaskGraphData(
        scenario: GraphScenario(
          name: 'Second task',
          seedId: 'task-2',
          nodes: [
            node('task-2'),
            node('project', type: GraphNodeType.project),
            node('note-2', type: GraphNodeType.textEntry),
            if (includeExtraNote) node('note-3', type: GraphNodeType.textEntry),
          ],
          edges: [
            const GraphEdge(
              fromId: 'project',
              toId: 'task-2',
              kind: GraphEdgeKind.containment,
            ),
            const GraphEdge(
              fromId: 'task-2',
              toId: 'note-2',
              kind: GraphEdgeKind.association,
            ),
            if (includeExtraNote)
              const GraphEdge(
                fromId: 'task-2',
                toId: 'note-3',
                kind: GraphEdgeKind.association,
              ),
          ],
          now: fixedNow,
        ),
        categoryColors: const {kUncategorized: Colors.purple},
        categoryNames: const {kUncategorized: 'Inbox'},
      );

  TaskGraphData taskThreeExpansionData() => TaskGraphData(
    scenario: GraphScenario(
      name: 'Third task',
      seedId: 'task-3',
      nodes: [
        node('task-3'),
        node('project', type: GraphNodeType.project),
        node('note-4', type: GraphNodeType.textEntry),
      ],
      edges: [
        const GraphEdge(
          fromId: 'project',
          toId: 'task-3',
          kind: GraphEdgeKind.containment,
        ),
        const GraphEdge(
          fromId: 'task-3',
          toId: 'note-4',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: fixedNow,
    ),
    categoryColors: const {},
  );

  TaskGraphData alternateTaskData() => TaskGraphData(
    scenario: GraphScenario(
      name: 'Fresh task',
      seedId: 'task-fresh',
      nodes: [
        node('task-fresh'),
        node('fresh-note', type: GraphNodeType.textEntry),
      ],
      edges: [
        const GraphEdge(
          fromId: 'task-fresh',
          toId: 'fresh-note',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: fixedNow,
    ),
    categoryColors: const {},
  );

  /// A scenario containing only the seed node — proves the `<= 1` empty guard.
  TaskGraphData seedOnlyData() => TaskGraphData(
    scenario: GraphScenario(
      name: 'Seed task',
      seedId: taskId,
      nodes: [node(taskId)],
      edges: const [],
      now: fixedNow,
    ),
    categoryColors: const {},
  );

  /// Builds the page under test with the family provider instance overridden.
  Future<void> pumpPage(
    WidgetTester tester,
    Override providerOverride, {
    // Phone-sized surface keeps the page off the desktop inspector path; either
    // is fine for the page-level branches we assert.
    Size surface = const Size(390, 844),
    Future<TaskGraphData> Function(TaskGraphData, TaskGraphData)?
    mergeGraphData,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        TaskKnowledgeGraphPage(
          taskId: taskId,
          mergeGraphData: mergeGraphData,
        ),
        mediaQueryData: MediaQueryData(size: surface),
        overrides: [providerOverride, ...extraOverrides],
      ),
    );
  }

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

  Set<String> paintedNodeIds(WidgetTester tester) => {
    for (final node in painterOf(tester).scenario.nodes) node.id,
  };

  Offset screenPosOf(WidgetTester tester, String nodeId) {
    final painter = painterOf(tester);
    final viewTopLeft = tester.getTopLeft(find.byType(KnowledgeGraphView));
    return viewTopLeft +
        painter.positions[nodeId]! * painter.scale +
        painter.pan;
  }

  bool graphContainsNode(WidgetTester tester, String id) =>
      find.byType(KnowledgeGraphView).evaluate().isNotEmpty &&
      paintedNodeIds(tester).contains(id);

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    String reason = 'condition',
  }) async {
    for (var i = 0; i < 12 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (!condition()) {
      fail('Timed out waiting for $reason');
    }
  }

  test(
    'mergeTaskGraphData adds expansion nodes without changing base seed',
    () async {
      final merged = await mergeTaskGraphData(
        projectHubData(),
        taskTwoExpansionData(),
        layoutBuilder: (scenario) async => computeLayoutForScenario(scenario),
      );

      expect(merged.scenario.seedId, taskId);
      expect(merged.scenario.name, 'Seed task');
      expect(
        merged.scenario.nodes.map((node) => node.id),
        containsAllInOrder(['task-1', 'project', 'task-2', 'note-2']),
      );
      expect(
        merged.scenario.edges.where(
          (edge) =>
              edge.fromId == 'project' &&
              edge.toId == 'task-2' &&
              edge.kind == GraphEdgeKind.containment,
        ),
        hasLength(1),
      );
      expect(
        merged.scenario.edges.any(
          (edge) =>
              edge.fromId == 'task-2' &&
              edge.toId == 'note-2' &&
              edge.kind == GraphEdgeKind.association,
        ),
        isTrue,
      );
      expect(merged.categoryColors[kUncategorized], Colors.purple);
      expect(merged.categoryNames[kUncategorized], 'Inbox');
      expect(merged.layout!.positions.keys, contains('note-2'));
    },
  );

  test(
    'mergeTaskGraphData drops expansion edges with missing endpoints',
    () async {
      final expansion = TaskGraphData(
        scenario: GraphScenario(
          name: 'Orphan edge',
          seedId: 'task-2',
          nodes: [node('task-2')],
          edges: const [
            GraphEdge(
              fromId: 'task-2',
              toId: 'missing-note',
              kind: GraphEdgeKind.association,
            ),
          ],
          now: fixedNow,
        ),
        categoryColors: const {},
      );

      final merged = await mergeTaskGraphData(
        projectHubData(),
        expansion,
        layoutBuilder: (scenario) async => computeLayoutForScenario(scenario),
      );

      expect(
        merged.scenario.nodes.map((node) => node.id),
        isNot(contains('missing-note')),
      );
      expect(
        merged.scenario.edges.where((edge) => edge.toId == 'missing-note'),
        isEmpty,
      );
    },
  );

  testWidgets(
    'renders KnowledgeGraphView for a multi-node graph (no empty/error)',
    (tester) async {
      await pumpPage(
        tester,
        taskGraphProvider(taskId).overrideWith(
          (ref) async => multiNodeData(),
        ),
      );
      // Resolve the future + first layout pass.
      await tester.pump();

      // The graph view is shown...
      expect(find.byType(KnowledgeGraphView), findsOneWidget);
      // ...and neither the empty nor the error state leaked through.
      expect(find.text(l10n.knowledgeGraphEmpty), findsNothing);
      expect(find.text(l10n.knowledgeGraphError), findsNothing);
      // ...and there is no loading spinner once data resolved.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The page title is always present.
      expect(find.text(l10n.knowledgeGraphTitle), findsOneWidget);
    },
  );

  testWidgets('renders empty state when data is null', (tester) async {
    await pumpPage(
      tester,
      taskGraphProvider(taskId).overrideWith(
        (ref) async => null,
      ),
    );
    await tester.pump();

    expect(find.text(l10n.knowledgeGraphEmpty), findsOneWidget);
    expect(find.byType(KnowledgeGraphView), findsNothing);
    expect(find.text(l10n.knowledgeGraphError), findsNothing);
    expect(find.text(l10n.knowledgeGraphTitle), findsOneWidget);
  });

  testWidgets(
    'renders empty state when only the seed node is present (<=1 guard)',
    (tester) async {
      await pumpPage(
        tester,
        taskGraphProvider(taskId).overrideWith(
          (ref) async => seedOnlyData(),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.knowledgeGraphEmpty), findsOneWidget);
      expect(find.byType(KnowledgeGraphView), findsNothing);
      expect(find.text(l10n.knowledgeGraphError), findsNothing);
      expect(find.text(l10n.knowledgeGraphTitle), findsOneWidget);
    },
  );

  testWidgets('shows a spinner while the graph is loading', (tester) async {
    // A never-completing future keeps the provider in the loading state.
    final completer = Completer<TaskGraphData?>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete(null);
    });

    await pumpPage(
      tester,
      taskGraphProvider(taskId).overrideWith((ref) => completer.future),
    );
    // Single pump so the spinner is visible (future never resolves).
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(KnowledgeGraphView), findsNothing);
    expect(find.text(l10n.knowledgeGraphEmpty), findsNothing);
    expect(find.text(l10n.knowledgeGraphError), findsNothing);
    expect(find.text(l10n.knowledgeGraphTitle), findsOneWidget);
  });

  testWidgets(
    'keeps the cached graph visible when a fresh provider is loading',
    (tester) async {
      final pageKey = GlobalKey();
      final loadingCompleter = Completer<TaskGraphData?>();
      addTearDown(() {
        if (!loadingCompleter.isCompleted) loadingCompleter.complete(null);
      });

      Widget buildPage(Override providerOverride) => makeTestableWidgetNoScroll(
        TaskKnowledgeGraphPage(key: pageKey, taskId: taskId),
        mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        overrides: [providerOverride],
      );

      await tester.pumpWidget(
        buildPage(
          taskGraphProvider(taskId).overrideWith(
            (ref) async => multiNodeData(),
          ),
        ),
      );
      await tester.pump();

      expect(paintedNodeIds(tester), containsAll([taskId, 'linked-1']));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(
        buildPage(
          taskGraphProvider(
            taskId,
          ).overrideWith((ref) => loadingCompleter.future),
        ),
      );
      await tester.pump();

      expect(find.byType(KnowledgeGraphView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(paintedNodeIds(tester), containsAll([taskId, 'linked-1']));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'walking project then sibling task additively loads the task neighborhood',
    (tester) async {
      var expansionReads = 0;
      await pumpPage(
        tester,
        taskGraphProvider(taskId).overrideWith(
          (ref) async => projectHubData(),
        ),
        surface: const Size(1280, 800),
        mergeGraphData: (current, expansion) => mergeTaskGraphData(
          current,
          expansion,
          layoutBuilder: (scenario) async => computeLayoutForScenario(scenario),
        ),
        extraOverrides: [
          taskGraphProvider('task-2').overrideWith((ref) async {
            expansionReads++;
            return taskTwoExpansionData();
          }),
        ],
      );
      await tester.pump();

      expect(find.text('Node note-2'), findsNothing);

      await tester.tap(find.text('Node project').last);
      await tester.pump();
      expect(expansionReads, 0);
      expect(find.text('Node task-2'), findsWidgets);

      await tester.tap(find.text('Node task-2').last);
      await tester.pump();
      expect(expansionReads, 1);

      for (
        var i = 0;
        i < 10 && find.text('Node note-2').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Node note-2'), findsWidgets);
      expect(find.text('Node project'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ignores seed-task focus callbacks',
    (tester) async {
      var expansionReads = 0;
      await pumpPage(
        tester,
        taskGraphProvider(taskId).overrideWith(
          (ref) async => projectHubData(),
        ),
        surface: const Size(1280, 800),
        mergeGraphData: (current, expansion) => mergeTaskGraphData(
          current,
          expansion,
          layoutBuilder: (scenario) async => computeLayoutForScenario(scenario),
        ),
        extraOverrides: [
          taskGraphProvider('task-2').overrideWith((ref) async {
            expansionReads++;
            return taskTwoExpansionData();
          }),
        ],
      );
      await tester.pump();

      await tester.tap(find.text('Node project').last);
      await tester.pump();
      await tester.tap(find.text('Node task-1').last);
      await tester.pump();
      expect(expansionReads, 0);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded graph remerges seed and expanded task provider updates',
    (tester) async {
      var seedHasNote = false;
      var expansionHasExtraNote = false;
      var expansionReads = 0;

      final result = makeTestableWidgetWithContainer(
        TaskKnowledgeGraphPage(
          taskId: taskId,
          mergeGraphData: (current, expansion) => mergeTaskGraphData(
            current,
            expansion,
            layoutBuilder: (scenario) async =>
                computeLayoutForScenario(scenario),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          taskGraphProvider(taskId).overrideWith(
            (ref) async => projectHubData(includeSeedNote: seedHasNote),
          ),
          taskGraphProvider('task-2').overrideWith((ref) async {
            expansionReads++;
            return taskTwoExpansionData(
              includeExtraNote: expansionHasExtraNote,
            );
          }),
        ],
      );
      addTearDown(result.container.dispose);

      await tester.pumpWidget(result.widget);
      await tester.pump();

      await tester.tap(find.text('Node project').last);
      await tester.pump();
      await tester.tap(find.text('Node task-2').last);
      await tester.pump();

      await pumpUntil(
        tester,
        () => paintedNodeIds(tester).contains('note-2'),
        reason: 'task-2 expansion to render note-2',
      );
      expect(paintedNodeIds(tester), contains('note-2'));
      expect(expansionReads, 1);

      seedHasNote = true;
      await tester.runAsync(() async {
        result.container.invalidate(taskGraphProvider(taskId));
        await result.container.read(taskGraphProvider(taskId).future);
      });
      await tester.pump();
      await pumpUntil(
        tester,
        () => paintedNodeIds(tester).contains('seed-note'),
        reason: 'seed refresh to preserve expansion and render seed-note',
      );

      final afterSeedRefresh = paintedNodeIds(tester);
      expect(afterSeedRefresh, contains('seed-note'));
      expect(afterSeedRefresh, contains('note-2'));

      expansionHasExtraNote = true;
      await tester.runAsync(() async {
        result.container.invalidate(taskGraphProvider('task-2'));
        await result.container.read(taskGraphProvider('task-2').future);
      });
      await tester.pump();
      await pumpUntil(
        tester,
        () => paintedNodeIds(tester).contains('note-3'),
        reason: 'expanded task refresh to render note-3',
      );

      final afterExpansionRefresh = paintedNodeIds(tester);
      expect(afterExpansionRefresh, contains('seed-note'));
      expect(afterExpansionRefresh, contains('note-2'));
      expect(afterExpansionRefresh, contains('note-3'));
      expect(expansionReads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ignores expanded task provider results with no graph data',
    (tester) async {
      var expansionReads = 0;

      final result = makeTestableWidgetWithContainer(
        const TaskKnowledgeGraphPage(taskId: taskId),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          taskGraphProvider(taskId).overrideWith(
            (ref) async => projectHubData(),
          ),
          taskGraphProvider(
            'task-2',
          ).overrideWith((ref) {
            expansionReads++;
            return null;
          }),
        ],
      );
      addTearDown(result.container.dispose);

      await tester.pumpWidget(result.widget);
      await tester.pump();

      await tester.tap(find.text('Node project').last);
      await tester.pump();
      await tester.tap(find.text('Node task-2').last);
      await tester.pump();
      await tester.pump();

      expect(expansionReads, greaterThan(0));
      expect(paintedNodeIds(tester), isNot(contains('note-2')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logs expansion provider failures and removes the cached expansion',
    (tester) async {
      final failure = Exception('expanded task failed');
      final expansionShouldThrowProvider =
          NotifierProvider<_BoolNotifier, bool>(_BoolNotifier.new);
      var expansionReads = 0;

      final result = makeTestableWidgetWithContainer(
        TaskKnowledgeGraphPage(
          taskId: taskId,
          mergeGraphData: (current, expansion) => mergeTaskGraphData(
            current,
            expansion,
            layoutBuilder: (scenario) async =>
                computeLayoutForScenario(scenario),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          taskGraphProvider.overrideWith((ref, visibleTaskId) {
            if (visibleTaskId == taskId) {
              return projectHubData();
            }
            if (visibleTaskId == 'task-2') {
              expansionReads++;
              if (ref.watch(expansionShouldThrowProvider)) throw failure;
              return taskTwoExpansionData();
            }
            return null;
          }),
        ],
      );
      addTearDown(result.container.dispose);

      await tester.pumpWidget(result.widget);
      await tester.pump();

      await tester.tap(find.text('Node project').last);
      await tester.pump();
      await tester.tap(find.text('Node task-2').last);
      await tester.pump();
      await pumpUntil(
        tester,
        () => graphContainsNode(tester, 'note-2'),
        reason: 'task-2 expansion to render before failing',
      );
      expect(expansionReads, 1);

      result.container.read(expansionShouldThrowProvider.notifier).value = true;
      await tester.pump();
      await tester.pump();

      await pumpUntil(
        tester,
        () => !graphContainsNode(tester, 'note-2'),
        reason: 'failed expansion to be removed from the visible graph',
      );

      final nodeIds = paintedNodeIds(tester);
      expect(nodeIds, containsAll([taskId, 'project', 'task-2']));
      expect(nodeIds, isNot(contains('note-2')));
      expect(expansionReads, greaterThan(1));

      final captured = verify(
        () => mockLoggingService.captureException(
          captureAny<Object>(),
          domain: 'KNOWLEDGE_GRAPH',
          subDomain: 'taskGraphProvider.expand',
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).captured;
      expect(captured.single, same(failure));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logs merge failures without replacing the visible seed graph',
    (tester) async {
      final failure = Exception('merge failed');

      await pumpPage(
        tester,
        taskGraphProvider(taskId).overrideWith(
          (ref) async => projectHubData(),
        ),
        surface: const Size(1280, 800),
        mergeGraphData: (current, expansion) async => throw failure,
        extraOverrides: [
          taskGraphProvider('task-2').overrideWith(
            (ref) async => taskTwoExpansionData(),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.text('Node project').last);
      await tester.pump();
      await tester.tap(find.text('Node task-2').last);
      await tester.pump();
      await tester.pump();

      expect(
        paintedNodeIds(tester),
        containsAll([taskId, 'project', 'task-2']),
      );
      expect(paintedNodeIds(tester), isNot(contains('note-2')));
      final captured = verify(
        () => mockLoggingService.captureException(
          captureAny<Object>(),
          domain: 'KNOWLEDGE_GRAPH',
          subDomain: 'taskGraphProvider.merge',
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).captured;
      expect(captured.single, same(failure));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ignores an in-flight expansion merge after the page task changes',
    (tester) async {
      final currentTaskId = ValueNotifier(taskId);
      final staleMergeGate = Completer<void>();
      var staleMergeStarted = false;

      Future<TaskGraphData> mergeGraphData(
        TaskGraphData current,
        TaskGraphData expansion,
      ) async {
        if (expansion.scenario.seedId == 'task-2' && !staleMergeStarted) {
          staleMergeStarted = true;
          await staleMergeGate.future;
        }
        return mergeTaskGraphData(
          current,
          expansion,
          layoutBuilder: (scenario) async => computeLayoutForScenario(scenario),
        );
      }

      final result = makeTestableWidgetWithContainer(
        ValueListenableBuilder<String>(
          valueListenable: currentTaskId,
          builder: (context, visibleTaskId, child) => TaskKnowledgeGraphPage(
            taskId: visibleTaskId,
            mergeGraphData: mergeGraphData,
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          taskGraphProvider(taskId).overrideWith(
            (ref) async => projectHubData(),
          ),
          taskGraphProvider('task-2').overrideWith(
            (ref) async => taskTwoExpansionData(),
          ),
          taskGraphProvider('task-fresh').overrideWith(
            (ref) async => alternateTaskData(),
          ),
        ],
      );
      addTearDown(result.container.dispose);
      addTearDown(currentTaskId.dispose);

      await tester.pumpWidget(result.widget);
      await tester.pump();
      await tester.tap(find.text('Node project').last);
      await tester.pump();
      await tester.tap(find.text('Node task-2').last);
      await tester.pump();
      await pumpUntil(
        tester,
        () => staleMergeStarted,
        reason: 'stale merge to start before switching tasks',
      );

      currentTaskId.value = 'task-fresh';
      await tester.pump();
      await pumpUntil(
        tester,
        () => graphContainsNode(tester, 'fresh-note'),
        reason: 'fresh task graph to replace old task graph',
      );

      expect(paintedNodeIds(tester), contains('fresh-note'));
      expect(paintedNodeIds(tester), isNot(contains('note-2')));

      staleMergeGate.complete();
      await tester.pump();
      await pumpUntil(
        tester,
        () => graphContainsNode(tester, 'fresh-note'),
        reason: 'stale merge completion to keep fresh task graph',
      );

      expect(paintedNodeIds(tester), contains('fresh-note'));
      expect(paintedNodeIds(tester), isNot(contains('note-2')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps both expansions when back-to-back merges complete out of order',
    (tester) async {
      final mergeGates = <Completer<void>>[];

      Future<TaskGraphData> controlledMerge(
        TaskGraphData current,
        TaskGraphData expansion,
      ) async {
        final gate = Completer<void>();
        mergeGates.add(gate);
        await gate.future;
        return mergeTaskGraphData(
          current,
          expansion,
          layoutBuilder: (scenario) async => computeLayoutForScenario(scenario),
        );
      }

      await pumpPage(
        tester,
        taskGraphProvider(taskId).overrideWith(
          (ref) async => projectHubData(includeThirdTask: true),
        ),
        surface: const Size(1280, 800),
        mergeGraphData: controlledMerge,
        extraOverrides: [
          taskGraphProvider('task-2').overrideWith(
            (ref) async => taskTwoExpansionData(),
          ),
          taskGraphProvider('task-3').overrideWith(
            (ref) async => taskThreeExpansionData(),
          ),
        ],
      );
      await tester.pump();

      await tester.tapAt(screenPosOf(tester, 'project'));
      await tester.pump();
      await tester.tapAt(screenPosOf(tester, 'task-2'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => mergeGates.isNotEmpty,
        reason: 'first merge gate',
      );

      await tester.tapAt(screenPosOf(tester, 'task-3'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => mergeGates.length >= 2,
        reason: 'second merge gate',
      );

      mergeGates[1].complete();
      await tester.pump();
      await pumpUntil(
        tester,
        () => mergeGates.length >= 3,
        reason: 'remerge gate for both expansions',
      );

      mergeGates[2].complete();
      await tester.pump();
      await pumpUntil(
        tester,
        () =>
            graphContainsNode(tester, 'note-2') &&
            graphContainsNode(tester, 'note-4'),
        reason: 'both out-of-order expansions to render',
      );

      expect(paintedNodeIds(tester), containsAll(['note-2', 'note-4']));

      mergeGates[0].complete();
      await tester.pump();
      await pumpUntil(
        tester,
        () =>
            graphContainsNode(tester, 'note-2') &&
            graphContainsNode(tester, 'note-4'),
        reason: 'stale first merge to leave both expansions visible',
      );

      expect(paintedNodeIds(tester), containsAll(['note-2', 'note-4']));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders error state and logs the failure with KNOWLEDGE_GRAPH domain',
    (tester) async {
      final failure = Exception('boom');
      // The page registers `ref.listen` inside build, so it only fires for a
      // provider transition that happens *after* the widget is mounted and
      // idle — not for an error that is already settled on first build. So the
      // provider first resolves with a valid graph (mounted, listener live),
      // then a flag flips it to throw on recompute. The error has to propagate
      // on the real event loop for Riverpod to surface AsyncError (under the
      // synchronous test scheduler the rejected future stays AsyncLoading),
      // hence the invalidate + future-drain inside `tester.runAsync`.
      var shouldThrow = false;
      final result = makeTestableWidgetWithContainer(
        const TaskKnowledgeGraphPage(taskId: taskId),
        mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        overrides: [
          taskGraphProvider(taskId).overrideWith((ref) async {
            if (shouldThrow) throw failure;
            return multiNodeData();
          }),
        ],
      );
      addTearDown(result.container.dispose);

      await tester.pumpWidget(result.widget);
      await tester.pump();
      // Healthy first state: the graph view rendered, nothing logged yet.
      expect(find.byType(KnowledgeGraphView), findsOneWidget);
      verifyNever(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
          level: any(named: 'level'),
          type: any(named: 'type'),
        ),
      );

      // Recompute into an error and let the rejection resolve on the real loop.
      shouldThrow = true;
      await tester.runAsync(() async {
        result.container.invalidate(taskGraphProvider(taskId));
        await result.container
            .read(taskGraphProvider(taskId).future)
            .then<void>((_) {}, onError: (_) {});
      });
      // Settle the AsyncError into a rebuild + fire the build-registered
      // listener.
      await tester.pump();
      await tester.pump();

      // The UI shows the generic localized error (never raw exception text).
      expect(find.text(l10n.knowledgeGraphError), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.byType(KnowledgeGraphView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.knowledgeGraphTitle), findsOneWidget);

      // ref.listen routed the failure to the logging service with the right
      // domain/subDomain (developer-facing detail).
      final captured = verify(
        () => mockLoggingService.captureException(
          captureAny<Object>(),
          domain: 'KNOWLEDGE_GRAPH',
          subDomain: 'taskGraphProvider',
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).captured;
      expect(captured.single, same(failure));
    },
  );

  testWidgets(
    "the floating header doesn't block the inspector — Open details still "
    'fires on a desktop surface',
    (tester) async {
      // Regression: the page used to chrome the graph with a full-width AppBar
      // (`extendBodyBehindAppBar`), whose transparent toolbar absorbed taps
      // across the whole top strip — so the inspector's top-right Open button
      // stopped working. The header is now a compact top-left widget that never
      // overlaps the right-hand inspector, so the tap reaches it.
      await pumpPage(
        tester,
        taskGraphProvider(taskId).overrideWith((ref) async => multiNodeData()),
        // Wide enough that the docked inspector (and its Open button) renders.
        surface: const Size(1280, 800),
        extraOverrides: [
          // The initial focus is the seed task; resolve its controller to a
          // null entry so the overlay shows the cheap "Entry not found" shell
          // instead of building the real detail page + full provider graph.
          entryControllerProvider(
            id: taskId,
          ).overrideWith(_NullEntryController.new),
        ],
      );
      await tester.pump();

      expect(find.byType(EntryDetailSidebar), findsNothing);
      // The compact top-left header does not overlap the right-hand inspector,
      // so this tap reaches the Open button instead of being swallowed.
      await tester.tap(find.byIcon(Icons.open_in_full_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.byType(EntryDetailSidebar), findsOneWidget);
    },
  );
}
