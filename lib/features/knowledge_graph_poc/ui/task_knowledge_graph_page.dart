/// In-app page hosting the knowledge-graph explorer for a real task
/// (ADR 0029 Phase 1). Loads the task's link neighborhood via
/// [taskGraphProvider] and renders it with real category colors.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/state/task_graph_provider.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';

/// Adds [expansion]'s nodes and edges to [current] without changing the
/// scenario seed, then recomputes layout for the combined graph.
Future<TaskGraphData> mergeTaskGraphData(
  TaskGraphData current,
  TaskGraphData expansion, {
  Future<GraphLayout> Function(GraphScenario scenario)? layoutBuilder,
}) async {
  final nodeById = <String, GraphNode>{};
  final orderedNodeIds = <String>[];
  void addNode(GraphNode node) {
    if (!nodeById.containsKey(node.id)) {
      orderedNodeIds.add(node.id);
    }
    nodeById[node.id] = node;
  }

  current.scenario.nodes.forEach(addNode);
  expansion.scenario.nodes.forEach(addNode);

  final edgeByKey = <String, GraphEdge>{};
  final orderedEdgeKeys = <String>[];
  void addEdge(GraphEdge edge) {
    if (!nodeById.containsKey(edge.fromId) ||
        !nodeById.containsKey(edge.toId)) {
      return;
    }
    final key = '${edge.fromId}|${edge.toId}|${edge.kind.name}';
    if (!edgeByKey.containsKey(key)) {
      orderedEdgeKeys.add(key);
    }
    edgeByKey[key] = edge;
  }

  current.scenario.edges.forEach(addEdge);
  expansion.scenario.edges.forEach(addEdge);

  final scenario = GraphScenario(
    name: current.scenario.name,
    seedId: current.scenario.seedId,
    nodes: [for (final id in orderedNodeIds) nodeById[id]!],
    edges: [for (final key in orderedEdgeKeys) edgeByKey[key]!],
    now: current.scenario.now,
  );
  final layout = await (layoutBuilder ?? layoutTaskGraphOffThread)(scenario);
  return TaskGraphData(
    scenario: scenario,
    categoryColors: {
      ...current.categoryColors,
      ...expansion.categoryColors,
    },
    categoryNames: {
      ...current.categoryNames,
      ...expansion.categoryNames,
    },
    layout: layout,
  );
}

class TaskKnowledgeGraphPage extends ConsumerStatefulWidget {
  const TaskKnowledgeGraphPage({
    required this.taskId,
    this.mergeGraphData,
    super.key,
  });

  final String taskId;

  /// Optional test hook for making additive expansion layout deterministic in
  /// widget tests. Production uses [mergeTaskGraphData].
  final Future<TaskGraphData> Function(
    TaskGraphData current,
    TaskGraphData expansion,
  )?
  mergeGraphData;

  @override
  ConsumerState<TaskKnowledgeGraphPage> createState() =>
      _TaskKnowledgeGraphPageState();
}

