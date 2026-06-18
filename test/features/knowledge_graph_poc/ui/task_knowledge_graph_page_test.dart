import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/state/task_graph_provider.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_view.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/task_knowledge_graph_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

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
          ..registerSingleton<LoggingService>(mockLoggingService);
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
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const TaskKnowledgeGraphPage(taskId: taskId),
        mediaQueryData: MediaQueryData(size: surface),
        overrides: [providerOverride],
      ),
    );
  }

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
}