class _TaskKnowledgeGraphPageState
    extends ConsumerState<TaskKnowledgeGraphPage> {
  TaskGraphData? _visibleData;
  TaskGraphData? _seedData;
  final Map<String, TaskGraphData> _expansions = {};
  final Map<String, ProviderSubscription<AsyncValue<TaskGraphData?>>>
  _expansionSubscriptions = {};
  String? _initialFocusId;
  String? _initialPreviousFocusId;
  TaskGraphData? _lastMergeSeedData;
  int _expansionVersion = 0;
  int _lastMergeExpansionVersion = -1;
  int _mergeRequestId = 0;

  @override
  void didUpdateWidget(TaskKnowledgeGraphPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _visibleData = null;
      _seedData = null;
      _clearExpansions();
      _initialFocusId = null;
      _initialPreviousFocusId = null;
    }
  }

  @override
  void dispose() {
    _clearExpansions();
    super.dispose();
  }

  void _clearExpansions() {
    for (final sub in _expansionSubscriptions.values) {
      sub.close();
    }
    _expansionSubscriptions.clear();
    _expansions.clear();
    _expansionVersion++;
    _lastMergeSeedData = null;
    _lastMergeExpansionVersion = -1;
    _mergeRequestId++;
  }

  void _handleTaskFocusChanged(String taskId, String previousFocusId) {
    if (taskId == widget.taskId ||
        _expansionSubscriptions.containsKey(taskId)) {
      return;
    }
    _initialFocusId = taskId;
    _initialPreviousFocusId = previousFocusId;
    _listenToExpansion(taskId);
  }

  void _listenToExpansion(String taskId) {
    final subscription = ref.listenManual(
      taskGraphProvider(taskId),
      (_, next) => _handleExpansionUpdate(taskId, next),
    );
    _expansionSubscriptions[taskId] = subscription;
    _handleExpansionUpdate(taskId, ref.read(taskGraphProvider(taskId)));
  }

  void _handleExpansionUpdate(
    String taskId,
    AsyncValue<TaskGraphData?> next,
  ) {
    if (!_expansionSubscriptions.containsKey(taskId)) return;

    if (next.hasError) {
      _logExpansionError(next.error!, next.stackTrace ?? StackTrace.current);
      _removeExpansion(taskId);
      return;
    }

    final expansion = next.asData?.value;
    if (expansion == null) return;

    _expansions[taskId] = expansion;
    _expansionVersion++;
    final seedData =
        _seedData ?? ref.read(taskGraphProvider(widget.taskId)).asData?.value;
    if (seedData != null) {
      _scheduleRemerge(seedData);
    }
  }

  void _logExpansionError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    getIt<LoggingService>().captureException(
      error,
      domain: 'KNOWLEDGE_GRAPH',
      subDomain: 'taskGraphProvider.expand',
      stackTrace: stackTrace,
    );
  }

  void _removeExpansion(String taskId) {
    _expansionSubscriptions.remove(taskId)?.close();
    if (_expansions.remove(taskId) != null) {
      _expansionVersion++;
      final seedData = _seedData;
      if (seedData != null) {
        _scheduleRemerge(seedData);
      }
    }
  }

  void _scheduleRemerge(TaskGraphData seedData) {
    if (identical(_lastMergeSeedData, seedData) &&
        _lastMergeExpansionVersion == _expansionVersion) {
      return;
    }
    _lastMergeSeedData = seedData;
    _lastMergeExpansionVersion = _expansionVersion;
    final requestId = ++_mergeRequestId;
    unawaited(_remergeWithSeed(seedData, requestId, _expansionVersion));
  }

  Future<void> _remergeWithSeed(
    TaskGraphData seedData,
    int requestId,
    int expansionVersion,
  ) async {
    try {
      final merge = widget.mergeGraphData ?? mergeTaskGraphData;
      final expansions = List<TaskGraphData>.of(_expansions.values);
      var merged = seedData;
      for (final expansion in expansions) {
        merged = await merge(merged, expansion);
      }
      if (!mounted ||
          requestId != _mergeRequestId ||
          expansionVersion != _expansionVersion) {
        return;
      }
      setState(() => _visibleData = merged);
    } on Object catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'KNOWLEDGE_GRAPH',
        subDomain: 'taskGraphProvider.merge',
        stackTrace: stackTrace,
      );
    }
  }

  void _setVisibleData(TaskGraphData data) {
    _seedData = data;
    if (_expansions.isEmpty) {
      _visibleData = data;
      _lastMergeSeedData = null;
      _lastMergeExpansionVersion = -1;
      return;
    }
    _scheduleRemerge(data);
  }

  Widget _graphContent(TaskGraphData? data) {
    // Only the focus node and nothing linked -> nothing to explore.
    if (data == null || data.scenario.nodes.length <= 1) {
      return const _EmptyState();
    }
    _setVisibleData(data);
    final visibleData = _visibleData ?? data;
    // The view derives its state once in initState, so key it on the
    // scenario to rebuild from scratch when fresh data arrives.
    return KnowledgeGraphView(
      key: ValueKey(visibleData.scenario),
      scenario: visibleData.scenario,
      categoryColors: visibleData.categoryColors,
      categoryNames: visibleData.categoryNames,
      initialFocusId: _initialFocusId,
      initialPreviousFocusId: _initialPreviousFocusId,
      onTaskFocusChanged: _handleTaskFocusChanged,
      // Relaxed off the main thread in the provider so the first frame
      // renders without a layout pass on the UI thread.
      layout: visibleData.layout,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    // Log provider failures with full detail for developers; the UI only ever
    // shows a generic, localized message (never raw exception text).
    ref.listen(taskGraphProvider(widget.taskId), (_, next) {
      if (next case AsyncError(:final error, :final stackTrace)) {
        getIt<LoggingService>().captureException(
          error,
          domain: 'KNOWLEDGE_GRAPH',
          subDomain: 'taskGraphProvider',
          stackTrace: stackTrace,
        );
      }
    });

    final graph = ref.watch(taskGraphProvider(widget.taskId));
    final mediaQuery = MediaQuery.of(context);

    final content = graph.when(
      // Keep the last rendered graph while a background refresh (sync / db
      // notification) reloads, instead of flashing the spinner.
      skipLoadingOnReload: true,
      data: _graphContent,
      loading: () => _visibleData == null
          ? const Center(child: CircularProgressIndicator())
          : _graphContent(_visibleData),
      error: (_, _) => const _ErrorState(),
    );

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: Stack(
        children: [
          // The graph fills the whole body, full-bleed under the floating
          // header. Reserving the header's height in the child's top padding
          // (the same contract `extendBodyBehindAppBar` uses) keeps the view's
          // own top-left chrome below the header - without banding off a header
          // row, and without a full-width bar that would swallow taps over the
          // inspector docked on the right.
          Positioned.fill(
            child: MediaQuery(
              data: mediaQuery.copyWith(
                padding: mediaQuery.padding.copyWith(
                  top: mediaQuery.padding.top + kToolbarHeight,
                ),
              ),
              child: content,
            ),
          ),
          // Compact header: a back affordance + the page title, occupying only
          // the top-left corner so it overlays the graph as part of the same
          // canvas (top-left aligned, no background, no gap).
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Padding(
                    padding: EdgeInsets.only(right: tokens.spacing.step4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BackButton(),
                        Text(
                          context.messages.knowledgeGraphTitle,
                          style: tokens.typography.styles.subtitle.subtitle1
                              .copyWith(color: tokens.colors.text.highEmphasis),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 48,
            color: tokens.colors.text.lowEmphasis,
          ),
          SizedBox(height: tokens.spacing.step4),
          Text(
            context.messages.knowledgeGraphEmpty,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Text(
          context.messages.knowledgeGraphError,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      ),
    );
  }
}
